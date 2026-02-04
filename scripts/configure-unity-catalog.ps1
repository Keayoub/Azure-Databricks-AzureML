#!/usr/bin/env pwsh
# Helper script to configure Unity Catalog
# This script retrieves parameters from deployed Azure resources and runs the setup script

param(
    [string]$ResourceGroupName,
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Output "========================================"
Write-Output "Unity Catalog Configuration Helper"
Write-Output "========================================"

# ========== Find Resource Group ==========
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    Write-Output "`nSearching for deployed resource group..."
    # Exclude Databricks managed resource groups (they contain internal resources only)
    $resourceGroups = az group list --query "[?contains(name, 'rg-secure-db') && !contains(name, 'databricks-managed')].name" -o tsv
    
    if ([string]::IsNullOrEmpty($resourceGroups)) {
        Write-Error "No resource groups found matching 'rg-secure-db'. Please specify -ResourceGroupName"
        exit 1
    }
    
    $rgArray = $resourceGroups -split "`n" | Where-Object { $_ }
    if ($rgArray.Count -gt 1) {
        Write-Output "`nFound multiple resource groups:"
        for ($i = 0; $i -lt $rgArray.Count; $i++) {
            Write-Output "  [$i] $($rgArray[$i])"
        }
        $selection = Read-Host "`nSelect resource group (0-$($rgArray.Count - 1))"
        $ResourceGroupName = $rgArray[$selection]
    }
    else {
        $ResourceGroupName = $rgArray[0]
    }
}

Write-Output "`n✓ Using Resource Group: $ResourceGroupName"

# ========== Get Databricks Workspace ==========
Write-Output "`nRetrieving Databricks workspace information..."
$workspace = az databricks workspace list -g $ResourceGroupName --query "[0]" -o json | ConvertFrom-Json

if ($null -eq $workspace) {
    Write-Error "No Databricks workspace found in resource group: $ResourceGroupName"
    exit 1
}

$workspaceUrl = "https://$($workspace.workspaceUrl)"
$workspaceId = $workspace.id

Write-Output "✓ Workspace URL: $workspaceUrl"
Write-Output "✓ Workspace ID: $workspaceId"

# ========== Get Storage Account ==========
Write-Output "`nRetrieving storage account information..."
$storageAccount = az storage account list -g $ResourceGroupName --query "[0].name" -o tsv

if ([string]::IsNullOrEmpty($storageAccount)) {
    Write-Error "No storage account found in resource group: $ResourceGroupName"
    exit 1
}

Write-Output "✓ Storage Account: $storageAccount"

# ========== Extract deployment details ==========
$location = $workspace.location
$projectName = $ResourceGroupName -replace 'rg-secure-db-', '' -replace '-[a-z0-9]+$', ''

# ========== Parameters ==========
$params = @{
    WorkspaceUrl         = $workspaceUrl
    WorkspaceId          = $workspaceId
    StorageAccountName   = $storageAccount
    StorageContainerName = "unity-catalog"
    MetastoreName        = "metastore-$Environment-$location"
    ProjectName          = $projectName
    Environment          = $Environment
    Location             = $location
}

Write-Output "`n========================================"
Write-Output "Configuration Parameters:"
Write-Output "========================================"
$params.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Output "  $($_.Key): $($_.Value)"
}

# ========== Confirm and Execute ==========
Write-Output "`n========================================"
$confirm = Read-Host "Proceed with Unity Catalog setup? (yes/no)"

if ($confirm -ne "yes" -and $confirm -ne "y") {
    Write-Output "Setup cancelled."
    exit 0
}

Write-Output "`nLaunching Unity Catalog setup script..."
Write-Output "========================================"

# Run the setup script
$scriptPath = Join-Path $PSScriptRoot "..\infra\modules\scripts\setup-unity-catalog.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Setup script not found: $scriptPath"
    exit 1
}

& $scriptPath @params
