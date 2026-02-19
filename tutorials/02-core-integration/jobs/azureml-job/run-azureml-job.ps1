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

Write-Host "`nSubmitting Azure ML job..."
Write-Host "Subscription: $SubscriptionId"
Write-Host "Workspace: $WorkspaceName"
Write-Host "Compute: $ComputeCluster"

# Validate Azure CLI
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Error "Azure CLI not found. Install from: https://aka.ms/installazurecliwindows"
    exit 1
}

# Validate ML extension
try {
    $mlExtension = az extension show --name ml --output json 2>$null | ConvertFrom-Json
    Write-Host "ML extension version: $($mlExtension.version)"
} catch {
    Write-Host "Installing Azure ML extension..."
    az extension add --name ml --yes
}

# Set subscription
az account set --subscription $SubscriptionId

# Check compute cluster
Write-Host "`nChecking compute cluster..."
$computeExists = az ml compute show --name $ComputeCluster --workspace-name $WorkspaceName --resource-group $ResourceGroup 2>$null

if (-not $computeExists) {
    Write-Host "Creating compute cluster..."
    az ml compute create `
        --name $ComputeCluster `
        --type amlcompute `
        --size Standard_DS3_v2 `
        --min-instances 0 `
        --max-instances 4 `
        --idle-time-before-scale-down 120 `
        --workspace-name $WorkspaceName `
        --resource-group $ResourceGroup
    Write-Host "Compute cluster created"
} else {
    Write-Host "Compute cluster exists"
}

# Submit job
Write-Host "`nSubmitting job..."

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
    Write-Host "`nJob submitted successfully"
    Write-Host "Job Name: $($job.name)"
    Write-Host "Job ID: $($job.id)"
    Write-Host "Status: $($job.status)"
    Write-Host "Studio URL: $($job.services.Studio.endpoint)"
    
    $stream = Read-Host "`nStream job logs? (y/n)"
    if ($stream -eq 'y' -or $stream -eq 'Y') {
        Write-Host "Streaming logs..."
        az ml job stream --name $job.name --workspace-name $WorkspaceName --resource-group $ResourceGroup
    }
} else {
    Write-Error "Job submission failed"
    exit 1
}
