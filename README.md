# azure-container-app
Simple container application for the Azure container apps platform

## Prerequisites
  - Bash Shell (Linux or WSL 2)
  - Azure CLI
  - make
  - Docker / Docker Desktop (only required for local dapr environment)

## Azure deployment
The bicep template deployment creates the following Azure resources
- 1 x CosmosDB account, SQL database & container
- 1 x Azure Servicebus namespace & topic
- 1 x Azure Container Registry
- 1 x Azure Container App environment
- 2 x Azure Container Apps

Clone the repo
- `$ git clone git@github.com:cbellee/container-apps.git`

Build & push the container images
  - `$ make deploy_rg && make build`

Deploy the infrastructure 
  - `& make deploy`

Test API
- `$ make test`

## Local dapr deployment with Azure backend 
Add new file ./components/secrets.json with following contents (replace asterix with secrets)
```
{
    "servicebus": {
        "connectionString": "Endpoint=sb://*.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=*"
    },
    "cosmosdb": {
        "connectionString": "https://*.documents.azure.com:443/",
        "key": "***"
    }
}
```
- `$ make build_local && make deploy_local`

Test local API 
- `$ make test_local`