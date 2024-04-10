output "resource_group__name" {
  value     = azurerm_resource_group.cluster-group.name
  sensitive = false
}

output "cluster_name" {
  value     = azurerm_kubernetes_cluster.aci-cluster.name
  sensitive = false
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aci-cluster.name
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aci-cluster.kube_config_raw
  sensitive = true
}
