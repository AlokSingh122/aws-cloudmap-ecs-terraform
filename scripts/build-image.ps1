$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TerraformDir = Join-Path $ProjectRoot "Terraform"
$Dockerfile = Join-Path $ProjectRoot "app\Dockerfile"

$RepositoryUrl = (& terraform "-chdir=$TerraformDir" output -raw ecr_repository_url).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the ECR repository URL. Apply Terraform first."
}

$ImageTag = (& terraform "-chdir=$TerraformDir" output -raw image_tag).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the configured image tag. Apply Terraform first."
}

$CpuArchitecture = (& terraform "-chdir=$TerraformDir" output -raw cpu_architecture).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the configured CPU architecture. Apply Terraform first."
}

$Platform = switch ($CpuArchitecture) {
  "ARM64" { "linux/arm64" }
  "X86_64" { "linux/amd64" }
  default { throw "Unsupported CPU architecture '$CpuArchitecture'." }
}

$Image = "${RepositoryUrl}:$ImageTag"
docker buildx build --platform $Platform --load --tag $Image --file $Dockerfile $ProjectRoot
if ($LASTEXITCODE -ne 0) {
  throw "Docker image build failed."
}

Write-Output "Built $Image for $Platform."