
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "cloudmap.local"

  description = "Private namespace for ECS service discovery"

  vpc = var.vpc_id

  tags = {
    Name = "${var.project_name}-namespace"
  }
}

resource "aws_service_discovery_service" "app" {
  name = var.project_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-service"
  }
}
