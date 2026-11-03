
output "ecs_task_security_group_id" {
  value = aws_security_group.ecs_task.id
}

output "vpc_link_security_group_id" {
  value = aws_security_group.vpc_link.id
}
