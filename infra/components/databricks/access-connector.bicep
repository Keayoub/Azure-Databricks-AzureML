// Azure Databricks Access Connector Module
// Creates a managed identity for Databricks to access Azure resources without shared keys
// This enables secure authentication to storage accounts

param location string
param projectName string
param environmentName string
param tags object
@description('Optional storage account id to grant access for Unity Catalog')
param storageAccountId string = ''

var accessConnectorName = 'ac-${projectName}-${environmentName}'

// Reference existing storage account in the same resource group
// (Not currently used since role assignment is commented out, but kept for reference)
// resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
//   name: storageAccountName
// }

// ========== Access Connector (Managed Identity) ==========
// Created in the same resource group, acts as system-assigned managed identity for Unity Catalog
resource accessConnector 'Microsoft.Databricks/accessConnectors@2023-05-01' = {
  name: accessConnectorName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// ========== Grant Storage Permissions ==========
// NOTE: Role assignment may fail if principalId is not immediately available.
// If deployment fails with InvalidPrincipalId, assign this manually:
// az role assignment create --role "Storage Blob Data Contributor" \
//   --assignee-object-id <accessConnectorPrincipalId> \
//   --scope /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.Storage/storageAccounts/<storageName> \
//   --assignee-principal-type ServicePrincipal

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (storageAccountId != '') {
  name: split(storageAccountId, '/')[8]
}

resource storageBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageAccountId != '') {
  name: guid(storageAccountId, accessConnector.id, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: accessConnector.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Outputs ==========
output accessConnectorId string = accessConnector.id
output accessConnectorName string = accessConnector.name
output principalId string = accessConnector.identity.principalId
