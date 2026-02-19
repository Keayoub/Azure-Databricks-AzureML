# PowerShell script to submit Azure ML job for KeyVault integration test
# Usage: .\run-azureml-job.ps1 -SubscriptionId "xxx" -ResourceGroup "xxx" -WorkspaceName "xxx" -KeyVaultName "xxx"

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabricksSecretScope = "azureml-kv-scope",
    
    [Parameter(Mandatory=$false)]
    [string]$ComputeCluster = "cpu-cluster"
)

Write-Host "🚀 Submitting AzureML KeyVault Integration Test Job" -ForegroundColor Cyan
Write-Host "=" * 80

# Validate Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI not found. Install from: https://aka.ms/installazurecliwindows"
    exit 1
}

# Validate Azure ML extension
try {
    $mlExtension = az extension show --name ml --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ Azure ML extension version: $($mlExtension.version)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Azure ML extension not found. Installing..." -ForegroundColor Yellow
    az extension add --name ml --yes
}

# Set Azure subscription
Write-Host "`n📍 Setting subscription to: $SubscriptionId" -ForegroundColor Cyan
az account set --subscription $SubscriptionId

# Verify compute cluster exists
Write-Host "`n🔍 Checking compute cluster: $ComputeCluster" -ForegroundColor Cyan
$computeExists = az ml compute show --name $ComputeCluster --workspace-name $WorkspaceName --resource-group $ResourceGroup 2>$null

if (-not $computeExists) {
    Write-Host "⚠️  Compute cluster '$ComputeCluster' not found. Creating..." -ForegroundColor Yellow
    
    # Create CPU compute cluster
    az ml compute create `
        --name $ComputeCluster `
        --type amlcompute `
        --size Standard_DS3_v2 `
        --min-instances 0 `
        --max-instances 4 `
        --idle-time-before-scale-down 120 `
        --workspace-name $WorkspaceName `
        --resource-group $ResourceGroup
    
    Write-Host "✅ Compute cluster created" -ForegroundColor Green
} else {
    Write-Host "✅ Compute cluster exists" -ForegroundColor Green
}

# Update job YAML with compute cluster name
$jobYaml = Get-Content "azureml-job.yml" -Raw
$jobYaml = $jobYaml -replace "compute: azureml:cpu-cluster", "compute: azureml:$ComputeCluster"
$jobYaml | Set-Content "azureml-job.yml"

# Submit job
Write-Host "`n🎯 Submitting job to Azure ML..." -ForegroundColor Cyan
Write-Host "   Workspace: $WorkspaceName"
Write-Host "   Resource Group: $ResourceGroup"
Write-Host "   Compute: $ComputeCluster"
Write-Host ""

$job = az ml job create `
    --file azureml-job.yml `
    --workspace-name $WorkspaceName `
    --resource-group $ResourceGroup `
    --set inputs.subscription_id="$SubscriptionId" `
    --set inputs.resource_group="$ResourceGroup" `
    --set inputs.workspace_name="$WorkspaceName" `
    --set inputs.key_vault_name="$KeyVaultName" `
    --set inputs.databricks_secret_scope="$DatabricksSecretScope" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Job submitted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Job Details:" -ForegroundColor Cyan
    Write-Host "  Job Name: $($job.name)" -ForegroundColor White
    Write-Host "  Job ID: $($job.id)" -ForegroundColor White
    Write-Host "  Status: $($job.status)" -ForegroundColor Yellow
    Write-Host "  Studio URL: $($job.services.Studio.endpoint)" -ForegroundColor Blue
    Write-Host ""
    Write-Host "🌐 Open in Azure ML Studio:" -ForegroundColor Cyan
    Write-Host "   $($job.services.Studio.endpoint)" -ForegroundColor Blue
    Write-Host ""
    Write-Host "📊 Monitor job status:" -ForegroundColor Cyan
    Write-Host "   az ml job show --name $($job.name) --workspace-name $WorkspaceName --resource-group $ResourceGroup" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📥 Stream job logs:" -ForegroundColor Cyan
    Write-Host "   az ml job stream --name $($job.name) --workspace-name $WorkspaceName --resource-group $ResourceGroup" -ForegroundColor Gray
    
    # Ask if user wants to stream logs
    $stream = Read-Host "`nWould you like to stream the job logs now? (y/n)"
    if ($stream -eq 'y' -or $stream -eq 'Y') {
        Write-Host "`n📡 Streaming job logs..." -ForegroundColor Cyan
        az ml job stream --name $job.name --workspace-name $WorkspaceName --resource-group $ResourceGroup
    }
} else {
    Write-Error "❌ Job submission failed"
    exit 1
}
