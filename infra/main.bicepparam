using './main.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'eastus'
param projectName = 'secure-db'

// Admin configuration - CHANGE THIS TO YOUR OBJECT ID
param adminObjectId = '' // Run: az ad signed-in-user show --query id -o tsv

// Feature flags
param enableUnityCatalog = true
param enableDeltaSharing = true
param deployAzureML = true
param deployAIFoundry = true
param deployAKS = false
param aksNodeCount = 3

// Tags
param tags = {
  Environment: 'dev'
  Project: 'secure-databricks-azureml'
  ManagedBy: 'Bicep'
}
