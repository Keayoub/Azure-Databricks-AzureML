// Azure Policy Assignment Module
// Enforces security and compliance policies across the deployment

param location string
param environmentName string

// Resource groups to apply policies to
param sharedResourceGroupName string

// ========== Policy Definitions (Built-in) ==========

// Deny Public Endpoints for Storage Accounts
var denyStoragePublicEndpoints = '/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693'

// Deny Public Endpoints for Key Vault
var denyKeyVaultPublicEndpoints = '/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b'

// Require Private Endpoint for

// Container Registry
var requireACRPrivateEndpoint = '/providers/Microsoft.Authorization/policyDefinitions/5ee5dcca-4ac5-4b4c-b3d8-dc1fbcc2f748'

// Require NSG on Subnets
var requireNSG = '/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517'

// Require Resource Tags
var requireTags = '/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'

// ========== Subscription-Level Policy Assignments ==========

// Reference existing resource groups
resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: sharedResourceGroupName
  scope: subscription()
}

// ========== Policy 1: Deny Public Endpoints for Storage Accounts ==========
resource denyStoragePublicPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'deny-storage-public-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deny Storage Accounts with Public Endpoints'
    description: 'Prevents creation of storage accounts with public network access enabled'
    enforcementMode: 'Default'
    policyDefinitionId: denyStoragePublicEndpoints
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
    metadata: {
      environment: environmentName
      managedBy: 'Bicep'
      category: 'Security'
    }
  }
}

// ========== Policy 2: Deny Public Endpoints for Key Vault ==========
resource denyKeyVaultPublicPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'deny-keyvault-public-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deny Key Vaults with Public Endpoints'
    description: 'Prevents creation of Key Vaults accessible from public internet'
    enforcementMode: 'Default'
    policyDefinitionId: denyKeyVaultPublicEndpoints
    parameters: {}
    metadata: {
      environment: environmentName
      managedBy: 'Bicep'
      category: 'Security'
    }
  }
}

// ========== Policy 3: Require Private Endpoint for ACR ==========
resource requireACRPrivatePolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'require-acr-private-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Container Registry Should Use Private Link'
    description: 'Ensures Azure Container Registry uses private endpoints'
    enforcementMode: 'Default'
    policyDefinitionId: requireACRPrivateEndpoint
    parameters: {
      effect: {
        value: 'Audit'  // Start with Audit, change to Deny after verification
      }
    }
    metadata: {
      environment: environmentName
      managedBy: 'Bicep'
      category: 'Security'
    }
  }
}

// ========== Policy 4: Require NSG on Subnets ==========
resource requireNSGPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'require-nsg-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Subnets Should Have Network Security Group'
    description: 'Ensures all subnets have NSG attached for network security'
    enforcementMode: 'Default'
    policyDefinitionId: requireNSG
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
    notScopes: [
      '${sharedResourceGroup.id}/providers/Microsoft.Network/virtualNetworks/*/subnets/AzureBastionSubnet'
      '${sharedResourceGroup.id}/providers/Microsoft.Network/virtualNetworks/*/subnets/GatewaySubnet'
    ]
    metadata: {
      environment: environmentName
      managedBy: 'Bicep'
      category: 'Security'
    }
  }
}

// ========== Policy 5: Require Resource Tags ==========
resource requireTagsPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'require-tags-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Require Tags on Resources'
    description: 'Enforces presence of required tags for governance'
    enforcementMode: 'Default'
    policyDefinitionId: requireTags
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
    metadata: {
      environment: environmentName
      managedBy: 'Bicep'
      category: 'Governance'
    }
  }
}

// ========== Outputs ==========
output policyAssignmentIds object = {
  denyStoragePublic: denyStoragePublicPolicy.id
  denyKeyVaultPublic: denyKeyVaultPublicPolicy.id
  requireACRPrivate: requireACRPrivatePolicy.id
  requireNSG: requireNSGPolicy.id
  requireTags: requireTagsPolicy.id
}

output policyAssignmentNames object = {
  denyStoragePublic: denyStoragePublicPolicy.name
  denyKeyVaultPublic: denyKeyVaultPublicPolicy.name
  requireACRPrivate: requireACRPrivatePolicy.name
  requireNSG: requireNSGPolicy.name
  requireTags: requireTagsPolicy.name
}
