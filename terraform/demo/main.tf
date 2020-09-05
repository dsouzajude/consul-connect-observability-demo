// Create the ECS Cluster for all our services
module "ecs_cluster" {
  source = "../modules/ecs-fargate-cluster"

  cluster_name = var.cluster_name
  environment  = var.environment
  subnet_ids   = var.subnet_ids
  tags         = var.tags
}

// Shared Security Group for ECS Services
resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-services"
  description = "Shared ECS SG"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow egress from ECS service to talk to the internet via TLS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
