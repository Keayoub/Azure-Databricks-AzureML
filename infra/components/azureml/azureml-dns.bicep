// Azure ML Private DNS Zone Module
// Creates privatelink.api.azureml.ms and links it to the VNet

param vnetId string
param tags object

resource azuremlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.api.azureml.ms'
  location: 'global'
  tags: tags
}

resource azuremlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlPrivateDnsZone
  name: 'aml-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output privateDnsZoneId string = azuremlPrivateDnsZone.id
