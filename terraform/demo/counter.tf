# ------
# Locals
# ------

locals {
  counter = var.services["counter"]

  // Create dynamic map of tags from counter.tags variable
  counter_tags = {
    for t in split(",", local.counter["tags"]) : split(":", t)[0] => split(":", t)[1]
  }
  counter_container_def = templatefile(
    "./templates/counter-container-definitions.json",
    {
      service_name      = local.counter["service_name"]
      service_image     = local.counter["service_image"]
      container_port    = local.counter["container_port"]
      health_check_port = local.counter["health_check_port"]
      health_check_path = local.counter["health_check_path"]
      region            = local.aws_region
    }
  )
}

# -------------------
# Consul Mesh Adapter
# -------------------

module "counter_mesh_adapter" {
  source = "../modules/consul-mesh-adapter/ecs-fargate"

  consul_image               = var.consul_image
  container_definitions_json = local.counter_container_def
  container_port             = local.counter["container_port"]
  consul_server_dns          = module.consul_server.dns
  consul_ecs_cluster         = module.ecs_cluster.cluster_name
  consul_ecs_service         = local.consul_service_name
  envoy_image                = var.envoy_image
  health_check_path          = local.counter["health_check_path"]
  health_check_port          = local.counter["health_check_port"]
  service_name               = local.counter["service_name"]
  tags                       = local.counter_tags
  enable_tracing             = true
}

# ---------------
# Counter Service
# ---------------

module "counter_service" {
  source = "../modules/ecs-fargate-service"

  cluster_name           = module.ecs_cluster.cluster_name
  container_definitions  = module.counter_mesh_adapter.updated_container_definitions_json
  container_port         = local.counter["container_port"]
  desired_count_of_tasks = local.counter["desired_count_tasks"]
  environment            = var.environment
  service_name           = local.counter["service_name"]
  security_group_ids = [
    aws_security_group.ecs_service_sg.id,
    module.consul_server.consul_client_sg_id
  ]
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, local.counter_tags)
}

# ------
# Deploy
# ------

resource "null_resource" "deploy_counter" {
  triggers = {
    task_definition_arn = module.counter_service.ecs_task_definition_arn
  }

  provisioner "local-exec" {
    command = "AWS_CONFIG_FILE=$HOME/.aws/config AWS_PROFILE=${var.profile} aws ecs update-service --cluster ${var.cluster_name} --service ${module.counter_service.ecs_service_arn} --task-definition ${module.counter_service.ecs_task_definition_arn}"
  }
}
