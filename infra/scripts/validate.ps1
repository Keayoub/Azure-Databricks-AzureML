#!/usr/bin/env pwsh

Write-Host "========================================================" -ForegroundColor Green
Write-Host "Pre-Deployment Validation" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

$all_passed = $true

# Check 1: Azure CLI
Write-Host "Checking Azure CLI..." -ForegroundColor Cyan
az --version > $null 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Host "  ✓ Azure CLI is installed" -ForegroundColor Green
} else {
  Write-Host "  ✗ Azure CLI is not installed or not in PATH" -ForegroundColor Red
  Write-Host "    Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
  $all_passed = $false
}

# Check 2: Terraform
Write-Host "Checking Terraform..." -ForegroundColor Cyan
terraform version > $null 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Host "  ✓ Terraform is installed" -ForegroundColor Green
} else {
  Write-Host "  ✗ Terraform is not installed or not in PATH" -ForegroundColor Red
  Write-Host "    Install from: https://www.terraform.io/downloads" -ForegroundColor Yellow
  $all_passed = $false
}

# Check 3: Azure authentication
Write-Host "Checking Azure authentication..." -ForegroundColor Cyan
az account show > $null 2>&1
if ($LASTEXITCODE -eq 0) {
  $account = az account show --query "name" -o tsv
  Write-Host "  ✓ Authenticated to Azure: $account" -ForegroundColor Green
} else {
  Write-Host "  ✗ Not authenticated to Azure" -ForegroundColor Red
  Write-Host "    Run: az login" -ForegroundColor Yellow
  $all_passed = $false
}

# Check 4: DATABRICKS_ACCOUNT_ID
Write-Host "Checking Databricks Account ID..." -ForegroundColor Cyan
if ($env:DATABRICKS_ACCOUNT_ID) {
  Write-Host "  ✓ DATABRICKS_ACCOUNT_ID is set: $($env:DATABRICKS_ACCOUNT_ID.Substring(0,8))..." -ForegroundColor Green
} else {
  Write-Host "  ✗ DATABRICKS_ACCOUNT_ID environment variable not set" -ForegroundColor Red
  Write-Host "    Set it with: `$env:DATABRICKS_ACCOUNT_ID = 'your-account-id'" -ForegroundColor Yellow
  Write-Host "    Get your account ID from: https://accounts.azuredatabricks.net" -ForegroundColor Yellow
  $all_passed = $false
}

# Check 5: Bicep parameter file
Write-Host "Checking Bicep configuration..." -ForegroundColor Cyan
$bicep_params = Join-Path $PSScriptRoot "..\main.bicepparam"
if (Test-Path $bicep_params) {
  Write-Host "  ✓ Bicep parameter file found: $bicep_params" -ForegroundColor Green
} else {
  Write-Host "  ✗ Bicep parameter file not found: $bicep_params" -ForegroundColor Red
  $all_passed = $false
}

# Check 6: Azure subscription
Write-Host "Checking Azure subscription..." -ForegroundColor Cyan
$sub_id = az account show --query "id" -o tsv 2>/dev/null
if ($sub_id) {
  Write-Host "  ✓ Active subscription: $sub_id" -ForegroundColor Green
} else {
  Write-Host "  ✗ No active Azure subscription" -ForegroundColor Red
  $all_passed = $false
}

# Results
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
if ($all_passed) {
  Write-Host "✓ All pre-deployment checks passed!" -ForegroundColor Green
  Write-Host "========================================================" -ForegroundColor Green
  exit 0
} else {
  Write-Host "✗ Some checks failed. Please fix the issues above." -ForegroundColor Red
  Write-Host "========================================================" -ForegroundColor Red
  exit 1
}
