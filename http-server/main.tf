resource "kubernetes_deployment" "browsh-http-server" {
  metadata {
    name = "browsh-http-server"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "browsh-http-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "browsh-http-server"
        }
      }
      spec {
        init_container {
          name = "fix-perms"
          image = "busybox"
          command = [
            "sh",
            "-c",
            "mkdir -p /app/.config/browsh/ && cp /etc/read-only/config.toml /app/.config/browsh/ && /bin/chmod -R 777 /app/.config/browsh/"
          ]
          volume_mount {
            name = "browsh-config"
            mount_path = "/etc/read-only"
          }
          volume_mount {
            name = "rw-config"
            mount_path = "/app/.config/browsh/"
          }
          security_context {
            run_as_user = 0
          }
        }
        container {
          image = "browsh/browsh:v${chomp(file(".browsh_version"))}"
          #image = "browsh/browsh:dev"
          name  = "app"
          command = ["/app/browsh", "--http-server-mode", "--debug"]
          port {
            container_port = 4333
          }
          resources {
            requests {
              memory = "500Mi"
              cpu = "1000m"
            }
            limits {
              memory = "2Gi"
              cpu = "2000m"
            }
          }
          volume_mount {
            name = "rw-config"
            mount_path = "/app/.config/browsh/"
          }
        }
        volume {
          name = "browsh-config"
          config_map {
            name = "browsh-http-server-config"
          }
        }
        volume {
          name = "rw-config"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_config_map" "browsh-http-server-config" {
  metadata {
    name = "browsh-http-server-config"
  }
  data = {
    "config.toml" = file("./http-server/main-config.toml")
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "http-server-scaler" {
  metadata {
    name = "http-server-scaler"
  }
  spec {
    min_replicas = 2
    max_replicas = 40
    target_cpu_utilization_percentage = "80"
    scale_target_ref {
      kind = "Deployment"
      name = "browsh-http-server"
    }
  }
}

resource "kubernetes_ingress" "http-server-ingress" {
  metadata {
    name = "browsh-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "certmanager.k8s.io/cluster-issuer": "letsencrypt-prod"
      "certmanager.k8s.io/acme-challenge-type": "http01"
    }
  }
  spec {
    tls {
      hosts = [
        "html.brow.sh",
        "text.brow.sh"
      ]
      secret_name = "browsh-tls"
    }
    backend {
      service_name = "browsh-http-server"
      service_port = 80
    }
    rule {
      host = "html.brow.sh"
      http {
        path {
          path = "/*"
          backend {
            service_name = "browsh-http-server"
            service_port = 80
          }
        }
      }
    }
    rule {
      host = "text.brow.sh"
      http {
        path {
          path = "/*"
          backend {
            service_name = "browsh-http-server"
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "browsh-http-server" {
  metadata {
    name = "browsh-http-server"
  }

  spec {
    selector = {
      app = "browsh-http-server"
    }

    port {
      name = "http"
      port        = 80
      target_port = 4333
    }
  }
}
