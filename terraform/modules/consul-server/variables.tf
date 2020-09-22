variable "additional_security_group_ids" {
  type        = list(string)
  description = "List of additional security group ids to attach to Consul"
}

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

variable "size" {
  type        = number
  description = "The size of the Consul cluster"
  default     = 1
}

variable "service_name" {
  type        = string
  description = "The name of the service application"
}

variable "subnet_ids" {
  type        = set(string)
  description = "Subnets to use in awsvpc network mode"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to be added"
  default     = {}
}

variable "vpc_id" {
  description = "ID of VPC where resources should be deployed"
  type        = string
}

variable "zone_id" {
  type        = string
  description = "The ID of the hosted zone to contain the Consul DNS record."
}
