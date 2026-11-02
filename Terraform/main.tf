
moved {
  from = module.ecs.aws_autoscaling_group.ecs
  to   = module.ecs_compute.aws_autoscaling_group.ecs
}

moved {
  from = module.ecs.aws_ecs_capacity_provider.spot
  to   = module.ecs_compute.aws_ecs_capacity_provider.spot
}

moved {
  from = module.ecs.aws_ecs_cluster.main
  to   = module.ecs_cluster.aws_ecs_cluster.main
}

moved {
  from = module.ecs.aws_cloudwatch_log_group.app
  to   = module.ecs_task.aws_cloudwatch_log_group.app
}

moved {
  from = module.ecs.aws_ecs_task_definition.app
  to   = module.ecs_task.aws_ecs_task_definition.app
}

moved {
  from = module.ecs.aws_launch_template.ecs
  to   = module.ecs_compute.aws_launch_template.ecs
}

moved {
  from = module.networking.aws_security_group.endpoints
  to   = module.security.aws_security_group.vpc_endpoints
}

moved {
  from = module.networking.aws_vpc_endpoint.s3
  to   = module.vpc_endpoints.aws_vpc_endpoint.s3
}

module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name   = var.project_name
  vpc_id         = module.networking.vpc_id
  aws_region     = var.aws_region
  container_port = var.container_port
}

module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  aws_region                 = var.aws_region
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  private_route_table_ids    = module.networking.private_route_table_ids
  endpoint_security_group_id = module.security.vpc_endpoint_security_group_id
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name = var.project_name
}

module "cloudmap" {
  source = "./modules/cloudmap"

  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

module "ecs_compute" {
  source = "./modules/ecs-compute"

  project_name               = var.project_name
  cluster_name               = module.ecs_cluster.cluster_name
  subnet_ids                 = module.networking.private_subnet_ids
  instance_security_group_id = module.security.ecs_instance_security_group_id
  instance_profile_name      = module.iam.ecs_instance_profile_name
  instance_type              = var.instance_type
}

module "ecs_task" {
  source = "./modules/ecs-task"

  project_name       = var.project_name
  aws_region         = var.aws_region
  repository_url     = module.ecr.repository_url
  image_tag          = var.image_tag
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  container_port     = var.container_port
  container_cpu      = var.container_cpu
  container_memory   = var.container_memory
}

module "ecs_service" {
  source = "./modules/ecs-service"

  project_name           = var.project_name
  cluster_arn            = module.ecs_cluster.cluster_arn
  task_definition_arn    = module.ecs_task.task_definition_arn
  capacity_provider      = module.ecs_compute.capacity_provider_name
  subnet_ids             = module.networking.private_subnet_ids
  task_security_group_id = module.security.ecs_task_security_group_id
  cloudmap_service_arn   = module.cloudmap.service_arn
  container_name         = module.ecs_task.container_name
  container_port         = var.container_port
  desired_task_count     = var.desired_task_count

  depends_on = [module.ecs_compute]
}

module "api_vpc_link" {
  source = "./modules/api-vpc-link"

  project_name               = var.project_name
  subnet_ids                 = module.networking.private_subnet_ids
  vpc_link_security_group_id = module.security.vpc_link_security_group_id
}

module "api_gateway" {
  source = "./modules/api-gateway"

  project_name         = var.project_name
  vpc_link_id          = module.api_vpc_link.vpc_link_id
  cloudmap_service_arn = module.cloudmap.service_arn
}

