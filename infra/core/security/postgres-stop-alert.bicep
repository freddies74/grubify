@description('Name for the Activity Log Alert rule')
param name string

@description('Location for the Activity Log Alert (must be global)')
param location string = 'global'

param tags object = {}

@description('Human-readable description for this alert rule')
param alertDescription string = 'Fires when a PostgreSQL Flexible Server stop/action is initiated. Review caller identity, correlationId, and Resource Health cause to determine whether the stop was authorised.'

@description('Resource group name containing the PostgreSQL server(s) to monitor. Leave empty to monitor all resource groups in the subscription.')
param targetResourceGroupName string = ''

@description('Action group resource ID to notify when the alert fires. Required for email/webhook notification.')
param actionGroupId string = ''

@description('Email address to receive alert notifications when no action group is provided')
param alertEmailAddress string = ''

// Action group created inline when an email address is provided but no external action group ID is given
resource inlineActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (empty(actionGroupId) && !empty(alertEmailAddress)) {
  name: '${name}-ag'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    groupShortName: 'pg-stop'
    emailReceivers: [
      {
        name: 'alert-email'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

var resolvedActionGroupId = !empty(actionGroupId)
  ? actionGroupId
  : ((!empty(alertEmailAddress)) ? inlineActionGroup.id : '')

// Scope conditions: optionally narrow alert to a specific resource group
var scopeConditions = !empty(targetResourceGroupName)
  ? [
      {
        field: 'category'
        equals: 'Administrative'
      }
      {
        field: 'operationName'
        equals: 'Microsoft.DBforPostgreSQL/flexibleServers/stop/action'
      }
      {
        field: 'resourceType'
        equals: 'microsoft.dbforpostgresql/flexibleservers'
      }
      {
        field: 'resourceGroup'
        equals: targetResourceGroupName
      }
    ]
  : [
      {
        field: 'category'
        equals: 'Administrative'
      }
      {
        field: 'operationName'
        equals: 'Microsoft.DBforPostgreSQL/flexibleServers/stop/action'
      }
      {
        field: 'resourceType'
        equals: 'microsoft.dbforpostgresql/flexibleservers'
      }
    ]

// Activity Log Alert that fires on PostgreSQL flexible server stop operations.
// The alert payload automatically includes the Activity Log event fields:
//   - caller         — identity (UPN or service principal) that initiated the stop
//   - correlationId  — correlation ID for cross-resource tracing
//   - eventTimestamp — UTC timestamp of the stop operation
//   - resourceId     — full ARM resource ID of the stopped server
//   - status         — Succeeded / Failed / Started
// These fields surface the actor, timing, and tracing context needed to triage the incident
// without manual Activity Log queries.
resource postgresStopAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enabled: true
    description: alertDescription
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: scopeConditions
    }
    actions: {
      actionGroups: !empty(resolvedActionGroupId)
        ? [
            {
              actionGroupId: resolvedActionGroupId
              // Webhook properties surface key enrichment fields in the alert payload so
              // that runbooks and on-call tooling can immediately identify:
              //   who performed the stop (caller), the cross-service trace handle
              //   (correlationId), and the affected resource — without opening the
              //   Azure portal or running Activity Log queries manually.
              webhookProperties: {
                incidentSummary: 'PostgreSQL flexible server stop operation detected'
                fieldsToReview: 'caller | correlationId | resourceId | eventTimestamp | status'
                runbookNote: 'Check Activity Log caller and correlationId. Verify Resource Health cause (UserInitiated vs PlatformInitiated). Restart server if stop was unintended.'
              }
            }
          ]
        : []
    }
  }
}

output id string = postgresStopAlert.id
output name string = postgresStopAlert.name
