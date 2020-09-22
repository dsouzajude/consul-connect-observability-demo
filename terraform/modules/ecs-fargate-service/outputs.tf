output "ecs_service_arn" {
  value       = aws_ecs_service.this.id
  description = "The ARN of the ECS service created"
}

output "ecs_service_name" {
  value       = aws_ecs_service.this.name
  description = "Name of the ECS service created"
}

output "ecs_task_role_id" {
  value       = aws_iam_role.task.id
  description = "The Name of ECS Task role"
}

output "ecs_task_role_arn" {
  value       = aws_iam_role.task.arn
  description = "The ARN of ECS Task role"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "The ARN of the ECS Task Definition"
}

output "suffix" {
  value       = random_id.postfix.hex
  description = "Hex value of the random suffix appended to service name"
}
