targetScope = 'subscription'

@description('Name for the custom role definition. Must be unique within the subscription.')
param roleName string = 'PostgreSQL Operator (No Stop/Start)'

@description('Human-readable description of this role')
param roleDescription string = 'Grants permissions to manage Azure Database for PostgreSQL Flexible Servers, excluding the ability to stop or start servers. Assign this role instead of Contributor to prevent accidental or unauthorised stop operations on production databases.'

@description('Assignable scopes for this role. Defaults to the current subscription.')
param assignableScopes array = [
  subscription().id
]

// Stable GUID derived from the role name so repeated deployments are idempotent
var roleDefinitionId = guid(subscription().id, roleName)

// Custom role that mirrors the standard PostgreSQL contributor permissions but explicitly
// excludes the stop and start control-plane actions.  Assigning this role to operators
// instead of Contributor removes the ability to invoke:
//   Microsoft.DBforPostgreSQL/flexibleServers/stop/action
//   Microsoft.DBforPostgreSQL/flexibleServers/start/action
// This directly addresses the remediation item to restrict who can stop production
// PostgreSQL flexible servers.
resource postgresOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionId
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    assignableScopes: assignableScopes
    permissions: [
      {
        actions: [
          // PostgreSQL Flexible Server — management operations (read, write, delete)
          'Microsoft.DBforPostgreSQL/flexibleServers/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/write'
          'Microsoft.DBforPostgreSQL/flexibleServers/delete'
          // Database, firewall, and configuration management
          'Microsoft.DBforPostgreSQL/flexibleServers/databases/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/databases/write'
          'Microsoft.DBforPostgreSQL/flexibleServers/databases/delete'
          'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/write'
          'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/delete'
          'Microsoft.DBforPostgreSQL/flexibleServers/configurations/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/configurations/write'
          // Backups, replicas, and health
          'Microsoft.DBforPostgreSQL/flexibleServers/backups/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/replicas/read'
          'Microsoft.DBforPostgreSQL/flexibleServers/checkNameAvailability/action'
          'Microsoft.DBforPostgreSQL/flexibleServers/restartServer/action'
          'Microsoft.DBforPostgreSQL/flexibleServers/updateConfigurations/action'
          // Resource metadata
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/deployments/read'
          'Microsoft.Resources/deployments/write'
          // Monitoring and diagnostics (read-only)
          'Microsoft.Insights/diagnosticSettings/read'
          'Microsoft.Insights/diagnosticSettings/write'
          'Microsoft.Insights/metricDefinitions/read'
          'Microsoft.Insights/metrics/read'
        ]
        notActions: [
          // Explicitly exclude stop and start to prevent availability incidents
          'Microsoft.DBforPostgreSQL/flexibleServers/stop/action'
          'Microsoft.DBforPostgreSQL/flexibleServers/start/action'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

output roleDefinitionId string = postgresOperatorRole.id
output roleName string = postgresOperatorRole.properties.roleName
