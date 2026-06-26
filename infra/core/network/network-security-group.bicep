param name string
param location string = resourceGroup().location
param tags object = {}

@description('Security rules to apply to the NSG. No broad inbound management-port rules (RDP/SSH from source=*) are permitted.')
param securityRules array = []

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

output id string = nsg.id
output name string = nsg.name
