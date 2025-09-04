

provider "aws" {
  region = var.region
}


data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# --- Create cluster --- 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "mars-vpc"

  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a", "us-east-1b"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    single = {
      name = "node-group-1"

      instance_types = ["t3.xlarge"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

  }
}



data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

# Wait for EKS control plane and IAM permissions to propagate
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks]
  create_duration = "120s" 
}

# data 
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
  depends_on = [time_sleep.wait_for_cluster]
}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks.cluster_name
  depends_on = [time_sleep.wait_for_cluster]
}

# ---  Providers --- 
provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.auth.token
  load_config_file       = false
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.auth.token
}


provider "helm" {

  kubernetes {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.auth.token
  }
}


# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
  depends_on = [time_sleep.wait_for_cluster]
}

# --- ArgoCD install via Helm ---
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = "$2a$10$fmcRTllwNFnBv2ZApIQ2SO/hPvRhCvpkdMlNa6iMmoQRT3IWgP1QS"
  }
  set {
    name  = "configs.secret.argocdServerAdminPasswordMtime"
    value = timestamp()
  }

  depends_on = [kubernetes_namespace.argocd]
}

# --- Argo CD Application that syncs a Helm chart from GitHub ---

resource "kubectl_manifest" "app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.app_repo_url
        path           = var.helm_chart
        targetRevision = var.chart_version
        helm = {
          values = var.helm_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}

# Create cert-manager namespace
resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
  depends_on = [time_sleep.wait_for_cluster]
}

# Install cert-manager via Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.15.3" # update if needed

  set {
    name  = "installCRDs"
    value = "true"
  }
depends_on = [kubernetes_namespace.cert_manager]
}

# Create ingress-nginx namespace
resource "kubernetes_namespace" "ingress_nginx" {
  metadata { name = "ingress-nginx" }
  depends_on = [time_sleep.wait_for_cluster]
}

# Install ingress Nginx via Helm
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = "4.13.2" 

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  depends_on = [kubernetes_namespace.ingress_nginx]
}



#Create  ingress LB for argoCD
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = "argocd"
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"      = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["argocd.local"]
      secret_name = kubernetes_secret.argocd_tls.metadata[0].name
    }

    rule {
      host = "argocd.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.argocd]
}

# Prometheus namespace
resource "kubernetes_namespace" "prometheus" {
  metadata { name = "monitoring" }
  depends_on = [time_sleep.wait_for_cluster]
}

# Install Prometheus stack via Helm
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "77.1.2"

  values = [
    <<-EOF
    grafana:
      adminPassword: "Grafana_pass!"
      service:
        type: ClusterIP
      ingress:
        enabled: true
        ingressClassName: nginx
        hosts:
          - grafana.local
        tls:
          - hosts:
              - grafana.local
            secretName: grafana-tls
        auth:
          disable_login_form: false
          anonymous:
            enabled: false
    prometheus:
      service:
        type: ClusterIP
      ingress:
        enabled: true
        ingressClassName: nginx
        hosts:
          - prometheus.local
        tls:
          - hosts:
              - prometheus.local
            secretName: prometheus-tls
    EOF
  ]
  depends_on = [kubernetes_namespace.prometheus]
}
