// Azure AI Foundry Hub Module
// This module deploys Azure AI Foundry hub with:
// - Network isolation
// - Integration with Azure ML and other AI services
// - Private endpoint connectivity

param location string
param projectName string
param environmentName string
param storageAccountId string
param keyVaultId string
param containerRegistryId string
param privateEndpointSubnetId string
param privateDnsZoneId string
param tags object

var hubName = 'aihub-${environmentName}-${projectName}'
var privateEndpointName = 'pe-${environmentName}-${projectName}-aihub'

var storageAccountName = split(storageAccountId, '/')[8]
var keyVaultName = split(keyVaultId, '/')[8]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// ========== Azure AI Hub ==========
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: hubName
  location: location
  tags: tags
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: hubName
    storageAccount: storageAccountId
    keyVault: keyVaultId
    containerRegistry: containerRegistryId
    publicNetworkAccess: 'Disabled'
    description: 'Azure AI Foundry Hub with network integration'
    hubResourceId: null
  }
}

// Assign Storage Blob Data Reader role to AI Hub
resource storageBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccountId, aiHub.id, 'StorageBlobDataReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign Key Vault Secrets User role to AI Hub
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVaultId, aiHub.id, 'KeyVaultAdmin')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Private Endpoint ==========
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: aiHub.id
          groupIds: [
            'amlworkspace'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'aihub-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ========== Outputs ==========
output hubName string = aiHub.name
output hubId string = aiHub.id
