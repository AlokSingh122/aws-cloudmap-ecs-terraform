variable "project_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "task_definition_arn" {
  type = string
}

variable "capacity_provider" {
  type = string
}

variable "capacity_provider_weight" {
  type = number
}

variable "capacity_provider_base" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "task_security_group_id" {
  type = string
}

variable "cloudmap_service_arn" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_port" {
  type = number
}

variable "desired_task_count" {
  type = number
}

variable "assign_public_ip" {
  type = bool
}

variable "deployment_minimum_healthy_percent" {
  type = number
}

variable "deployment_maximum_percent" {
  type = number
}

variable "health_check_grace_period_seconds" {
  type = number
}

variable "deployment_circuit_breaker_enabled" {
  type = bool
}

variable "deployment_circuit_breaker_rollback" {
  type = bool
}