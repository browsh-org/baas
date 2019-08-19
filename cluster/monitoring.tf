
resource "helm_release" "prometheus-operator" {
  name = "prometheus-operator"
  namespace = "monitoring"
  chart = "stable/prometheus-operator"

  timeout = 900

  values = [
    file("cluster/prometheus_custom_values.yaml")
  ]

  set {
    name = "prometheusOperator.createCustomResource"
    value = false
  }
}
