param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceId string

var http5xxAlertName = '${name}-http-5xx-errors'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: http5xxAlertName
  location: location
  tags: tags
  properties: {
    description: 'Triggers only on true HTTP 5xx request telemetry so 404 secret-scan probes do not page as server errors.'
    displayName: 'Grubify HTTP 5xx Errors'
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    severity: 2
    scopes: [
      applicationInsights.id
    ]
    criteria: {
      allOf: [
        {
          query: 'requests | where toint(resultCode) between (500 .. 599)'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    targetResourceTypes: [
      'microsoft.insights/components'
    ]
  }
}

output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output http5xxAlertName string = http5xxAlert.name
