# Script to link Databricks private DNS zones to your VNet
# This enables DNS resolution from your VM to the Databricks private endpoint

param(
    [Parameter(Mandatory=$true)]
    [string]$VmVNetResourceId,  # Full resource ID of your VNet
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabricksWorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabricksResourceGroup
)

Write-Host "Setting Azure subscription context..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId

# Get the Databricks workspace managed resource group
Write-Host "Getting Databricks workspace information..." -ForegroundColor Cyan
$workspace = az databricks workspace show --name $DatabricksWorkspaceName --resource-group $DatabricksResourceGroup --query "{managedResourceGroupId:managedResourceGroupId}" -o json | ConvertFrom-Json
$managedRgId = $workspace.managedResourceGroupId
$managedRgName = $managedRgId.Split('/')[-1]

Write-Host "Managed Resource Group: $managedRgName" -ForegroundColor Yellow

# Find the private DNS zones in the managed resource group
Write-Host "Finding Databricks private DNS zones..." -ForegroundColor Cyan
$dnsZones = az network private-dns zone list --resource-group $managedRgName --query "[].{name:name, id:id}" -o json | ConvertFrom-Json

if ($dnsZones.Count -eq 0) {
    Write-Host "⚠️  No private DNS zones found in managed resource group. Your workspace might not be using private endpoints." -ForegroundColor Yellow
    Write-Host "If your workspace has publicNetworkAccess: 'Disabled', the DNS zones should be created automatically." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($dnsZones.Count) DNS zone(s):" -ForegroundColor Green
$dnsZones | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor Gray }

# Link each DNS zone to the VM VNet
foreach ($zone in $dnsZones) {
    $linkName = "vm-vnet-link-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    Write-Host "`nLinking DNS zone '$($zone.name)' to VM VNet..." -ForegroundColor Cyan
    
    try {
        az network private-dns link vnet create `
            --resource-group $managedRgName `
            --zone-name $zone.name `
            --name $linkName `
            --virtual-network $VmVNetResourceId `
            --registration-enabled false
        
        Write-Host "✓ Successfully linked $($zone.name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to link $($zone.name): $_" -ForegroundColor Red
    }
}

Write-Host "`n✓ DNS zone linking complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Wait 1-2 minutes for DNS propagation" -ForegroundColor Gray
Write-Host "2. From your VM, test DNS resolution: nslookup <your-databricks-workspace-url>" -ForegroundColor Gray
Write-Host "3. Try accessing the Databricks workspace from your VM's browser" -ForegroundColor Gray
