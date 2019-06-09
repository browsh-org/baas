variable "do_browsh_key" {
}

provider "digitalocean" {
  token = var.do_browsh_key
}

resource "digitalocean_kubernetes_cluster" "browsh" {
  name    = "browsh"
  region  = "sfo2"
  version = "1.14.1-do.4"

  node_pool {
    name       = "browsh-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
  }
}

output "cluster-id" {
  value = digitalocean_kubernetes_cluster.browsh.id
}

provider "kubernetes" {
  host = digitalocean_kubernetes_cluster.browsh.endpoint

  client_certificate = base64decode(
    digitalocean_kubernetes_cluster.browsh.kube_config[0].client_certificate,
  )
  client_key = base64decode(
    digitalocean_kubernetes_cluster.browsh.kube_config[0].client_key,
  )
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.browsh.kube_config[0].cluster_ca_certificate,
  )
}

