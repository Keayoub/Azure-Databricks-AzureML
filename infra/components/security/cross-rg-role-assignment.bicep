// Module for cross-resource group role assignments
// Deployed at resource group scope via metadata
targetScope = 'resourceGroup'

param principalId string
@description('The principal type: User, Group, ServicePrincipal, etc.')
param principalType string = 'ServicePrincipal'
param roleDefinitionId string

// Deploy at resource group scope to enable role assignments
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, roleDefinitionId, subscription().subscriptionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
