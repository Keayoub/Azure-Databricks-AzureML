using './main.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'canadaeast'
param projectName = 'dbxaml'

// Admin configuration - CHANGE THIS TO YOUR OBJECT ID
param adminObjectId = '' // Run: az ad signed-in-user show --query id -o tsv


// Feature flags
param enableUnityCatalog = true
param deployAzureML = true
param deployAzureMLRegistry = true
param deployAIFoundry = true
param deployAKS = false
param aksNodeCount = 3

// Azure ML Registry Configuration (optional)
param azureMLRegistryName = ''
param azureMLRegistryPublicNetworkAccess = 'Enabled'
param azureMLRegistryReplicationRegions = []
param azureMLRegistryIdentityMode = 'SystemAssigned'
param azureMLRegistrySkuName = 'Basic'
param azureMLRegistryUseSystemCreatedResources = true
param azureMLRegistryStorageAccountName = ''
param azureMLRegistryStorageAccountType = ''
param azureMLRegistryStorageAccountHnsEnabled = true
param azureMLRegistryStorageAccountAllowBlobPublicAccess = false
param azureMLRegistryAcrAccountName = ''
param azureMLRegistryAcrAccountSku = ''

// AI Foundry Landing Zone - Optional Services (set to true to deploy)
param deployAISearch = false
param deployCosmosDB = false
param deployAppConfiguration = false
param deployAPIM = false

// Azure ML Compute Instances Configuration
param enableSharedComputeInstance = true
param enablePersonalComputeInstance = false
param sharedComputeInstanceVmSize = 'Standard_D4s_v3'

// AI Service SKUs and Configuration
param aiSearchSku = 'standard'
param cosmosDbConsistencyLevel = 'Session'
param apimSku = 'Developer'
param apimPublisherEmail = 'admin@yourdomain.com'
param apimPublisherName = 'Your Organization'

// Bastion and Jumpbox Configuration (Optional)
param deployBastion = true
param deployJumpbox = true
param jumpboxAdminUsername = ''
param jumpboxAdminPassword = '' // TODO: Change this to a secure password

// Tags
param tags = {
  Environment: environmentName
  Project: projectName
  ManagedBy: 'Bicep'
}

