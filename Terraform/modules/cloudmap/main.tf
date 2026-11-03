
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = var.namespace_name

  description = var.namespace_description

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
      ttl  = var.record_ttl
      type = var.record_type
    }

    routing_policy = var.routing_policy
  }

  tags = {
    Name = "${var.project_name}-service"
  }
}
