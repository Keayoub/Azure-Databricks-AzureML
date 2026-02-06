// Azure Bastion Module
// Provides secure RDP/SSH access to VMs without public IPs
// Deployed in a dedicated AzureBastionSubnet

param location string
param projectName string
param environmentName string
param bastionSubnetId string
param tags object

@description('Bastion SKU (Basic or Standard)')
@allowed(['Basic', 'Standard'])
param bastionSku string = 'Basic'

var bastionName = 'bastion-${environmentName}-${projectName}'
var bastionPublicIpName = 'pip-${bastionName}'

// ========== Public IP for Bastion ==========
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: bastionPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

// ========== Azure Bastion ==========
resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
    // Standard SKU features (Basic SKU doesn't support these)
    enableTunneling: bastionSku == 'Standard'
    enableIpConnect: bastionSku == 'Standard'
    enableShareableLink: false
  }
}

// ========== Outputs ==========
output bastionId string = bastion.id
output bastionName string = bastion.name
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
