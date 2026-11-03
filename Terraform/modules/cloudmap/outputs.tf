
output "namespace_name" {
  value = aws_service_discovery_private_dns_namespace.main.name
}

output "service_arn" {
  value = aws_service_discovery_service.app.arn
}
