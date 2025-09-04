# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  default     = ""
}

variable "cluster_name" {
  type        = string
  default     = "Mars-task-cluster"
}

variable "argocd_chart_version" {
  type        = string
  default     = "7.9.0" # update as desired
}

# Argo CD Application inputs
variable "app_name" {
  type        = string
  default     = "guestbook"
}

# For a public Helm chart repo
variable "app_repo_url" {
  type        = string
  default     = "https://github.com/talvolcov/mars-task-completed"
}



variable "helm_chart" {
  type        = string
  default     = "guestbook"
}

variable "chart_version" {
  type        = string
  default     = "HEAD" 
}

variable "app_namespace" {
  type        = string
  default     = "default"
}


# Optional inline Helm values (YAML string). Leave empty for defaults.
variable "helm_values" {
  type        = string
  default     = ""
}

