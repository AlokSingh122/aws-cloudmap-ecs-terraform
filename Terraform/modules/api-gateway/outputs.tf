
output "api_id" {
  value = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "integration_id" {
  value = aws_apigatewayv2_integration.cloudmap.id
}
