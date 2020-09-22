# ------
# Locals
# ------

locals {
  dashboard = var.services["dashboard"]

  // Create dynamic map of tags from dashboard.tags variable
  dashboard_tags = {
    for t in split(",", local.dashboard["tags"]) : split(":", t)[0] => split(":", t)[1]
  }
  dashboard_container_def = templatefile(
    "./templates/dashboard-container-definitions.json",
    {
      service_name      = local.dashboard["service_name"]
      service_image     = local.dashboard["service_image"]
      container_port    = local.dashboard["container_port"]
      counter_endpoint  = local.dashboard["counter_endpoint"]
      health_check_port = local.dashboard["health_check_port"]
      health_check_path = local.dashboard["health_check_path"]
      region            = local.aws_region
    }
  )
}

# -------------------
# Consul Mesh Adapter
# -------------------

module "dashboard_mesh_adapter" {
  source = "../modules/consul-mesh-adapter/ecs-fargate"

  consul_image               = var.consul_image
  container_definitions_json = local.dashboard_container_def
  container_port             = local.dashboard["container_port"]
  consul_server_dns          = module.consul_server.dns
  consul_ecs_cluster         = module.ecs_cluster.cluster_name
  consul_ecs_service         = local.consul_service_name
  envoy_image                = var.envoy_image
  health_check_path          = local.dashboard["health_check_path"]
  health_check_port          = local.dashboard["health_check_port"]
  service_name               = local.dashboard["service_name"]
  tags                       = local.dashboard_tags
  upstream_connections       = split(",", local.dashboard["upstream_connections"])
  enable_tracing             = true
}

# -----------------
# Dashboard Service
# -----------------

module "dashboard_service" {
  source = "../modules/ecs-fargate-service"

  cluster_name           = module.ecs_cluster.cluster_name
  container_definitions  = module.dashboard_mesh_adapter.updated_container_definitions_json
  container_port         = local.dashboard["container_port"]
  desired_count_of_tasks = local.dashboard["desired_count_tasks"]
  environment            = var.environment
  service_name           = local.dashboard["service_name"]
  security_group_ids = [
    aws_security_group.ecs_service_sg.id,
    module.consul_server.consul_client_sg_id
  ]
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, local.dashboard_tags)
}

# ------
# Deploy
# ------

resource "null_resource" "deploy_dashboard" {
  triggers = {
    task_definition_arn = module.dashboard_service.ecs_task_definition_arn
  }

  provisioner "local-exec" {
    command = "AWS_CONFIG_FILE=$HOME/.aws/config AWS_PROFILE=${var.profile} aws ecs update-service --cluster ${var.cluster_name} --service ${module.dashboard_service.ecs_service_arn} --task-definition ${module.dashboard_service.ecs_task_definition_arn}"
  }
}
