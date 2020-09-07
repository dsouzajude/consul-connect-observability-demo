data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  tags           = var.tags
  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  proxy_port     = 21000
  xray_port      = 2000

  # -------------------
  # Consul Config parts
  # -------------------

  // Upstreams Config
  upstreams = length(compact(var.upstream_connections)) > 0 ? [
    for u in var.upstream_connections : {
      "destination_name" = split(":", u)[0],
      "local_bind_port"  = tonumber(split(":", u)[1])
    }
  ] : []

  // Tracing Config - Needs to be JSON escaped
  tracing_config = templatefile(
    "${path.module}/templates/tracing-config.json.escaped",
    {
      service_name = var.service_name
      xray_port    = local.xray_port
    }
  )

  // Consul Service Definition Config
  consul_service_config = templatefile(
    "${path.module}/templates/consul-service-config.json",
    {
      service_name          = var.service_name
      container_port        = var.container_port
      region                = local.aws_region
      health_check_port     = var.health_check_port
      health_check_path     = var.health_check_path
      health_check_interval = var.health_check_interval
      health_check_timeout  = var.health_check_timeout
      upstreams             = jsonencode(local.upstreams)
      envoy_tracing_json    = var.enable_tracing ? local.tracing_config : null
    }
  )

  # ---------------------
  # Container Definitions
  # ---------------------

  // Consul Mesh Container Definitions
  consul_mesh_container_definitions = jsondecode(templatefile(
    "${path.module}/templates/consul-mesh-container-definitions.json",
    {
      consul_image              = var.consul_image
      service_name              = var.service_name
      region                    = local.aws_region
      consul_ecs_cluster        = var.consul_ecs_cluster
      consul_ecs_service        = var.consul_ecs_service
      consul_server_dns         = var.consul_server_dns
      envoy_image               = var.envoy_image
      proxy_port                = local.proxy_port
      consul_service_config_b64 = base64encode(local.consul_service_config)
    }
  ))

  // [Optional] X-Ray Container Definitions
  xray_container_definitions = var.enable_tracing ? jsondecode(templatefile(
    "${path.module}/templates/xray-container-definitions.json",
    {
      service_name = var.service_name
      region       = local.aws_region
    }
  )) : []

  // Existing Service's Container Definitions
  service_container_definitions = jsondecode(var.container_definitions_json)

  // Putting it all together
  merged_container_definitions_json = jsonencode(
    concat(
      local.service_container_definitions,
      local.consul_mesh_container_definitions,
      local.xray_container_definitions
    )
  )
}
