output "consul_service_arn" {
  value       = module.ecs_service.ecs_service_arn
  description = "The ARN of the Consul ECS service created"
}

output "consul_service_name" {
  value       = module.ecs_service.ecs_service_name
  description = "Name of the Consul ECS service created"
}

output "consul_task_definition_arn" {
  value       = module.ecs_service.ecs_task_definition_arn
  description = "The ARN of the Consul ECS Task Definition"
}

output "consul_task_role_arn" {
  value       = module.ecs_service.ecs_task_role_arn
  description = "The ARN of Consul ECS Task role"
}

output "consul_task_role_id" {
  value       = module.ecs_service.ecs_task_role_id
  description = "The Name of Consul ECS Task role"
}

output "nlb_arn" {
  description = "ARN of NLB"
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name of NLB"
  value       = aws_lb.nlb.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of NLB"
  value       = aws_lb.nlb.zone_id
}

output "suffix" {
  value       = random_id.postfix.hex
  description = "Hex value of the random suffix appended to Consul ECS service name"
}

output "consul_server_sg_id" {
  value       = aws_security_group.consul_server.id
  description = "Consul Server securigy group id"
}

output "consul_client_sg_id" {
  value       = aws_security_group.consul_client.id
  description = "Consul Client securigy group id"
}

output "dns" {
  value       = "var.service_name.${data.aws_route53_zone.consul.name}"
  description = "Consul DNS"
}
