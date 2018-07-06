provider "google" {
  project = "browsh-193210"
}


resource "google_container_cluster" "primary" {
  name = "browsh-cluster"
  network = "projects/browsh-193210/global/networks/default"
  # https://cloud.google.com/compute/docs/regions-zones/
  zone = "asia-southeast1-a"
  lifecycle {
    # I don't quite understand why ignoring "node_pool" is needed, but without
    # it autoscaling causes a diff that means that whole cluster gets rebuilt!
    ignore_changes = ["node_count", "node_pool"]
  }
  node_pool {
    name       = "default-pool"
    node_config {
      machine_type = "g1-small"
    }
    management {
      auto_repair  = true
      auto_upgrade = true
    }
    autoscaling {
      min_node_count = 1
      max_node_count = 4
    }
  }
}

resource "google_container_node_pool" "browsh-node-pool" {
  name = "browsh-node-pool"
  cluster = "${google_container_cluster.primary.name}"
  zone = "asia-southeast1-a"
  node_count = 2

  # NB. changes to this destroy the entire node pool
  node_config {
    # https://cloud.google.com/compute/docs/machine-types
    machine_type = "n1-standard-2"
    preemptible = "true"
    labels {
      node-type = "preemptible"
    }
    taint {
      key = "life_time"
      value = "preemptible"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 3
    max_node_count = 6
  }
}

provider kubernetes {
  host     = "${google_container_cluster.primary.endpoint}"
  username = "${google_container_cluster.primary.master_auth.0.username}"
  password = "${google_container_cluster.primary.master_auth.0.password}"
  client_certificate     = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
  client_key             = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
}

resource "kubernetes_deployment" "browsh-http-server" {
  metadata {
    name = "browsh-http-server"
  }

  spec {
    replicas = 2
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
        container {
          image = "tombh/texttop:v${chomp(file(".browsh_version"))}"
          name  = "app"
          command = ["/app/browsh", "-http-server", "-debug"]
          port {
            container_port = 4333
          }
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

resource "kubernetes_deployment" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

  # This causes a crash :/
  #lifecycle {
    #ignore_changes = ["spec.0.template.0.metadata.0.labels.date"]
  #}

  spec {
    replicas = 3
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

resource "kubernetes_secret" "browsh-tls" {
  metadata {
    name = "browsh-tls"
  }
  data {
    tls.crt = "${file("etc/browsh-tls.crt")}"
    tls.key = "${file("etc/browsh-tls.key")}"
  }
}

// It seems like changes to this might disbale the CDN
resource "kubernetes_ingress" "browsh-ingress" {
  metadata {
    name = "browsh-ingress"
    annotations {
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
