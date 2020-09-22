// Cluster
output "ecs_cluster" {
  value = module.ecs_cluster
}

// Consul
output "consul_server" {
  value = module.consul_server
}

// Dashboard
output "dashboard_mesh_adapter" {
  value = module.dashboard_mesh_adapter
}

output "dashboard_service" {
  value = module.dashboard_service
}

// Counter
output "counter_mesh_adapter" {
  value = module.counter_mesh_adapter
}

output "counter_service" {
  value = module.counter_service
}

// Grafana
output "grafana_mesh_adapter" {
  value = module.grafana_mesh_adapter
}

output "grafana_service" {
  value = module.grafana_service
}

// Prometheus
output "prometheus_mesh_adapter" {
  value = module.prometheus_mesh_adapter
}

output "prometheus_service" {
  value = module.prometheus_service
}

// Ingress
output "ingress_gw_mesh_adapter" {
  value = module.ingress_gw_mesh_adapter
}

output "ingress_gw_service" {
  value = module.ingress_gw_service
}

output "ingress_gw_alb" {
  value = aws_lb.ingress_gw
}
