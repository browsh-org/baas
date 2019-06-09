variable "k8s_dashboard_ver" {
  description = "Version of Kubernetes dashboard to deploy"
  type        = string
  default     = "1.10.1"
}

variable "minimal_role_name" {
  description = "Name of limited permissions role"
  type        = string
  default     = "kubernetes-dashboard-minimal"
}

variable "name" {
  description = "Name of deployed service"
  type        = string
  default     = "kubernetes-dashboard"
}

variable "app_name" {
  description = "Value of k8s-app label"
  type        = string
  default     = "kubernetes-dashboard"
}

variable "namespace" {
  description = "Target namespace to deploy"
  type        = string
  default     = "kube-system"
}

variable "revision_history_limit" {
  description = "Revision history limit"
  type        = string
  default     = "10"
}

variable "replicas" {
  description = "Number of replicas"
  type        = string
  default     = "1"
}

resource "kubernetes_secret" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard-certs"
    namespace = var.namespace

    labels = {
      k8s-app = var.app_name
    }
  }

  type = "Opaque"
}

resource "kubernetes_role" "dashboard-minimal" {
  metadata {
    name      = var.minimal_role_name
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resource_names = ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs"]
    resources      = ["secrets"]
    verbs          = ["get", "update", "delete"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["kubernetes-dashboard-settings"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups     = [""]
    resources      = ["services"]
    resource_names = ["heapster"]
    verbs          = ["proxy"]
  }

  rule {
    api_groups     = [""]
    resources      = ["services/proxy"]
    resource_names = ["heapster", "http:heapster:", "https:heapster:"]
    verbs          = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "dashboard" {
  metadata {
    name = var.name

    labels = {
      k8s-app = var.app_name
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
    api_group = ""
  }
}

resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      k8s-app = var.app_name
    }
  }
}

resource "kubernetes_role_binding" "dashboard" {
  metadata {
    name      = var.minimal_role_name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = var.minimal_role_name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
    api_group = ""
  }
}

resource "kubernetes_deployment" "dashboard" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      k8s-app = var.app_name
    }
  }

  spec {
    replicas               = var.replicas
    revision_history_limit = var.revision_history_limit

    selector {
      match_labels = {
        k8s-app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = var.app_name
        }
      }

      spec {
        service_account_name = "kubernetes-dashboard"

        volume {
          name = "kubernetes-dashboard-certs"

          secret {
            secret_name = "kubernetes-dashboard-certs"
          }
        }
        volume {
          name = kubernetes_service_account.dashboard.default_secret_name

          secret {
            secret_name = kubernetes_service_account.dashboard.default_secret_name
          }
        }
        volume {
          name = "tmp-volume"
          empty_dir {}
        }

        container {
          name  = "kubernetes-dashboard"
          args  = ["--auto-generate-certificates", "--enable-skip-login"]
          image = "k8s.gcr.io/kubernetes-dashboard-amd64:v${var.k8s_dashboard_ver}"

          port {
            container_port = 8443
            protocol       = "TCP"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }

            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          volume_mount {
            name       = "kubernetes-dashboard-certs"
            mount_path = "/certs"
          }
          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
          volume_mount {
            name       = kubernetes_service_account.dashboard.default_secret_name
            read_only  = true
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "dashboard" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      k8s-app = var.app_name
    }
  }

  spec {
    selector = {
      k8s-app = "kubernetes-dashboard"
    }

    port {
      port        = 443
      target_port = 8443
    }
  }
}

