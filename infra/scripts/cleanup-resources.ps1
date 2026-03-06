#!/usr/bin/env pwsh
# Comprehensive Azure resource cleanup script
# Handles dependency order: Databricks -> Private Endpoints -> NSGs -> Subnets -> VNets -> Resource Groups

$ErrorActionPreference = "Continue"
$subscriptionId = "c7b690b3-d9ad-4ed0-9942-4e7a36d0c187"

Write-Host "=== Azure Resource Cleanup Script ===" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Yellow
Write-Host ""

# Step 1: Delete Databricks workspace (already initiated, but check status)
Write-Host "[1/7] Checking Databricks workspace..." -ForegroundColor Cyan
$dbwRg = "rg-dev-dbxaml-databricks"
$dbwName = "dbw-dev-dbxaml"
$dbw = az databricks workspace show --resource-group $dbwRg --name $dbwName 2>$null
if ($dbw) {
    Write-Host "  ⏳ Databricks workspace still exists, waiting for deletion..." -ForegroundColor Yellow
    az databricks workspace wait --resource-group $dbwRg --name $dbwName --deleted --timeout 600 2>$null
    Write-Host "  ✅ Databricks workspace deleted" -ForegroundColor Green
} else {
    Write-Host "  ✅ Databricks workspace already deleted" -ForegroundColor Green
}

# Step 2: Delete remaining private endpoints in Databricks RG
Write-Host "[2/7] Cleaning up Databricks resource group..." -ForegroundColor Cyan
$dbwResources = az resource list --resource-group $dbwRg --query "[].{name:name,type:type}" -o json | ConvertFrom-Json
foreach ($resource in $dbwResources) {
    Write-Host "  🗑️  Deleting: $($resource.name) ($($resource.type))" -ForegroundColor Yellow
    az resource delete --ids "/subscriptions/$subscriptionId/resourceGroups/$dbwRg/providers/$($resource.type)/$($resource.name)" --no-wait 2>$null
}
Write-Host "  ⏳ Waiting for resource deletions..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Step 3: Delete Databricks resource group
Write-Host "[3/7] Deleting Databricks resource group..." -ForegroundColor Cyan
az group delete --name $dbwRg --yes --no-wait 2>$null
Write-Host "  ✅ Deletion initiated" -ForegroundColor Green

# Step 4: Delete orphaned private endpoints in shared RG
Write-Host "[4/7] Cleaning up orphaned private endpoints..." -ForegroundColor Cyan
$sharedRg = "rg-dev-dbxaml-shared"
$privateEndpoints = az network private-endpoint list --resource-group $sharedRg --query "[].name" -o tsv 2>$null
foreach ($peName in $privateEndpoints) {
    if ($peName) {
        Write-Host "  🗑️  Deleting private endpoint: $peName" -ForegroundColor Yellow
        az network private-endpoint delete --resource-group $sharedRg --name $peName --no-wait 2>$null
    }
}
if ($privateEndpoints) {
    Write-Host "  ⏳ Waiting for private endpoint deletions..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}

# Step 5: Remove NSG associations from subnets
Write-Host "[5/7] Removing NSG associations from subnets..." -ForegroundColor Cyan
$vnetName = "vnet-dev-dbxaml"
$subnets = az network vnet subnet list --resource-group $sharedRg --vnet-name $vnetName --query "[].{name:name,nsg:networkSecurityGroup.id}" -o json 2>$null | ConvertFrom-Json
foreach ($subnet in $subnets) {
    if ($subnet.nsg) {
        Write-Host "  🔗 Removing NSG from subnet: $($subnet.name)" -ForegroundColor Yellow
        az network vnet subnet update --resource-group $sharedRg --vnet-name $vnetName --name $subnet.name --network-security-group "" 2>$null
    }
}
Write-Host "  ✅ NSG associations removed" -ForegroundColor Green

# Step 6: Delete network intent policies
Write-Host "[6/7] Deleting network intent policies..." -ForegroundColor Cyan
$intentPolicies = az resource list --resource-group $sharedRg --resource-type "Microsoft.Network/networkIntentPolicies" --query "[].name" -o tsv 2>$null
foreach ($policyName in $intentPolicies) {
    if ($policyName) {
        Write-Host "  🗑️  Deleting intent policy: $policyName" -ForegroundColor Yellow
        az resource delete --resource-group $sharedRg --resource-type "Microsoft.Network/networkIntentPolicies" --name $policyName --no-wait 2>$null
    }
}
if ($intentPolicies) {
    Start-Sleep -Seconds 10
}

# Step 7: Run azd down --purge again
Write-Host "[7/7] Running azd down --purge to clean up remaining resources..." -ForegroundColor Cyan
azd down --purge --force
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "=== ✅ Cleanup completed successfully ===" -ForegroundColor Green
} else {
    Write-Host "=== ⚠️  Cleanup completed with warnings (exit code: $exitCode) ===" -ForegroundColor Yellow
    Write-Host "Some resources may still exist. Check the Azure Portal for:" -ForegroundColor Yellow
    Write-Host "  - Soft-deleted resources (Key Vault, Log Analytics, ML workspaces)" -ForegroundColor Yellow
    Write-Host "  - Locked resources or resources in use" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "To verify cleanup, run:" -ForegroundColor Cyan
Write-Host "  az group list --query `"[?starts_with(name, 'rg-dev-dbxaml')].name`" -o table" -ForegroundColor White
