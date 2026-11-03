
variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "container_port" {
  type = number
}

variable "https_port" {
  type = number
}

variable "task_egress_cidr" {
  type = string
}
