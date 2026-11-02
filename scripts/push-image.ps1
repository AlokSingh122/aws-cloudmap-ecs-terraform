$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TerraformDir = Join-Path $ProjectRoot "Terraform"

$RepositoryUrl = (& terraform "-chdir=$TerraformDir" output -raw ecr_repository_url).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the ECR repository URL. Apply Terraform first."
}

$Region = (& terraform "-chdir=$TerraformDir" output -raw aws_region).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the AWS region. Apply Terraform first."
}

$ImageTag = (& terraform "-chdir=$TerraformDir" output -raw image_tag).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the configured image tag. Apply Terraform first."
}

$Registry = $RepositoryUrl.Split("/")[0]
$Image = "${RepositoryUrl}:$ImageTag"
$Password = aws ecr get-login-password --region $Region
if ($LASTEXITCODE -ne 0) {
  throw "Could not retrieve ECR login credentials."
}

$Password | docker login --username AWS --password-stdin $Registry
if ($LASTEXITCODE -ne 0) {
  throw "Docker login to ECR failed."
}

docker push $Image
if ($LASTEXITCODE -ne 0) {
  throw "Docker image push failed."
}

Write-Output "Pushed $Image."