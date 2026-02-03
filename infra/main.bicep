// Main Bicep file for Secure Azure Databricks, Azure ML, and AI Foundry deployment
// This template deploys a complete secure data platform with:
// - Azure Databricks with Unity Catalog, VNet injection, and data exfiltration protection
// - Azure ML workspace with network isolation
// - AI Foundry hub with network integration
// - Optional AKS cluster for Azure ML model serving
// - Full network isolation with private endpoints

targetScope = 'subscription'

// ========== Parameters ==========
@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Primary Azure region for resources')
param location string = deployment().location

@description('Project name prefix for resource naming')
@minLength(3)
@maxLength(10)
param projectName string

@description('Enable Unity Catalog for Databricks')
param enableUnityCatalog bool = true

@description('Enable Delta Sharing for Databricks')
param enableDeltaSharing bool = true

@description('Deploy Azure ML workspace')
param deployAzureML bool = true

@description('Deploy AI Foundry hub')
param deployAIFoundry bool = true

@description('Deploy AKS cluster for Azure ML model serving')
param deployAKS bool = false

@description('AKS node count for model serving')
@minValue(1)
@maxValue(10)
param aksNodeCount int = 3

@description('Your object ID for admin permissions')
param adminObjectId string

@description('Tags for all resources')
param tags object = {
  Environment: environmentName
  Project: projectName
  ManagedBy: 'Bicep'
  Purpose: 'SecureDataPlatform'
}

// ========== Variables ==========
var uniqueSuffix = uniqueString(subscription().id, projectName, location)
var resourceGroupName = 'rg-${projectName}-${environmentName}-${uniqueSuffix}'

// ========== Resource Group ==========
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========== Networking Infrastructure ==========
module networking 'modules/networking.bicep' = {
  scope: resourceGroup
  name: 'networking-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    deployAKS: deployAKS
  }
}

// ========== Azure Databricks with Security Features ==========
module databricks 'modules/databricks.bicep' = {
  scope: resourceGroup
  name: 'databricks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateSubnetName: networking.outputs.databricksPrivateSubnetName
    publicSubnetName: networking.outputs.databricksPublicSubnetName
    enableUnityCatalog: enableUnityCatalog
    enableDeltaSharing: enableDeltaSharing
    tags: tags
  }
}

// ========== Storage Account for Unity Catalog and Azure ML ==========
module storage 'modules/storage.bicep' = {
  scope: resourceGroup
  name: 'storage-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// ========== Azure Key Vault ==========
module keyVault 'modules/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyvault-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    adminObjectId: adminObjectId
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// ========== Azure Container Registry ==========
module containerRegistry 'modules/acr.bicep' = {
  scope: resourceGroup
  name: 'acr-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// ========== Azure ML Workspace ==========
module azureML 'modules/azureml.bicep' = if (deployAzureML) {
  scope: resourceGroup
  name: 'azureml-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    containerRegistryId: containerRegistry.outputs.acrId
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    computeSubnetId: networking.outputs.azureMLComputeSubnetId
    tags: tags
  }
}

// ========== AI Foundry Hub ==========
module aiFoundry 'modules/ai-foundry.bicep' = if (deployAIFoundry) {
  scope: resourceGroup
  name: 'ai-foundry-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    containerRegistryId: containerRegistry.outputs.acrId
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// ========== AKS Cluster for Azure ML Model Serving ==========
module aks 'modules/aks.bicep' = if (deployAKS) {
  scope: resourceGroup
  name: 'aks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    aksSubnetId: networking.outputs.aksSubnetId
    nodeCount: aksNodeCount
    tags: tags
  }
}

// ========== Unity Catalog Configuration ==========
module unityCatalog 'modules/unity-catalog.bicep' = if (enableUnityCatalog) {
  scope: resourceGroup
  name: 'unity-catalog-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    databricksWorkspaceUrl: databricks.outputs.workspaceUrl
    databricksWorkspaceId: databricks.outputs.workspaceId
    storageAccountId: storage.outputs.storageAccountId
    storageAccountName: storage.outputs.storageAccountName
    storageContainerName: 'unity-catalog'
    adminObjectId: adminObjectId
    tags: tags
  }
  dependsOn: [
    databricks
    storage
  ]
}

// ========== Outputs ==========
output resourceGroupName string = resourceGroup.name
output databricksWorkspaceUrl string = databricks.outputs.workspaceUrl
output databricksWorkspaceId string = databricks.outputs.workspaceId
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultName string = keyVault.outputs.keyVaultName
output containerRegistryName string = containerRegistry.outputs.acrName
output azureMLWorkspaceName string = deployAzureML ? azureML.outputs.workspaceName : 'Not deployed'
output aiFoundryHubName string = deployAIFoundry ? aiFoundry.outputs.hubName : 'Not deployed'
output aksClusterName string = deployAKS ? aks.outputs.aksClusterName : 'Not deployed'
output unityCatalogMetastoreName string = 'See deployment logs for Unity Catalog metastore details'
output vnetName string = networking.outputs.vnetName
