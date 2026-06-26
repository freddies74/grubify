// Network Security Group for an AKS subnet.
//
// Security policy:
//   - HTTPS (TCP/443) inbound from Internet is permitted.
//   - HTTP  (TCP/80)  inbound from Internet is intentionally ABSENT.
//     Port 80 must NOT be opened from the Internet source tag on AKS subnet NSGs.
//     Any HTTP->HTTPS redirect should be handled at the ingress controller layer,
//     not by allowing raw port-80 traffic through the subnet NSG.
//   - Azure Load Balancer probes are permitted (required for AKS managed LBs).
//   - All other inbound traffic is denied by the default Azure rules.

param name string
param location string = resourceGroup().location
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-https-inbound'
        properties: {
          description: 'Allow HTTPS inbound from the Internet to the AKS ingress path.'
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'allow-azure-load-balancer-inbound'
        properties: {
          description: 'Allow Azure Load Balancer health probes required by AKS managed load balancers.'
          priority: 1020
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          description: 'Explicit deny-all fallback to complement default Azure deny rule.'
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

output id string = nsg.id
output name string = nsg.name
