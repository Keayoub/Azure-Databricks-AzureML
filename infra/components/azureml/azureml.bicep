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
param storageContainerName string = 'azureml'
param adlsContainerName string = 'azureml'
param keyVaultId string
param containerRegistryId string
param privateEndpointSubnetId string
param computeSubnetId string
param apiPrivateDnsZoneId string
param notebooksPrivateDnsZoneId string
param instancesPrivateDnsZoneId string
param contentPrivateDnsZoneId string
param inferencePrivateDnsZoneId string
param logAnalyticsWorkspaceId string = ''
param enableDiagnostics bool = true
param tags object

@description('Enable shared compute instance for team')
param enableSharedComputeInstance bool = true

@description('VM size for shared compute instance')
param sharedComputeInstanceVmSize string = 'Standard_D4s_v3'

@description('Enable personal compute instance for development')
param enablePersonalComputeInstance bool = true

@description('VM size for personal compute instance')
param personalComputeInstanceVmSize string = 'Standard_DS3_v2'

var workspaceName = 'aml-${environmentName}-${projectName}'
var applicationInsightsName = 'appi-${environmentName}-${projectName}'
var privateEndpointName = 'pe-${environmentName}-${projectName}-aml'

var storageAccountName = split(storageAccountId, '/')[8]
var storageAccountSubscriptionId = split(storageAccountId, '/')[2]
var storageAccountResourceGroup = split(storageAccountId, '/')[4]
var storageEndpointSuffix = environment().suffixes.storage

// Note: We don't declare 'existing' resources here because they're in a different RG
// Instead, we reference them by their full resource ID in RBAC assignments below

// ========== Application Insights ==========
resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ========== Azure ML Workspace ==========
resource workspace 'Microsoft.MachineLearningServices/workspaces@2025-10-01-preview' = {
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
    imageBuildCompute: 'cpu-cluster'
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    description: 'Secure Azure ML workspace with network integration'
    discoveryUrl: null
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
          privateLinkServiceId: workspace.id
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
  name: 'aml-dns-zone-group'
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

// ========== Compute Cluster ==========
resource computeCluster 'Microsoft.MachineLearningServices/workspaces/computes@2025-10-01-preview' = {
  parent: workspace
  name: 'cpu-cluster'
  location: location
  tags: tags
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

// ========== Compute Instance (Personal - Development) ==========
resource personalComputeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2025-10-01-preview' = if (enablePersonalComputeInstance) {
  parent: workspace
  name: 'aml-compute-personal'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    description: 'Azure ML personal compute instance for development'
    properties: {
      vmSize: personalComputeInstanceVmSize
      subnet: {
        id: computeSubnetId
      }
      applicationSharingPolicy: 'Personal'
      enableSSO: false
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      enableNodePublicIp: false
    }
  }
}

// ========== Compute Instance (Shared - Team) ==========
resource sharedComputeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2025-10-01-preview' = if (enableSharedComputeInstance) {
  parent: workspace
  name: 'aml-compute-shared'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    description: 'Azure ML shared compute instance for team collaboration'
    properties: {
      vmSize: sharedComputeInstanceVmSize
      subnet: {
        id: computeSubnetId
      }
      applicationSharingPolicy: 'Shared'
      enableSSO: false
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      enableNodePublicIp: false
    }
  }
}

// ========== Datastore (Azure Blob) ==========
resource dataStore 'Microsoft.MachineLearningServices/workspaces/dataStores@2025-10-01-preview' = {
  parent: workspace
  name: 'ml_blob'
  properties: {
    datastoreType: 'AzureBlob'
    accountName: storageAccountName
    containerName: storageContainerName
    endpoint: storageEndpointSuffix
    protocol: 'https'
    subscriptionId: storageAccountSubscriptionId
    resourceGroup: storageAccountResourceGroup
    credentials: {
      credentialsType: 'None'
    }
    serviceDataAccessAuthIdentity: 'WorkspaceSystemAssignedIdentity'
  }
}

// ========== Datastore (ADLS Gen2) ==========
resource adlsDataStore 'Microsoft.MachineLearningServices/workspaces/dataStores@2025-10-01-preview' = {
  parent: workspace
  name: 'ml_adls'
  properties: {
    datastoreType: 'AzureDataLakeGen2'
    accountName: storageAccountName
    filesystem: adlsContainerName
    endpoint: storageEndpointSuffix
    protocol: 'https'
    subscriptionId: storageAccountSubscriptionId
    resourceGroup: storageAccountResourceGroup
    credentials: {
      credentialsType: 'None'
    }
    serviceDataAccessAuthIdentity: 'WorkspaceSystemAssignedIdentity'
  }
}

// ========== Diagnostic Settings ==========
resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  scope: workspace
  name: 'aml-diagnostics'
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
output workspaceName string = workspace.name
output workspaceId string = workspace.id
output workspacePrincipalId string = workspace.identity.principalId
output applicationInsightsId string = applicationInsights.id
output computeClusterName string = computeCluster.name
output computeClusterId string = computeCluster.id
output personalComputeInstanceName string = enablePersonalComputeInstance ? personalComputeInstance.name : ''
output personalComputeInstanceId string = enablePersonalComputeInstance ? personalComputeInstance.id : ''
output sharedComputeInstanceName string = enableSharedComputeInstance ? sharedComputeInstance.name : ''
output sharedComputeInstanceId string = enableSharedComputeInstance ? sharedComputeInstance.id : ''
output blobDatastoreName string = dataStore.name
output blobDatastoreId string = dataStore.id
output adlsDatastoreName string = adlsDataStore.name
output adlsDatastoreId string = adlsDataStore.id
