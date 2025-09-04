# Create self signed certificates
resource "tls_private_key" "argocd" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "argocd" {
  private_key_pem = tls_private_key.argocd.private_key_pem
  subject {
    common_name  = "argocd.local"
    organization = "Demo"
  }
  validity_period_hours = 8760  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  
}

resource "kubernetes_secret" "argocd_tls" {
  metadata {
    name      = "argocd-cert"
    namespace = "argocd"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = tls_self_signed_cert.argocd.cert_pem
    "tls.key" = tls_private_key.argocd.private_key_pem
  }
  depends_on = [kubernetes_namespace.argocd]
}


# Grafana TLS
resource "tls_private_key" "grafana" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "grafana" {
  private_key_pem = tls_private_key.grafana.private_key_pem

  subject {
    common_name  = "grafana.local"
    organization = "Demo"
  }

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret" "grafana_tls" {
  metadata {
    name      = "grafana-tls"
    namespace = "monitoring"
  }

  data = {
    "tls.crt" = base64encode(tls_self_signed_cert.grafana.cert_pem)
    "tls.key" = base64encode(tls_private_key.grafana.private_key_pem)
  }

  type = "kubernetes.io/tls"
  depends_on = [kubernetes_namespace.prometheus]
}

# Prometheus TLS
resource "tls_private_key" "prometheus" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "prometheus" {
  private_key_pem = tls_private_key.prometheus.private_key_pem

  subject {
    common_name  = "prometheus.local"
    organization = "Demo"
  }

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret" "prometheus_tls" {
  metadata {
    name      = "prometheus-tls"
    namespace = "monitoring"
  }

  data = {
    "tls.crt" = base64encode(tls_self_signed_cert.prometheus.cert_pem)
    "tls.key" = base64encode(tls_private_key.prometheus.private_key_pem)
  }

  type = "kubernetes.io/tls"
  depends_on = [kubernetes_namespace.prometheus]
}