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
param deployAIFoundry = true
param deployAKS = false
param aksNodeCount = 3

// AI Foundry Landing Zone - Optional Services (set to true to deploy)
param deployAISearch = false
param deployCosmosDB = false
param deployAppConfiguration = false
param deployAPIM = false

// AI Service SKUs and Configuration
param aiSearchSku = 'standard'
param cosmosDbConsistencyLevel = 'Session'
param apimSku = 'Developer'
param apimPublisherEmail = 'admin@yourdomain.com'
param apimPublisherName = 'Your Organization'

// Bastion and Jumpbox Configuration (Optional)
param deployBastion = true
param deployJumpbox = true
param jumpboxAdminUsername = 'azureadmin'
param jumpboxAdminPassword = '' // Required if deployJumpbox = true

// Tags
param tags = {
  Environment: environmentName
  Project: projectName
  ManagedBy: 'Bicep'
}

