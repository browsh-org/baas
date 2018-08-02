resource "kubernetes_deployment" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

  # This causes a crash :/
  #lifecycle {
    #ignore_changes = ["spec.0.template.0.metadata.0.labels.date"]
  #}

  spec {
    selector {
      app = "browsh-ssh-server"
    }
    template {
      metadata {
        labels {
          app = "browsh-ssh-server"
        }
      }
      spec {
        node_selector {
          node-type = "preemptible"
        }
        container {
          image = "gcr.io/browsh-193210/baas"
          image_pull_policy = "Always"
          name  = "app"
          port {
            container_port = 2222
          }
          volume_mount {
            name = "rw-config"
            mount_path = "/etc/browsh"
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
        toleration {
          key = "life_time"
          operator = "Equal"
          value = "preemptible"
          effect = "NoSchedule"
        }
        init_container {
          name = "fix-perms"
          image = "busybox"
          command = [
            "sh",
            "-c",
            "cp /etc/browsh-ro/id_rsa /etc/browsh && /bin/chmod 600 /etc/browsh/id_rsa && /bin/chown 1000 /etc/browsh/id_rsa"
          ]
          volume_mount {
            name = "browsh-ssh-rsa-key"
            mount_path = "/etc/browsh-ro"
          }
          volume_mount {
            name = "rw-config"
            mount_path = "/etc/browsh"
          }
          security_context {
            run_as_user = 0
          }
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
          name = "rw-config"
          empty_dir = {}
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "ssh-server-scaler" {
  metadata {
    name = "ssh-server-scaler"
  }
  spec {
    min_replicas = 2
    max_replicas = 40
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
  data {
    id_rsa_private_key = "${file("etc/browsh_id_rsa")}"
  }
}


resource "kubernetes_service" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

  spec {
    selector {
      app = "browsh-ssh-server"
    }

    port {
      port        = 22
      target_port = 2222
    }

    type = "NodePort"
  }
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
    "22" = "default/browsh-ssh-server:22"
  }
}
