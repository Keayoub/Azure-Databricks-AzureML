// Azure ML Private DNS Zone Module
// Creates privatelink.api.azureml.ms (API) and privatelink.notebooks.azure.net (UI)
// Both are required for full private connectivity to Azure ML workspace

param vnetId string
param tags object

// ========== API Private DNS Zone ==========
resource azuremlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.api.azureml.ms'
  location: 'global'
  tags: tags
}

resource azuremlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlPrivateDnsZone
  name: 'aml-api-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Notebooks (UI) Private DNS Zone ==========
resource azuremlNotebooksPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.notebooks.azure.net'
  location: 'global'
  tags: tags
}

resource azuremlNotebooksDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlNotebooksPrivateDnsZone
  name: 'aml-notebooks-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output apiPrivateDnsZoneId string = azuremlPrivateDnsZone.id
output notebooksPrivateDnsZoneId string = azuremlNotebooksPrivateDnsZone.id
