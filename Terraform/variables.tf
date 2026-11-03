
variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "container_port" {
  type = number
}

variable "container_cpu" {
  type = number
}

variable "container_memory" {
  type = number
}

variable "image_tag" {
  type = string
}

variable "desired_task_count" {
  description = "Set to one to run the website task; the ARM64 image must already exist in ECR."
  type        = number

  validation {
    condition     = var.desired_task_count >= 0
    error_message = "desired_task_count must be zero or greater."
  }
}

variable "https_port" {
  type = number
}

variable "task_egress_cidr" {
  description = "IPv4 CIDR range ECS tasks can reach on the configured HTTPS port."
  type        = string
}

variable "ecr_image_tag_mutability" {
  type = string
}

variable "ecr_scan_on_push" {
  type = bool
}

variable "ecr_encryption_type" {
  type = string
}

variable "ecr_image_retention_count" {
  type = number
}

variable "container_insights_enabled" {
  type = bool
}

variable "cpu_architecture" {
  type = string
}

variable "ecs_capacity_providers" {
  type = list(string)
}

variable "ecs_capacity_provider" {
  type = string
}

variable "ecs_capacity_provider_weight" {
  type = number
}

variable "ecs_capacity_provider_base" {
  type = number
}

variable "assign_public_ip" {
  type = bool
}

variable "log_retention_days" {
  type = number
}

variable "health_check_interval" {
  type = number
}

variable "health_check_timeout" {
  type = number
}

variable "health_check_retries" {
  type = number
}

variable "health_check_start_period" {
  type = number
}

variable "container_health_check_path" {
  type = string
}

variable "container_health_check_timeout_seconds" {
  type = number
}

variable "cloudmap_namespace_name" {
  type = string
}

variable "cloudmap_namespace_description" {
  type = string
}

variable "cloudmap_record_ttl" {
  type = number
}

variable "cloudmap_record_type" {
  type = string
}

variable "cloudmap_routing_policy" {
  type = string
}

variable "api_stage_name" {
  description = "Use $default to serve the API from the root URL path."
  type        = string
}

variable "api_auto_deploy" {
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
