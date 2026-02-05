// Security and RBAC Module
// Based on AI Landing Zones patterns
// Centralizes role assignments and managed identity configurations

param location string
param projectName string
param environmentName string
param adminObjectId string // Reserved for future admin role assignments
param tags object

// Role IDs (these are built-in Azure roles)
var ownerRoleId = 'a4b10055-b0c7-44c2-8714-1d4c851b36fc'      // Owner
var contributorRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Contributor
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'      // Reader
var storageAccountContributorRoleId = '17d1049b-9a84-46fb-a30c-e9fa2610e3e1' // Storage Account Contributor
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86339e9' // Key Vault Secrets User
var mlDataScientistRoleId = 'f6c7ebca-8b80-4b6f-9a9c-3a7f1bae495a' // AML Data Scientist (managed identity access)

// ========== Create Managed Identity for Applications ==========
resource appManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-app-${projectName}-${environmentName}'
  location: location
  tags: tags
}

resource workflowManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-workflow-${projectName}-${environmentName}'
  location: location
  tags: tags
}

resource dataPipelineManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-datapipeline-${projectName}-${environmentName}'
  location: location
  tags: tags
}

// ========== Outputs for Managed Identities ==========
output appManagedIdentityId string = appManagedIdentity.id
output appManagedIdentityPrincipalId string = appManagedIdentity.properties.principalId
output appManagedIdentityClientId string = appManagedIdentity.properties.clientId

output workflowManagedIdentityId string = workflowManagedIdentity.id
output workflowManagedIdentityPrincipalId string = workflowManagedIdentity.properties.principalId

output dataPipelineManagedIdentityId string = dataPipelineManagedIdentity.id
output dataPipelineManagedIdentityPrincipalId string = dataPipelineManagedIdentity.properties.principalId

// ========== Role Definition Outputs (for use in other modules) ==========
output roleIds object = {
  owner: ownerRoleId
  contributor: contributorRoleId
  reader: readerRoleId
  storageAccountContributor: storageAccountContributorRoleId
  keyVaultAdministrator: keyVaultAdministratorRoleId
  keyVaultSecretsUser: keyVaultSecretsUserRoleId
  mlDataScientist: mlDataScientistRoleId
}
