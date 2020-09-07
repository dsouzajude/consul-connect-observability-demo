variable "cluster_name" {
  type        = string
  description = "Name to be given to the ECS cluster"
}

variable "consul_image" {
  type        = string
  description = "Consul docker image"
}

variable "environment" {
  type        = string
  description = "The name of the AWS environment that the topic is being created in"
}

variable "envoy_image" {
  type        = string
  description = "Envoy docker image"
}

variable "services" {
  type        = map(map(string))
  description = "An object that holds values for all services"
}

variable "subnet_ids" {
  type        = set(string)
  description = "Subnets to use in awsvpc network mode"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to be added"
}

variable "vpc_id" {
  description = "ID of VPC where resources should be deployed"
  type        = string
}

variable "zone_id" {
  type        = string
  description = "The ID of the hosted zone to contain the Consul DNS record."
}
