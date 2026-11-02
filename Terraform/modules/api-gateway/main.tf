
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
  description   = "Public HTTP API with private Cloud Map integration"

  tags = {
    Name = "${var.project_name}-http-api"
  }
}

resource "aws_apigatewayv2_integration" "cloudmap" {
  api_id = aws_apigatewayv2_api.main.id

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  connection_type = "VPC_LINK"
  connection_id   = var.vpc_link_id

  integration_uri = var.cloudmap_service_arn

  payload_format_version = "1.0"

  # Forward the original request path to Flask.
  request_parameters = {
    "overwrite:path" = "$request.path"
  }

}

resource "aws_apigatewayv2_route" "root" {
  api_id = aws_apigatewayv2_api.main.id

  route_key = "ANY /"

  target = "integrations/${aws_apigatewayv2_integration.cloudmap.id}"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id = aws_apigatewayv2_api.main.id

  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.cloudmap.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.main.id

  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "${var.project_name}-default-stage"
  }
}
