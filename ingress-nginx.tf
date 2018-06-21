# Initial inspiration came from;
# https://akomljen.com/kubernetes-nginx-ingress-controller/

# All Nginx Ingress resources need to be under a their own namespace
resource "kubernetes_namespace" "nginx-ingress-namespace" {
  metadata {
    name = "ingress"
  }
}

resource "kubernetes_service_account" "nginx-ingress-service-account" {
  metadata {
    name = "nginx"
    namespace = "ingress"
  }
}

resource "kubernetes_ingress" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
    namespace = "ingress"
    annotations {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    backend {
      service_name = "default-backend"
      service_port = 80
    }
    rule {
      host = "lb.brow.sh"
      http {
        path {
          path_regex = "/nginx_status"
          backend {
            service_name = "nginx-ingress"
            service_port = 18080
          }
        }
      }
    }
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

# All the Nginx-specific config that Kubernetes' Ingress does not support
resource "kubernetes_config_map" "nginx-ingress-main-config" {
  metadata {
    name = "nginx-ingress-controller-conf"
    namespace = "ingress"
    labels {
      app = "nginx-ingress-lb"
    }
  }
  data {
    enable-vts-status = true
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

# TCP-specific load balancing rules
resource "kubernetes_config_map" "nginx-ingress-tcp-config" {
  metadata {
    name = "nginx-ingress-tcp-conf"
    namespace = "ingress"
    labels {
      app = "nginx-ingress-lb"
    }
  }
  data {
    "22" = "default/browsh-ssh-server:2222"
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

# A default backend for unmatched routes
resource "kubernetes_deployment" "default-backend" {
  metadata {
    name = "default-backend"
    namespace = "ingress"
  }
  spec {
    selector {
      app = "default-backend"
    }
    replicas = 2
    template {
      metadata {
        labels {
          app = "default-backend"
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
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

resource "kubernetes_service" "default-backend" {
  metadata {
    name = "default-backend"
    namespace = "ingress"
  }
  spec {
    port {
      port = 80
      protocol = "TCP"
      target_port = 8080
    }
    selector {
      app = "default-backend"
    }
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

# The Nginx controller, the heart of load balancing and routing. It is however not the most
# forward facing component, it sits behind a L4 GCE load balancer.
resource "kubernetes_deployment" "nginx-controller" {
  metadata {
    name = "nginx-ingress-controller"
    namespace = "ingress"
  }
  spec {
    selector {
      app = "nginx-ingress-lb"
    }
    replicas = 1
    revision_history_limit = 3
    template {
      metadata {
        labels {
          app = "nginx-ingress-lb"
        }
      }
      spec {
        service_account_name = "nginx"
        termination_grace_period_seconds = 60
        container {
          name = "nginx-ingress-controller"
          image = "quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.15.0"
          image_pull_policy = "Always"
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 10254
              scheme = "HTTP"
            }
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 10254
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            timeout_seconds = 5
          }
          args = [
            "/nginx-ingress-controller",
            "--default-backend-service=$(POD_NAMESPACE)/default-backend",
            "--configmap=$(POD_NAMESPACE)/nginx-ingress-controller-conf",
            "--tcp-services-configmap=$(POD_NAMESPACE)/nginx-ingress-tcp-conf",
            "--publish-service=$(POD_NAMESPACE)/nginx-ingress",
            "--v=2"
          ]
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
          port {
            container_port = 80
          }
          port {
            container_port = 18080
          }
        }
      }
    }
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}

resource "kubernetes_service" "nginx-ingress-loadbalancer" {
  metadata {
    name = "nginx-ingress"
    namespace = "ingress"
  }
  spec {
    type = "LoadBalancer"
    # If you end up needing the original client IP somewhere, use this:
    # kubectl patch svc nginx-ingress -p '{"spec":{"externalTrafficPolicy":"Local"}}'
    load_balancer_ip = "35.197.149.86"
    port {
      port = 80
      node_port = 30000
      name = "http"
    }
    port {
      port = 18080
      node_port = 32000
      name = "http-mgmt"
    }
    selector {
      app = "nginx-ingress-lb"
    }
  }
  depends_on = ["kubernetes_namespace.nginx-ingress-namespace"]
}
