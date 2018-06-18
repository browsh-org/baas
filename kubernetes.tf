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

resource "kubernetes_ingress" "browsh-ingress" {
  metadata {
    name = "browsh-ingress"
    annotations {
      "kubernetes.io/ingress.global-static-ip-name" = "browsh-static-ip"
    }
  }

  spec {
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
  }
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
        container {
          image = "tombh/texttop:v1.1.1"
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
