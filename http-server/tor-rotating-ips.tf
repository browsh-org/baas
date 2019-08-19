resource "kubernetes_deployment" "tor-rotating-ips" {
  count = 0
  metadata {
    name = "tor-rotating-ips"
  }
  spec {
    replicas = 0
    selector {
      match_labels = {
        app = "tor-rotating-ips"
      }
    }
    template {
      metadata {
        labels = {
          app = "tor-rotating-ips"
        }
      }
      spec {
        container {
          image = "zeta0/alpine-tor"
          name  = "app"
          env {
            name = "tors"
            value = 10
          }
          env {
            name = "privoxy"
            value = 1
          }
          port {
            container_port = 8118
          }
          port {
            container_port = 2090
          }
          resources {
            requests {
              memory = "250Mi"
              cpu = "250m"
            }
            limits {
              memory = "2Gi"
              cpu = "2000m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "tor-rotating-ips" {
  count = 0
  metadata {
    name = "tor-rotating-ips"
  }

  spec {
    selector = {
      app = "tor-rotating-ips"
    }

    port {
      name = "endpoint"
      port = 8118
      target_port = 8118
    }
    port {
      name = "dashboard"
      port = 2090
      target_port = 2090
    }
  }
}

