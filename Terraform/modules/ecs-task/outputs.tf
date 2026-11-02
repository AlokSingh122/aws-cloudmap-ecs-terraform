output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "container_name" {
  value = var.project_name
}