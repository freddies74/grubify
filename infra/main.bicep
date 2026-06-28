targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the resource group')
param resourceGroupName string = ''

@description('API container image')
param apiImage string = ''

@description('Frontend container image')
param frontendImage string = ''

@description('PostgreSQL administrator login name')
param postgresAdminLogin string = 'grubifyadmin'

@description('PostgreSQL administrator login password')
@secure()
param postgresAdminPassword string = ''

@description('Email address to receive PostgreSQL stop alert notifications')
param alertEmailAddress string = ''

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = 'grubify'  // Fixed naming instead of random string
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : 'rg-grubify-app'
  location: location
  tags: tags
}

// Container registry
module containerRegistry 'core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container Apps Environment
module containerAppsEnvironment 'core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container app for the API
module api 'core/host/container-app.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: 'ca-grubify-api'
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    containerName: 'grubify-api'
    containerImage: !empty(apiImage) ? apiImage : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    targetPort: 8080
    external: true
    minReplicas: 1  // Always keep 1 instance running
    maxReplicas: 1  // No autoscaling - single instance only
    env: [
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Production'
      }
      {
        name: 'AllowedOrigins__0'
        value: 'https://ca-grubify-frontend.${containerAppsEnvironment.outputs.defaultDomain}'
      }
    ]
  }
}

// Container app for the frontend
module frontend 'core/host/container-app.bicep' = {
  name: 'frontend'
  scope: rg
  params: {
    name: 'ca-grubify-frontend'
    location: location
    tags: union(tags, { 'azd-service-name': 'frontend' })
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    containerName: 'grubify-frontend'
    containerImage: !empty(frontendImage) ? frontendImage : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    targetPort: 80
    external: true
    minReplicas: 1  // Always keep 1 instance running
    maxReplicas: 1  // No autoscaling - single instance only
    env: [
      {
        name: 'REACT_APP_API_BASE_URL'
        value: 'https://${api.outputs.fqdn}/api'
      }
    ]
  }
}

// PostgreSQL flexible server
module postgresServer 'core/database/postgres-flexible-server.bicep' = if (!empty(postgresAdminPassword)) {
  name: 'postgres-server'
  scope: rg
  params: {
    name: '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    location: location
    tags: tags
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
  }
}

// Custom RBAC role: PostgreSQL Operator (No Stop/Start)
// Assign this role to operators/service principals instead of Contributor to prevent
// accidental or unauthorised stop operations on production PostgreSQL servers.
module postgresOperatorRole 'core/security/postgres-operator-role.bicep' = {
  name: 'postgres-operator-role'
}

// Activity Log Alert: fires when any PostgreSQL flexible server in the subscription
// is stopped via the control-plane stop/action operation.
// The alert payload includes caller identity, correlationId, resourceId, and
// eventTimestamp so on-call engineers can triage without additional portal queries.
module postgresStopAlert 'core/security/postgres-stop-alert.bicep' = {
  name: 'postgres-stop-alert'
  scope: rg
  params: {
    name: 'postgres-server-stopped'
    targetResourceGroupName: rg.name
    alertEmailAddress: alertEmailAddress
    tags: tags
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output RESOURCE_GROUP_ID string = rg.id

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name

output API_BASE_URL string = 'https://${api.outputs.fqdn}'
output FRONTEND_URL string = 'https://${frontend.outputs.fqdn}'

output POSTGRES_OPERATOR_ROLE_ID string = postgresOperatorRole.outputs.roleDefinitionId
