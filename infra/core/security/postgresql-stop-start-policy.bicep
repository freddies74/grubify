targetScope = 'subscription'

@description('Environment name used to scope the policy assignment and RBAC role assignable scopes.')
param environmentName string

@description('Policy effect applied to the PostgreSQL Flexible Server governance policy. Deny blocks new servers missing the required tag; Audit only logs; Disabled turns the policy off.')
@allowed([
  'Deny'
  'Audit'
  'Disabled'
])
param policyEffect string = 'Audit'

// ---------------------------------------------------------------------------
// Custom RBAC role – PostgreSQL Flexible Server Operator (no stop/start)
//
// Assigns full read/write access to PostgreSQL Flexible Servers while
// explicitly excluding the stop and start control-plane actions.  Assign
// this role to production operators instead of Contributor to prevent
// accidental or unauthorised database downtime.
//
// Defense-in-depth approach: RBAC is the enforcement layer; the Activity Log
// alerts in postgresql-activity-alerts.bicep are the detection layer.
// ---------------------------------------------------------------------------
resource postgresqlOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'postgresql-flexible-server-operator-no-stop-start')
  properties: {
    roleName: 'PostgreSQL Flexible Server Operator (no stop/start) - ${environmentName}'
    description: 'Provides management access to Azure Database for PostgreSQL Flexible Servers but explicitly removes the stop and start actions to prevent user-initiated downtime. Assign to production operators instead of Contributor.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.DBforPostgreSQL/flexibleServers/*'
          'Microsoft.DBforPostgreSQL/locations/*'
          'Microsoft.DBforPostgreSQL/operations/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: [
          // Explicitly block the two control-plane actions that caused the
          // 2026-06-29 Zava incident (postgres-server-down Sev1).
          'Microsoft.DBforPostgreSQL/flexibleServers/stop/action'
          'Microsoft.DBforPostgreSQL/flexibleServers/start/action'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Policy – audit PostgreSQL Flexible Server stop/start governance
//
// Audits (or denies) the existence of PostgreSQL Flexible Servers that have
// not been tagged with an owner, making them discoverable for access review.
// Set policyEffect = 'Deny' to enforce tagging at resource creation time.
// ---------------------------------------------------------------------------
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'audit-postgresql-flexible-server-owner-tag'
  properties: {
    displayName: 'PostgreSQL Flexible Servers must have an owner tag'
    description: 'Ensures every PostgreSQL Flexible Server carries an owner tag so that access-review processes can identify who authorised the resource and contact them when control-plane events like stop/start occur.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'SQL'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Deny blocks resources missing the tag; Audit logs them; Disabled turns the policy off.'
        }
        allowedValues: [
          'Deny'
          'Audit'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.DBforPostgreSQL/flexibleServers'
          }
          {
            field: 'tags[\'owner\']'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'pa-psql-owner-tag-${take(environmentName, 37)}'
  properties: {
    displayName: 'PostgreSQL owner tag - ${environmentName}'
    description: 'Blocks or audits PostgreSQL Flexible Servers without an owner tag in the ${environmentName} environment.'
    policyDefinitionId: policyDefinition.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: policyEffect
      }
    }
  }
}

output postgresqlOperatorRoleId string = postgresqlOperatorRole.id
output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.id
