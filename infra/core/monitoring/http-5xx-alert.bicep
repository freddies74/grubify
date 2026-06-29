param name string
param location string
param tags object = {}
param workspaceResourceId string
param enabled bool = true
@minValue(0)
@maxValue(4)
param severity int = 2
param evaluationFrequency string = 'PT1M'
param windowSize string = 'PT5M'
@minValue(1)
param min5xxCount int = 5
@minValue(1)
param minRequestVolume int = 100
@minValue(1)
@maxValue(100)
param minErrorRatePercent int = 5

var http5xxAlertQuery = format('let MinRequests = {0};\nlet MinErrorRate = todouble({1}) / 100.0;\nunion isfuzzy=true\n(\n    AppRequests\n    | project resultCode = tostring(ResultCode)\n),\n(\n    requests\n    | project resultCode = tostring(resultCode)\n)\n| summarize TotalRequests = count(), FiveXxCount = countif(resultCode startswith "5")\n| extend ErrorRate = iif(TotalRequests == 0, 0.0, todouble(FiveXxCount) / todouble(TotalRequests))\n| where FiveXxCount >= {2}\n| where TotalRequests >= MinRequests\n| where ErrorRate >= MinErrorRate\n| project AlertHit = 1', minRequestVolume, minErrorRatePercent, min5xxCount)

resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    description: 'Triggers only on true HTTP 5xx signals with request-volume and error-rate guardrails.'
    displayName: name
    enabled: enabled
    severity: severity
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: http5xxAlertQuery
          timeAggregation: 'Count'
          metricMeasureColumn: 'AlertHit'
          operator: 'GreaterThanOrEqual'
          threshold: 1
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
