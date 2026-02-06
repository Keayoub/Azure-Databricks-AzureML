// Networking module - VNet, subnets, NSGs, and network security
// This module creates a secure network architecture with:
// - VNet with multiple subnets for different services
// - Network Security Groups with appropriate rules
// - Service endpoints and delegation for Databricks
// - Subnets for Azure ML, AKS, and private endpoints

param location string
param projectName string
param environmentName string
param tags object
param deployAKS bool
param deployAPIM bool = false
param deployBastion bool = false

// Network Address Space Configuration
@description('VNet address space (CIDR block)')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Databricks public subnet address prefix')
param databricksPublicSubnetPrefix string = '10.0.1.0/24'

@description('Databricks private subnet address prefix')
param databricksPrivateSubnetPrefix string = '10.0.2.0/24'

@description('Azure ML compute subnet address prefix')
param azureMLComputeSubnetPrefix string = '10.0.3.0/24'

@description('AKS subnet address prefix (minimum /23)')
param aksSubnetPrefix string = '10.0.4.0/23'

@description('ACA infrastructure subnet address prefix (minimum /23)')
param acaInfrastructureSubnetPrefix string = '10.0.6.0/23'

@description('Private endpoints subnet address prefix')
param privateEndpointSubnetPrefix string = '10.0.8.0/24'

@description('API Management subnet address prefix')
param apimSubnetPrefix string = '10.0.9.0/24'

@description('Azure Bastion subnet address prefix')
param bastionSubnetPrefix string = '10.0.10.0/27'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetPrefix string = '10.0.11.0/27'

// VNet configuration
var vnetName = 'vnet-${environmentName}-${projectName}'

// Subnet configurations
var databricksPublicSubnetName = 'snet-databricks-public'

var databricksPrivateSubnetName = 'snet-databricks-private'

var azureMLComputeSubnetName = 'snet-azureml-compute'

var aksSubnetName = 'snet-aks'

var acaInfrastructureSubnetName = 'snet-aca-infrastructure'

var privateEndpointSubnetName = 'snet-private-endpoints'

var apimSubnetName = 'snet-apim'

var bastionSubnetName = 'AzureBastionSubnet' // Must be exactly this name

var jumpboxSubnetName = 'snet-jumpbox'

// ========== Network Security Groups ==========

// NSG for Databricks Public Subnet
resource databricksPublicNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-${databricksPublicSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDatabricksControlPlane'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureDatabricks'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowDatabricksOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureDatabricks'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowSqlOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Sql'
          destinationPortRange: '3306'
        }
      }
      {
        name: 'AllowStorageOutbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Storage'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowVnetOutbound'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowEventHubOutbound'
        properties: {
          priority: 140
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'EventHub'
          destinationPortRange: '9093'
        }
      }
    ]
  }
}

// NSG for Databricks Private Subnet
resource databricksPrivateNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-${databricksPrivateSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDatabricksControlPlane'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureDatabricks'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowDatabricksOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureDatabricks'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowSqlOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Sql'
          destinationPortRange: '3306'
        }
      }
      {
        name: 'AllowStorageOutbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Storage'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowVnetOutbound'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowEventHubOutbound'
        properties: {
          priority: 140
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'EventHub'
          destinationPortRange: '9093'
        }
      }
    ]
  }
}

// NSG for Azure ML Compute Subnet
resource azureMLComputeNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-${azureMLComputeSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBatchNodeManagement'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'BatchNodeManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '29876-29877'
        }
      }
      {
        name: 'AllowAzureMachineLearning'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureMachineLearning'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '44224'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for AKS Subnet
resource aksNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = if (deployAKS) {
  name: 'nsg-${aksSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for Private Endpoints Subnet
resource privateEndpointNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-${privateEndpointSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for ACA Infrastructure Subnet
resource acaInfrastructureNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-${acaInfrastructureSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAnyHTTPSInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// NSG for APIM Subnet
resource apimNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = if (deployAPIM) {
  name: 'nsg-${apimSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowClientCommunicationToAPIM'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowManagementEndpointForPortal'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '6390'
        }
      }
    ]
  }
}

// NSG for Jumpbox Subnet
resource jumpboxNSG 'Microsoft.Network/networkSecurityGroups@2024-01-01' = if (deployBastion) {
  name: 'nsg-${jumpboxSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBastionInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['3389', '22']
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ========== Virtual Network ==========
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: databricksPublicSubnetName
        properties: {
          addressPrefix: databricksPublicSubnetPrefix
          networkSecurityGroup: {
            id: databricksPublicNSG.id
          }
          delegations: [
            {
              name: 'databricks-delegation-public'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: databricksPrivateSubnetName
        properties: {
          addressPrefix: databricksPrivateSubnetPrefix
          networkSecurityGroup: {
            id: databricksPrivateNSG.id
          }
          delegations: [
            {
              name: 'databricks-delegation-private'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: azureMLComputeSubnetName
        properties: {
          addressPrefix: azureMLComputeSubnetPrefix
          networkSecurityGroup: {
            id: azureMLComputeNSG.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
          networkSecurityGroup: deployAKS ? {
            id: aksNSG.id
          } : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointNSG.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: acaInfrastructureSubnetName
        properties: {
          addressPrefix: acaInfrastructureSubnetPrefix
          networkSecurityGroup: {
            id: acaInfrastructureNSG.id
          }
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: deployAPIM ? apimNSG.id : privateEndpointNSG.id // Fallback to PE NSG if APIM not deployed
          }
          serviceEndpoints: deployAPIM ? [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.Sql'
            }
          ] : []
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
          // Bastion subnet doesn't use NSG
        }
      }
      {
        name: jumpboxSubnetName
        properties: {
          addressPrefix: jumpboxSubnetPrefix
          networkSecurityGroup: deployBastion ? {
            id: jumpboxNSG.id
          } : null
        }
      }
    ]
  }
}

// ========== Outputs ==========
output vnetId string = vnet.id
output vnetName string = vnet.name
output databricksPublicSubnetName string = databricksPublicSubnetName
output databricksPrivateSubnetName string = databricksPrivateSubnetName
output azureMLComputeSubnetId string = '${vnet.id}/subnets/${azureMLComputeSubnetName}'
output aksSubnetId string = '${vnet.id}/subnets/${aksSubnetName}'
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'
output acaInfrastructureSubnetId string = '${vnet.id}/subnets/${acaInfrastructureSubnetName}'
output apimSubnetId string = '${vnet.id}/subnets/${apimSubnetName}'
output bastionSubnetId string = deployBastion ? '${vnet.id}/subnets/${bastionSubnetName}' : ''
output jumpboxSubnetId string = deployBastion ? '${vnet.id}/subnets/${jumpboxSubnetName}' : ''
