// Shared Private DNS Zone for Key Vault
// This module creates the central DNS zone to avoid duplication when multiple Key Vaults reference it

param location string = 'global'
param vnetId string
param tags object

// ========== Private DNS Zone ==========
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: location
  tags: tags
}

// ========== Private DNS Zone Link ==========
resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'kv-dns-link'
  location: location
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Outputs ==========
output dnsZoneId string = keyVaultPrivateDnsZone.id
output dnsZoneName string = keyVaultPrivateDnsZone.name
