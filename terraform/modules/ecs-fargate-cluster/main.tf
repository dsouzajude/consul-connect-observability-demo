terraform {
  required_version = ">= 0.12"
}

# ----------------
#  Data and Locals
# ----------------

data "aws_region" "current" {}

locals {
  mandatory_tags = {
    "ManagedBy"   = "Terraform"
    "Environment" = var.environment
    "Region"      = data.aws_region.current.name
    "ClusterName" = var.cluster_name
  }

  tags = merge(local.mandatory_tags, var.tags)
}


# ----
#  ECS
# ----

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
  tags = local.tags
}
