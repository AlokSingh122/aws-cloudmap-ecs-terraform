
output "api_endpoint" {
  value = format(
    "%s%s",
    aws_apigatewayv2_api.main.api_endpoint,
    var.stage_name == "$default" ? "" : format("/%s", var.stage_name)
  )
}
