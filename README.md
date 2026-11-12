# CloudMap ECS on EC2

This learning project deploys a Flask container to Amazon ECS on one ARM64 EC2 container host. A public API Gateway HTTP API reaches the task through a VPC Link and AWS Cloud Map. It does not create an ALB, NLB, NAT Gateway, or VPC endpoints.

## Architecture and request flow

The browser resolves the public API Gateway hostname and opens HTTPS to the HTTP API. API Gateway matches `ANY /` or `ANY /{proxy+}`, then uses a VPC Link to reach the integration. The integration uses the Cloud Map service ARN; API Gateway calls Cloud Map `DiscoverInstances`, selects a healthy ECS SRV registration, and forwards the request to the EC2 host on TCP 8080. The ECS task uses bridge networking with host port 8080. Flask handles the route, and the response follows the same path back to the browser. Cloud Map supplies endpoint discovery; it is not itself a load balancer.

The ECS-optimized ARM64 EC2 host runs the ECS agent and receives a public IP in a public subnet. It pulls the container image and sends logs through the Internet Gateway without a NAT Gateway or VPC endpoints. Its security group allows application traffic only from the VPC Link security group; the host's public IP does not allow direct access to the website container.

## Step-by-Step Implementation: Prometheus and Grafana

This section documents the monitoring workflow used with the project and the
exported dashboards in [`grafana/dashboards/`](grafana/dashboards/). It is a
manual implementation guide, not a claim that the current Terraform stack
installs Prometheus, Grafana, Node Exporter, or cAdvisor. The current Terraform
configuration creates one ARM64 ECS container host; it does not create the
separate monitoring EC2 host described below or configure exporter ingress.

The notes also cover an earlier `monitoring-app` deployment that used
application port 5000. Do not mix that deployment with this Cloud Map
application: this project uses the `cloudmap-fargate-demo` application on port
8080. The private IP address of an EC2 instance can change; use the current
instance's private IP rather than copying an address from old notes.

### 1. Monitoring architecture and network access

The monitoring design uses two hosts:

| Host | Components | Metrics endpoints |
|---|---|---|
| ECS EC2 host | ECS agent and application containers; Node Exporter and cAdvisor are installed separately | Node Exporter on TCP 9100; cAdvisor on TCP 8081 |
| Monitoring EC2 host | Prometheus and Grafana | Prometheus on TCP 9090; Grafana on TCP 3000 |

Prometheus scrapes the ECS host over its **private IP**. Keep the Prometheus
web UI and Grafana bound to localhost and reach them through an SSH tunnel.
Configure the ECS host security group to allow TCP 9100 and 8081 **only from
the monitoring host's security group**. Do not open exporter, Prometheus, or
Grafana ports to `0.0.0.0/0` or the public internet.

The security groups in this repository currently allow application traffic on
port 8080 from the API Gateway VPC Link and SSH from the EC2 Instance Connect
managed prefix list. They do not include the monitoring host or exporter rules;
add and review those rules before attempting remote scraping. The monitoring
host should be in a subnet with network connectivity to the ECS host.

### 2. Install Node Exporter on the ECS EC2 host

Node Exporter exposes host-level CPU, memory, disk, and network metrics. The
commands below use the ARM64 release for the project's `t4g` host. Verify the
release version and checksum against the official Node Exporter release before
installing it.

```bash
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-arm64.tar.gz
tar -xzf node_exporter-1.9.1.linux-arm64.tar.gz
sudo install -o root -g root -m 0755 \
  node_exporter-1.9.1.linux-arm64/node_exporter \
  /usr/local/bin/node_exporter
sudo useradd --system --no-create-home --shell /sbin/nologin node_exporter
```

Create `/etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable the service and verify its metrics endpoint:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
curl http://127.0.0.1:9100/metrics
```

Look for metrics such as `node_cpu_seconds_total`,
`node_memory_MemAvailable_bytes`, `node_filesystem_size_bytes`, and
`node_network_transmit_bytes_total`.

### 3. Run cAdvisor for container metrics

cAdvisor reports Docker container CPU, memory, filesystem, and network
metrics. Port 8081 is used on the host so it does not conflict with the
application's port 8080.

```bash
sudo docker run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  -p 8081:8080 \
  --privileged \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker:/var/lib/docker:ro \
  -v /dev/disk:/dev/disk:ro \
  gcr.io/cadvisor/cadvisor:<PINNED_VERSION>
```

Replace `<PINNED_VERSION>` with a tested cAdvisor release that supports the
host architecture. cAdvisor needs extensive host visibility, so treat this as
a privileged host-level component: review its mounts and permissions, keep it
patched, and restrict TCP 8081 to the monitoring host.

Verify the container and endpoint:

```bash
sudo docker ps
sudo docker inspect --format='{{.State.Health.Status}}' cadvisor
curl http://127.0.0.1:8081/metrics
```

Metrics include `container_cpu_usage_seconds_total`,
`container_memory_usage_bytes`, and `container_network_transmit_bytes_total`.

### 4. Configure and run Prometheus on the monitoring host

Create persistent storage and `/opt/prometheus/prometheus.yml`:

```bash
sudo mkdir -p /opt/prometheus/data
sudo tee /opt/prometheus/prometheus.yml >/dev/null <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["127.0.0.1:9090"]

  - job_name: node-exporter
    static_configs:
      - targets: ["<ECS_PRIVATE_IP>:9100"]

  - job_name: cadvisor
    static_configs:
      - targets: ["<ECS_PRIVATE_IP>:8081"]
EOF
```

Replace `<ECS_PRIVATE_IP>` with the current private IPv4 address of the ECS
host. The `127.0.0.1` targets shown in some local test setups apply only when
Prometheus and the exporters run on the same machine; they are not correct for
this two-host layout.

Run Prometheus with persistent data, bounded resources, two-day retention, and
a localhost-only web listener. Pin the image to a tested version rather than
using `latest`:

```bash
sudo docker run -d \
  --name prometheus \
  --restart unless-stopped \
  --network host \
  --memory=512m \
  --cpus=0.5 \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  -v /opt/prometheus/data:/prometheus \
  prom/prometheus:<PINNED_VERSION> \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --storage.tsdb.retention.time=2d \
  --web.listen-address=127.0.0.1:9090
```

Check Prometheus locally:

```bash
sudo docker ps
sudo docker logs prometheus
curl http://127.0.0.1:9090/-/healthy
```

### 5. Run Grafana on the monitoring host

Persist Grafana's data in a Docker volume, bind the web server to localhost,
and set a unique administrator password through a secure secret-management
method. Do not use the default `admin` password or commit credentials.

```bash
sudo docker volume create grafana-storage
sudo docker run -d \
  --name grafana \
  --restart unless-stopped \
  --network host \
  -e GF_SERVER_HTTP_ADDR=127.0.0.1 \
  -e GF_SERVER_HTTP_PORT=3000 \
  -e GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD" \
  -v grafana-storage:/var/lib/grafana \
  grafana/grafana:<PINNED_VERSION>
```

Set `GRAFANA_ADMIN_PASSWORD` securely in the shell or secret manager before
running the command. Verify startup with `sudo docker ps` and
`sudo docker logs grafana`.

### 6. Open Grafana securely and add Prometheus

From Windows PowerShell, create an SSH tunnel to the monitoring host. Replace
the key path and public IP with your own values; keep the terminal open while
using Grafana:

```powershell
ssh -i "$env:USERPROFILE\.ssh\grafana-ec2" -N `
  -L 3000:127.0.0.1:3000 `
  ec2-user@<MONITORING_EC2_PUBLIC_IP>
```

Open `http://localhost:3000` in a browser and sign in with the administrator
credentials you configured. Add a Prometheus data source in Grafana and set
its URL to `http://127.0.0.1:9090`, then choose **Save & test**. This localhost
URL is correct because Grafana and Prometheus share the monitoring host and
use host networking.

### 7. Check targets and import dashboards

Use the same SSH tunnel approach to open `http://localhost:9090/targets`. The
`prometheus`, `node-exporter`, and `cadvisor` targets should show **UP**. If a
target is down, verify the ECS host's private IP, exporter processes,
security-group rules, and network reachability from the monitoring host.

The exported dashboards are stored in [`grafana/dashboards/`](grafana/dashboards/):

- `ec2-cpu.json`, `ec2-memory.json`, and `ec2-disk.json`
- `network-transmit.json`
- `ecs-container-cpu.json` and `ecs-container-memory.json`
- `container-last-seen.json` and `cadvisor-monitoring-status.json`

Import a dashboard using Grafana's dashboard import workflow, select the
Prometheus data source when prompted, and verify that the queries match the
metric labels exposed by your exporters. The exports may need data-source or
label adjustments for a different Prometheus/Grafana environment.

Example PromQL queries:

| Metric | Query |
|---|---|
| EC2 CPU usage (%) | `100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))` |
| EC2 memory usage (%) | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` |
| Root filesystem usage (%) | `100 * (1 - node_filesystem_avail_bytes{mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{mountpoint="/",fstype!~"tmpfs|overlay"})` |
| EC2 network transmit | `rate(node_network_transmit_bytes_total{device="ens5"}[5m])` |
| Container CPU | `sum by (name) (rate(container_cpu_usage_seconds_total{id!="/"}[5m]))` |
| Container memory | `sum by (name) (container_memory_usage_bytes{id!="/"})` |

Network interface names and cAdvisor labels vary by host and version. Inspect
the available series in Prometheus before relying on a device filter or
container label.

### 8. Verify and troubleshoot

Test a dashboard using normal application traffic and inspect
`sudo docker stats` on the ECS host. For a short CPU-load test, use a
disposable or explicitly approved test instance, not a production workload:

```bash
sudo dnf install stress-ng -y
stress-ng --cpu 2 --timeout 60s
```

Check service health and host resources with:

```bash
sudo systemctl status node_exporter
sudo docker ps
sudo docker logs prometheus
sudo docker logs grafana
sudo docker logs cadvisor
free -h
df -h
sudo ss -tulpn
```

Common causes of problems:

- **Exporter target is down:** confirm the process/container is healthy, the
  target uses the ECS host's current private IP, and the ECS security group
  permits ports 9100/8081 only from the monitoring host.
- **cAdvisor cannot start or has no metrics:** check Docker logs, host
  architecture, required read-only mounts, and the selected cAdvisor release.
- **Grafana cannot reach Prometheus:** ensure both run on the monitoring host
  and the Grafana data source URL is `http://127.0.0.1:9090`.
- **Grafana is not reachable in the browser:** verify the SSH tunnel and
  localhost-only listener; do not solve this by opening TCP 3000 publicly.
- **High memory use:** Prometheus, Grafana, cAdvisor, and ECS tasks compete for
  host resources. Check `free -h`, container limits, and Prometheus retention.

### Monitoring scope and limitations

Node Exporter provides host-level metrics and cAdvisor provides container
resource metrics. cAdvisor does not report ECS service-level desired/running
task counts, deployment state, or ECS service events; use AWS CloudWatch/ECS
metrics or an ECS-aware exporter for those. This Flask application currently
exposes `/health` but does not implement a Prometheus `/metrics` endpoint, so
do not claim application metrics are collected unless instrumentation and a
Prometheus scrape target are added and verified. Likewise, the exporters,
Prometheus, and Grafana described here require separate deployment and
security-group configuration; they are not created by this repository's
current Terraform configuration.

## Terraform modules

- `networking`: dual-stack VPC, two public subnets in separate AZs, an Internet Gateway IPv4 route, and an IPv6 egress-only route. There is no NAT Gateway or VPC endpoint.
- `security`: VPC Link and ECS host security groups. VPC Link egress and host ingress are limited to TCP 8080 between those groups. Host egress permits HTTPS for ECS agent communication, ECR image pulls, and CloudWatch Logs. No inbound internet rule is created.
- `iam`: ECS task execution role for image pulls and log delivery, and EC2 instance role/profile for the ECS agent. There is no task role because this Flask app does not call AWS APIs.
- `ecr`: private mutable image repository, scan-on-push, AES-256 encryption, and lifecycle retention of the ten most recent images.
- `ecs-cluster`: ECS cluster with configurable Container Insights.
- `ecs-host`: one ECS-optimized ARM64 EC2 host, joined to the cluster through its user data and instance profile.
- `ecs-task`: ARM64 EC2 task definition using bridge networking, container/log configuration, and `/health` container health check.
- `cloudmap`: private `cloudmap.local` namespace and SRV service. ECS registers and deregisters task IP/port records; ECS container health is reflected through Cloud Map custom health.
- `ecs-service`: EC2 launch type, desired task count, Cloud Map registration, and deployment rollback circuit breaker.
- `api-vpc-link`: VPC Link ENIs in the VPC subnets.
- `api-gateway`: public HTTP API, Cloud Map HTTP proxy integration, root/proxy routes, and auto-deployed default stage.

The EC2 host reaches ECS, ECR, and CloudWatch Logs over HTTPS through the Internet Gateway. Its public IP is used for outbound connections; the security group blocks direct inbound internet traffic.

## Configuration and cost

Review `Terraform/terraform.tfvars` before deployment. The example uses a `t4g.small` ARM64 EC2 host, a 30 GiB encrypted gp3 root volume, 0.25 vCPU, 512 MiB task memory, two AZs, and `desired_task_count = 1`. Terraform creates an ECR repository, not a Docker image; Docker separately builds and pushes the ARM64 image. The EC2 host receives a public IPv4 address for outbound AWS API access, which may incur a separate public IPv4 charge.

This stack is not guaranteed to be Free Tier eligible. The EC2 host, its public IPv4 address, API Gateway VPC Link (which may incur recurring hourly charges even when idle), API Gateway requests, Cloud Map/Route 53, ECR storage, and CloudWatch Logs may incur charges. Review AWS pricing and the Terraform plan before applying.

## Connect to the EC2 container host

Use **EC2 Instance Connect** from the EC2 console's **Connect** page. The host security group allows SSH only from AWS's regional EC2 Instance Connect managed prefix list; it does not allow SSH directly from the public internet. Select the EC2 Instance Connect tab and connect as `ec2-user`. The AWS identity used in the console must have permission to send an EC2 Instance Connect SSH public key.

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

This creates the EC2 host and ECS task definition/service with zero tasks.

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

ECS should start the container on the EC2 host. If the task cannot start, check that the host registered in the cluster, instance health, ECS service events, and available host CPU/memory.

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

- **Task does not start / no EC2 capacity:** check that the instance is running and registered in the ECS cluster, then inspect ECS service events and host CPU/memory.
- **Image pull or logs fail:** check the ARM64 ECR tag, task execution-role and EC2 instance-role policies, public subnet Internet Gateway route, host public IP, and HTTPS host egress rule.
- **Cloud Map has no healthy instance:** confirm the ECS task is running, service registry container name/port match the task definition, and the container health check passes.
- **API Gateway returns 500/502 or times out:** confirm the VPC Link is `AVAILABLE`, the Cloud Map instance is healthy, and VPC Link egress/host ingress permit TCP 8080.
- **No API URL output:** Terraform apply did not complete successfully; inspect the failed resource and re-run `terraform plan` before applying again.

Useful commands:

```powershell
aws ecs describe-services --region $Region --cluster $Cluster --services $Service
aws ecs list-tasks --region $Region --cluster $Cluster --service-name $Service
```
