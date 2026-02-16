// Azure ML Private DNS Zone Module
// Creates all 5 required private DNS zones for full AzureML private connectivity:
// 1. privatelink.api.azureml.ms - API & workspace management
// 2. privatelink.notebooks.azure.net - Studio UI
// 3. privatelink.instances.azureml.ms - Compute instances
// 4. privatelink.aznbcontent.net - Notebook content
// 5. privatelink.inference.ml.azure.com - Managed online endpoints
// Reference: https://learn.microsoft.com/azure/private-link/private-endpoint-dns

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

// ========== Instances Private DNS Zone ==========
resource azuremlInstancesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.instances.azureml.ms'
  location: 'global'
  tags: tags
}

resource azuremlInstancesDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlInstancesPrivateDnsZone
  name: 'aml-instances-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Notebook Content Private DNS Zone ==========
resource azuremlContentPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.aznbcontent.net'
  location: 'global'
  tags: tags
}

resource azuremlContentDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlContentPrivateDnsZone
  name: 'aml-content-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Managed Online Endpoints (Inference) Private DNS Zone ==========
resource azuremlInferencePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.inference.ml.azure.com'
  location: 'global'
  tags: tags
}

resource azuremlInferenceDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: azuremlInferencePrivateDnsZone
  name: 'aml-inference-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Outputs ==========
output apiPrivateDnsZoneId string = azuremlPrivateDnsZone.id
output notebooksPrivateDnsZoneId string = azuremlNotebooksPrivateDnsZone.id
output instancesPrivateDnsZoneId string = azuremlInstancesPrivateDnsZone.id
output contentPrivateDnsZoneId string = azuremlContentPrivateDnsZone.id
output inferencePrivateDnsZoneId string = azuremlInferencePrivateDnsZone.id
