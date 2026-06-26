// AKS environment infrastructure.
//
// This template is the source-of-truth for the AKS cluster and its associated
// networking. All NSG rules are declared here; changes MUST go through this
// IaC / GitOps flow — never through manual portal or CLI edits — to prevent
// the security drift described in incident 64c69c9e-bb50-a6f8-0771-92c38169f000.

targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the environment (used to generate resource names).')
param environmentName string

@minLength(1)
@description('Primary Azure region for all resources.')
param location string = resourceGroup().location

@description('CIDR block for the virtual network.')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('CIDR block for the AKS node subnet.')
param aksSubnetPrefix string = '10.1.1.0/24'

var tags = { 'azd-env-name': environmentName }
var resourceToken = uniqueString(resourceGroup().id, environmentName)
// AKS cluster names are capped at 63 characters; truncate the combined name to stay within limits.
var aksName = take('aks-${environmentName}-${resourceToken}', 63)

// ── Network Security Group (AKS subnet) ──────────────────────────────────────
// The NSG explicitly omits inbound HTTP (TCP/80) from Internet.
// See infra/core/network/nsg-aks.bicep for the full security policy rationale.
module nsg '../core/network/nsg-aks.bicep' = {
  name: 'nsg-aks'
  params: {
    name: 'nsg-aks-${resourceToken}'
    location: location
    tags: tags
  }
}

// ── Virtual Network ───────────────────────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: aksSubnetPrefix
          networkSecurityGroup: {
            id: nsg.outputs.id
          }
        }
      }
    ]
  }
}

// ── AKS Cluster ───────────────────────────────────────────────────────────────
resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: take('aks-${environmentName}', 54)
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 1
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: '${vnet.id}/subnets/aks-subnet'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output aksName string = aks.name
output aksId string = aks.id
output vnetName string = vnet.name
output nsgName string = nsg.outputs.name
output nsgId string = nsg.outputs.id
