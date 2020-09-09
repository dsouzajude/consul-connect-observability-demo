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
      service_name      = local.ingress_gw["service_name"]
      service_image     = local.ingress_gw["service_image"]
      container_port    = local.ingress_gw["container_port"]
      http_port         = local.ingress_gw["http_port"]
      health_check_port = local.ingress_gw["health_check_port"]
      region            = local.aws_region
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
  container_port             = local.ingress_gw["container_port"]
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
  container_port         = local.ingress_gw["container_port"]
  desired_count_of_tasks = local.ingress_gw["desired_count_tasks"]
  environment            = var.environment
  service_name           = local.ingress_gw["service_name"]
  security_group_ids = [
    aws_security_group.ecs_service_sg.id,
    module.consul_server.consul_client_sg_id
  ]
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, local.ingress_gw_tags)
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
