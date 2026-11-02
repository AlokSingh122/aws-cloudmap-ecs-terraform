$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TerraformDir = Join-Path $ProjectRoot "Terraform"
$ApiUrl = (& terraform "-chdir=$TerraformDir" output -raw api_gateway_url).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not read the API URL. Apply Terraform first."
}

foreach ($Path in @("/", "/health", "/info")) {
  $Response = Invoke-WebRequest -Uri "$ApiUrl$Path" -Method Get -UseBasicParsing
  if ($Response.StatusCode -ne 200) {
    throw "Request to $Path returned HTTP $($Response.StatusCode)."
  }

  Write-Output "$Path -> HTTP $($Response.StatusCode)"
  if ($Path -ne "/") {
    Write-Output $Response.Content
  }
}