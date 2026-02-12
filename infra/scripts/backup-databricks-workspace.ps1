# Backup Databricks Workspace
# Automated hourly/daily backup of workspace objects (notebooks, jobs, policies)

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceUrl = "",  # Auto-detected if not provided
    
    [Parameter(Mandatory=$false)]
    [string]$BackupStorageAccount = "st${Environment}shared",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupContainer = "databricks-backups",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Full", "Incremental")]
    [string]$BackupType = "Incremental",
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 90
)

$ErrorActionPreference = "Stop"
$backupTimestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$backupPath = "$BackupContainer/$backupTimestamp"

Write-Host "========== Databricks Workspace Backup ==========" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Backup Type: $BackupType" -ForegroundColor Yellow
Write-Host "Timestamp: $backupTimestamp" -ForegroundColor Yellow

# Auto-detect workspace URL if not provided
if ([string]::IsNullOrEmpty($WorkspaceUrl)) {
    $workspace = az databricks workspace list --query "[?tags.Environment=='$Environment'] | [0]" | ConvertFrom-Json
    $WorkspaceUrl = "https://$($workspace.workspaceUrl)"
    Write-Host "Auto-detected Workspace URL: $WorkspaceUrl" -ForegroundColor Yellow
}

# Create temporary directory
$tempDir = New-Item -ItemType Directory -Path "./dbx-backup-temp-$backupTimestamp" -Force
Write-Host "`nCreated temporary directory: $tempDir" -ForegroundColor Green

try {
    # 1. Backup Notebooks
    Write-Host "`n[1/5] Backing up notebooks..." -ForegroundColor Yellow
    $notebooksDir = "$tempDir/notebooks"
    New-Item -ItemType Directory -Path $notebooksDir -Force | Out-Null
    
    databricks workspace export_dir --profile $Environment / $notebooksDir --overwrite
    
    $notebookCount = (Get-ChildItem -Path $notebooksDir -Recurse -File).Count
    Write-Host "✓ Backed up $notebookCount notebook(s)" -ForegroundColor Green

    # 2. Backup Jobs
    Write-Host "`n[2/5] Backing up jobs..." -ForegroundColor Yellow
    $jobs = databricks jobs list --profile $Environment --output JSON | ConvertFrom-Json
    $jobs | ConvertTo-Json -Depth 20 | Out-File "$tempDir/jobs-backup.json"
    Write-Host "✓ Backed up $($jobs.jobs.Count) job(s)" -ForegroundColor Green

    # 3. Backup Cluster Policies
    Write-Host "`n[3/5] Backing up cluster policies..." -ForegroundColor Yellow
    try {
        $policies = databricks cluster-policies list --profile $Environment --output JSON | ConvertFrom-Json
        $policies | ConvertTo-Json -Depth 20 | Out-File "$tempDir/policies-backup.json"
        Write-Host "✓ Backed up $($policies.policies.Count) cluster policy(ies)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup cluster policies. Error: $_"
    }

    # 4. Backup Instance Pools
    Write-Host "`n[4/5] Backing up instance pools..." -ForegroundColor Yellow
    try {
        $pools = databricks instance-pools list --profile $Environment --output JSON | ConvertFrom-Json
        $pools | ConvertTo-Json -Depth 20 | Out-File "$tempDir/instance-pools-backup.json"
        Write-Host "✓ Backed up $($pools.instance_pools.Count) instance pool(s)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup instance pools. Error: $_"
    }

    # 5. Backup Secret Scopes (metadata only)
    Write-Host "`n[5/5] Backing up secret scopes..." -ForegroundColor Yellow
    try {
        $scopes = databricks secrets list-scopes --profile $Environment --output JSON | ConvertFrom-Json
        # Don't backup actual secrets, just scope metadata
        $scopeMetadata = $scopes.scopes | Select-Object name, backend_type
        $scopeMetadata | ConvertTo-Json -Depth 10 | Out-File "$tempDir/secret-scopes-metadata-backup.json"
        Write-Host "✓ Backed up $($scopes.scopes.Count) secret scope metadata" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup secret scopes. Error: $_"
    }

    # 6. Upload to Storage Account
    Write-Host "`nUploading backup to Azure Storage..." -ForegroundColor Yellow
    
    # Ensure container exists
    az storage container create --name $BackupContainer --account-name $BackupStorageAccount --auth-mode login --only-show-errors | Out-Null
    
    # Upload all backup files
    azcopy copy "$tempDir/*" "https://$BackupStorageAccount.blob.core.windows.net/$backupPath/" --recursive=true --overwrite=true
    
    Write-Host "✓ Uploaded backup to: $backupPath" -ForegroundColor Green

    # 7. Clean Up Old Backups
    Write-Host "`nCleaning up old backups (retention: $RetentionDays days)..." -ForegroundColor Yellow
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays).ToString("yyyy-MM-dd")
    
    $blobs = az storage blob list --container-name $BackupContainer --account-name $BackupStorageAccount --auth-mode login --query "[?properties.creationTime < '$cutoffDate'].name" -o json | ConvertFrom-Json
    
    foreach ($blob in $blobs) {
        az storage blob delete --container-name $BackupContainer --account-name $BackupStorageAccount --name $blob --auth-mode login --only-show-errors | Out-Null
    }
    Write-Host "✓ Deleted $($blobs.Count) old backup(s)" -ForegroundColor Green

    # 8. Generate Backup Report
    $report = @"
Databricks Workspace Backup Report
===================================
Date: $backupTimestamp  
Environment: $Environment  
Workspace URL: $WorkspaceUrl  
Backup Type: $BackupType  
Storage Account: $BackupStorageAccount  
Backup Path: $backupPath  

Summary:
- Notebooks: $notebookCount
- Jobs: $($jobs.jobs.Count)
- Cluster Policies: $($policies.policies.Count)
- Instance Pools: $($pools.instance_pools.Count)
- Secret Scopes: $($scopes.scopes.Count)

Status: SUCCESS
"@
    
    $report | Out-File "$tempDir/backup-report.txt"
    azcopy copy "$tempDir/backup-report.txt" "https://$BackupStorageAccount.blob.core.windows.net/$backupPath/backup-report.txt" --overwrite=true
    
    Write-Host "`n========== Backup Complete ==========" -ForegroundColor Green
    Write-Host $report -ForegroundColor Cyan

} catch {
    Write-Error "Backup failed: $_"
    exit 1
} finally {
    # Clean up temporary directory
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
