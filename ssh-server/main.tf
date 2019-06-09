resource "kubernetes_deployment" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

  lifecycle {
    ignore_changes = ["spec[0].replicas"]
  }

  spec {
    selector {
      match_labels = {
        app = "browsh-ssh-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "browsh-ssh-server"
        }
      }
      spec {
        container {
          image = "gcr.io/browsh-193210/baas"
          image_pull_policy = "Always"
          name  = "app"
          port {
            container_port = 2222
          }
          volume_mount {
            name = "rw-config-ssh-key"
            mount_path = "/etc/browsh"
          }
          volume_mount {
            name = "rw-config-ssh-server-config"
            mount_path = "/app/.config/browsh/"
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
        }
        init_container {
          name = "fix-perms"
          image = "busybox"
          command = [
            "sh",
            "-c",
            "cp /etc/browsh-ro-ssh-key/id_rsa /etc/browsh && /bin/chmod 600 /etc/browsh/id_rsa && /bin/chown 1000 /etc/browsh/id_rsa && mkdir -p /app/.config/browsh/ && cp /etc/browsh-ro-config/config.toml /app/.config/browsh/ && /bin/chmod -R 777 /app/.config/browsh/"
          ]
          volume_mount {
            # The read-only mount of the k8s SSH secrets
            name = "browsh-ssh-rsa-key"
            mount_path = "/etc/browsh-ro-ssh-key"
          }
          volume_mount {
            # The read-only mount of the k8s config map for the Browsh config.toml
            name = "browsh-config"
            mount_path = "/etc/browsh-ro-config"
          }
          volume_mount {
            # The read-write helper mount to copy the SSH keys
            name = "rw-config-ssh-key"
            mount_path = "/etc/browsh"
          }
          volume_mount {
            # The read-write helper mount to copy the Browsh config.toml
            name = "rw-config-ssh-server-config"
            mount_path = "/app/.config/browsh/"
          }
          security_context {
            run_as_user = 0
          }
        }
        volume {
          name = "browsh-config"
          config_map {
            name = "browsh-ssh-server-config"
          }
        }
        volume {
          name = "rw-config-ssh-server-config"
          empty_dir {}
        }
        volume {
          name = "browsh-ssh-rsa-key"
          secret {
            secret_name = "browsh-ssh-rsa-key"
            items {
              key = "id_rsa_private_key"
              path = "id_rsa"
            }
          }
        }
        volume {
          name = "rw-config-ssh-key"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_config_map" "browsh-ssh-server-config" {
  metadata {
    name = "browsh-ssh-server-config"
  }
  data = {
    "config.toml" = file("./ssh-server/config.toml")
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "ssh-server-scaler" {
  metadata {
    name = "ssh-server-scaler"
  }
  spec {
    min_replicas = 1
    max_replicas = 10
    target_cpu_utilization_percentage = "80"
    scale_target_ref {
      kind = "Deployment"
      name = "browsh-ssh-server"
    }
  }
}

resource "kubernetes_secret" "browsh-ssh-rsa-key" {
  metadata {
    name = "browsh-ssh-rsa-key"
  }
  data = {
    id_rsa_private_key = file("etc/browsh_id_rsa")
  }
}


resource "kubernetes_service" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

  spec {
    selector = {
      app = "browsh-ssh-server"
    }

    port {
      port        = 22
      target_port = 2222
    }
  }
}

# TCP-specific load balancing rules
resource "kubernetes_config_map" "nginx-ingress-tcp-config" {
  metadata {
    name = "nginx-ingress-tcp-conf"
    namespace = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }
  }
  data = {
    "22" = "default/browsh-ssh-server:22"
  }
}
