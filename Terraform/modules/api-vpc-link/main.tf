resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link"
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.vpc_link_security_group_id]

  tags = {
    Name = "${var.project_name}-vpc-link"
  }
}