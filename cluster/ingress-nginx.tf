resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"

    labels = {
      "app.kubernetes.io/part-of" = "ingress-nginx"
      "app.kubernetes.io/name"    = "ingress-nginx"
    }
  }
}

resource "kubernetes_config_map" "nginx_configuration" {
  metadata {
    name      = "nginx-configuration"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

resource "kubernetes_config_map" "tcp_services" {
  metadata {
    name      = "tcp-services"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

resource "kubernetes_config_map" "udp_services" {
  metadata {
    name      = "udp-services"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

resource "kubernetes_service_account" "nginx_ingress_serviceaccount" {
  metadata {
    name      = "nginx-ingress-serviceaccount"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

resource "kubernetes_cluster_role" "nginx_ingress_clusterrole" {
  metadata {
    name = "nginx-ingress-clusterrole"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "nodes", "pods", "secrets"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["nodes"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["extensions"]
    resources  = ["ingresses"]
  }

  rule {
    verbs      = ["create", "patch"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["update"]
    api_groups = ["extensions"]
    resources  = ["ingresses/status"]
  }
}

resource "kubernetes_role" "nginx_ingress_role" {
  metadata {
    name      = "nginx-ingress-role"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["configmaps", "pods", "secrets", "namespaces"]
  }

  rule {
    verbs          = ["get", "update"]
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["ingress-controller-leader-nginx"]
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["endpoints"]
  }
}

resource "kubernetes_role_binding" "nginx_ingress_role_nisa_binding" {
  metadata {
    name      = "nginx-ingress-role-nisa-binding"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "nginx-ingress-serviceaccount"
    namespace = "ingress-nginx"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "nginx-ingress-role"
  }
}

resource "kubernetes_cluster_role_binding" "nginx_ingress_clusterrole_nisa_binding" {
  metadata {
    name = "nginx-ingress-clusterrole-nisa-binding"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "nginx-ingress-serviceaccount"
    namespace = "ingress-nginx"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "nginx-ingress-clusterrole"
  }
}

resource "kubernetes_deployment" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"    = "ingress-nginx"
        "app.kubernetes.io/part-of" = "ingress-nginx"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/part-of" = "ingress-nginx"
          "app.kubernetes.io/name"    = "ingress-nginx"
        }

        annotations = {
          "prometheus.io/port"   = "10254"
          "prometheus.io/scrape" = "true"
        }
      }

      spec {
        // Workaround for https://github.com/terraform-providers/terraform-provider-kubernetes/pull/261
        volume {
          name = kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name
          secret {
            secret_name = kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name
          }
        }
        container {
          name  = "nginx-ingress-controller"
          image = "quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.24.1"
          args = [
            "/nginx-ingress-controller",
            "--configmap=$(POD_NAMESPACE)/nginx-configuration",
            "--tcp-services-configmap=$(POD_NAMESPACE)/nginx-ingress-tcp-conf",
            "--udp-services-configmap=$(POD_NAMESPACE)/udp-services",
            "--publish-service=$(POD_NAMESPACE)/ingress-nginx-service",
            "--annotations-prefix=nginx.ingress.kubernetes.io",
          ]

          port {
            name           = "http"
            container_port = 80
          }

          port {
            name           = "https"
            container_port = 443
          }

          env {
            name = "POD_NAME"

            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "10254"
              scheme = "HTTP"
            }

            initial_delay_seconds = 10
            timeout_seconds       = 10
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "10254"
              scheme = "HTTP"
            }

            timeout_seconds   = 10
            period_seconds    = 10
            success_threshold = 1
            failure_threshold = 3
          }

          security_context {
            run_as_user                = 33
            allow_privilege_escalation = true
          }

          // Workaround for https://github.com/terraform-providers/terraform-provider-kubernetes/pull/261
          volume_mount {
            name       = kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            read_only  = true
          }
        }

        service_account_name = "nginx-ingress-serviceaccount"
      }
    }
  }
}

resource "kubernetes_service" "nginx-ingress-loadbalancer" {
  metadata {
    name = "ingress-nginx-service"
    namespace = "ingress-nginx"
  }
  spec {
    type = "LoadBalancer"
    port {
      // Needs to be first as this is where the DO loadbalancer sends its health checks
      port = 80
      name = "http"
    }
    port {
      port = 443
      name = "https"
    }
    port {
      port = 22
      name = "ssh"
    }
    selector = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

# A default backend for unmatched routes
resource "kubernetes_deployment" "default-backend" {
  metadata {
    name = "default-backend"
    namespace = "ingress-nginx"
  }
  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name"    = "default-backend"
        "app.kubernetes.io/part-of" = "ingress-nginx"
      }
    }
    replicas = 2
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "default-backend"
          "app.kubernetes.io/part-of" = "ingress-nginx"
        }
      }
      spec {
        termination_grace_period_seconds = 60
        container {
          name = "default-backend"
          image = "gcr.io/google_containers/defaultbackend:1.0"
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            timeout_seconds = 5
          }
          port {
            container_port = 8080
          }
          resources {
            limits {
              cpu = "10m"
              memory = "20Mi"
            }
            requests {
              cpu = "10m"
              memory = "20Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "default-backend" {
  metadata {
    name = "default-backend"
    namespace = "ingress-nginx"
  }
  spec {
    port {
      name = "http"
      port = 80
      protocol = "TCP"
      target_port = 8080
    }
    selector = {
      "app.kubernetes.io/name"    = "default-backend"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
}

resource "kubernetes_ingress" "nginx-ingress-default" {
  metadata {
    name = "nginx-ingress-default"
    namespace = "ingress-nginx"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/server-snippet" = "if ($host = 'brow.sh' ) {return 301 https://www.brow.sh$request_uri;}"
    }
  }
  spec {
    backend {
      service_name = "default-backend"
      service_port = 80
    }
    rule {
      host = "brow.sh"
      http {
        path {
          path = "/*"
          backend {
            service_name = "default-backend"
            service_port = 443
          }
        }
      }
    }
  }
}
