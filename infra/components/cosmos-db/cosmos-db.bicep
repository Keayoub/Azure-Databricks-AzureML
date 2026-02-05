// Azure Cosmos DB Module
// This module deploys Azure Cosmos DB (NoSQL API) with:
// - Private endpoint connectivity
// - Private DNS zone integration
// - Session consistency for chat applications
// - Databases and containers for AI agent data
// - System-assigned managed identity
// - Zone redundancy support

param location string
param projectName string
param environmentName string
param vnetId string
param privateEndpointSubnetId string
param consistencyLevel string = 'Session'  // Session, Eventual, Strong, BoundedStaleness, ConsistentPrefix
param enableZoneRedundancy bool = false
param tags object

var cosmosAccountName = 'cosmos-${projectName}-${environmentName}'
var privateEndpointName = 'pe-cosmos-${projectName}-${environmentName}'
var privateDnsZoneName = 'privatelink.documents.azure.com'

// Databases and containers for AI workloads
var chatDatabaseName = 'chat-sessions'
var agentsDatabaseName = 'agents'
var documentsDatabaseName = 'documents'

// ========== Cosmos DB Account ==========
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: []
    ipRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: enableZoneRedundancy
      }
    ]
    cors: []
    capabilities: [
      {
        name: 'EnableServerless'  // Serverless for cost-effective AI workloads
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
  }
}

// ========== Chat Sessions Database ==========
resource chatDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: chatDatabaseName
  properties: {
    resource: {
      id: chatDatabaseName
    }
  }
}

resource chatSessionsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: chatDatabase
  name: 'sessions'
  properties: {
    resource: {
      id: 'sessions'
      partitionKey: {
        paths: [
          '/userId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
      defaultTtl: 2592000  // 30 days TTL for chat sessions
    }
  }
}

// ========== Agents Database ==========
resource agentsDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: agentsDatabaseName
  properties: {
    resource: {
      id: agentsDatabaseName
    }
  }
}

resource agentsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: agentsDatabase
  name: 'agent-configs'
  properties: {
    resource: {
      id: 'agent-configs'
      partitionKey: {
        paths: [
          '/agentId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// ========== Documents Database ==========
resource documentsDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: documentsDatabaseName
  properties: {
    resource: {
      id: documentsDatabaseName
    }
  }
}

resource documentsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: documentsDatabase
  name: 'metadata'
  properties: {
    resource: {
      id: 'metadata'
      partitionKey: {
        paths: [
          '/documentId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// ========== Private DNS Zone ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${cosmosAccountName}-link'
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
          privateLinkServiceId: cosmosAccount.id
          groupIds: [
            'Sql'  // For NoSQL API
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'cosmos-dns-zone-group'
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

// ========== Outputs ==========
output cosmosAccountName string = cosmosAccount.name
output cosmosAccountId string = cosmosAccount.id
output cosmosAccountEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosPrincipalId string = cosmosAccount.identity.principalId
output chatDatabaseName string = chatDatabase.name
output agentsDatabaseName string = agentsDatabase.name
output documentsDatabaseName string = documentsDatabase.name
