# Unity Catalog Auto-Configuration Script
# Uses Access Connector managed identity for secure authentication
# No shared keys required - fully managed identity-based access

param(
    [string]$WorkspaceUrl,
    [string]$WorkspaceId,
    [string]$StorageAccountName,
    [string]$StorageContainerName,
    [string]$MetastoreName,
    [string]$ProjectName,
    [string]$Environment,
    [string]$Location,
    [string]$AccessConnectorId
)

$ErrorActionPreference = "Stop"

Write-Output "Starting Unity Catalog Configuration with Access Connector..."
Write-Output "Workspace URL: $WorkspaceUrl"
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Metastore Name: $MetastoreName"
Write-Output "Access Connector ID: $AccessConnectorId"

# ========== Get Databricks Token ==========
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

$headers = @{
    "Authorization" = "Bearer $databricksToken"
    "Content-Type"  = "application/json"
}

# ========== Create Metastore ==========
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
    if ($_ -match "already exists") {
        Write-Output "ℹ Metastore already exists, retrieving..."
        
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
    Write-Warning "Could not assign metastore: $_"
}

# ========== Create Catalogs ==========
$catalogNames = @("${Environment}_lob_team_1", "${Environment}_lob_team_2", "${Environment}_lob_team_3")

foreach ($catalogName in $catalogNames) {
    $catalogPayload = @{
        name = $catalogName
        comment = "Catalog for Line of Business"
    } | ConvertTo-Json
    
    try {
        Write-Output "Creating catalog: $catalogName"
        
        Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/catalogs" `
            -Method POST `
            -Headers $headers `
            -Body $catalogPayload `
            -ErrorAction Stop
        
        Write-Output "✓ Catalog $catalogName created"
    }
    catch {
        if ($_ -match "already exists") {
            Write-Output "ℹ Catalog $catalogName already exists"
        }
    }
    
    # ========== Create Schemas ==========
    $schemaNames = @("bronze", "silver", "gold")
    
    foreach ($schemaName in $schemaNames) {
        $schemaPayload = @{
            name = $schemaName
            catalog_name = $catalogName
            comment = "$schemaName schema"
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Uri "${WorkspaceUrl}/api/2.0/unity-catalog/schemas" `
                -Method POST `
                -Headers $headers `
                -Body $schemaPayload `
                -ErrorAction Stop
            
            Write-Output "✓ Schema ${catalogName}.${schemaName} created"
        }
        catch {
            if ($_ -match "already exists") {
                Write-Output "ℹ Schema ${catalogName}.${schemaName} already exists"
            }
        }
    }
}

Write-Output "✓ Unity Catalog configuration complete!"
