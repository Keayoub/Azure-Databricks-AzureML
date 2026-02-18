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
param apiPrivateDnsZoneId string
param notebooksPrivateDnsZoneId string
param instancesPrivateDnsZoneId string
param contentPrivateDnsZoneId string
param inferencePrivateDnsZoneId string
param logAnalyticsWorkspaceId string = ''
param enableDiagnostics bool = true
param tags object

var hubName = 'aihub-${environmentName}-${projectName}'
var privateEndpointName = 'pe-${environmentName}-${projectName}-aihub'

// Note: We don't declare 'existing' resources here because they're in a different RG
// Storage, Key Vault, and Container Registry are referenced by their full resource IDs

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

// Note: RBAC role assignments are handled in main.bicep at the subscription scope
// to allow cross-resource group assignments

// ========== Private Endpoint ==========
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
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

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'aihub-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'api-config'
        properties: {
          privateDnsZoneId: apiPrivateDnsZoneId
        }
      }
      {
        name: 'notebooks-config'
        properties: {
          privateDnsZoneId: notebooksPrivateDnsZoneId
        }
      }
      {
        name: 'instances-config'
        properties: {
          privateDnsZoneId: instancesPrivateDnsZoneId
        }
      }
      {
        name: 'content-config'
        properties: {
          privateDnsZoneId: contentPrivateDnsZoneId
        }
      }
      {
        name: 'inference-config'
        properties: {
          privateDnsZoneId: inferencePrivateDnsZoneId
        }
      }
    ]
  }
}

// ========== Diagnostic Settings ==========
resource hubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  scope: aiHub
  name: 'aihub-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// ========== Outputs ==========
output hubName string = aiHub.name
output hubId string = aiHub.id
output hubPrincipalId string = aiHub.identity.principalId
