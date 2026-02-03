// Azure Machine Learning Workspace Module
// This module deploys Azure ML with:
// - Network isolation with private endpoints
// - Integration with Key Vault and Storage
// - Compute cluster configuration
// - Container Registry integration

param location string
param projectName string
param environmentName string
param storageAccountId string
param keyVaultId string
param containerRegistryId string
param vnetId string
param privateEndpointSubnetId string
param computeSubnetId string
param tags object

var workspaceName = 'aml-${projectName}-${environmentName}'
var applicationInsightsName = 'appi-${projectName}-${environmentName}'
var privateEndpointName = 'pe-aml-${projectName}-${environmentName}'

// ========== Application Insights ==========
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ========== Azure ML Workspace ==========
resource workspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: workspaceName
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistryId
    publicNetworkAccess: 'Disabled'
    imageBuildCompute: 'cpu-cluster' // Optional
    description: 'Secure Azure ML workspace with network integration'
    discoveryUrl: null
  }
}

// Assign Storage Blob Data Reader role to workspace
resource storageBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccountId
  name: guid(storageAccountId, workspace.id, 'StorageBlobDataReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign Key Vault Secrets User role to workspace
resource keyVaultSecretsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVaultId
  name: guid(keyVaultId, workspace.id, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86a0e88') // Key Vault Secrets User
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Private DNS Zone ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.api.azureml.ms'
  location: 'global'
  tags: tags
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'aml-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
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
          privateLinkServiceId: workspace.id
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
  name: 'aml-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ========== Compute Cluster ==========
resource computeCluster 'Microsoft.MachineLearningServices/workspaces/computes@2024-04-01' = {
  parent: workspace
  name: 'cpu-cluster'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    description: 'Azure ML CPU compute cluster'
    properties: {
      vmSize: 'Standard_DS3_v2'
      vmPriority: 'Dedicated'
      scaleSettings: {
        maxNodeCount: 10
        minNodeCount: 0
        nodeIdleTimeBeforeScaleDown: 900
      }
      userAccountCredentials: null
      subnet: {
        id: computeSubnetId
      }
      remoteLoginPortPubliclyAccessible: false
      isolatedNetwork: false
    }
  }
}

// ========== Outputs ==========
output workspaceName string = workspace.name
output workspaceId string = workspace.id
output applicationInsightsId string = applicationInsights.id
