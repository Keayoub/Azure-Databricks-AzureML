// Unity Catalog Configuration Module
// Uses Databricks REST API via deployment script to configure:
// - Metastore (storage root)
// - External locations
// - Catalogs
// - Schemas
// - Grants and permissions

param location string
param projectName string
param environmentName string
param databricksWorkspaceUrl string
param databricksWorkspaceId string
param storageAccountId string
param storageAccountName string
param storageContainerName string
param adminObjectId string
param tags object

// Variables
var deploymentScriptName = 'deploy-unity-catalog-${projectName}-${environmentName}'
var metastoreName = 'metastore-${projectName}-${environmentName}'
var catalogNames = [
  'raw_data'
  'processed_data'
  'analytics'
]

// ========== Managed Identity for Deployment Script ==========
// This identity will be used to authenticate with Databricks API
resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uai-unity-catalog-${projectName}-${environmentName}'
  location: location
  tags: tags
}

// ========== Deployment Script - Unity Catalog Configuration ==========
resource unityCatalogDeploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: deploymentScriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    timeout: 'PT1H'
    arguments: '-WorkspaceUrl "${databricksWorkspaceUrl}" -WorkspaceId "${databricksWorkspaceId}" -StorageAccountName "${storageAccountName}" -StorageContainerName "${storageContainerName}" -MetastoreName "${metastoreName}" -ProjectName "${projectName}" -Environment "${environmentName}"'
    scriptContent: loadTextContent('scripts/setup-unity-catalog.ps1')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}

// ========== Outputs ==========
output metastoreName string = metastoreName
output metastoreId string = unityCatalogDeploymentScript.properties.outputs.metastoreId ?? ''
output catalogNames array = catalogNames
output deploymentScriptStatus string = unityCatalogDeploymentScript.properties.status
