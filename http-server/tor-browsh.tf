resource "kubernetes_deployment" "tor-browsh-http-server" {
  count = 0
  metadata {
    name = "tor-browsh-http-server"
  }

  spec {
    replicas = 0
    selector {
      match_labels = {
        app = "tor-browsh-http-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "tor-browsh-http-server"
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
            name = "tor-browsh-config"
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
          name  = "app"
          command = ["/app/browsh", "--http-server-mode", "--debug"]
          port {
            container_port = 4333
          }
          resources {
            requests {
              memory = "500Mi"
              cpu = "250m"
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
          name = "tor-browsh-config"
          config_map {
            name = "tor-browsh-http-server-config"
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

resource "kubernetes_config_map" "tor-browsh-http-server-config" {
  count = 0
  metadata {
    name = "tor-browsh-http-server-config"
  }
  data = {
    "config.toml" = file("./http-server/tor-browsh-config.toml")
  }
}

resource "kubernetes_service" "tor-browsh-http-server" {
  count = 0
  metadata {
    name = "tor-browsh-http-server"
  }

  spec {
    selector = {
      app = "tor-browsh-http-server"
    }

    port {
      name = "http"
      port        = 4334
      target_port = 4334
    }
  }
}

resource "kubernetes_ingress" "tor-http-server-ingress" {
  count = 0
  metadata {
    name = "tor-browsh-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "certmanager.k8s.io/cluster-issuer": "letsencrypt-prod"
      "certmanager.k8s.io/acme-challenge-type": "http01"
    }
  }
  spec {
    tls {
      hosts = [
        "tor.brow.sh"
      ]
      secret_name = "tor-browsh-tls"
    }
    backend {
      service_name = "tor-browsh-http-server"
      service_port = 4334
    }
    rule {
      host = "tor.brow.sh"
      http {
        path {
          path = "/*"
          backend {
            service_name = "tor-browsh-http-server"
            service_port = 4334
          }
        }
      }
    }
  }
}

