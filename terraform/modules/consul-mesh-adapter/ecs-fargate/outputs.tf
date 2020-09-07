output "updated_container_definitions_json" {
  value       = local.merged_container_definitions_json
  description = "The updated Container Definitions with service and Consul mesh dependent container definitions"
}

output "consul_service_config_json" {
  value       = local.consul_service_config
  description = "The auto-generated service definition to register into Consul"
}
