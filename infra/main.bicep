targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicaitonInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    eventHubNamespaceName: '${abbrs.eventHubNamespaces}${resourceToken}'
    eventHubName: '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
    functionAppName: '${abbrs.webSitesFunctions}${resourceToken}'
    functionHostingPlanName: '${abbrs.webServerFarms}${resourceToken}'
    storageAccountName: '${abbrs.storageStorageAccounts}${resourceToken}'
  }
}

output STORAGE_ACCOUNT_RESOURCE_ID string = resources.outputs.storageResourceId
output STORAGE_ACCOUNT_NAME string = resources.outputs.storageAccountName
output FUNCTION_APP_NAME string = resources.outputs.functionName
output RESOURCE_GROUP_NAME string = rg.name
