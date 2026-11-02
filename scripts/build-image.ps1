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

$Image = "${RepositoryUrl}:$ImageTag"
docker buildx build --platform linux/amd64 --load --tag $Image --file $Dockerfile $ProjectRoot
if ($LASTEXITCODE -ne 0) {
  throw "Docker image build failed."
}

Write-Output "Built $Image for linux/amd64."