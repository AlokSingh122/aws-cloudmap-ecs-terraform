# CloudMap ECS on EC2 Spot

This learning project deploys a Flask container to Amazon ECS on EC2 Spot. A public API Gateway HTTP API reaches the private ECS task through a VPC Link and AWS Cloud Map. It does not create an ALB, NLB, NAT Gateway, or Fargate service.

## Architecture and request flow

The browser resolves the public API Gateway hostname and opens HTTPS to the HTTP API. API Gateway matches `ANY /` or `ANY /{proxy+}`, then uses a VPC Link to reach the private integration. The integration uses the Cloud Map service ARN; API Gateway calls Cloud Map `DiscoverInstances`, selects a healthy task IP and port from the ECS SRV registrations, and forwards the request to the task ENI on TCP 8080. Flask handles the route, and the HTTP response follows the same path back to the browser. Cloud Map supplies endpoint discovery; it is not itself a load balancer.

The ECS service uses `awsvpc`, so every task receives a private ENI and private IP in one of the two private subnets. The EC2 host runs the ECS agent and provides task capacity. The ECS capacity provider adjusts the Auto Scaling Group when tasks are pending. Its initial ASG capacity and initial ECS desired count are zero by design.

## Terraform modules

- `networking`: dual-stack VPC, two private subnets in separate AZs, private route table, and IPv6 egress-only gateway route. The VPC local route is created automatically. There is no public IPv4 route or NAT Gateway.
- `security`: separate host, task, VPC Link, and endpoint security groups. VPC Link egress and task ingress are limited to TCP 8080 between those groups. The host can reach HTTPS interface endpoints and the S3 managed prefix list. No inbound internet rules are created.
- `vpc-endpoints`: ECR API/registry, ECS, ECS agent, ECS telemetry, CloudWatch Logs interface endpoints, and an S3 gateway endpoint. Interface endpoints have hourly and data-processing charges; the S3 gateway endpoint has no hourly charge.
- `iam`: EC2 ECS-container-instance role/profile and ECS task execution role. The execution role grants image-pull and log-delivery permissions. There is no task role because this Flask app does not call AWS APIs.
- `ecr`: private mutable image repository, scan-on-push, AES-256 encryption, and lifecycle retention of the ten most recent images.
- `ecs-cluster`: ECS cluster with Container Insights.
- `ecs-compute`: latest Amazon Linux 2023 ECS-optimized AMI from SSM, x86_64 launch template, IMDSv2, encrypted gp3 root disk, Spot ASG, and ECS managed capacity provider. The ASG ignores ECS-managed desired capacity changes.
- `ecs-task`: EC2-compatible `awsvpc` task definition, container/log configuration, and `/health` container health check.
- `cloudmap`: private `cloudmap.local` namespace and SRV service. ECS registers and deregisters task IP/port records; ECS container health is reflected through Cloud Map custom health.
- `ecs-service`: desired task count, capacity provider strategy, private task networking, Cloud Map registration, and deployment rollback circuit breaker.
- `api-vpc-link`: VPC Link ENIs in the private subnets.
- `api-gateway`: public HTTP API, Cloud Map HTTP proxy integration, root/proxy routes, and auto-deployed default stage.

Interface endpoints let private hosts reach AWS APIs without NAT. ECR image layers are fetched from S3 through the gateway endpoint. The ECS agent, task image pulls, and CloudWatch logging depend on the appropriate endpoints and IAM roles.

## Configuration and cost

Review `Terraform/terraform.tfvars` before deployment. The example uses `ap-south-1`, two AZs, `t3.large`, and `desired_task_count = 0`. Terraform creates an ECR repository, not a Docker image; Docker separately builds and pushes that image. Set the desired count to one only after the push.

This stack is not guaranteed to be Free Tier eligible. Interface VPC endpoints and API Gateway VPC Links can incur recurring hourly charges even when the ECS desired count is zero. ECS/EC2 Spot, EBS, API Gateway requests, Cloud Map/Route 53, ECR storage, CloudWatch Logs, and IPv6 data transfer may also incur charges. Spot capacity and prices vary, and capacity is not guaranteed. Review AWS pricing and the Terraform plan before applying.

## Deploy (Windows PowerShell)

Run commands from the `cloudmap` project directory. Prerequisites: Terraform 1.6+, AWS CLI credentials with permission to create the listed resources, Docker Desktop with Buildx, and an account/region quota that permits the resources.

### 1. Initialize, validate, and review

```powershell
terraform -chdir=Terraform fmt -recursive
terraform -chdir=Terraform init
terraform -chdir=Terraform validate
terraform -chdir=Terraform plan
```

Review resource counts and costs. Keep `desired_task_count = 0` for this first apply.

### 2. Create infrastructure and ECR

```powershell
terraform -chdir=Terraform apply
```

This creates the ECS task definition and service with zero tasks; therefore it does not yet request an EC2 instance.

### 3. Build and push the AMD64 image

```powershell
.\scripts\build-image.ps1
.\scripts\push-image.ps1
```

The build script uses the repository URL and tag from Terraform outputs. The push script authenticates Docker to ECR using AWS CLI credentials.

### 4. Start one task

Change `desired_task_count` to `1` in `Terraform/terraform.tfvars`, then run:

```powershell
terraform -chdir=Terraform plan
terraform -chdir=Terraform apply
```

ECS should create a pending task; the capacity provider then asks the ASG for Spot capacity. If the task cannot be placed, check ECS service events, ASG activity history, Spot capacity, and account vCPU quotas.

### 5. Verify and test

```powershell
$Region = terraform -chdir=Terraform output -raw aws_region
$Cluster = terraform -chdir=Terraform output -raw ecs_cluster_name
$Service = terraform -chdir=Terraform output -raw ecs_service_name
$Vpc = terraform -chdir=Terraform output -raw vpc_id

aws ecs describe-services --region $Region --cluster $Cluster --services $Service
aws ecs list-container-instances --region $Region --cluster $Cluster
.\scripts\test-api.ps1
```

Use the ARNs returned by `list-container-instances` and `list-tasks` with their corresponding `describe-*` commands. Get the API URL with `terraform -chdir=Terraform output -raw api_gateway_url`.

### 6. Clean up

```powershell
terraform -chdir=Terraform destroy
```

Confirm the destroy plan. If ECR refuses repository deletion because images remain, delete those images and retry. Destroy the stack when finished to stop ongoing resource charges.

## Troubleshooting

- **No EC2 instance:** confirm Terraform was applied in the intended account and region. With desired count zero, no task is pending and no instance is expected. For desired count one, inspect ECS service events and Auto Scaling activity history.
- **Task remains pending / no Spot capacity:** check cluster capacity-provider association, ASG min/max/desired settings, Spot availability for `t3.large`, and EC2 vCPU quotas.
- **Instance does not join ECS:** check the instance profile, `/etc/ecs/ecs.config` `ECS_CLUSTER` value, ECS-optimized AMI, and ECS/ECS-agent/telemetry endpoint states and DNS.
- **Image pull or logs fail:** check ECR repository/tag, execution-role policy, endpoint SG ingress from the host SG, host egress to endpoints/S3, and endpoint states.
- **Cloud Map has no healthy instance:** confirm the ECS task is running, service registry container name/port match the task definition, and the container health check passes.
- **API Gateway returns 500/502 or times out:** confirm the VPC Link is `AVAILABLE`, the Cloud Map instance is healthy, and VPC Link egress/task ingress permit TCP 8080.
- **No API URL output:** Terraform apply did not complete successfully; inspect the failed resource and re-run `terraform plan` before applying again.

Useful commands:

```powershell
aws ecs describe-services --region $Region --cluster $Cluster --services $Service
aws autoscaling describe-auto-scaling-groups --region $Region --auto-scaling-group-names cloudmap-demo-ecs-asg
aws autoscaling describe-scaling-activities --region $Region --auto-scaling-group-name cloudmap-demo-ecs-asg
aws ec2 describe-vpc-endpoints --region $Region --filters "Name=vpc-id,Values=$Vpc"
```
