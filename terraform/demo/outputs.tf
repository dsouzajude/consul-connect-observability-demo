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
