
output "ecs_instance_security_group_id" {
  value = aws_security_group.ecs_instance.id
}

output "ecs_task_security_group_id" {
  value = aws_security_group.ecs_task.id
}

output "vpc_link_security_group_id" {
  value = aws_security_group.vpc_link.id
}

output "vpc_endpoint_security_group_id" {
  value = aws_security_group.vpc_endpoints.id
}
