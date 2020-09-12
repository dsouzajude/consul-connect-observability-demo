# ------
# Locals
# ------

locals {
  prometheus = var.services["prometheus"]

  // Create dynamic map of tags from prometheus.tags variable
  prometheus_tags = {
    for t in split(",", local.prometheus["tags"]) : split(":", t)[0] => split(":", t)[1]
  }
  prometheus_container_def = templatefile(
    "./templates/prometheus-container-definitions.json",
    {
      service_name      = local.prometheus["service_name"]
      service_image     = local.prometheus["service_image"]
      container_port    = local.prometheus["container_port"]
      health_check_port = local.prometheus["health_check_port"]
      region            = local.aws_region
    }
  )
}

# -------------------
# Consul Mesh Adapter
# -------------------

module "prometheus_mesh_adapter" {
  source = "../modules/consul-mesh-adapter/ecs-fargate"

  consul_image               = var.consul_image
  container_definitions_json = local.prometheus_container_def
  container_port             = local.prometheus["container_port"]
  consul_server_dns          = module.consul_server.dns
  consul_ecs_cluster         = module.ecs_cluster.cluster_name
  consul_ecs_service         = local.consul_service_name
  envoy_image                = var.envoy_image
  health_check_path          = local.prometheus["health_check_path"]
  health_check_port          = local.prometheus["health_check_port"]
  service_name               = local.prometheus["service_name"]
  tags                       = local.prometheus_tags
  enable_tracing             = true
}

# ------------------
# Prometheus Service
# ------------------

module "prometheus_service" {
  source = "../modules/ecs-fargate-service"

  cluster_name           = module.ecs_cluster.cluster_name
  container_definitions  = module.prometheus_mesh_adapter.updated_container_definitions_json
  container_port         = local.prometheus["container_port"]
  desired_count_of_tasks = local.prometheus["desired_count_tasks"]
  environment            = var.environment
  service_name           = local.prometheus["service_name"]
  security_group_ids = [
    aws_security_group.ecs_service_sg.id,
    module.consul_server.consul_client_sg_id
  ]
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, local.prometheus_tags)
}

# ------
# Deploy
# ------

resource "null_resource" "deploy_prometheus" {
  triggers = {
    task_definition_arn = module.prometheus_service.ecs_task_definition_arn
  }

  provisioner "local-exec" {
    command = "AWS_CONFIG_FILE=$HOME/.aws/config AWS_PROFILE=${var.profile} aws ecs update-service --cluster ${var.cluster_name} --service ${module.prometheus_service.ecs_service_arn} --task-definition ${module.prometheus_service.ecs_task_definition_arn}"
  }
}
