// Main Bicep file for Secure Azure Databricks, Azure ML, and AI Foundry deployment
// Organized into 4 separate resource groups:
// 1. Shared Services (VNet, Storage, Key Vault, ACR, App Config, APIM)
// 2. Databricks Infrastructure
// 3. AI Platform (Azure ML, AI Foundry, AI Search, Cosmos DB)
// 4. Container Compute (AKS, ACA)

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

@description('Deploy Azure ML registry')
param deployAzureMLRegistry bool = false

@description('Deploy AI Foundry hub')
param deployAIFoundry bool = true

@description('Deploy AKS cluster for Azure ML model serving')
param deployAKS bool = false

@description('Deploy Azure Container Apps environment')
param deployACA bool = false

@description('Deploy Azure AI Search for RAG scenarios')
param deployAISearch bool = false

@description('Deploy Azure Cosmos DB for AI agent data')
param deployCosmosDB bool = false

@description('Deploy Azure App Configuration for feature flags')
param deployAppConfiguration bool = false

@description('Deploy API Management as API gateway')
param deployAPIM bool = false

@description('Deploy Azure Bastion for secure VM access')
param deployBastion bool = false

@description('Deploy Jumpbox VM for management tasks')
param deployJumpbox bool = false

@description('Enable NSG flow logs (deprecated in 2025)')
param enableNsgFlowLogs bool = false

@description('Enable Azure Policy assignments (optional)')
param enablePolicyAssignments bool = false

@description('Jumpbox admin username')
param jumpboxAdminUsername string = 'azureadmin'

@secure()
@description('Jumpbox admin password (required if deployJumpbox is true)')
param jumpboxAdminPassword string = ''

@description('AKS node count for model serving')
@minValue(1)
@maxValue(10)
param aksNodeCount int = 3

@description('AI Search SKU')
@allowed(['basic', 'standard', 'standard2', 'standard3'])
param aiSearchSku string = 'standard'

@description('Cosmos DB consistency level')
@allowed(['Eventual', 'Session', 'Strong', 'BoundedStaleness', 'ConsistentPrefix'])
param cosmosDbConsistencyLevel string = 'Session'

@description('API Management SKU')
@allowed(['Developer', 'Basic', 'Standard', 'Premium'])
param apimSku string = 'Developer'

@description('API Management publisher email')
param apimPublisherEmail string = 'admin@example.com'

@description('API Management publisher name')
param apimPublisherName string = 'API Management Admin'

@description('Your object ID for admin permissions')
param adminObjectId string

@description('Enable shared compute instance for Azure ML team')
param enableSharedComputeInstance bool = true

@description('Enable personal compute instance for Azure ML development')
param enablePersonalComputeInstance bool = false

@description('Optional explicit Azure ML registry name. Leave empty for auto-generated name.')
@maxLength(33)
param azureMLRegistryName string = ''

@description('Azure ML Registry public network access setting')
@allowed(['Enabled', 'Disabled'])
param azureMLRegistryPublicNetworkAccess string = 'Enabled'

@description('Azure ML Registry replication regions. If empty, only primary location is used.')
param azureMLRegistryReplicationRegions array = []

@description('Azure ML Registry identity mode')
@allowed(['SystemAssigned', 'None'])
param azureMLRegistryIdentityMode string = 'SystemAssigned'

@description('Azure ML Registry SKU name')
param azureMLRegistrySkuName string = 'Basic'

@description('Use system-created storage and ACR for Azure ML Registry')
param azureMLRegistryUseSystemCreatedResources bool = true

@description('Optional system-created registry storage account name')
param azureMLRegistryStorageAccountName string = ''

@description('Optional system-created registry storage account type')
param azureMLRegistryStorageAccountType string = ''

@description('Optional system-created registry storage account HNS setting')
param azureMLRegistryStorageAccountHnsEnabled bool = true

@description('Optional system-created registry storage account public blob access setting')
param azureMLRegistryStorageAccountAllowBlobPublicAccess bool = false

@description('Optional system-created registry ACR account name')
param azureMLRegistryAcrAccountName string = ''

@description('Optional system-created registry ACR SKU')
param azureMLRegistryAcrAccountSku string = ''

@description('VM size for Azure ML shared compute instance')
param sharedComputeInstanceVmSize string = 'Standard_D4s_v3'

@description('VM size for Azure ML personal compute instance')
param personalComputeInstanceVmSize string = 'Standard_DS3_v2'

@description('Tags for all resources')
param tags object = {
  Environment: environmentName
  Project: projectName
  ManagedBy: 'Bicep'
}

// Network Address Space Configuration (optional - customize if needed)
@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Databricks public subnet')
param databricksPublicSubnetPrefix string = '10.0.1.0/24'

@description('Databricks private subnet')
param databricksPrivateSubnetPrefix string = '10.0.2.0/24'

@description('Azure ML compute subnet')
param azureMLComputeSubnetPrefix string = '10.0.3.0/24'

@description('AKS subnet')
param aksSubnetPrefix string = '10.0.4.0/23'

@description('ACA infrastructure subnet')
param acaInfrastructureSubnetPrefix string = '10.0.6.0/23'

@description('Private endpoints subnet')
param privateEndpointSubnetPrefix string = '10.0.8.0/24'

@description('API Management subnet')
param apimSubnetPrefix string = '10.0.9.0/24'

// ========== Variables ==========
var sharedRgName = 'rg-${environmentName}-${projectName}-shared'
var databricksRgName = 'rg-${environmentName}-${projectName}-databricks'
var aiPlatformRgName = 'rg-${environmentName}-${projectName}-ai-platform'
var computeRgName = 'rg-${environmentName}-${projectName}-compute'

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

resource computeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: computeRgName
  location: location
  tags: union(tags, { Purpose: 'ContainerCompute' })
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
    deployAPIM: deployAPIM
    deployBastion: deployBastion
    vnetAddressPrefix: vnetAddressPrefix
    databricksPublicSubnetPrefix: databricksPublicSubnetPrefix
    databricksPrivateSubnetPrefix: databricksPrivateSubnetPrefix
    azureMLComputeSubnetPrefix: azureMLComputeSubnetPrefix
    aksSubnetPrefix: aksSubnetPrefix
    acaInfrastructureSubnetPrefix: acaInfrastructureSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    apimSubnetPrefix: apimSubnetPrefix
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

// Platform Key Vault (RBAC - for Azure ML, AI Foundry, platform services)
module keyVault 'components/keyvault/keyvault.bicep' = {
  scope: sharedResourceGroup
  name: 'keyvault-platform-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    adminObjectId: adminObjectId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// Databricks Key Vault (Access Policies - for Databricks secret scopes)
// Dedicated vault for Databricks-accessible secrets only
// Uses Access Policies (required by Microsoft for Databricks secret scope integration)
module databricksKeyVault 'components/keyvault/keyvault-databricks.bicep' = {
  scope: sharedResourceGroup
  name: 'keyvault-databricks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
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

// Shared Private DNS Zone for Key Vault (avoid duplicate zone creation)
module sharedDnsZone 'components/networking/shared-dns-zone.bicep' = {
  scope: sharedResourceGroup
  name: 'shared-dns-zone-deployment'
  params: {
    location: 'global'
    vnetId: networking.outputs.vnetId
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
    storageAccountId: storage.outputs.storageAccountId
  }
}

// Azure Bastion (optional - STAYS IN SHARED RG)
module bastion 'components/compute/bastion.bicep' = if (deployBastion) {
  scope: sharedResourceGroup
  name: 'bastion-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    bastionSubnetId: networking.outputs.bastionSubnetId
    tags: tags
  }
}

// Jumpbox VM (optional - STAYS IN SHARED RG)
module jumpbox 'components/compute/jumpbox.bicep' = if (deployJumpbox) {
  scope: sharedResourceGroup
  name: 'jumpbox-deployment'
  params: {
    location: location
    environmentName: environmentName
    subnetId: networking.outputs.jumpboxSubnetId
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    tags: tags
  }
  dependsOn: [
    bastion // Deploy bastion first if both are enabled
  ]
}

// ========== COMPUTE RESOURCE GROUP ==========

// AKS Cluster (optional)
module aks 'components/aks/aks.bicep' = if (deployAKS) {
  scope: computeResourceGroup
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

// Azure Container Apps Environment (optional)
module containerApps 'components/aca/aca.bicep' = if (deployACA) {
  scope: computeResourceGroup
  name: 'aca-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    infrastructureSubnetId: networking.outputs.acaInfrastructureSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
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
    tags: tags
  }
}

// NSG Flow Logs (Network Monitoring)
module nsgFlowLogs 'components/networking/nsg-flow-logs.bicep' = if (enableNsgFlowLogs) {
  scope: sharedResourceGroup
  name: 'nsg-flowlogs-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    networkSecurityGroupIds: networking.outputs.nsgIds
    storageAccountName: storage.outputs.storageAccountName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    enableTrafficAnalytics: true
    retentionDays: 30
  }
}

// Azure Policy Assignments (Security & Governance)
module policyAssignments 'components/security/policy-assignments.bicep' = if (enablePolicyAssignments) {
  scope: sharedResourceGroup
  name: 'policy-assignments-deployment'
  params: {
    location: location
    environmentName: environmentName
    sharedResourceGroupName: sharedResourceGroup.name
  }
}

// App Configuration (optional)
module appConfig 'components/app-config/app-config.bicep' = if (deployAppConfiguration) {
  scope: sharedResourceGroup
  name: 'appconfig-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// API Management (optional)
module apim 'components/apim/apim.bicep' = if (deployAPIM) {
  scope: sharedResourceGroup
  name: 'apim-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    apimSubnetId: networking.outputs.apimSubnetId
    appInsightsId: monitoring.outputs.applicationInsightsId
    appInsightsInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    sku: apimSku
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
    apiPrivateDnsZoneId: azuremlDns!.outputs.apiPrivateDnsZoneId
    notebooksPrivateDnsZoneId: azuremlDns!.outputs.notebooksPrivateDnsZoneId
    instancesPrivateDnsZoneId: azuremlDns!.outputs.instancesPrivateDnsZoneId
    contentPrivateDnsZoneId: azuremlDns!.outputs.contentPrivateDnsZoneId
    inferencePrivateDnsZoneId: azuremlDns!.outputs.inferencePrivateDnsZoneId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    enableDiagnostics: true
    enableSharedComputeInstance: enableSharedComputeInstance
    enablePersonalComputeInstance: enablePersonalComputeInstance
    sharedComputeInstanceVmSize: sharedComputeInstanceVmSize
    personalComputeInstanceVmSize: personalComputeInstanceVmSize
    tags: tags
  }
}

// Azure ML Registry (optional)
module azureMLRegistry 'components/azureml/registry.bicep' = if (deployAzureMLRegistry) {
  scope: aiPlatformResourceGroup
  name: 'azureml-registry-deployment'
  params: {
    location: location
    environmentName: environmentName
    projectName: projectName
    registryName: azureMLRegistryName
    publicNetworkAccess: azureMLRegistryPublicNetworkAccess
    replicationRegions: azureMLRegistryReplicationRegions
    identityMode: azureMLRegistryIdentityMode
    skuName: azureMLRegistrySkuName
    managedResourceGroupResourceId: sharedResourceGroup.id
    useSystemCreatedResources: azureMLRegistryUseSystemCreatedResources
    registryStorageAccountName: azureMLRegistryStorageAccountName
    registryStorageAccountType: azureMLRegistryStorageAccountType
    registryStorageAccountHnsEnabled: azureMLRegistryStorageAccountHnsEnabled
    registryStorageAccountAllowBlobPublicAccess: azureMLRegistryStorageAccountAllowBlobPublicAccess
    registryAcrAccountName: azureMLRegistryAcrAccountName
    registryAcrAccountSku: azureMLRegistryAcrAccountSku
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
    apiPrivateDnsZoneId: azuremlDns!.outputs.apiPrivateDnsZoneId
    notebooksPrivateDnsZoneId: azuremlDns!.outputs.notebooksPrivateDnsZoneId
    instancesPrivateDnsZoneId: azuremlDns!.outputs.instancesPrivateDnsZoneId
    contentPrivateDnsZoneId: azuremlDns!.outputs.contentPrivateDnsZoneId
    inferencePrivateDnsZoneId: azuremlDns!.outputs.inferencePrivateDnsZoneId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    enableDiagnostics: true
    tags: tags
  }
}

// AI Search (optional)
module aiSearch 'components/ai-search/ai-search.bicep' = if (deployAISearch) {
  scope: aiPlatformResourceGroup
  name: 'aisearch-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    sku: aiSearchSku
    tags: tags
  }
}

// Cosmos DB (optional)
module cosmosDb 'components/cosmos-db/cosmos-db.bicep' = if (deployCosmosDB) {
  scope: aiPlatformResourceGroup
  name: 'cosmosdb-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    consistencyLevel: cosmosDbConsistencyLevel
    tags: tags
  }
}

// ========== Cross-Resource Group RBAC Assignments ==========
// 
// These assign roles at SHARED RESOURCE GROUP scope (where both storage accounts live).
// This means roles apply to both:
// 1. Unity Catalog storage - accessed via Access Connector, not direct RBAC
// 2. Azure ML storage - accessed via managed identities
//
// DESIGN NOTE:
// - RG-scoped roles are simpler than resource-scoped roles
// - UC storage access is controlled by Access Connector, not these RBAC assignments
// - Azure ML benefits from having Contributor role (can write models/artifacts)
// - AI Foundry only needs Reader (read-only access to workspace storage)
//
// For detailed RBAC configuration, see: docs/STORAGE-AND-RBAC-CONFIGURATION.md
//

// Azure ML Workspace - Storage Blob Data Contributor
// Scope: Shared RG (both storage accounts, but primarily for Azure ML storage)
// Purpose: Write training artifacts, models, datasets to azureml container
// REQUIRED: When allowSharedKeyAccess=false, workspace MUST have this role
// Identity: azure-ml-workspace managed identity
module amlStorageBlobRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-storage-blob-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalType: 'ServicePrincipal'
  }
}

// Azure ML Workspace - Storage File Data Privileged Contributor
// Scope: Shared RG (Azure ML storage account)
// Purpose: Access file shares when allowSharedKeyAccess=false
// REQUIRED: For datastore file share access with identity-based auth
// Identity: azure-ml-workspace managed identity
module amlStorageFileRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-storage-file-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69566ab7-960f-475b-8e7c-b3118f30c6bd')
    principalType: 'ServicePrincipal'
  }
}

// Note: Azure ML and AI Foundry get Key Vault access through the linked keyVault property
// in their workspace definitions. Direct RBAC role assignments are not required.
// Commenting out to avoid role definition errors.

// AI Foundry Hub - Storage Blob Data Reader (Read-Only)
// Scope: Shared RG (both storage accounts, but primarily for Azure ML storage)
// Purpose: Read-only access to workspace storage (models, artifacts)
// Note: Reader role is SUFFICIENT for AI Foundry (shares workspace with Azure ML)
// Identity: ai-foundry-hub managed identity (f55da7e0-4eea-4f16-ab3d-e7b3401cc804)
module aiFoundryStorageBlobRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAIFoundry) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aihub-storage-blob-role'
  params: {
    principalId: aiFoundry!.outputs.hubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalType: 'ServicePrincipal'
  }
}

// ========== Admin User Storage Access ==========
// IMPORTANT: When allowSharedKeyAccess=false, users need RBAC roles to access storage via Studio
// These roles enable the admin user to access datastores in Azure ML Studio
// See: docs/FIX-DATASTORE-ACCOUNT-KEY-ERROR.md

// Admin User - Storage Blob Data Contributor
// Scope: Shared RG (Azure ML storage account)
// Purpose: Access Azure ML datastores in Studio when account key is disabled
module adminStorageBlobRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'admin-storage-blob-role'
  params: {
    principalId: adminObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalType: 'User'
  }
}

// Admin User - Storage File Data Privileged Contributor
// Scope: Shared RG (Azure ML storage account)
// Purpose: Access file shares in Azure ML storage when account key is disabled
module adminStorageFileRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'admin-storage-file-role'
  params: {
    principalId: adminObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69566ab7-960f-475b-8e7c-b3118f30c6bd')
    principalType: 'User'
  }
}

// ========== Azure Container Registry (ACR) Access ==========
// Azure ML and AI Foundry need ACR access to push/pull container images

// Azure ML Workspace - ACR Pull (Read Images)
// Scope: Shared RG (ACR)
// Purpose: Pull base images and custom environments
module amlAcrPullRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-acr-pull-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

// Azure ML Workspace - ACR Push (Write Images)
// Scope: Shared RG (ACR)
// Purpose: Push custom environment images and training containers
module amlAcrPushRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-acr-push-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalType: 'ServicePrincipal'
  }
}

// AI Foundry Hub - ACR Pull (Read Images)
// Scope: Shared RG (ACR)
// Purpose: Pull images for AI model deployments
module aiFoundryAcrPullRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAIFoundry) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aihub-acr-pull-role'
  params: {
    principalId: aiFoundry!.outputs.hubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

// AI Foundry Hub - ACR Push (Write Images)
// Scope: Shared RG (ACR)
// Purpose: Push model container images
module aiFoundryAcrPushRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAIFoundry) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aihub-acr-push-role'
  params: {
    principalId: aiFoundry!.outputs.hubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalType: 'ServicePrincipal'
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

@description('Platform Key Vault outputs from shared RG (RBAC - for Azure ML, AI Foundry)')
output keyVaultOutputs object = keyVault.outputs

@description('Databricks Key Vault ID (Access Policies - for secret scopes)')
output databricksKeyVaultId string = databricksKeyVault.outputs.keyVaultId

@description('Databricks Key Vault name')
output databricksKeyVaultName string = databricksKeyVault.outputs.keyVaultName

@description('Databricks Key Vault URI for secret scope configuration')
output databricksKeyVaultUri string = databricksKeyVault.outputs.keyVaultUri

@description('Databricks Key Vault full resource ID for Terraform')
output databricksKeyVaultResourceId string = databricksKeyVault.outputs.resourceId

@description('Container Registry outputs from shared RG')
output containerRegistryOutputs object = containerRegistry.outputs

@description('Monitoring outputs (Application Insights & Log Analytics)')
output monitoringOutputs object = monitoring.outputs

@description('Security & RBAC outputs (Managed Identities)')
output securityRbacOutputs object = securityRbac.outputs

@description('App Configuration endpoint')
output appConfigurationEndpoint string = deployAppConfiguration ? appConfig!.outputs.appConfigEndpoint : ''

@description('API Management gateway URL')
output apimGatewayUrl string = deployAPIM ? apim!.outputs.apimGatewayUrl : ''

@description('Databricks workspace URL')
output databricksWorkspaceUrl string = databricks.outputs.workspaceUrl

@description('Azure ML workspace ID')
output azureMLWorkspaceId string = deployAzureML ? azureML!.outputs.workspaceId : ''

@description('Azure ML registry ID')
output azureMLRegistryId string = deployAzureMLRegistry ? azureMLRegistry!.outputs.registryId : ''

@description('Azure ML registry name')
output azureMLRegistryName string = deployAzureMLRegistry ? azureMLRegistry!.outputs.registryName : ''

@description('Azure ML registry managed resource group ID (read-only)')
output azureMLRegistryManagedResourceGroupId string = deployAzureMLRegistry ? azureMLRegistry!.outputs.managedResourceGroupId : ''

@description('AI Foundry hub ID')
output aiFoundryHubId string = deployAIFoundry ? aiFoundry!.outputs.hubId : ''

@description('AI Search endpoint')
output aiSearchEndpoint string = deployAISearch ? aiSearch!.outputs.searchServiceEndpoint : ''

@description('Cosmos DB endpoint')
output cosmosDbEndpoint string = deployCosmosDB ? cosmosDb!.outputs.cosmosAccountEndpoint : ''

@description('AKS cluster resource ID')
output aksClusterResourceId string = deployAKS ? aks!.outputs.aksClusterResourceId : ''

@description('Azure Container Apps environment ID')
output containerAppsEnvironmentId string = deployACA ? containerApps!.outputs.containerAppsEnvironmentId : ''

@description('Azure Bastion name')
output bastionName string = deployBastion ? bastion!.outputs.bastionName : ''

@description('Jumpbox VM name')
output jumpboxVmName string = deployJumpbox ? jumpbox!.outputs.vmName : ''

@description('Jumpbox private IP address')
output jumpboxPrivateIp string = deployJumpbox ? jumpbox!.outputs.privateIPAddress : ''
