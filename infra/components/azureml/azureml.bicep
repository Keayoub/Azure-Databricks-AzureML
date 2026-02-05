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
param privateEndpointSubnetId string
param computeSubnetId string
param privateDnsZoneId string
param tags object

var workspaceName = 'aml-${environmentName}-${projectName}'
var applicationInsightsName = 'appi-${environmentName}-${projectName}'
var privateEndpointName = 'pe-${environmentName}-${projectName}-aml'

var storageAccountName = split(storageAccountId, '/')[8]
var keyVaultName = split(keyVaultId, '/')[8]
var containerRegistryName = split(containerRegistryId, '/')[8]

// Note: We don't declare 'existing' resources here because they're in a different RG
// Instead, we reference them by their full resource ID in RBAC assignments below

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

// Note: RBAC role assignments are handled in main.bicep at the subscription scope
// to allow cross-resource group assignments

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
          privateDnsZoneId: privateDnsZoneId
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
        nodeIdleTimeBeforeScaleDown: 'PT15M'
      }
      userAccountCredentials: null
      subnet: {
        id: computeSubnetId
      }
      remoteLoginPortPublicAccess: 'Disabled'
      isolatedNetwork: false
    }
  }
}

// ========== Outputs ==========
output workspaceName string = workspace.name
output workspaceId string = workspace.id
output workspacePrincipalId string = workspace.identity.principalId
output applicationInsightsId string = applicationInsights.id
