variable "cluster_name" {
  description = "Name to be given to the ECS cluster"
  type        = string
}

variable "environment" {
  type        = string
  description = "The name of the AWS environment that the topic is being created in"
}

variable "subnet_ids" {
  description = "List of subnet IDs resources should span"
  type        = list(string)
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to be added"
  default     = {}
}
