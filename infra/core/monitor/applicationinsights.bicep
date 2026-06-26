param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceId string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Query-based latency alert scoped to user-facing API requests only.
// Excludes internal localhost MSI/token calls to prevent false-positive alerts
// (see incident: MSI token request at ~5 s triggered the static metric threshold).
resource apiLatencyAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: '${name}-api-latency'
  location: location
  tags: tags
  properties: {
    description: 'Alerts when average latency of user-facing API requests exceeds 5 seconds. Internal MSI token and localhost calls are excluded to avoid false positives.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [applicationInsights.id]
    criteria: {
      allOf: [
        {
          query: '''AppRequests
| where Url !contains "localhost"
    and Url !contains "/msi/token"
    and Url !contains "/metadata/"
| summarize AvgDurationMs = avg(DurationMs) by bin(TimeGenerated, 5m)
| where AvgDurationMs > 5000'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
  }
}

output id string = applicationInsights.id
output name string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
