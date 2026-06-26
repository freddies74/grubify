param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string
param containerName string
param containerImage string
param targetPort int = 80
param external bool = false
param cpu string = '0.5'
param memory string = '1.0Gi'
param minReplicas int = 1
param maxReplicas int = 3
param env array = []
param activeRevisionsMode string = 'Single'

// Workload identity support: provide the Container Apps environment OIDC issuer URL
// to enable federated credentials for this app's managed identity.
// Prevents the empty-federated-credential state that can cause authentication failures.
@description('OIDC issuer URL of the Container Apps environment. When non-empty, a federated identity credential is created for workload identity.')
param containerAppsEnvironmentOidcIssuer string = ''

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-identity'
  location: location
  tags: {
    'azd-env-name': tags['azd-env-name']
  }
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userIdentity.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d'))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: userIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Federated identity credential so the workload can exchange tokens with the Container Apps
// OIDC endpoint. This prevents the empty-federated-credential state that would otherwise
// cause authentication failures when the workload identity path is used.
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (!empty(containerAppsEnvironmentOidcIssuer)) {
  parent: userIdentity
  name: 'containerapp-fedcred'
  properties: {
    audiences: ['api://AzureADTokenExchange']
    issuer: containerAppsEnvironmentOidcIssuer
    subject: name
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: activeRevisionsMode
      ingress: {
        external: external
        targetPort: targetPort
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['*']
          allowedHeaders: ['*']
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: containerImage
          name: containerName
          env: env
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
  dependsOn: [
    acrPullRole
  ]
}

output id string = containerApp.id
output name string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output uri string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
