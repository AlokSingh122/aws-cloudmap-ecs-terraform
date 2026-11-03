# CloudMap ECS Fargate Spot

This learning project deploys a Flask container to Amazon ECS Fargate Spot on ARM64. A public API Gateway HTTP API reaches the task through a VPC Link and AWS Cloud Map. It does not create an ALB, NLB, NAT Gateway, EC2 host, or VPC endpoints.

## Architecture and request flow

The browser resolves the public API Gateway hostname and opens HTTPS to the HTTP API. API Gateway matches `ANY /` or `ANY /{proxy+}`, then uses a VPC Link to reach the integration. The integration uses the Cloud Map service ARN; API Gateway calls Cloud Map `DiscoverInstances`, selects a healthy task IP and port from the ECS SRV registrations, and forwards the request to the task ENI on TCP 8080. Flask handles the route, and the HTTP response follows the same path back to the browser. Cloud Map supplies endpoint discovery; it is not itself a load balancer.

The ECS service uses `awsvpc`, so each Fargate task receives an ENI in one of the two public subnets. A public IP and Internet Gateway route let the task pull its image and send logs without a NAT Gateway or VPC endpoints. The task security group allows inbound application traffic only from the VPC Link security group; the public IP does not permit direct access to the website container.

## Terraform modules

- `networking`: dual-stack VPC, two public subnets in separate AZs, an Internet Gateway IPv4 route, and an IPv6 egress-only route. There is no NAT Gateway or VPC endpoint.
- `security`: VPC Link and task security groups. VPC Link egress and task ingress are limited to TCP 8080 between those groups. Task egress permits HTTPS for ECR image pulls and CloudWatch Logs. No inbound internet rule is created.
- `iam`: ECS task execution role for image pulls and log delivery. There is no task role because this Flask app does not call AWS APIs.
- `ecr`: private mutable image repository, scan-on-push, AES-256 encryption, and lifecycle retention of the ten most recent images.
- `ecs-cluster`: ECS cluster with configurable Container Insights and Fargate/Fargate Spot capacity providers.
- `ecs-task`: ARM64 Fargate task definition, container/log configuration, and `/health` container health check.
- `cloudmap`: private `cloudmap.local` namespace and SRV service. ECS registers and deregisters task IP/port records; ECS container health is reflected through Cloud Map custom health.
- `ecs-service`: desired task count, Fargate Spot strategy, public-subnet task networking, Cloud Map registration, and deployment rollback circuit breaker.
- `api-vpc-link`: VPC Link ENIs in the VPC subnets.
- `api-gateway`: public HTTP API, Cloud Map HTTP proxy integration, root/proxy routes, and auto-deployed default stage.

Tasks reach ECR and CloudWatch Logs over HTTPS through the Internet Gateway. The public IP is used for outbound connections; the task security group still blocks direct inbound internet traffic.

## Configuration and cost

Review `Terraform/terraform.tfvars` before deployment. The example uses ARM64 Fargate Spot, 0.25 vCPU, 512 MiB memory, two AZs, and `desired_task_count = 1`. Terraform creates an ECR repository, not a Docker image; Docker separately builds and pushes the ARM64 image. The task gets a public IPv4 address for outbound AWS API access, which may incur a separate public IPv4 charge.

This stack is not guaranteed to be Free Tier eligible. API Gateway VPC Links can incur recurring hourly charges even when the ECS desired count is zero. Fargate Spot runtime, public IPv4 addresses, API Gateway requests, Cloud Map/Route 53, ECR storage, and CloudWatch Logs may also incur charges. Spot capacity and prices vary, and capacity is not guaranteed. Review AWS pricing and the Terraform plan before applying.

## Deploy (Windows PowerShell)

Run commands from the `cloudmap` project directory. Prerequisites: Terraform 1.6+, AWS CLI credentials with permission to create the listed resources, Docker Desktop with Buildx, and an account/region quota that permits the resources.

### 1. Initialize, validate, and review

```powershell
terraform -chdir=Terraform fmt -recursive
terraform -chdir=Terraform init
terraform -chdir=Terraform validate
terraform -chdir=Terraform plan
```

Review resource counts and costs. For the first apply, override the task count to zero so ECS does not try to start a task before the image is pushed:

```powershell
terraform -chdir=Terraform apply -var="desired_task_count=0"
```

This creates the ECS task definition and service with zero tasks.

### 3. Build and push the ARM64 image

```powershell
.\scripts\build-image.ps1
.\scripts\push-image.ps1
```

The build script uses the repository URL and tag from Terraform outputs. The push script authenticates Docker to ECR using AWS CLI credentials.

### 4. Start one task

After pushing the image, `terraform.tfvars` already sets `desired_task_count = 1`; apply that configuration:

```powershell
terraform -chdir=Terraform plan
terraform -chdir=Terraform apply
```

ECS should start a Fargate Spot task. If the task cannot start, check ECS service events, Fargate Spot availability, and account vCPU quotas.

### 5. Verify and test

```powershell
$Region = terraform -chdir=Terraform output -raw aws_region
$Cluster = terraform -chdir=Terraform output -raw ecs_cluster_name
$Service = terraform -chdir=Terraform output -raw ecs_service_name
aws ecs describe-services --region $Region --cluster $Cluster --services $Service
aws ecs list-tasks --region $Region --cluster $Cluster --service-name $Service
.\scripts\test-api.ps1
```

Use task ARNs returned by `list-tasks` with `aws ecs describe-tasks`. Get the API URL with `terraform -chdir=Terraform output -raw api_gateway_url`.

### 6. Clean up

```powershell
terraform -chdir=Terraform destroy
```

Confirm the destroy plan. If ECR refuses repository deletion because images remain, delete those images and retry. Destroy the stack when finished to stop ongoing resource charges.

## Troubleshooting

- **Task does not start / no Spot capacity:** check the ECS service events, Fargate Spot capacity in the selected region, and Fargate vCPU quotas.
- **Image pull or logs fail:** check the ARM64 ECR tag, task execution-role policy, public subnet Internet Gateway route, task public-IP assignment, and HTTPS task egress rule.
- **Cloud Map has no healthy instance:** confirm the ECS task is running, service registry container name/port match the task definition, and the container health check passes.
- **API Gateway returns 500/502 or times out:** confirm the VPC Link is `AVAILABLE`, the Cloud Map instance is healthy, and VPC Link egress/task ingress permit TCP 8080.
- **No API URL output:** Terraform apply did not complete successfully; inspect the failed resource and re-run `terraform plan` before applying again.

Useful commands:

```powershell
aws ecs describe-services --region $Region --cluster $Cluster --services $Service
aws ecs list-tasks --region $Region --cluster $Cluster --service-name $Service
```
