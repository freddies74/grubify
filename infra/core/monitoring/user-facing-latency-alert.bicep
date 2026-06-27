param name string
param location string = resourceGroup().location
param workspaceId string
param tags object = {}

resource userFacingLatencyAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: name
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    description: 'Alerts when average user-facing API request latency exceeds 5000 ms over 5 minutes for at least 5 API requests. Excludes localhost/MSI token requests.'
    displayName: 'Grubify user-facing API slow response time'
    enabled: true
    severity: 3
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [
      workspaceId
    ]
    targetResourceTypes: [
      'microsoft.operationalinsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            AppRequests
            | extend UrlLower = tolower(tostring(Url)), NameLower = tolower(tostring(Name))
            | where NameLower contains "/api/" or UrlLower contains "/api/"
            | where not(
                UrlLower matches regex @"^https?://(localhost|127\.0\.0\.1|169\.254\.169\.254)" or
                UrlLower contains "/msi/token" or
                NameLower contains "/msi/token"
              )
            | summarize AvgDurationMs = avg(DurationMs), RequestCount = count()
            | where RequestCount >= 5
            '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'AvgDurationMs'
          operator: 'GreaterThan'
          threshold: 5000
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
