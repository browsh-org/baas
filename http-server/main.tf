resource "kubernetes_deployment" "browsh-http-server" {
  metadata {
    name = "browsh-http-server"
  }

  lifecycle {
    ignore_changes = ["spec.replicas"]
  }

  spec {
    selector {
      app = "browsh-http-server"
    }
    template {
      metadata {
        labels {
          app = "browsh-http-server"
        }
      }
      spec {
        node_selector {
          node-type = "preemptible"
        }
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
          #image = "browsh/browsh:v${chomp(file(".browsh_version"))}"
          image = "gcr.io/browsh-193210/browsh"
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
              memory = "4Gi"
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
          config_map = {
            name = "browsh-http-server-config"
          }
        }
        volume {
          name = "rw-config"
          empty_dir = {}
        }
        toleration {
          key = "life_time"
          operator = "Equal"
          value = "preemptible"
          effect = "NoSchedule"
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
    "config.toml" = "${file("./http-server/config.toml")}"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "http-server-sacler" {
  metadata {
    name = "http-server-sacler"
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

resource "kubernetes_secret" "browsh-tls" {
  metadata {
    name = "browsh-tls"
  }
  data = {
    tls.crt = "${file("etc/browsh-tls.crt")}"
    tls.key = "${file("etc/browsh-tls.key")}"
  }
}

// It seems like changes to this might disbale the CDN
resource "kubernetes_ingress" "http-server-ingress" {
  metadata {
    name = "browsh-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = "browsh-http-server"
    }
  }
  spec {
    tls {
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
          path_regex = "/"
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
          path_regex = "/"
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
    type = "NodePort"
    selector {
      app = "browsh-http-server"
    }

    port {
      name = "http"
      port        = 80
      target_port = 4333
    }
    port {
      name = "https"
      port        = 443
      target_port = 4333
    }
  }
}
