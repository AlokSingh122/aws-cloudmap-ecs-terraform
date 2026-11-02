output "autoscaling_group_name" {
  value = aws_autoscaling_group.ecs.name
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.spot.name
}