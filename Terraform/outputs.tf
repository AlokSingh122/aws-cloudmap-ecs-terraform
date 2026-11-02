
output "vpc_id" {
  value = module.networking.vpc_id
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "ecs_service_name" {
  value = module.ecs_service.service_name
}

output "ecs_capacity_provider_name" {
  value = module.ecs_compute.capacity_provider_name
}

output "cloudmap_namespace" {
  value = module.cloudmap.namespace_name
}

output "cloudmap_service_arn" {
  value = module.cloudmap.service_arn
}

output "api_gateway_url" {
  value = module.api_gateway.api_endpoint
}

output "aws_region" {
  value = var.aws_region
}

output "image_tag" {
  value = var.image_tag
}
