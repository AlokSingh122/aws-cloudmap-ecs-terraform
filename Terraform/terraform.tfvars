
aws_region   = "ap-south-1"
project_name = "cloudmap-fargate-demo"
environment  = "dev"

vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24"
]

container_port   = 8080
container_cpu    = 256
container_memory = 512

cpu_architecture = "ARM64"
image_tag        = "arm64"

# Ensure the ARM64 image is pushed to ECR before applying this desired count.
desired_task_count = 1

https_port = 443

task_egress_cidr = "0.0.0.0/0"

ecr_image_tag_mutability  = "MUTABLE"
ecr_scan_on_push          = true
ecr_encryption_type       = "AES256"
ecr_image_retention_count = 10

container_insights_enabled   = false
ecs_capacity_providers       = ["FARGATE", "FARGATE_SPOT"]
ecs_capacity_provider        = "FARGATE_SPOT"
ecs_capacity_provider_weight = 1
ecs_capacity_provider_base   = 0
assign_public_ip             = true

log_retention_days = 7

health_check_interval     = 30
health_check_timeout      = 5
health_check_retries      = 3
health_check_start_period = 30

container_health_check_path            = "/health"
container_health_check_timeout_seconds = 2

cloudmap_namespace_name        = "cloudmap.local"
cloudmap_namespace_description = "Private namespace for ECS service discovery"
cloudmap_record_ttl            = 10
cloudmap_record_type           = "SRV"
cloudmap_routing_policy        = "MULTIVALUE"

api_stage_name  = "$default"
api_auto_deploy = true

deployment_minimum_healthy_percent  = 0
deployment_maximum_percent          = 200
health_check_grace_period_seconds   = 60
deployment_circuit_breaker_enabled  = true
deployment_circuit_breaker_rollback = true
