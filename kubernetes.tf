provider "google" {
  project = "browsh-193210"
}


resource "google_container_cluster" "primary" {
  name = "browsh-cluster"
  # https://cloud.google.com/compute/docs/regions-zones/
  zone = "asia-southeast1-a"
  remove_default_node_pool = true
  initial_node_count = 3
}

resource "google_container_node_pool" "browsh-node-pool" {
  name = "browsh-node-pool"
  cluster = "${google_container_cluster.primary.name}"
  zone = "asia-southeast1-a"
  node_count = 3

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

resource "google_container_node_pool" "long-lived-node-pool" {
  name = "long-lived-node-pool"
  cluster = "${google_container_cluster.primary.name}"
  zone = "asia-southeast1-a"
  node_count = 1

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
    replicas = 3
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
      }
    }
  }
}

resource "kubernetes_service" "browsh-http-server" {
  metadata {
    name = "browsh-http-server"
  }

  spec {
    selector {
      app = "browsh-http-server"
    }

    port {
      port        = 80
      target_port = 4333
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "browsh-ssh-server" {
  metadata {
    name = "browsh-ssh-server"
  }

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
        toleration {
          key = "life_time"
          operator = "Equal"
          value = "preemptible"
          effect = "NoSchedule"
        }
        container {
          image = "browh-org/baas:v0.0.1"
          name  = "app"
          port {
            container_port = 22
          }
          readiness_probe {
            exec {
              command = ["cat", "/tmp/browsh-ssh-server-available"]
            }
            initial_delay_seconds = 5
            period_seconds = 1
          }
        }
        volume {
          name = "browsh-ssh-rsa-key"
          secret {
            secret_name = "browsh-ssh-rsa-key"
            default_mode = 0444
            items {
              key = "id_rsa_private_key"
              path = "/app/id_rsa"
            }
          }
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
      target_port = 22
    }

    type = "NodePort"
  }
}
