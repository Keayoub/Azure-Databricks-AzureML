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
param deployACA = false
param aksNodeCount = 3

// Tags
param tags = {
  Environment: environmentName
  Project: projectName
  ManagedBy: 'Bicep'
}
