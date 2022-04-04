param acrName string 
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: acrName
  location: resourceGroup().location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: true
  }
}

output registryName string = acr.name
output registryLoginServer string = acr.properties.loginServer
output registryPassword string = listCredentials(acr.id, '2020-11-01-preview').passwords[0].value
output registryResourceId string = acr.id
