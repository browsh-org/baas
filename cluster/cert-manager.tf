data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "cert-manager" {
  name      = "cert-manager"
  namespace = "cert-manager"
  repository = "${data.helm_repository.jetstack.metadata.0.name}"
  chart     = "jetstack/cert-manager"
}
