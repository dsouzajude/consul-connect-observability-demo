terraform {
  backend "s3" {
  }
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  profile = var.profile
}

variable "bucket" {
  description = "Name of bucket to store terraform state"
  type        = string
}

variable "key" {
  description = "Name of key for the terraform state"
  type        = string
}

variable "profile" {
  description = "Name of profile for programatic access to terraform state"
  type        = string
}

variable "region" {
  description = "The region into which resources will deployed to"
  type        = string
}
