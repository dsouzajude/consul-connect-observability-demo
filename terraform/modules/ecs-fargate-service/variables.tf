variable "cluster_name" {
  type        = string
  description = "ECS cluster name to deploy the service on"
}

variable "container_definitions" {
  type        = string
  description = "Container definitions provided as valid JSON document. Required if create_task_definition is true"
  default     = ""
}

variable "container_port" {
  type        = number
  description = "The application port within container"
  default     = 8080
}

variable "cpu" {
  type        = number
  description = "The number of cpu units used by the task. Required for FARGATE."
  default     = 256
}

variable "desired_count_of_tasks" {
  type        = number
  description = "The number of tasks to be schedules with the service"
  default     = 1
}

variable "environment" {
  type        = string
  description = "The name of the AWS environment that the topic is being created in"
}

variable "memory" {
  type        = number
  description = "The amount (in MiB) of memory used by the task. Required for FARGATE."
  default     = 512
}

variable "service_name" {
  type        = string
  description = "The name of the service application"
}

variable "security_group_ids" {
  type        = set(string)
  description = "Security groups to use in awsvpc network mode"
  default     = []
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

variable "target_groups" {
  type = set(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  description = "List of Target groups to associate with the service"
  default     = []
}
