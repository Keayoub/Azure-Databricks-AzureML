// ========== Storage Account Module with Security Features ==========
// 
// IMPORTANT: This module deploys TWO SEPARATE storage accounts for DIFFERENT purposes.
// Do NOT confuse them - they have different SKUs, configurations, and use cases.
//
// 1. UNITY CATALOG STORAGE (storageAccount)
//    - SKU: Standard_RAGRS (geo-redundant for HA)
//    - HNS: Enabled (ADLS Gen2 - required for Unity Catalog)
//    - Container: unity-catalog
//    - Private Endpoints: blob, dfs (ADLS Gen2), file
//    - Primary Consumer: Databricks via Access Connector
//    - Access: Managed identity (no shared keys)
//
// 2. AZURE ML STORAGE (mlStorageAccount)
//    - SKU: Standard_LRS (local redundancy, cost-optimized)
//    - HNS: Disabled (standard blob storage)
//    - Container: azureml
//    - Private Endpoints: blob, file (no DFS - not needed)
//    - Primary Consumers: Azure ML workspace, AI Foundry hub
//    - Access: Managed identity (no shared keys)
//
// See docs/STORAGE-AND-RBAC-CONFIGURATION.md for detailed RBAC and access flow.

param location string
param projectName string
param environmentName string
param vnetId string
param privateEndpointSubnetId string
param tags object

var storageAccountName = 'st${replace(projectName, '-', '')}${environmentName}${uniqueString(resourceGroup().id)}'
var blobPrivateEndpointName = 'pe-${storageAccountName}-blob'
var dfsPrivateEndpointName = 'pe-${storageAccountName}-dfs'
var filePrivateEndpointName = 'pe-${storageAccountName}-file'

var mlStorageAccountName = 'stml${replace(projectName, '-', '')}${environmentName}${uniqueString(resourceGroup().id)}'
var mlBlobPrivateEndpointName = 'pe-${mlStorageAccountName}-blob'
var mlFilePrivateEndpointName = 'pe-${mlStorageAccountName}-file'

// ========== Storage Account #1: UNITY CATALOG (ADLS Gen2) ==========
// Purpose: Databricks Unity Catalog metastore and data lake
// SKU: Standard_RAGRS (geo-redundant for HA in production)
// HNS: Enabled (ADLS Gen2 hierarchical namespace)
// Accessed via: Access Connector + Databricks managed identity
// Private Endpoints: blob, dfs (ADLS Gen2), file
// Role Assignments: Handled by Access Connector (no direct RBAC to AML/AI Foundry)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(storageAccountName, 24) // Storage account names max 24 chars
  location: location
  tags: tags
  sku: {
    name: 'Standard_RAGRS' // Read-access geo-redundant storage for HA
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false // Disable public blob access
    allowSharedKeyAccess: false // CRITICAL: Disable shared key - Access Connector uses managed identity
    networkAcls: {
      defaultAction: 'Deny' // Deny all traffic by default
      bypass: 'AzureServices, Logging' // Allow Azure platform services
      virtualNetworkRules: []
      ipRules: []
    }
    encryption: {
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: true // *** CRITICAL: Enable hierarchical namespace for ADLS Gen2 (required for Unity Catalog) ***
    isNfsV3Enabled: false
    isSftpEnabled: false
    publicNetworkAccess: 'Disabled' // Disable public access
  }
}

// ========== Storage Account #2: AZURE ML (Standard Blob) ==========
// Purpose: Azure ML workspace storage, experiments, models, artifacts, AI Foundry hub storage
// SKU: Standard_LRS (local redundancy, cost-optimized - single region only)
// HNS: Disabled (standard blob storage, NOT ADLS Gen2)
// Accessed via: Azure ML identity + AI Foundry identity
// Private Endpoints: blob, file (NO DFS endpoint - not needed for standard blob)
// Role Assignments: 
//   - Azure ML: Storage Blob Data Contributor (write models, artifacts)
//   - AI Foundry: Storage Blob Data Reader (read-only, shared workspace)
resource mlStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(mlStorageAccountName, 24)
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS' // Local redundancy only, cost-optimized
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // CRITICAL: Disable shared key - forces identity-based authentication
    networkAcls: {
      defaultAction: 'Deny' // Deny by default, access via private endpoint
      bypass: 'AzureServices, Logging, Metrics' // Allow Azure services, logging, and metrics
      virtualNetworkRules: []
      ipRules: []
      resourceAccessRules: [] // Resource access rules for workspace-specific access
    }
    encryption: {
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: false // *** Standard blob storage (not ADLS Gen2) - DFS not needed ***
    isNfsV3Enabled: false
    isSftpEnabled: false
    publicNetworkAccess: 'Disabled' // Disabled - access via private endpoint only (secure by default)
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    changeFeed: {
      enabled: true
      retentionInDays: 7
    }
    isVersioningEnabled: false
  }
}

// Container for Unity Catalog
resource unityCatalogContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'unity-catalog'
  properties: {
    publicAccess: 'None'
  }
}

// Blob Service for ML storage
resource mlBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: mlStorageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    changeFeed: {
      enabled: false
    }
    isVersioningEnabled: false
  }
}

// Container for Azure ML / AI Foundry
resource azureMLContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: mlBlobService
  name: 'azureml'
  properties: {
    publicAccess: 'None'
  }
}

// ========== Private DNS Zones ==========
resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource dfsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.dfs.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

// Link DNS zones to VNet
resource blobDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobPrivateDnsZone
  name: 'blob-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource dfsDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dfsPrivateDnsZone
  name: 'dfs-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource fileDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: filePrivateDnsZone
  name: 'file-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Private Endpoints ==========
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: blobPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: blobPrivateEndpointName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource dfsPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: dfsPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: dfsPrivateEndpointName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }
}

resource filePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: filePrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: filePrivateEndpointName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

// ========== Private Endpoints for ML Storage ==========
resource mlBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: mlBlobPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: mlBlobPrivateEndpointName
        properties: {
          privateLinkServiceId: mlStorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource mlFilePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: mlFilePrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: mlFilePrivateEndpointName
        properties: {
          privateLinkServiceId: mlStorageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Groups
resource blobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: blobPrivateEndpoint
  name: 'blob-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource dfsPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: dfsPrivateEndpoint
  name: 'dfs-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: dfsPrivateDnsZone.id
        }
      }
    ]
  }
}

resource filePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: filePrivateEndpoint
  name: 'file-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

resource mlBlobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: mlBlobPrivateEndpoint
  name: 'ml-blob-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource mlFilePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: mlFilePrivateEndpoint
  name: 'ml-file-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

// ========== Outputs ==========
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output dfsEndpoint string = storageAccount.properties.primaryEndpoints.dfs
output mlStorageAccountId string = mlStorageAccount.id
output mlStorageAccountName string = mlStorageAccount.name
output mlBlobEndpoint string = mlStorageAccount.properties.primaryEndpoints.blob
