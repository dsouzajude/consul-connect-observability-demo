# ------
# Locals
# ------

locals {
  ingress_gw = var.services["ingress-gw"]

  // Create dynamic map of tags from .tags variable
  ingress_gw_tags = {
    for t in split(",", local.ingress_gw["tags"]) : split(":", t)[0] => split(":", t)[1]
  }
  ingress_gw_container_def = templatefile(
    "./templates/ingress-gw-container-definitions.json",
    {
      region = local.aws_region

      service_name            = local.ingress_gw["service_name"]
      envoy_gw_image          = local.ingress_gw["envoy_gw_image"]
      envoy_port              = local.ingress_gw["envoy_port"]
      envoy_process_port      = local.ingress_gw["envoy_process_port"]
      envoy_health_check_port = local.ingress_gw["envoy_health_check_port"]
    }
  )
}

# -------------------
# Consul Mesh Adapter
# -------------------

module "ingress_gw_mesh_adapter" {
  source = "../modules/consul-mesh-adapter/ecs-fargate"

  consul_image               = var.consul_image
  container_definitions_json = local.ingress_gw_container_def
  consul_server_dns          = module.consul_server.dns
  consul_ecs_cluster         = module.ecs_cluster.cluster_name
  consul_ecs_service         = local.consul_service_name
  envoy_image                = ""
  service_name               = local.ingress_gw["service_name"]
  tags                       = local.ingress_gw_tags
  enable_tracing             = true
  enable_proxy               = false
}

# ------------------
# Ingress GW Service
# ------------------

module "ingress_gw_service" {
  source = "../modules/ecs-fargate-service"

  cluster_name           = module.ecs_cluster.cluster_name
  container_definitions  = module.ingress_gw_mesh_adapter.updated_container_definitions_json
  container_port         = local.ingress_gw["envoy_port"]
  desired_count_of_tasks = local.ingress_gw["desired_count_tasks"]
  environment            = var.environment
  service_name           = local.ingress_gw["service_name"]
  security_group_ids = [
    aws_security_group.ecs_service_sg.id,
    module.consul_server.consul_client_sg_id
  ]
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, local.ingress_gw_tags)

  target_groups = [
    {
      target_group_arn = aws_alb_target_group.ingress_gw.arn
      container_name   = local.ingress_gw["service_name"]
      container_port   = local.ingress_gw["envoy_port"]
    }
  ]
}

# --------------------------
#  Application Load Balancer
# --------------------------

resource "random_id" "postfix" {
  byte_length = 5
}

resource "aws_lb" "ingress_gw" {
  name                       = "int-alb-${local.ingress_gw["service_name"]}-${random_id.postfix.hex}"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ingress_gw_alb.id]
  subnets                    = var.subnet_ids
  enable_deletion_protection = false
  idle_timeout               = 60
  tags                       = merge(var.tags, local.ingress_gw_tags)
}

resource "aws_lb_listener" "ingress_gw" {
  load_balancer_arn = aws_lb.ingress_gw.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ingress_gw.arn
  }
}

resource "aws_alb_target_group" "ingress_gw" {
  name                 = "${local.ingress_gw["service_name"]}-${random_id.postfix.hex}"
  port                 = local.ingress_gw["envoy_port"]
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30
  slow_start           = 30

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = local.ingress_gw["envoy_port"]
    path                = "/health"
    interval            = "5"
    timeout             = "4"
    matcher             = "404" // Currently health checks are not supported on Consul Ingress Gateways
  }

  tags = merge(var.tags, local.ingress_gw_tags)

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------
#  Security Groups
# ----------------

resource "aws_security_group" "ingress_gw_alb" {
  name        = "ingress-gw"
  description = "Ingress Gateway SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP inbound connectivity to Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Allow egress to ECS Services"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  tags = merge(var.tags, local.ingress_gw_tags)
}

// Allow inbound from Ingress GW to ECS Service
resource "aws_security_group_rule" "allow_ingress_gw_inbound_to_ecs_service" {
  type                     = "ingress"
  description              = "Allow Inbound connectivity from Ingress GW to ECS Service"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.ecs_service_sg.id
  source_security_group_id = aws_security_group.ingress_gw_alb.id
}

# ------
# Deploy
# ------

resource "null_resource" "deploy_ingress_gw" {
  triggers = {
    task_definition_arn = module.ingress_gw_service.ecs_task_definition_arn
  }

  provisioner "local-exec" {
    command = "AWS_CONFIG_FILE=$HOME/.aws/config AWS_PROFILE=${var.profile} aws ecs update-service --cluster ${var.cluster_name} --service ${module.ingress_gw_service.ecs_service_arn} --task-definition ${module.ingress_gw_service.ecs_task_definition_arn}"
  }
}
