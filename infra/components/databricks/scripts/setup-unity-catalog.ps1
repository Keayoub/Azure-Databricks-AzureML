# Unity Catalog Setup Script
# Uses Databricks CLI for secure, simple configuration
# Configures Unity Catalog metastore, catalogs, and schemas

param(
    [string]$WorkspaceUrl,
    [string]$WorkspaceId,
    [string]$StorageAccountName,
    [string]$StorageContainerName,
    [string]$MetastoreName,
    [string]$ProjectName,
    [string]$Environment,
    [string]$Location
)

# Enable error handling
$ErrorActionPreference = "Stop"

Write-Output "Starting Unity Catalog Configuration..."
Write-Output "Workspace URL: $WorkspaceUrl"
Write-Output "Workspace ID: $WorkspaceId"
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Metastore Name: $MetastoreName"

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
# Set environment variables for Databricks CLI authentication
$env:DATABRICKS_HOST = $WorkspaceUrl.TrimEnd('/')

# Try managed identity first (for Azure Cloud Shell / Azure VMs)
$tokenObtained = $false
try {
    $response = Invoke-RestMethod `
        -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
        -Method GET `
        -Headers @{ "Metadata" = "true" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $env:DATABRICKS_TOKEN = $response.access_token
    $tokenObtained = $true
    Write-Output "✓ Configured Databricks CLI with managed identity token"
}
catch {
    Write-Output "ℹ Managed identity not available (running locally)"
}

# If managed identity fails, try using existing Azure CLI token
if (-not $tokenObtained) {
    try {
        Write-Output "Attempting to obtain Databricks token using Azure CLI..."
        
        # Get Azure access token for Databricks
        $azToken = az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $azToken) {
            $env:DATABRICKS_TOKEN = $azToken
            $tokenObtained = $true
            Write-Output "✓ Configured Databricks CLI with Azure CLI token"
        }
    }
    catch {
        Write-Output "ℹ Azure CLI token not available"
    }
}

# If both fail, prompt for manual token
if (-not $tokenObtained) {
    Write-Output "`n⚠ Automatic authentication failed. Please provide a Databricks Personal Access Token (PAT)."
    Write-Output "To create a PAT:"
    Write-Output "  1. Go to: $WorkspaceUrl"
    Write-Output "  2. Click Settings → User Settings → Access Tokens"
    Write-Output "  3. Generate new token and copy it"
    Write-Output ""
    $patToken = Read-Host "Enter your Databricks PAT token" -AsSecureString
    $env:DATABRICKS_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($patToken))
    Write-Output "✓ Configured Databricks CLI with provided PAT token"
}

# ========== Create Metastore ==========
Write-Output "`n[1/3] Creating Unity Catalog Metastore..."
try {
    $storageRoot = "abfss://${StorageContainerName}@${StorageAccountName}.dfs.core.windows.net"
    
    # Create metastore using Databricks CLI
    $output = databricks unity-catalog metastores create `
        --name $MetastoreName `
        --storage-root $storageRoot `
        --region $Location 2>&1
    
    Write-Output "✓ Metastore created successfully"
}
catch {
    # Check if metastore already exists
    Write-Output "ℹ Checking if metastore already exists..."
    $metastores = databricks unity-catalog metastores list --output json 2>&1
    
    if ($metastores -like "*$MetastoreName*") {
        Write-Output "✓ Metastore already exists, proceeding..."
    }
    else {
        Write-Error "Failed to create metastore: $_"
        exit 1
    }
}

# ========== Get Metastore ID ==========
Write-Output "`nRetrieving metastore ID..."
try {
    $metastoreList = databricks unity-catalog metastores list --output json 2>&1 | ConvertFrom-Json
    $metastoreId = $metastoreList.metastores | Where-Object { $_.name -eq $MetastoreName } | Select-Object -First 1 | ForEach-Object { $_.metastore_id }
    
    if ($null -eq $metastoreId) {
        Write-Error "Could not find metastore ID for: $MetastoreName"
        exit 1
    }
    
    Write-Output "✓ Metastore ID: $metastoreId"
}
catch {
    Write-Error "Failed to retrieve metastore ID: $_"
    exit 1
}

# ========== Assign Metastore to Workspace ==========
Write-Output "`n[2/3] Assigning Metastore to Workspace..."
try {
    databricks unity-catalog metastores assign `
        --workspace-id $WorkspaceId `
        --metastore-id $metastoreId 2>&1
    
    Write-Output "✓ Metastore assigned to workspace"
}
catch {
    if ($_ -match "already assigned|Metastore already assigned") {
        Write-Output "ℹ Metastore already assigned to workspace"
    }
    else {
        Write-Error "Error assigning metastore: $_"
        exit 1
    }
}

# ========== Create Catalogs and Schemas ==========
Write-Output "`n[3/3] Creating Catalogs and Schemas..."

$catalogs = @(
    @{ Name = "bronze_$Environment"; Description = "Bronze layer - raw data"; Schemas = @("data", "archive") },
    @{ Name = "silver_$Environment"; Description = "Silver layer - cleaned and deduplicated data"; Schemas = @("data", "processing") },
    @{ Name = "gold_$Environment"; Description = "Gold layer - aggregated data for BI/reporting"; Schemas = @("data", "reporting") }
)

foreach ($catalog in $catalogs) {
    try {
        Write-Output "`nCreating catalog: $($catalog.Name)"
        
        # Create catalog using Databricks CLI
        databricks unity-catalog catalogs create `
            --name $catalog.Name `
            --comment $catalog.Description 2>&1 | Out-Null
        
        Write-Output "✓ Catalog created: $($catalog.Name)"
    }
    catch {
        if ($_ -match "already exists") {
            Write-Output "ℹ Catalog already exists: $($catalog.Name)"
        }
        else {
            Write-Error "Failed to create catalog $($catalog.Name): $_"
            continue
        }
    }
    
    # Create schemas within catalog
    foreach ($schema in $catalog.Schemas) {
        try {
            databricks unity-catalog schemas create `
                --catalog-name $catalog.Name `
                --schema-name $schema `
                --comment "$schema schema" 2>&1 | Out-Null
            
            Write-Output "  ✓ Schema created: $($catalog.Name).$($schema)"
        }
        catch {
            if ($_ -match "already exists") {
                Write-Output "  ℹ Schema already exists: $($catalog.Name).$($schema)"
            }
            else {
                Write-Error "  ✗ Failed to create schema $($schema): $_"
            }
        }
    }
}

# ========== Summary ==========
Write-Output "`n========================================"
Write-Output "✓ Unity Catalog setup completed successfully!"
Write-Output "`nConfigured Resources:"
Write-Output "  • Metastore: $MetastoreName"
Write-Output "  • Storage Root: abfss://${StorageContainerName}@${StorageAccountName}.dfs.core.windows.net"
Write-Output "  • Assigned to Workspace: $WorkspaceId"
Write-Output "`nCreated Catalogs and Schemas:"

foreach ($catalog in $catalogs) {
    Write-Output "  • $($catalog.Name):"
    foreach ($schema in $catalog.Schemas) {
        Write-Output "    - $schema"
    }
}

Write-Output "`nNext Steps:"
Write-Output "  1. Navigate to $WorkspaceUrl"
Write-Output "  2. Open Catalog Explorer to view your catalogs"
Write-Output "  3. Configure table-level access control as needed"
Write-Output "  4. Start creating tables using Unity Catalog"
Write-Output "`n========================================"
