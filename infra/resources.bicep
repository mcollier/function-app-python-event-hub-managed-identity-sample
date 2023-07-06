// param name string
param location string = resourceGroup().location
param tags object = {}

param logAnalyticsWorkspaceName string
param applicaitonInsightsName string
param storageAccountName string
param functionHostingPlanName string
param functionAppName string
param eventHubNamespaceName string
param eventHubName string

@description('This is the built-in role definition for the Key Vault Secret User role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user for more information.')
resource keyVaultSecretUserRoleDefintion 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

@description('This is the built-in role definition for the Azure Event Hubs Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver for more information.')
resource eventHubDataReceiverUserRoleDefintion 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
}

resource eventHubDataSenderUserRoleDefintion 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '2b629674-e913-4c01-ae53-ef4638d8f975'
}

@description('This is the built-in role definition for the Azure Storage Blob Data Owner role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-owner for more information.')
resource storageBlobDataOwnerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicaitonInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }

  resource deploymentContainer 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: 'deployment'
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: functionHostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: union(tags, { 'azd-service-name': 'myapp' })
  properties: {
    reserved: true
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsight.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        // {
        //   name: 'WEBSITE_RUN_FROM_PACKAGE'
        //   value: packageUri
        // }
        {
          name: 'EventHubConnection__fullyQualifiedNamespace'
          value: '${eventHubNamespace.name}.servicebus.windows.net'
        }
        {
          // Used for Python v2 (https://learn.microsoft.com/en-us/azure/azure-functions/create-first-function-cli-python?tabs=azure-cli%2Cbash&pivots=python-mode-decorators#update-app-settings)
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
        {
          name: 'EventHubName'
          value: eventHubNamespace::eventHub.name
        }
      ]
    }
  }

  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {}

  resource eventHub 'eventhubs' = {
    name: eventHubName
    properties: {}
  }
}

module storageRoleAssignment 'role.bicep' = {
  name: 'storageFunctionRoleAssignment'
  params: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: storageBlobDataOwnerRoleDefinition.name
  }
}

module eventHubDataReceiverRoleAssignment 'role.bicep' = {
  name: 'eventHubDataReceiverRoleAssignment'
  params: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: eventHubDataReceiverUserRoleDefintion.name
  }
}

module keyVaultSecretUserRoleAssignment 'role.bicep' = {
  name: 'keyVaultSecretUserRoleAssignment'
  params: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: keyVaultSecretUserRoleDefintion.name
  }
}

module eventHubDataSenderUserRoleAssignment 'role.bicep' = {
  name: 'eventHubDataSenderUserRoleAssignment'
  params: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: eventHubDataSenderUserRoleDefintion.name
  }
}

output functionUrl string = functionApp.properties.defaultHostName
output functionName string = functionApp.name
output storageAccountName string = storageAccount.name
output storageResourceId string = storageAccount.id
