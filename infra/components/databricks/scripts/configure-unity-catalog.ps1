#!/usr/bin/env pwsh
# Helper script to configure Unity Catalog
# This script retrieves parameters from deployed Azure resources and runs the setup script
# Works with the 3-resource-group architecture (Shared, Databricks, AI Platform)

param(
    [string]$ResourceGroupName,
    [string]$ProjectName,
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Output "========================================"
Write-Output "Unity Catalog Configuration Helper"
Write-Output "========================================"

# ========== Find Shared Services Resource Group ==========
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    Write-Output "`nSearching for Shared Services resource group..."
    # Look for shared RG with pattern: rg-{projectName}-shared-{environment}
    # If no projectName provided, search for any -shared- RG
    
    if (-not [string]::IsNullOrEmpty($ProjectName)) {
        $pattern = "*-${ProjectName}-shared-${Environment}"
        $resourceGroups = az group list --query "[?contains(name, '-shared-') && contains(name, '${ProjectName}')].name" -o tsv
    }
    else {
        # Search for any shared RG
        $resourceGroups = az group list --query "[?contains(name, '-shared-')].name" -o tsv
    }
    
    if ([string]::IsNullOrEmpty($resourceGroups)) {
        Write-Error "No Shared Services resource group found matching pattern 'rg-{projectName}-shared-{environment}'"
        Write-Output "Please run deployment first with: azd provision"
        exit 1
    }
    
    $rgArray = $resourceGroups -split "`n" | Where-Object { $_ } | Sort-Object
    if ($rgArray.Count -gt 1) {
        Write-Output "`nFound multiple resource groups:"
        for ($i = 0; $i -lt $rgArray.Count; $i++) {
            Write-Output "  [$i] $($rgArray[$i])"
        }
        $selection = Read-Host "`nSelect Shared Services resource group (0-$($rgArray.Count - 1))"
        $ResourceGroupName = $rgArray[$selection]
    }
    else {
        $ResourceGroupName = $rgArray[0]
    }
}

Write-Output "`n✓ Using Shared Services Resource Group: $ResourceGroupName"

# ========== Find Databricks Workspace ==========
Write-Output "`nSearching for Databricks workspace (in Databricks RG)..."

# Extract pattern from shared RG name to find Databricks RG
# Example: rg-dbxaml-shared-dev -> rg-dbxaml-databricks-dev
$sharedPattern = $ResourceGroupName -replace '-shared-', '-databricks-'
$databricksRg = az group list --query "[?name=='$sharedPattern'].name" -o tsv

if ([string]::IsNullOrEmpty($databricksRg)) {
    Write-Error "Could not find Databricks resource group. Expected: $sharedPattern"
    exit 1
}

Write-Output "✓ Databricks Resource Group: $databricksRg"

# Get Databricks workspace from Databricks RG
$workspace = az databricks workspace list -g $databricksRg --query "[0]" -o json | ConvertFrom-Json

if ($null -eq $workspace) {
    Write-Error "No Databricks workspace found in resource group: $databricksRg"
    exit 1
}

$workspaceUrl = "https://$($workspace.workspaceUrl)"
$workspaceId = $workspace.id

Write-Output "✓ Workspace URL: $workspaceUrl"
Write-Output "✓ Workspace ID: $workspaceId"

# ========== Get Storage Account from Shared RG ==========
Write-Output "`nRetrieving storage account from Shared Services RG..."
$storageAccount = az storage account list -g $ResourceGroupName --query "[0].name" -o tsv

if ([string]::IsNullOrEmpty($storageAccount)) {
    Write-Error "No storage account found in Shared Services resource group: $ResourceGroupName"
    exit 1
}

Write-Output "✓ Storage Account: $storageAccount"

# ========== Get Access Connector from Shared RG ==========
Write-Output "Retrieving Access Connector..."
$accessConnector = az databricks access-connector list -g $ResourceGroupName --query "[0]" -o json | ConvertFrom-Json

if ($null -eq $accessConnector) {
    Write-Output "ℹ No Access Connector found (may use alternative auth)"
    $accessConnectorId = ""
}
else {
    $accessConnectorId = $accessConnector.id
    Write-Output "✓ Access Connector: $accessConnectorId"
}

# ========== Extract deployment details ==========
$location = $workspace.location
if ([string]::IsNullOrEmpty($ProjectName)) {
    # Extract project name from RG: rg-{projectName}-shared-{environment}
    $ProjectName = $ResourceGroupName -replace 'rg-', '' -replace '-shared-.*', ''
}

# ========== Parameters ==========
$params = @{
    WorkspaceUrl         = $workspaceUrl
    WorkspaceId          = $workspaceId
    StorageAccountName   = $storageAccount
    StorageContainerName = "unity-catalog"
    MetastoreName        = "metastore-$Environment-$location"
    ProjectName          = $ProjectName
    Environment          = $Environment
    Location             = $location
    AccessConnectorResourceId = $accessConnectorId
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
