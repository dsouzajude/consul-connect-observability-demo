variable "consul_image" {
  type        = string
  description = "The Consul Agent Docker image"
}

variable "container_definitions_json" {
  type        = string
  description = "The existing container definitions for the task. Consul Mesh dependent containers will be added on to this."
}

variable "container_port" {
  type        = number
  description = "The application port within container"
  default     = 8080
}

variable "consul_server_dns" {
  type        = string
  description = "The Consul Server DNS Name"
}

variable "consul_ecs_cluster" {
  type        = string
  description = "The ECS Cluster name where Consul Servers run"
}

variable "consul_ecs_service" {
  type        = string
  description = "The ECS Service name for Consul"
}

variable "enable_proxy" {
  type    = bool
  default = true
}

variable "enable_tracing" {
  type    = bool
  default = false
}

variable "envoy_image" {
  type        = string
  description = "The Envoy Proxy Docker image"
}

variable "health_check_path" {
  type        = string
  description = "The path of the health check"
  default     = "/health"
}

variable "health_check_interval" {
  type        = string
  description = "The health check interval"
  default     = "3s"
}

variable "health_check_port" {
  type        = string
  description = "Port to use for the health check by the consul agent"
  default     = 9090
}

variable "health_check_timeout" {
  type        = string
  description = "The timeout of the health check"
  default     = "3s"
}

variable "service_name" {
  type        = string
  description = "Name of the service"
}

variable "tags" {
  type        = map(string)
  description = "Tags to associate with the Load Balancer"
  default     = {}
}

variable "upstream_connections" {
  type        = list(string)
  description = "List of Upstream Consul Service Names and Port the service communicates with on outbound."
  default     = []
}
