
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

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_tasks" {
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Application traffic to ECS tasks"
}

resource "aws_vpc_security_group_egress_rule" "tasks_to_internet" {
  security_group_id = aws_security_group.ecs_task.id
  cidr_ipv4         = var.task_egress_cidr
  ip_protocol       = "tcp"
  from_port         = var.https_port
  to_port           = var.https_port
  description       = "HTTPS to ECR and CloudWatch Logs through the internet gateway"
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_vpc_link" {
  security_group_id            = aws_security_group.ecs_task.id
  referenced_security_group_id = aws_security_group.vpc_link.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Application traffic from API Gateway VPC Link"
}
