
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

variable "private_subnet_cidrs" {
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

variable "instance_type" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "desired_task_count" {
  description = "Keep at zero for the first apply; set to one after pushing the image to ECR."
  type        = number

  validation {
    condition     = var.desired_task_count >= 0
    error_message = "desired_task_count must be zero or greater."
  }
}
