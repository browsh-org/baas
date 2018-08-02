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

  lifecycle {
    ignore_changes = ["node_count", "node_pool"]
  }

  # NB. changes to this destroy the entire node pool
  node_config {
    # https://cloud.google.com/compute/docs/machine-types
    machine_type = "n1-standard-2" # 7.5Gb
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

  // Changing this doesn't seem to cause any app downtime
  autoscaling {
    min_node_count = 3
    max_node_count = 20
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
