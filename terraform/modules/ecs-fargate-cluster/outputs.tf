output "cluster_arn" {
  description = "ARN of ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the Consul cluster"
  value       = split("/", aws_ecs_cluster.this.arn)[1]
}
