param name string
param location string = resourceGroup().location
param tags object = {}
param workspaceResourceId string

@description('Number of HTTP 5xx requests required to trigger the alert.')
param threshold int = 5

resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    description: 'Alerts on true HTTP 5xx responses for user-facing endpoints and excludes known scanner noise.'
    displayName: name
    enabled: true
    severity: 2
    autoMitigate: true
    scopes: [
      workspaceResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            AppRequests
            | where TimeGenerated >= ago(5m)
            | extend StatusCode = toint(ResultCode)
            | where StatusCode >= 500 and StatusCode < 600
            | where Url has '/api/' or Url has '/health' or Url has '/livez'
            | where not(Url has '/vendor/phpunit' or Url has 'pearcmd' or Url has '/hello.world')
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: threshold
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: []
    }
  }
}
