
resource "aws_security_group" "ecs_instance" {
  name        = "${var.project_name}-ecs-instance-sg"
  description = "ECS EC2 host security group"
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  lifecycle {
    ignore_changes = [ingress, egress]
  }

  tags = {
    Name = "${var.project_name}-ecs-instance-sg"
  }
}

resource "aws_security_group" "vpc_link" {
  name        = "${var.project_name}-vpc-link-sg"
  description = "API Gateway VPC Link security group"
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  lifecycle {
    ignore_changes = [ingress, egress]
  }

  tags = {
    Name = "${var.project_name}-vpc-link-sg"
  }
}

resource "aws_security_group" "ecs_task" {
  name        = "${var.project_name}-ecs-task-sg"
  description = "ECS task security group"
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  lifecycle {
    ignore_changes = [ingress, egress]
  }

  tags = {
    Name = "${var.project_name}-ecs-task-sg"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-endpoint-sg"
  description = "Allow HTTPS from the project VPC to interface endpoints"
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  lifecycle {
    ignore_changes = [ingress, egress]
  }

  tags = {
    Name = "${var.project_name}-endpoint-sg"
  }
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_ecs_host" {
  security_group_id            = aws_security_group.vpc_endpoints.id
  referenced_security_group_id = aws_security_group.ecs_instance.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from ECS container instances"
}

resource "aws_vpc_security_group_egress_rule" "ecs_host_to_endpoints" {
  security_group_id            = aws_security_group.ecs_instance.id
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to interface VPC endpoints"
}

resource "aws_vpc_security_group_egress_rule" "ecs_host_to_s3" {
  security_group_id = aws_security_group.ecs_instance.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to S3 for ECR image layers"
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_tasks" {
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Application traffic to ECS tasks"
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_vpc_link" {
  security_group_id            = aws_security_group.ecs_task.id
  referenced_security_group_id = aws_security_group.vpc_link.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Application traffic from API Gateway VPC Link"
}
