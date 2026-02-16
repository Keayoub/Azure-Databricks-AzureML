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
        name: 'config'
        properties: {
          privateDnsZoneId: apiPrivateDnsZoneId
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
    logs: [
      {
        category: 'AmlComputeClusterEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AmlComputeClusterNodeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AmlComputeJobEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AmlRunStatusChangedEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ModelsChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ModelsReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ModelsActionEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DeploymentReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'EnvironmentChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'EnvironmentReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataStoreChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataStoreReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataSetChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataSetReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'PipelineChangeEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'PipelineReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RunEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RunReadEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
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
