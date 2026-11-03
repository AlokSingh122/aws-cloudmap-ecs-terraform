
module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name     = var.project_name
  vpc_id           = module.networking.vpc_id
  container_port   = var.container_port
  https_port       = var.https_port
  task_egress_cidr = var.task_egress_cidr
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name          = var.project_name
  image_tag_mutability  = var.ecr_image_tag_mutability
  scan_on_push          = var.ecr_scan_on_push
  encryption_type       = var.ecr_encryption_type
  image_retention_count = var.ecr_image_retention_count
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name               = var.project_name
  container_insights_enabled = var.container_insights_enabled
  capacity_providers         = var.ecs_capacity_providers
  default_capacity_provider  = var.ecs_capacity_provider
  capacity_provider_weight   = var.ecs_capacity_provider_weight
  capacity_provider_base     = var.ecs_capacity_provider_base
}

module "cloudmap" {
  source = "./modules/cloudmap"

  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  namespace_name        = var.cloudmap_namespace_name
  namespace_description = var.cloudmap_namespace_description
  record_ttl            = var.cloudmap_record_ttl
  record_type           = var.cloudmap_record_type
  routing_policy        = var.cloudmap_routing_policy
}

module "ecs_task" {
  source = "./modules/ecs-task"

  project_name                           = var.project_name
  aws_region                             = var.aws_region
  repository_url                         = module.ecr.repository_url
  image_tag                              = var.image_tag
  execution_role_arn                     = module.iam.ecs_task_execution_role_arn
  container_port                         = var.container_port
  container_cpu                          = var.container_cpu
  container_memory                       = var.container_memory
  cpu_architecture                       = var.cpu_architecture
  log_retention_days                     = var.log_retention_days
  health_check_interval                  = var.health_check_interval
  health_check_timeout                   = var.health_check_timeout
  health_check_retries                   = var.health_check_retries
  health_check_start_period              = var.health_check_start_period
  container_health_check_path            = var.container_health_check_path
  container_health_check_timeout_seconds = var.container_health_check_timeout_seconds
}

module "ecs_service" {
  source = "./modules/ecs-service"

  project_name                        = var.project_name
  cluster_arn                         = module.ecs_cluster.cluster_arn
  task_definition_arn                 = module.ecs_task.task_definition_arn
  capacity_provider                   = var.ecs_capacity_provider
  subnet_ids                          = module.networking.public_subnet_ids
  task_security_group_id              = module.security.ecs_task_security_group_id
  cloudmap_service_arn                = module.cloudmap.service_arn
  container_name                      = module.ecs_task.container_name
  container_port                      = var.container_port
  desired_task_count                  = var.desired_task_count
  deployment_minimum_healthy_percent  = var.deployment_minimum_healthy_percent
  deployment_maximum_percent          = var.deployment_maximum_percent
  health_check_grace_period_seconds   = var.health_check_grace_period_seconds
  deployment_circuit_breaker_enabled  = var.deployment_circuit_breaker_enabled
  deployment_circuit_breaker_rollback = var.deployment_circuit_breaker_rollback
  assign_public_ip                    = var.assign_public_ip
  capacity_provider_weight            = var.ecs_capacity_provider_weight
  capacity_provider_base              = var.ecs_capacity_provider_base
}

module "api_vpc_link" {
  source = "./modules/api-vpc-link"

  project_name               = var.project_name
  subnet_ids                 = module.networking.public_subnet_ids
  vpc_link_security_group_id = module.security.vpc_link_security_group_id
}

module "api_gateway" {
  source = "./modules/api-gateway"

  project_name         = var.project_name
  vpc_link_id          = module.api_vpc_link.vpc_link_id
  cloudmap_service_arn = module.cloudmap.service_arn
  stage_name           = var.api_stage_name
  auto_deploy          = var.api_auto_deploy
}
