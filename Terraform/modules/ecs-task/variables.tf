variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "execution_role_arn" {
  type = string
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

variable "cpu_architecture" {
  type = string
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