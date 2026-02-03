// Storage Account Module with Security Features
// This storage account is used for:
// - Unity Catalog metastore storage
// - Azure ML workspace storage
// - AI Foundry hub storage

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

// ========== Storage Account ==========
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(storageAccountName, 24) // Storage account names max 24 chars
  location: location
  tags: tags
  sku: {
    name: 'Standard_RAGRS' // Read-access geo-redundant storage
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false // Disable public blob access
    allowSharedKeyAccess: false // Disable shared key access - use Entra ID only
    networkAcls: {
      defaultAction: 'Deny' // Deny all traffic by default
      bypass: 'AzureServices'
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
    isHnsEnabled: true // Enable hierarchical namespace for ADLS Gen2 (required for Unity Catalog)
    isNfsV3Enabled: false
    isSftpEnabled: false
    publicNetworkAccess: 'Disabled' // Disable public access
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
    isVersioningEnabled: true
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

// Container for Azure ML
resource azureMLContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
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

// ========== Outputs ==========
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output dfsEndpoint string = storageAccount.properties.primaryEndpoints.dfs
