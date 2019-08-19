resource "helm_release" "metrics-server" {
  name      = "metrics-server"
  namespace = "kube-system"
  chart     = "stable/metrics-server"
}
