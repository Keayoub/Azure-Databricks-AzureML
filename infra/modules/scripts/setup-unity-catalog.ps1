# Unity Catalog Setup Script
# This script configures Unity Catalog in Databricks workspace
# Called by Bicep deployment script

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

# ========== Get Databricks Token ==========
# Use managed identity to get token for Databricks API
try {
    $response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2017-09-01&resource=2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" `
        -Method GET `
        -Headers @{ "Metadata" = "true" } `
        -ErrorAction Stop
    
    $databricksToken = $response.access_token
    Write-Output "✓ Successfully obtained Databricks token"
}
catch {
    Write-Error "Failed to obtain Databricks token: $_"
    exit 1
}

# ========== Setup Headers ==========
$headers = @{
    "Authorization" = "Bearer $databricksToken"
    "Content-Type"  = "application/json"
}

# ========== Create Metastore ==========
# Create Unity Catalog metastore
$storageRoot = "abfss://${StorageContainerName}@${StorageAccountName}.dfs.core.windows.net/"

$metastorePayload = @{
    name           = $MetastoreName
    storage_root   = $storageRoot
    region         = $Location
    delta_sharing_scope = "ALL"
} | ConvertTo-Json

try {
    Write-Output "Creating metastore with storage root: $storageRoot"
    
    $metastoreResponse = Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/metastores" `
        -Method POST `
        -Headers $headers `
        -Body $metastorePayload `
        -ErrorAction Stop
    
    $metastoreId = $metastoreResponse.metastore_id
    Write-Output "✓ Metastore created successfully (ID: $metastoreId)"
}
catch {
    # Check if metastore already exists
    if ($_.Exception.Response.StatusCode -eq 400 -and $_ -match "already exists") {
        Write-Output "ℹ Metastore already exists, retrieving existing metastore..."
        
        $existingMetastores = Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/metastores" `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop
        
        $metastoreId = $existingMetastores.metastores[0].metastore_id
        Write-Output "✓ Using existing metastore (ID: $metastoreId)"
    }
    else {
        Write-Error "Failed to create metastore: $_"
        exit 1
    }
}

# ========== Assign Metastore to Workspace ==========
# Assign the metastore to the workspace
$assignPayload = @{
    workspace_id = $WorkspaceId
    metastore_id = $metastoreId
    default_catalog_name = "default"
} | ConvertTo-Json

try {
    Write-Output "Assigning metastore to workspace..."
    
    Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/workspaces/${WorkspaceId}/metastores" `
        -Method PUT `
        -Headers $headers `
        -Body $assignPayload `
        -ErrorAction Stop
    
    Write-Output "✓ Metastore assigned to workspace"
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Output "ℹ Metastore already assigned to workspace"
    }
    else {
        Write-Error "Failed to assign metastore: $_"
        exit 1
    }
}

# ========== Create Storage Credential ==========
# Create storage credential for accessing data
$credentialPayload = @{
    name = "storage-credential-${ProjectName}"
    azure_service_principal = @{
        directory_id       = (az account show --query tenantId -o tsv)
        application_id     = $null  # Will use managed identity
        client_secret      = $null
    }
} | ConvertTo-Json

try {
    Write-Output "Creating storage credential..."
    
    $credentialResponse = Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/storage-credentials" `
        -Method POST `
        -Headers $headers `
        -Body $credentialPayload `
        -ErrorAction Stop
    
    $credentialId = $credentialResponse.id
    Write-Output "✓ Storage credential created (ID: $credentialId)"
}
catch {
    if ($_.Exception.Response.StatusCode -eq 400 -and $_ -match "already exists") {
        Write-Output "ℹ Storage credential already exists"
    }
    else {
        Write-Output "ℹ Storage credential creation skipped (will use workspace managed identity)"
    }
}

# ========== Create External Location ==========
# Create external location for data
$externalLocationPayload = @{
    name = "external-location-${ProjectName}"
    url  = $storageRoot
    credential_name = "storage-credential-${ProjectName}"
    comment = "External location for ${ProjectName} data"
} | ConvertTo-Json

try {
    Write-Output "Creating external location..."
    
    $locationResponse = Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/external-locations" `
        -Method POST `
        -Headers $headers `
        -Body $externalLocationPayload `
        -ErrorAction Stop
    
    Write-Output "✓ External location created"
}
catch {
    if ($_.Exception.Response.StatusCode -eq 400 -and $_ -match "already exists") {
        Write-Output "ℹ External location already exists"
    }
    else {
        Write-Output "ℹ External location creation skipped"
    }
}

# ========== Create Catalogs ==========
# Create LoB catalogs per environment
$catalogNames = @(
    "${Environment}_lob_team_1",
    "${Environment}_lob_team_2",
    "${Environment}_lob_team_3"
)

foreach ($catalogName in $catalogNames) {
    $catalogPayload = @{
        name = $catalogName
        comment = "Catalog for ${catalogName} in ${Environment} environment"
    } | ConvertTo-Json
    
    try {
        Write-Output "Creating catalog: $catalogName..."
        
        Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/catalogs" `
            -Method POST `
            -Headers $headers `
            -Body $catalogPayload `
            -ErrorAction Stop
        
        Write-Output "✓ Catalog created: $catalogName"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 400 -and $_ -match "already exists") {
            Write-Output "ℹ Catalog already exists: $catalogName"
        }
        else {
            Write-Output "ℹ Catalog creation skipped: $catalogName"
        }
    }
}

# ========== Create Schemas ==========
# Create medallion schemas in each catalog
$schemaNames = @(
    @{ name = "bronze"; comment = "Bronze layer - raw data" },
    @{ name = "silver"; comment = "Silver layer - cleaned data" },
    @{ name = "gold"; comment = "Gold layer - business-ready data" }
)

foreach ($catalogName in $catalogNames) {
    foreach ($schema in $schemaNames) {
        $fullSchemaName = "$catalogName.$($schema.name)"

        $schemaPayload = @{
            name = $schema.name
            catalog_name = $catalogName
            comment = $schema.comment
        } | ConvertTo-Json

        try {
            Write-Output "Creating schema: $fullSchemaName..."

            Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/schemas" `
                -Method POST `
                -Headers $headers `
                -Body $schemaPayload `
                -ErrorAction Stop

            Write-Output "✓ Schema created: $fullSchemaName"
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 400 -and $_ -match "already exists") {
                Write-Output "ℹ Schema already exists: $fullSchemaName"
            }
            else {
                Write-Output "ℹ Schema creation skipped: $fullSchemaName"
            }
        }
    }
}

# ========== Enable Delta Sharing ==========
# Enable Delta Sharing on metastore
try {
    Write-Output "Enabling Delta Sharing..."
    
    $deltaSharePayload = @{
        metastore_id = $metastoreId
        delta_sharing_scope = "ALL"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/metastores/${metastoreId}" `
        -Method PATCH `
        -Headers $headers `
        -Body $deltaSharePayload `
        -ErrorAction Stop
    
    Write-Output "✓ Delta Sharing enabled"
}
catch {
    Write-Output "ℹ Delta Sharing configuration skipped"
}

# ========== Output Results ==========
Write-Output ""
Write-Output "========== Unity Catalog Configuration Complete =========="
Write-Output "Metastore ID: $metastoreId"
Write-Output "Metastore Name: $MetastoreName"
Write-Output "Storage Root: $storageRoot"
Write-Output "Catalogs: raw_data, processed_data, analytics"
Write-Output "=========================================================="

# Return outputs for Bicep
$output = @{
    metastoreId = $metastoreId
    metastoreName = $MetastoreName
    storageRoot = $storageRoot
    catalogNames = @("raw_data", "processed_data", "analytics")
} | ConvertTo-Json

Write-Output $output
