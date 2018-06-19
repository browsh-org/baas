# Initial inspiration came from;
# https://akomljen.com/kubernetes-nginx-ingress-controller/

# All Nginx resources need to be under a their own namespace
resource "kubernetes_namespace" "nginx-namespace" {
  metadata {
    name = "nginx"
  }
}

# A default backend for unmatched routes
resource "kubernetes_deployment" "default-backend" {
  metadata {
    name = "default-backend"
    namespace = "nginx"
  }
  spec {
    replicas = 2
    template {
      metadata {
        labels {
          app = "default-backend"
        }
      }
      spec {
        node_selector {
          node-type = "long-lived"
        }
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
    namespace = "nginx"
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
}

# All the Nginx-specific config that Kubernetes' Ingress does not support
resource "kubernetes_config_map" "example" {
  metadata {
    name = "nginx-ingress-controller-conf"
    namespace = "nginx"
    labels {
      app = "nginx-ingress-lb"
    }
  }
  data {
    enable-vts-status = true
  }
}

# A route to the Nginx status page
resource "kubernetes_ingress" "nginx-status" {
  metadata {
    name = "nginx-status"
    namespace = "nginx"
  }
  spec {
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
}

# The Nginx controller, the heart of load balancing and routing. It is however not the most
# forward facing component, it sits behind a L4 GCE load balancer.
resource "kubernetes_deployment" "nginx-controller" {
  metadata {
    name = "nginx-ingress-controller"
    namespace = "nginx"
  }
  spec {
    replicas = 1
    revision_history_limit = 3
    template {
      metadata {
        labels {
          app = "nginx-ingress-lb"
        }
      }
      spec {
        node_selector {
          node-type = "long-lived"
        }
        termination_grace_period_seconds = 60
        container {
          name = "nginx-ingress-controller"
          image = "quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.9.0"
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
}

resource "kubernetes_service" "nginx-ingress-loadbalancer" {
  metadata {
    name = "nginx-ingress"
    namespace = "nginx"
  }
  spec {
    type = "NodePort"
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
}

