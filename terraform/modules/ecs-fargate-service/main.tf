terraform {
  required_version = ">= 0.12"
}

# -------------------------
#  Random String Generator
# -------------------------

resource "random_id" "postfix" {
  byte_length = 4
}

# ----------------
#  Data and Locals
# ----------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  mandatory_tags = {
    "ManagedBy"   = "Terraform"
    "Environment" = var.environment
    "Region"      = data.aws_region.current.name
    "ServiceName" = var.service_name
    "ClusterName" = var.cluster_name
  }

  task_role_name = "ECSTaskRole-${var.service_name}-${random_id.postfix.hex}"

  tags           = merge(local.mandatory_tags, var.tags)
  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_dns_suffix = data.aws_partition.current.dns_suffix
}

# ----
#  ECS
# ----

resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  container_definitions    = var.container_definitions
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.task.arn
  tags                     = var.tags
}

resource "aws_ecs_service" "this" {
  name                               = "${var.service_name}-${random_id.postfix.hex}"
  cluster                            = var.cluster_name
  task_definition                    = aws_ecs_task_definition.this.arn
  launch_type                        = "FARGATE"
  desired_count                      = var.desired_count_of_tasks
  deployment_minimum_healthy_percent = 95
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = var.requires_target_group ? 90 : null
  propagate_tags                     = "SERVICE"

  dynamic "load_balancer" {
    for_each = var.requires_target_group ? ["_"] : []
    iterator = index

    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  network_configuration {
    security_groups = var.security_group_ids
    subnets         = var.subnet_ids
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [task_definition, desired_count, load_balancer]
  }

  tags = local.tags
}

# ----
#  IAM
# ----

resource "aws_iam_role" "task" {
  name               = local.task_role_name
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ecs-tasks.${local.aws_dns_suffix}"
            }
        }
    ]
}
EOF
}

// Default policies to attach to the role.
// Includes ecs Permissions for Consul to join the cluster
resource "aws_iam_role_policy" "task" {
  name = "${var.service_name}-default-policy"
  role = aws_iam_role.task.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup"
        ],
        "Resource": "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:*"
      },
      {
        "Effect": "Allow",
        "Action": [
            "ecs:ListTasks"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
            "ecs:DescribeTasks"
        ],
        "Resource": "arn:aws:ecs:${local.aws_region}:${local.aws_account_id}:task/*"
      }
    ]
  }
  EOF
}

// Allow ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.task.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Allow for XRay tracing
resource "aws_iam_role_policy_attachment" "xray_daemon_write_access" {
  role       = aws_iam_role.task.id
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
