# Configure Databricks Monitoring
# Adds diagnostic settings and activity log alerts for Databricks workspace

param(
    [Parameter(M andatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabricksWorkspaceName,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertEmailAddress,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "dbxaml"
)

Write-Host "`n=== Configuring Databricks Monitoring ===" -ForegroundColor Cyan

# Auto-discover resources if not specified
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-$EnvironmentName-$ProjectName-databricks"
    Write-Host "Using resource group: $ResourceGroupName" -ForegroundColor Gray
}

if (-not $DatabricksWorkspaceName) {
    $DatabricksWorkspaceName = "dbw-$EnvironmentName-$ProjectName"
    Write-Host "Using workspace: $DatabricksWorkspaceName" -ForegroundColor Gray
}

# Get workspace resource ID
Write-Host "`n1. Getting Databricks workspace info..." -ForegroundColor Yellow
$workspace = az databricks workspace show `
    --resource-group $ResourceGroupName `
    --name $DatabricksWorkspaceName `
    --query "{id:id, name:name}" -o json | ConvertFrom-Json

if (-not $workspace) {
    Write-Error "Databricks workspace not found: $DatabricksWorkspaceName in RG: $ResourceGroupName"
    exit 1
}

Write-Host "  ✅ Found workspace: $($workspace.name)" -ForegroundColor Green

# Get Log Analytics workspace
Write-Host "`n2. Getting Log Analytics workspace..." -ForegroundColor Yellow
$sharedRgName = "rg-$EnvironmentName-$ProjectName-shared"
$lawName = "law-$EnvironmentName-$ProjectName"

$logAnalyticsWorkspace = az monitor log-analytics workspace show `
    --resource-group $sharedRgName `
    --workspace-name $lawName `
    --query "{id:id, name:name}" -o json | ConvertFrom-Json

if (-not $logAnalyticsWorkspace) {
    Write-Error "Log Analytics workspace not found: $lawName in RG: $sharedRgName"
    exit 1
}

Write-Host "  ✅ Found Log Analytics: $($logAnalyticsWorkspace.name)" -ForegroundColor Green

# Configure diagnostic settings
Write-Host "`n3. Configuring diagnostic settings..." -ForegroundColor Yellow

$diagName = "$($workspace.name)-diag"

try {
    az monitor diagnostic-settings create `
        --resource $workspace.id `
        --name $diagName `
        --workspace $logAnalyticsWorkspace.id `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]' `
        --metrics '[{"category":"AllMetrics","enabled":true}]' `
        --output none
    
    Write-Host "  ✅ Diagnostic settings configured" -ForegroundColor Green
} catch {
    Write-Warning "Diagnostic settings may already exist or failed to create: $_"
}

# Configure alerts (if email provided)
if ($AlertEmailAddress) {
    Write-Host "`n4. Configuring monitoring alerts..." -ForegroundColor Yellow
    
    # Create action group
    $actionGroupName = "ag-$EnvironmentName-$ProjectName-ops"
    $actionGroupShortName = ($ProjectName + $EnvironmentName).Substring(0, [Math]::Min(12, ($ProjectName + $EnvironmentName).Length)).Replace('-', '')
    
    try {
        az monitor action-group create `
            --resource-group $sharedRgName `
            --name $actionGroupName `
            --short-name $actionGroupShortName `
            --email-receiver name=primary email-address=$AlertEmailAddress `
            --output none
        
        Write-Host "  ✅ Action group created: $actionGroupName" -ForegroundColor Green
    } catch {
        Write-Warning "Action group may already exist: $_"
    }
    
    # Create alert: Admin failures
    $alertName1 = "ala-$EnvironmentName-$ProjectName-dbx-admin-fail"
    try {
        az monitor activity-log alert create `
            --resource-group $sharedRgName `
            --name $alertName1 `
            --description "Alert on failed administrative operations" `
            --scope $workspace.id `
            --condition "category=Administrative and status=Failed and resourceType=Microsoft.Databricks/workspaces" `
            --action-group $actionGroupName `
            --output none
        
        Write-Host "  ✅ Admin failure alert created: $alertName1" -ForegroundColor Green
    } catch {
        Write-Warning "Admin alert may already exist: $_"
    }
    
    # Create alert: Resource health
    $alertName2 = "ala-$EnvironmentName-$ProjectName-dbx-health"
    try {
        az monitor activity-log alert create `
            --resource-group $sharedRgName `
            --name $alertName2 `
            --description "Alert on resource health degradation" `
            --scope $workspace.id `
            --condition "category=ResourceHealth and resourceType=Microsoft.Databricks/workspaces" `
            --action-group $actionGroupName `
            --output none
        
        Write-Host "  ✅ Resource health alert created: $alertName2" -ForegroundColor Green
    } catch {
        Write-Warning "Health alert may already exist: $_"
    }
} else {
    Write-Host "`n4. Skipping alerts (no email address provided)" -ForegroundColor Gray
}

# Verify configuration
Write-Host "`n5. Verifying configuration..." -ForegroundColor Yellow

$diag = az monitor diagnostic-settings list --resource $workspace.id --query "value[?name=='$diagName'] | [0].{name:name, workspace:workspaceId}" -o json | ConvertFrom-Json
if ($diag) {
    Write-Host "  ✅ Diagnostic settings verified" -ForegroundColor Green
} else {
    Write-Warning "Diagnostic settings not found"
}

if ($AlertEmailAddress) {
    $alerts = az monitor activity-log alert list --resource-group $sharedRgName --query "[?contains(name, 'dbx')].name" -o json | ConvertFrom-Json
    if ($alerts.Count -ge 2) {
        Write-Host "  ✅ Alerts verified ($($alerts.Count) alerts found)" -ForegroundColor Green
    } else {
        Write-Warning "Expected 2 alerts, found $($alerts.Count)"
    }
}

Write-Host "`n=== Monitoring Configuration Complete ===" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 10-15 minutes for logs to appear in Log Analytics" -ForegroundColor White
Write-Host "  2. Generate activity in Databricks (create cluster, run notebook)" -ForegroundColor White
Write-Host "  3. Query logs: See docs/DEPLOYMENT-VALIDATION.md" -ForegroundColor White
