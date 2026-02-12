# Backup Unity Catalog Metastore
# Automated daily backup of Unity Catalog metadata to storage account

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupStorageAccount = "st${Environment}shared",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupContainer = "unity-catalog-backups",
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30
)

$ErrorActionPreference = "Stop"
$backupDate = Get-Date -Format "yyyy-MM-dd"
$backupPath = "$BackupContainer/$backupDate"

Write-Host "========== Unity Catalog Backup ==========" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Backup Date: $backupDate" -ForegroundColor Yellow
Write-Host "Storage Account: $BackupStorageAccount" -ForegroundColor Yellow

# Create temporary directory for backup files
$tempDir = New-Item -ItemType Directory -Path "./uc-backup-temp-$backupDate" -Force
Write-Host "`nCreated temporary directory: $tempDir" -ForegroundColor Green

try {
    # 1. Backup Metastore Configuration
    Write-Host "`n[1/6] Backing up metastore configuration..." -ForegroundColor Yellow
    $metastores = databricks unity-catalog metastores list --profile $Environment --output JSON | ConvertFrom-Json
    $metastores | ConvertTo-Json -Depth 10 | Out-File "$tempDir/metastores-backup.json"
    Write-Host "✓ Backed up $($metastores.Count) metastore(s)" -ForegroundColor Green

    # 2. Backup Catalogs
    Write-Host "`n[2/6] Backing up catalogs..." -ForegroundColor Yellow
    $catalogs = databricks unity-catalog catalogs list --profile $Environment --output JSON | ConvertFrom-Json
    $catalogs | ConvertTo-Json -Depth 10 | Out-File "$tempDir/catalogs-backup.json"
    Write-Host "✓ Backed up $($catalogs.Count) catalog(s)" -ForegroundColor Green

    # 3. Backup Schemas for Each Catalog
    Write-Host "`n[3/6] Backing up schemas..." -ForegroundColor Yellow
    $schemaCount = 0
    foreach ($catalog in $catalogs) {
        try {
            $schemas = databricks unity-catalog schemas list --catalog-name $catalog.name --profile $Environment --output JSON | ConvertFrom-Json
            $schemas | ConvertTo-Json -Depth 10 | Out-File "$tempDir/schemas-$($catalog.name)-backup.json"
            $schemaCount += $schemas.Count
        } catch {
            Write-Warning "Failed to backup schemas for catalog: $($catalog.name). Error: $_"
        }
    }
    Write-Host "✓ Backed up $schemaCount schema(s)" -ForegroundColor Green

    # 4. Backup External Locations
    Write-Host "`n[4/6] Backing up external locations..." -ForegroundColor Yellow
    try {
        $externalLocations = databricks unity-catalog external-locations list --profile $Environment --output JSON | ConvertFrom-Json
        $externalLocations | ConvertTo-Json -Depth 10 | Out-File "$tempDir/external-locations-backup.json"
        Write-Host "✓ Backed up $($externalLocations.Count) external location(s)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup external locations. Error: $_"
    }

    # 5. Backup Storage Credentials
    Write-Host "`n[5/6] Backing up storage credentials..." -ForegroundColor Yellow
    try {
        $storageCredentials = databricks unity-catalog storage-credentials list --profile $Environment --output JSON | ConvertFrom-Json
        # Don't backup actual credentials, just metadata
        $credentialMetadata = $storageCredentials | Select-Object name, comment, read_only, created_at, updated_at
        $credentialMetadata | ConvertTo-Json -Depth 10 | Out-File "$tempDir/storage-credentials-metadata-backup.json"
        Write-Host "✓ Backed up $($storageCredentials.Count) storage credential metadata" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup storage credentials. Error: $_"
    }

    # 6. Upload to Storage Account
    Write-Host "`n[6/6] Uploading backup to Azure Storage..." -ForegroundColor Yellow
    
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
Unity Catalog Backup Report
===========================
Date: $backupDate  
Environment: $Environment  
Storage Account: $BackupStorageAccount  
Backup Path: $backupPath  

Summary:
- Metastores: $($metastores.Count)
- Catalogs: $($catalogs.Count)
- Schemas: $schemaCount
- External Locations: $($externalLocations.Count)
- Storage Credentials: $($storageCredentials.Count)

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
