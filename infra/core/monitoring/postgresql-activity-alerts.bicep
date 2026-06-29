@description('Tags to apply to resources')
param tags object = {}

@description('Email address to notify when a PostgreSQL stop or start action is detected')
param alertEmailAddress string

@description('Name prefix for alert resources')
param resourceToken string

// Action group that emails the on-call address when a PostgreSQL control-plane alert fires
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-postgresql-alerts-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'pg-alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'on-call-email'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// Activity Log alert: fires when a PostgreSQL flexible server stop action succeeds
// NOTE: This resource is deployed in the application resource group but the alert
// scope is set to subscription().id so it monitors ALL PostgreSQL flexible servers
// across the subscription, not only those in this resource group.
resource stopAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-postgresql-stop-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Fires when a PostgreSQL flexible server stop/action is accepted on the subscription. Pages on-call immediately with actor identity.'
    enabled: true
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.DBforPostgreSQL/flexibleServers/stop/action'
        }
        {
          field: 'status'
          containsAny: [
            'Accepted'
            'Succeeded'
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

// Activity Log alert: fires when a PostgreSQL flexible server start action succeeds
// NOTE: This resource is deployed in the application resource group but the alert
// scope is set to subscription().id so it monitors ALL PostgreSQL flexible servers
// across the subscription, not only those in this resource group.
resource startAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-postgresql-start-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Fires when a PostgreSQL flexible server start/action is accepted on the subscription. Used to correlate recovery events with prior stop incidents.'
    enabled: true
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.DBforPostgreSQL/flexibleServers/start/action'
        }
        {
          field: 'status'
          containsAny: [
            'Accepted'
            'Succeeded'
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

output actionGroupId string = actionGroup.id
output stopAlertId string = stopAlert.id
output startAlertId string = startAlert.id
