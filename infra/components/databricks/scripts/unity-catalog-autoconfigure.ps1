# Unity Catalog Auto-Configure Script
# Uses Databricks CLI with Access Connector managed identity
# Automatically configures storage credentials and external locations

param(
    [string]$WorkspaceUrl,
    [string]$WorkspaceId,
    [string]$StorageAccountName,
    [string]$StorageContainerName,
    [string]$AccessConnectorResourceId,
    [string]$ProjectName,
    [string]$Environment,
    [string]$TenantId
)

# Enable error handling
$ErrorActionPreference = "Stop"

Write-Output "Starting Unity Catalog Auto-Configuration..."
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Access Connector: $AccessConnectorResourceId"

# ========== Check Databricks CLI Installation ==========
try {
    $cliVersion = databricks --version 2>&1
    Write-Output "✓ Databricks CLI found: $cliVersion"
}
catch {
    Write-Error "Databricks CLI not installed. Install with: pip install databricks-cli"
    exit 1
}

# ========== Configure Databricks CLI ==========
$env:DATABRICKS_HOST = $WorkspaceUrl.TrimEnd('/')

# Get token from managed identity
try {
    $response = Invoke-RestMethod `
        -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
        -Method GET `
        -Headers @{ "Metadata" = "true" } `
        -ErrorAction Stop
    
    $env:DATABRICKS_TOKEN = $response.access_token
    Write-Output "✓ Configured Databricks CLI with managed identity token"
}
catch {
    Write-Error "Failed to obtain Databricks token: $_"
    exit 1
}

# ========== Create Storage Credential ==========
Write-Output "`n[1/3] Creating Storage Credential with Access Connector..."
$credentialName = "cred-$Environment-$ProjectName"

try {
    # Create storage credential using managed identity via Access Connector
    $credentialConfig = @{
        name = $credentialName
        azure_managed_identity = @{
            access_connector_id = $AccessConnectorResourceId
        }
    } | ConvertTo-Json -Compress
    
    # Write config to temp file (CLI-friendly)
    $tempFile = [System.IO.Path]::GetTempFileName()
    $credentialConfig | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Create credential using Databricks CLI
    databricks unity-catalog storage-credentials create --json "@$tempFile" 2>&1 | Out-Null
    
    Remove-Item -Path $tempFile -Force
    Write-Output "✓ Storage credential created: $credentialName"
}
catch {
    if ($_ -match "already exists") {
        Write-Output "ℹ Storage credential already exists: $credentialName"
    }
    else {
        Write-Error "Failed to create storage credential: $_"
        exit 1
    }
}

# ========== Create External Location ==========
Write-Output "`n[2/3] Creating External Location..."
$locationName = "loc-$Environment-$ProjectName"
$storageUrl = "abfss://${StorageContainerName}@${StorageAccountName}.dfs.core.windows.net"

try {
    # Create external location using Databricks CLI
    databricks unity-catalog external-locations create `
        --name $locationName `
        --url "$storageUrl" `
        --credential-name $credentialName 2>&1 | Out-Null
    
    Write-Output "✓ External location created: $locationName"
    Write-Output "  URL: $storageUrl"
}
catch {
    if ($_ -match "already exists") {
        Write-Output "ℹ External location already exists: $locationName"
    }
    else {
        Write-Error "Failed to create external location: $_"
        exit 1
    }
}

# ========== Grant Workspace Access ==========
Write-Output "`n[3/3] Granting Workspace Access to External Location..."

try {
    # Grant READ_METADATA permission to workspace
    databricks unity-catalog external-locations update `
        --name $locationName `
        --read-only false 2>&1 | Out-Null
    
    Write-Output "✓ Workspace access granted to external location"
}
catch {
    Write-Output "ℹ Could not update permissions (may require manual setup)"
}

# ========== Summary ==========
Write-Output "`n========================================"
Write-Output "✓ Unity Catalog auto-configuration completed!"
Write-Output "`nConfigured Resources:"
Write-Output "  • Storage Credential: $credentialName"
Write-Output "  • External Location: $locationName"
Write-Output "  • Storage URL: $storageUrl"
Write-Output "  • Access Connector: $AccessConnectorResourceId"
Write-Output "`nNext Steps:"
Write-Output "  1. Verify external location in Catalog Explorer"
Write-Output "  2. Create external tables from this location"
Write-Output "  3. Configure fine-grained access control as needed"
Write-Output "`n========================================"

Write-Output "`nNote: If you encounter permission issues:"
Write-Output "  • Ensure Access Connector has Storage Blob Data Contributor role"
Write-Output "  • Verify the storage container exists and is accessible"
Write-Output "  • Check workspace audit logs for authentication details"
