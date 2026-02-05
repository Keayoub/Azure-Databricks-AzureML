// Main Bicep file for Secure Azure Databricks, Azure ML, and AI Foundry deployment
// Organized into 3 separate resource groups:
// 1. Shared Services (VNet, Storage, Key Vault, ACR)
// 2. Databricks Infrastructure
// 3. AI Platform (Azure ML, AI Foundry)

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
}

// ========== Variables ==========
var sharedRgName = 'rg-${projectName}-shared-${environmentName}'
var databricksRgName = 'rg-${projectName}-databricks-${environmentName}'
var aiPlatformRgName = 'rg-${projectName}-ai-platform-${environmentName}'

// ========== Resource Groups ==========
resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: sharedRgName
  location: location
  tags: union(tags, { Purpose: 'SharedServices' })
}

resource databricksResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: databricksRgName
  location: location
  tags: union(tags, { Purpose: 'DatabricksInfra' })
}

resource aiPlatformResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: aiPlatformRgName
  location: location
  tags: union(tags, { Purpose: 'AIPlatform' })
}

// ========== SHARED SERVICES RESOURCE GROUP ==========

// Networking Infrastructure
module networking 'components/networking/networking.bicep' = {
  scope: sharedResourceGroup
  name: 'networking-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    deployAKS: deployAKS
  }
}

// Storage Account for Unity Catalog and Azure ML (STAYS IN SHARED RG)
module storage 'components/storage/storage.bicep' = {
  scope: sharedResourceGroup
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

// Key Vault
module keyVault 'components/keyvault/keyvault.bicep' = {
  scope: sharedResourceGroup
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

// Container Registry
module containerRegistry 'components/acr/acr.bicep' = {
  scope: sharedResourceGroup
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

// Access Connector (for Unity Catalog - STAYS IN SHARED RG)
module accessConnector 'components/databricks/access-connector.bicep' = if (enableUnityCatalog) {
  scope: sharedResourceGroup
  name: 'access-connector-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
  }
}

// AKS Cluster (optional)
module aks 'components/aks/aks.bicep' = if (deployAKS) {
  scope: sharedResourceGroup
  name: 'aks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    aksSubnetId: networking.outputs.aksSubnetId
    nodeCount: aksNodeCount
    tags: tags
  }
}

// Monitoring (Application Insights & Log Analytics)
module monitoring 'components/monitoring/monitoring.bicep' = {
  scope: sharedResourceGroup
  name: 'monitoring-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    enableApplicationInsights: true
    enableLogAnalytics: true
    logRetentionInDays: 30
    tags: tags
  }
}

// Security & RBAC (Managed Identities & Role Templates)
module securityRbac 'components/security/security-rbac.bicep' = {
  scope: sharedResourceGroup
  name: 'security-rbac-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    adminObjectId: adminObjectId
    tags: tags
  }
}

// ========== DATABRICKS RESOURCE GROUP ==========

module databricks 'components/databricks/databricks.bicep' = {
  scope: databricksResourceGroup
  name: 'databricks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateSubnetName: networking.outputs.databricksPrivateSubnetName
    publicSubnetName: networking.outputs.databricksPublicSubnetName
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// ========== AI PLATFORM RESOURCE GROUP ==========

// Azure ML Private DNS Zone
module azuremlDns 'components/azureml/azureml-dns.bicep' = if (deployAzureML || deployAIFoundry) {
  scope: aiPlatformResourceGroup
  name: 'azureml-dns'
  params: {
    vnetId: networking.outputs.vnetId
    tags: tags
  }
}

// Azure ML Workspace
module azureML 'components/azureml/azureml.bicep' = if (deployAzureML) {
  scope: aiPlatformResourceGroup
  name: 'azureml-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    storageAccountId: storage.outputs.mlStorageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    containerRegistryId: containerRegistry.outputs.acrId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    computeSubnetId: networking.outputs.azureMLComputeSubnetId
    privateDnsZoneId: azuremlDns!.outputs.privateDnsZoneId
    tags: tags
  }
}

// AI Foundry Hub
module aiFoundry 'components/ai-foundry/ai-foundry.bicep' = if (deployAIFoundry) {
  scope: aiPlatformResourceGroup
  name: 'ai-foundry-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    storageAccountId: storage.outputs.mlStorageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    containerRegistryId: containerRegistry.outputs.acrId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    privateDnsZoneId: azuremlDns!.outputs.privateDnsZoneId
    tags: tags
  }
}

// ========== Outputs ==========
output sharedResourceGroupName string = sharedResourceGroup.name
output databricksResourceGroupName string = databricksResourceGroup.name
output aiPlatformResourceGroupName string = aiPlatformResourceGroup.name
output sharedResourceGroupId string = sharedResourceGroup.id
output databricksResourceGroupId string = databricksResourceGroup.id
output aiPlatformResourceGroupId string = aiPlatformResourceGroup.id

@description('Networking outputs from shared RG')
output networkingOutputs object = networking.outputs

@description('Storage outputs from shared RG')
output storageOutputs object = storage.outputs

@description('Key Vault outputs from shared RG')
output keyVaultOutputs object = keyVault.outputs

@description('Container Registry outputs from shared RG')
output containerRegistryOutputs object = containerRegistry.outputs

@description('Monitoring outputs (Application Insights & Log Analytics)')
output monitoringOutputs object = monitoring.outputs

@description('Security & RBAC outputs (Managed Identities)')
output securityRbacOutputs object = securityRbac.outputs

@description('Databricks workspace URL')
output databricksWorkspaceUrl string = databricks.outputs.workspaceUrl

@description('Azure ML workspace ID')
output azureMLWorkspaceId string = deployAzureML ? azureML!.outputs.workspaceId : ''

@description('AI Foundry hub ID')
output aiFoundryHubId string = deployAIFoundry ? aiFoundry!.outputs.hubId : ''
