#!/usr/bin/env pwsh

Write-Host "========================================================" -ForegroundColor Green
Write-Host "Post-Provision: Creating Unity Catalog Metastore" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

# Get outputs from Bicep deployment
Write-Host "Retrieving Bicep deployment outputs..." -ForegroundColor Cyan

$SUBSCRIPTION_ID = $(az account show --query id -o tsv)
Write-Host "  ✓ Subscription ID: $SUBSCRIPTION_ID" -ForegroundColor Green

# Get workspace info from azd environment variables (set by Bicep outputs)
$DATABRICKS_RESOURCE_GROUP = $env:databricksResourceGroupName
$SHARED_RESOURCE_GROUP = $env:sharedResourceGroupName
$WORKSPACE_URL = $env:databricksWorkspaceUrl

if (-not $DATABRICKS_RESOURCE_GROUP -or -not $WORKSPACE_URL -or -not $SHARED_RESOURCE_GROUP) {
  Write-Host "ERROR: Missing Databricks environment variables" -ForegroundColor Red
  Write-Host "  DATABRICKS_RESOURCE_GROUP: $DATABRICKS_RESOURCE_GROUP" -ForegroundColor Red
  Write-Host "  SHARED_RESOURCE_GROUP: $SHARED_RESOURCE_GROUP" -ForegroundColor Red
  Write-Host "  WORKSPACE_URL: $WORKSPACE_URL" -ForegroundColor Red
  exit 1
}

# Extract workspace ID from URL (e.g., "adb-7405605886894136.16.azuredatabricks.net" -> "7405605886894136")
$WORKSPACE_URL_TRIMMED = $WORKSPACE_URL -replace "^adb-" -replace "\..*$"
$DATABRICKS_WORKSPACE_ID = $WORKSPACE_URL_TRIMMED.Split(".")[0]
$DATABRICKS_WORKSPACE_HOST = "https://$WORKSPACE_URL"

Write-Host "  ✓ Databricks Resource Group: $DATABRICKS_RESOURCE_GROUP" -ForegroundColor Green
Write-Host "  ✓ Shared Resource Group: $SHARED_RESOURCE_GROUP" -ForegroundColor Green
Write-Host "  ✓ Workspace ID: $DATABRICKS_WORKSPACE_ID" -ForegroundColor Green
Write-Host "  ✓ Workspace Host: $DATABRICKS_WORKSPACE_HOST" -ForegroundColor Green

# Get workspace region
$WORKSPACE_DETAILS = $(az databricks workspace list `
  --resource-group $DATABRICKS_RESOURCE_GROUP `
  --query "[0]" -o json | ConvertFrom-Json)

$WORKSPACE_REGION = $WORKSPACE_DETAILS.location
Write-Host "  ✓ Region: $WORKSPACE_REGION" -ForegroundColor Green

# Parse storage outputs from Bicep
$STORAGE_OUTPUTS = $env:storageOutputs | ConvertFrom-Json
$STORAGE_ACCOUNT_NAME = $STORAGE_OUTPUTS.storageAccountName.value
Write-Host "  ✓ Storage Account: $STORAGE_ACCOUNT_NAME" -ForegroundColor Green

# Get environment name from the bicep parameter file (more reliable than AZURE_ENV_NAME)
$BICEP_PARAMS_FILE = Join-Path $PSScriptRoot "..\main.bicepparam"
if (Test-Path $BICEP_PARAMS_FILE) {
  $BICEP_PARAMS = Get-Content $BICEP_PARAMS_FILE -Raw
  # Extract environmentName = 'dev' or "dev"
  if ($BICEP_PARAMS -match "param environmentName = '(\w+)'") {
    $ENV_NAME = $Matches[1]
    Write-Host "  ✓ Environment Name (from bicep): $ENV_NAME" -ForegroundColor Green
  } elseif ($BICEP_PARAMS -match 'param environmentName = "(\w+)"') {
    $ENV_NAME = $Matches[1]
    Write-Host "  ✓ Environment Name (from bicep): $ENV_NAME" -ForegroundColor Green
  } else {
    # Fallback: extract from AZURE_ENV_NAME
    $ENV_NAME = $env:AZURE_ENV_NAME -replace "databricks-azureml-", ""
    Write-Host "  ✓ Environment Name (from AZURE_ENV_NAME): $ENV_NAME" -ForegroundColor Yellow
  }
} else {
  # Fallback if no bicep params file
  $ENV_NAME = $env:AZURE_ENV_NAME -replace "databricks-azureml-", ""
  Write-Host "  ✓ Environment Name (from AZURE_ENV_NAME): $ENV_NAME" -ForegroundColor Yellow
}

# Get project name
$PROJECT_NAME = if ($env:PROJECT_NAME) { $env:PROJECT_NAME } else { "dbxaml" }
$ACCESS_CONNECTOR_NAME = "ac-$PROJECT_NAME-$ENV_NAME"
Write-Host "  ✓ Access Connector: $ACCESS_CONNECTOR_NAME" -ForegroundColor Green
Write-Host ""

# Get Databricks account ID from environment
if (-not $env:DATABRICKS_ACCOUNT_ID) {
  Write-Host "ERROR: DATABRICKS_ACCOUNT_ID not set" -ForegroundColor Red
  Write-Host ""
  Write-Host "PowerShell: `$env:DATABRICKS_ACCOUNT_ID = 'your-account-id'"
  Write-Host "Bash:       export DATABRICKS_ACCOUNT_ID='your-account-id'"
  Write-Host ""
  Write-Host "Get your account ID from: https://accounts.azuredatabricks.net"
  exit 1
}

$DATABRICKS_ACCOUNT_ID = $env:DATABRICKS_ACCOUNT_ID
Write-Host "  ✓ Account ID: $DATABRICKS_ACCOUNT_ID" -ForegroundColor Green
Write-Host ""

# Navigate to terraform metastore directory
Write-Host "Initializing Terraform for Metastore..." -ForegroundColor Cyan

# Get the project root (2 levels up from this script: scripts -> infra -> root)
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TERRAFORM_DIR = Join-Path $PROJECT_ROOT "terraform" "metastore"

Write-Host "  Script Root: $PSScriptRoot" -ForegroundColor Cyan
Write-Host "  Project Root: $PROJECT_ROOT" -ForegroundColor Green
Write-Host "  Terraform Dir: $TERRAFORM_DIR" -ForegroundColor Green

if (-not (Test-Path $TERRAFORM_DIR)) {
  Write-Host "ERROR: Terraform metastore directory not found: $TERRAFORM_DIR" -ForegroundColor Red
  exit 1
}

Push-Location $TERRAFORM_DIR

# Create terraform.tfvars for metastore
Write-Host "Creating metastore terraform.tfvars..."

$tfvars = @"
# Auto-generated by azd postprovision
subscription_id                = "$SUBSCRIPTION_ID"
azure_region                   = "$WORKSPACE_REGION"
project_name                   = "$PROJECT_NAME"
environment_name               = "$ENV_NAME"
shared_resource_group_name     = "$SHARED_RESOURCE_GROUP"
databricks_resource_group_name = "$DATABRICKS_RESOURCE_GROUP"
databricks_workspace_id        = $DATABRICKS_WORKSPACE_ID
databricks_workspace_host      = "$DATABRICKS_WORKSPACE_HOST"
metastore_storage_name         = "$STORAGE_ACCOUNT_NAME"
access_connector_name          = "$ACCESS_CONNECTOR_NAME"
databricks_account_id          = "$DATABRICKS_ACCOUNT_ID"
databricks_region              = "$WORKSPACE_REGION"
"@

Set-Content -Path "terraform.tfvars" -Value $tfvars
Write-Host "  ✓ Created metastore terraform.tfvars" -ForegroundColor Green

Write-Host ""
Write-Host "Cleaning Terraform cache..." -ForegroundColor Cyan
Remove-Item -Path ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".terraform.lock.hcl" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "tfplan" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Running: terraform init..." -ForegroundColor Cyan
terraform init -upgrade

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: terraform init failed" -ForegroundColor Red
  Pop-Location
  exit 1
}
Write-Host "  ✓ Terraform initialized" -ForegroundColor Green

Write-Host ""
Write-Host "Running: terraform validate..." -ForegroundColor Cyan
terraform validate

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: terraform validate failed" -ForegroundColor Red
  Pop-Location
  exit 1
}
Write-Host "  ✓ Terraform configuration valid" -ForegroundColor Green

Write-Host ""
Write-Host "Running: terraform plan..." -ForegroundColor Cyan
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: terraform plan failed" -ForegroundColor Red
  Write-Host ""
  Write-Host "Common issues:" -ForegroundColor Yellow
  Write-Host "  1. Access Connector not found - check SHARED_RESOURCE_GROUP env var" -ForegroundColor Yellow
  Write-Host "  2. Metastore already exists - use 'terraform import' to adopt it" -ForegroundColor Yellow
  Write-Host "  3. Account ID invalid - set DATABRICKS_ACCOUNT_ID correctly" -ForegroundColor Yellow
  Pop-Location
  exit 1
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Metastore Deployment Summary:" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ACCOUNT ID       : $DATABRICKS_ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "  WORKSPACE ID     : $DATABRICKS_WORKSPACE_ID" -ForegroundColor Cyan
Write-Host "  WORKSPACE HOST   : $DATABRICKS_WORKSPACE_HOST" -ForegroundColor Cyan
Write-Host "  REGION           : $WORKSPACE_REGION" -ForegroundColor Cyan
Write-Host "  ACCESS CONNECTOR : $ACCESS_CONNECTOR_NAME" -ForegroundColor Cyan
Write-Host "  STORAGE ACCOUNT  : $STORAGE_ACCOUNT_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Review the plan above to verify resource creation." -ForegroundColor Yellow
Write-Host ""

Write-Host "Running: terraform apply (auto-approved)..." -ForegroundColor Cyan
terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "========================================================" -ForegroundColor Red
  Write-Host "✗ Metastore deployment failed!" -ForegroundColor Red
  Write-Host "========================================================" -ForegroundColor Red
  Write-Host ""
  Write-Host "Troubleshooting:" -ForegroundColor Yellow
  Write-Host "  1. Check tfplan for error details" -ForegroundColor Yellow
  Write-Host "  2. Verify Access Connector exists in $SHARED_RESOURCE_GROUP" -ForegroundColor Yellow
  Write-Host "  3. Verify Account ID is correct: $DATABRICKS_ACCOUNT_ID" -ForegroundColor Yellow
  Write-Host "  4. Check Databricks admin console for metastore configuration" -ForegroundColor Yellow
  Write-Host "  5. Review logs: cat terraform.log" -ForegroundColor Yellow
  Write-Host ""
  Pop-Location
  exit 1
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "✓ Metastore deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Metastore Configuration:" -ForegroundColor Cyan
Write-Host "  Metastore Name   : metastore-$PROJECT_NAME" -ForegroundColor Cyan
Write-Host "  Region           : $WORKSPACE_REGION" -ForegroundColor Cyan
Write-Host "  Workspace        : $DATABRICKS_WORKSPACE_ID is now assigned" -ForegroundColor Cyan
Write-Host ""

# ========== Assign Azure AI Administrator Role ==========
Write-Host "Assigning Azure AI Administrator roles..." -ForegroundColor Cyan
Write-Host ""

$AI_PLATFORM_RG = "rg-$ENV_NAME-$PROJECT_NAME-ai-platform"
$AML_WORKSPACE_NAME = "aml-$ENV_NAME-$PROJECT_NAME"
$AI_HUB_NAME = "aihub-$ENV_NAME-$PROJECT_NAME"
$AML_AI_ADMIN_ROLE_ID = "f2310ffd-7978-4846-9ad3-f6f7c1ec8dfd" # Azure AI Administrator

try {
  # Get Azure ML Workspace
  $amlWorkspace = az ml workspace show -g $AI_PLATFORM_RG -w $AML_WORKSPACE_NAME -o json 2>/dev/null | ConvertFrom-Json
  if ($amlWorkspace) {
    $amlPrincipalId = $amlWorkspace.identity.principal_id
    if ($amlPrincipalId) {
      Write-Host "  ✓ Azure ML Workspace: $AML_WORKSPACE_NAME" -ForegroundColor Green
      Write-Host "    Principal ID: $amlPrincipalId" -ForegroundColor Gray
      
      # Assign Azure AI Administrator at subscription scope
      az role assignment create `
        --assignee-object-id $amlPrincipalId `
        --role $AML_AI_ADMIN_ROLE_ID `
        --scope "/subscriptions/$SUBSCRIPTION_ID" `
        --assignee-principal-type ServicePrincipal `
        2>/dev/null
      
      Write-Host "    ✓ Azure AI Administrator role assigned" -ForegroundColor Green
    }
  }
} catch {
  Write-Host "  ⚠ Could not assign role to Azure ML Workspace: $_" -ForegroundColor Yellow
}

try {
  # Get AI Foundry Hub
  $aiHub = az ml workspace show -g $AI_PLATFORM_RG -w $AI_HUB_NAME -o json 2>/dev/null | ConvertFrom-Json
  if ($aiHub) {
    $aiHubPrincipalId = $aiHub.identity.principal_id
    if ($aiHubPrincipalId) {
      Write-Host "  ✓ AI Foundry Hub: $AI_HUB_NAME" -ForegroundColor Green
      Write-Host "    Principal ID: $aiHubPrincipalId" -ForegroundColor Gray
      
      # Assign Azure AI Administrator at subscription scope
      az role assignment create `
        --assignee-object-id $aiHubPrincipalId `
        --role $AML_AI_ADMIN_ROLE_ID `
        --scope "/subscriptions/$SUBSCRIPTION_ID" `
        --assignee-principal-type ServicePrincipal `
        2>/dev/null
      
      Write-Host "    ✓ Azure AI Administrator role assigned" -ForegroundColor Green
    }
  }
} catch {
  Write-Host "  ⚠ Could not assign role to AI Foundry Hub: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Verify in Databricks: Catalog browser → Settings → Metastore" -ForegroundColor Cyan
Write-Host "  2. Verify in Azure: rg-$ENV_NAME-$PROJECT_NAME-ai-platform → Role assignments" -ForegroundColor Cyan
Write-Host "  3. Run 'azd deploy' to deploy UC catalogs and schemas" -ForegroundColor Cyan
Write-Host "  4. Review DEPLOYMENT-PROCESS.md for verification steps" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠ Manual Step Required: Migrate Azure ML datastore to identity-based auth" -ForegroundColor Yellow
Write-Host "  Go to: https://ml.azure.com → Data → Datastores → workspaceblobstore" -ForegroundColor Yellow
Write-Host "  Click 'Update credentials' → Change to 'Identity-based' → Update" -ForegroundColor Yellow
Write-Host "  See: docs/FIX-DATASTORE-ACCOUNT-KEY-ERROR.md for detailed steps" -ForegroundColor Yellow
Write-Host ""

Pop-Location

Write-Host "Returning to project root: $PROJECT_ROOT" -ForegroundColor Green
