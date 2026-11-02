variable "project_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_link_security_group_id" {
  type = string
}