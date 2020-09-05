locals {
  consul_service_name = "consul"
}

// Create the Consul Server
module "consul_server" {
  source = "../modules/consul-server"

  additional_security_group_ids = [aws_security_group.ecs_service_sg.id]
  cluster_name                  = module.ecs_cluster.cluster_name
  consul_image                  = var.consul_image
  environment                   = var.environment
  size                          = 3
  service_name                  = local.consul_service_name
  subnet_ids                    = var.subnet_ids
  tags                          = var.tags
  vpc_id                        = var.vpc_id
  zone_id                       = var.zone_id
}
