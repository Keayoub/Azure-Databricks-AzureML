// Unity Catalog Configuration Module
// Uses Access Connector managed identity for secure storage access
// No shared keys required

param location string
param projectName string
param environmentName string
param databricksWorkspaceUrl string
param databricksWorkspaceId string
param storageAccountName string
param storageContainerName string
param tags object

// Variables
var deploymentScriptName = 'deploy-unity-catalog-${projectName}-${environmentName}'
var metastoreName = 'metastore-${projectName}-${environmentName}'

// ========== Access Connector (Managed Identity) ==========
// This provides secure authentication to storage without shared keys
module accessConnector 'access-connector.bicep' = {
  name: 'access-connector-${projectName}-${environmentName}'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    storageAccountName: storageAccountName
    tags: tags
  }
}

// ========== Managed Identity for Deployment Script ==========
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
    arguments: '-WorkspaceUrl "${databricksWorkspaceUrl}" -WorkspaceId "${databricksWorkspaceId}" -StorageAccountName "${storageAccountName}" -StorageContainerName "${storageContainerName}" -MetastoreName "${metastoreName}" -ProjectName "${projectName}" -Environment "${environmentName}" -Location "${location}" -AccessConnectorId "${accessConnector.outputs.accessConnectorId}"'
    scriptContent: loadTextContent('scripts/unity-catalog-autoconfigure.ps1')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}

// ========== Outputs ==========
output metastoreName string = metastoreName
output accessConnectorId string = accessConnector.outputs.accessConnectorId
output metastoreId string = unityCatalogDeploymentScript.properties.outputs.metastoreId ?? ''
