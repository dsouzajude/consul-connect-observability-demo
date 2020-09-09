terraform {
  required_version = ">= 0.12"
}

# ----------------
#  Data and Locals
# ----------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc_id
}
data "aws_route53_zone" "consul" {
  zone_id = var.zone_id
}

locals {
  mandatory_tags = {
    "ManagedBy"   = "Terraform"
    "Environment" = var.environment
    "Region"      = data.aws_region.current.name
  }
  aws_account_id = data.aws_caller_identity.current.account_id

  http_port = 8500
  grpc_port = 8502
  rpc_port  = 8301

  container_definitions = templatefile(
    "${path.module}/templates/container-definitions.json",
    {
      service_name     = var.service_name
      consul_image     = var.consul_image
      region           = data.aws_region.current.name
      cluster_name     = var.cluster_name
      http_port        = local.http_port
      rpc_port         = local.rpc_port
      grpc_port        = local.grpc_port
      bootstrap_expect = var.size
    }
  )
  tags = merge(local.mandatory_tags, var.tags)
}

# ---
# ECS
# ---

module "ecs_service" {
  source = "../ecs-fargate-service"

  cluster_name           = var.cluster_name
  container_definitions  = local.container_definitions
  container_port         = local.http_port
  desired_count_of_tasks = var.size
  environment            = var.environment
  service_name           = var.service_name

  security_group_ids = concat(var.additional_security_group_ids,
    [
      aws_security_group.consul_server.id
    ]
  )

  subnet_ids = var.subnet_ids
  tags       = var.tags
  target_groups = [
    {
      target_group_arn = aws_alb_target_group.http.arn
      container_name   = var.service_name
      container_port   = local.http_port
    },
    {
      target_group_arn = aws_alb_target_group.rpc.arn
      container_name   = var.service_name
      container_port   = local.rpc_port
    },
    {
      target_group_arn = aws_alb_target_group.grpc.arn
      container_name   = var.service_name
      container_port   = local.grpc_port
    }
  ]
}

# ----------------------
#  Network Load Balancer
# ----------------------

resource "random_id" "postfix" {
  byte_length = 5
}

resource "aws_lb" "nlb" {
  name                       = "int-nlb-${var.service_name}-${random_id.postfix.hex}"
  internal                   = true
  load_balancer_type         = "network"
  subnets                    = var.subnet_ids
  enable_deletion_protection = false
  tags                       = local.tags
}

resource "aws_alb_target_group" "http" {
  name        = "${var.service_name}-http-${random_id.postfix.hex}"
  port        = local.http_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_target_group" "rpc" {
  name        = "${var.service_name}-rpc-${random_id.postfix.hex}"
  port        = local.rpc_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_target_group" "grpc" {
  name        = "${var.service_name}-grpc-${random_id.postfix.hex}"
  port        = local.grpc_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = local.http_port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.http.arn
  }
}

resource "aws_lb_listener" "rpc" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = local.rpc_port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.rpc.arn
  }
}

resource "aws_lb_listener" "grpc" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = local.grpc_port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.grpc.arn
  }
}

# ----------
# Consul DNS
# ----------

resource "aws_route53_record" "consul_record" {
  name    = var.service_name
  type    = "A"
  zone_id = var.zone_id

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}

# ---------------
# Security Groups
# ---------------

// Consul Server SG
resource "aws_security_group" "consul_server" {
  name        = "consul-server-${random_id.postfix.hex}"
  description = "Consul Server connectivity SG"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "The port used by clients to talk to the HTTP API. Also used for NLB Target Group health check"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "TCP"

    // For clients as well + NLB Health Checks
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description     = "The port used by clients to talk to the gRPC API. Also used for NLB Target Group health check"
    from_port       = 8502
    to_port         = 8502
    protocol        = "TCP"

    // For clients as well + NLB Health Checks
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description     = "The port used by servers to handle incoming requests from other agents."
    from_port       = 8300
    to_port         = 8300
    protocol        = "TCP"
    self            = true
    security_groups = [aws_security_group.consul_client.id]
  }

  ingress {
    description     = "The port/udp used by servers to handle incoming requests from other agents."
    from_port       = 8300
    to_port         = 8300
    protocol        = "UDP"
    self            = true
    security_groups = [aws_security_group.consul_client.id]
  }

  ingress {
    description = "The port used by servers to gossip over the WAN to other servers."
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "The port/udp used by servers to gossip over the WAN to other servers."
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
    self        = true
  }

  ingress {
    description     = "The port used to handle gossip in the LAN. Required by all agents."
    from_port       = 8301
    to_port         = 8301
    protocol        = "tcp"
    self            = true
    cidr_blocks     = [data.aws_vpc.selected.cidr_block]
    security_groups = [aws_security_group.consul_client.id]
  }

  ingress {
    description     = "The port/udp used to handle gossip in the LAN. Required by all agents."
    from_port       = 8301
    to_port         = 8301
    protocol        = "udp"
    self            = true
    cidr_blocks     = [data.aws_vpc.selected.cidr_block]
    security_groups = [aws_security_group.consul_client.id]
  }

  ingress {
    description = "The port used to resolve DNS queries."
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description = "The port/udp used to resolve DNS queries."
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description = "The port used by all agents to handle RPC from the CLI"
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description = "The port/udp used by all agents to handle RPC from the CLI"
    from_port   = 8400
    to_port     = 8400
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "Allow outbound connectivity to other Consul servers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

// Consul Client SG
resource "aws_security_group" "consul_client" {
  name        = "consul-client-${random_id.postfix.hex}"
  description = "Consul Clients connectivity SG"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "The port used by clients to talk to the HTTP API. Also used for NLB Target Group health check"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "TCP"

    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    description = "The port used to handle gossip in the LAN. Required by all agents."
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "The port/udp used to handle gossip in the LAN. Required by all agents."
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Allow incoming connections from proxy instances"
    from_port   = 21000
    to_port     = 21255
    protocol    = "TCP"
    self        = true
  }

  ingress {
    description = "Allow scraping of prometheus metrics"
    from_port   = 9102
    to_port     = 9102
    protocol    = "TCP"
    self        = true
  }

  ingress {
    description = "Allow HTTP to Ingress Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    self        = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}
