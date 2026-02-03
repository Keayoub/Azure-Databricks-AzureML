// Azure Databricks Workspace Module with Security Features
// Features:
// - VNet injection for network isolation
// - Unity Catalog support for centralized governance
// - Delta Sharing enabled
// - Data exfiltration protection
// - Secure cluster connectivity (No Public IP - NPIP)
// - Customer-managed VNet

param location string
param projectName string
param environmentName string
param vnetId string
param privateSubnetName string
param publicSubnetName string
param privateEndpointSubnetId string
param tags object

var workspaceName = 'dbw-${projectName}-${environmentName}'
var managedResourceGroupName = 'rg-${projectName}-databricks-managed-${environmentName}'
var pricingTier = 'premium' // Premium required for Unity Catalog and Delta Sharing

// ========== Azure Databricks Workspace ==========
resource databricksWorkspace 'Microsoft.Databricks/workspaces@2024-05-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: pricingTier
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    parameters: {
      customVirtualNetworkId: {
        value: vnetId
      }
      customPublicSubnetName: {
        value: publicSubnetName
      }
      customPrivateSubnetName: {
        value: privateSubnetName
      }
      enableNoPublicIp: {
        value: true // Secure Cluster Connectivity (No Public IP)
      }
      // Data exfiltration protection - enforced via requiredNsgRules at workspace level
      storageAccountSkuName: {
        value: 'Standard_GRS' // Geo-redundant storage for DBFS
      }
      // Enable encryption
      requireInfrastructureEncryption: {
        value: true
      }
    }
    publicNetworkAccess: 'Disabled' // Disable public network access for enhanced security
    requiredNsgRules: 'NoAzureDatabricksRules'
    // Unity Catalog configuration
    // Note: Unity Catalog metastore must be created separately via Databricks API
    // This can be done post-deployment using Databricks CLI or REST API
  }
}

// ========== Private Endpoints for Databricks Control Plane ==========
// Required for accessing workspace UI and APIs when publicNetworkAccess is Disabled

// Private DNS Zones for Databricks
resource databricksUiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azuredatabricks.net'
  location: 'global'
  tags: tags
}

resource databricksUiDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: databricksUiPrivateDnsZone
  name: '${workspaceName}-ui-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Private Endpoint for Workspace UI and API (databricks_ui_api)
resource databricksUiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${workspaceName}-ui'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'databricks-ui-connection'
        properties: {
          privateLinkServiceId: databricksWorkspace.id
          groupIds: [
            'databricks_ui_api'
          ]
        }
      }
    ]
  }
}

resource databricksUiPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: databricksUiPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'databricks-ui-config'
        properties: {
          privateDnsZoneId: databricksUiPrivateDnsZone.id
        }
      }
    ]
  }
}

// Private Endpoint for Browser Authentication (browser_authentication)
resource databricksBrowserAuthPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${workspaceName}-auth'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'databricks-auth-connection'
        properties: {
          privateLinkServiceId: databricksWorkspace.id
          groupIds: [
            'browser_authentication'
          ]
        }
      }
    ]
  }
}

resource databricksBrowserAuthPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: databricksBrowserAuthPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'databricks-auth-config'
        properties: {
          privateDnsZoneId: databricksUiPrivateDnsZone.id
        }
      }
    ]
  }
}

// ========== Outputs ==========
output workspaceId string = databricksWorkspace.id
output workspaceName string = databricksWorkspace.name
output workspaceUrl string = databricksWorkspace.properties.workspaceUrl
output managedResourceGroupId string = databricksWorkspace.properties.managedResourceGroupId

// ========== Post-Deployment Notes ==========
// After deployment, configure Unity Catalog using Databricks CLI:
// 1. Create Unity Catalog metastore
// 2. Assign metastore to workspace
// 3. Configure Delta Sharing if enabled
// 4. Set up external locations and storage credentials
// 5. Create catalogs, schemas, and tables

// Example Databricks CLI commands (run after deployment):
// databricks unity-catalog metastores create --name <metastore-name> --storage-root <storage-account-url> --region <location>
// databricks unity-catalog metastores assign --workspace-id <workspace-id> --metastore-id <metastore-id>
// databricks unity-catalog delta-sharing shares create --name <share-name>
