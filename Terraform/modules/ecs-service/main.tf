resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = var.cluster_arn
  task_definition = var.task_definition_arn
  desired_count   = var.desired_task_count

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = var.capacity_provider_weight
    base              = var.capacity_provider_base
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  service_registries {
    registry_arn   = var.cloudmap_service_arn
    container_name = var.container_name
    container_port = var.container_port
  }

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker_enabled
    rollback = var.deployment_circuit_breaker_rollback
  }
}