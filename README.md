# container-apps
Simple container application for the Azure container apps platform

## Prerequisites
  - Docker / Docker Desktop
  - Bash Shell (Linux or WSL 2)
  - Azure CLI
  - make

## Azure deployment
The bicep template deployment creates the following Azure resources
- 1 x CosmosDB account, SQL database & container
- 1 x Azure Servicebus namespace & topic
- 1 x Azure Container Registry
- 1 x Azure Container App environment
- 2 x Azure Container Apps

### clone the repo
- `$ git clone git@github.com:cbellee/container-apps.git`
### deploy the infrastructure 
  - `$ make deploy`
### build & push the container images
  - `& make build_and_push`

### test the api
- `$ make test_api`

## local deployment with Azure backend
### install dapr
- `$ make deploy && make build_local && make run_local`

### test the api
- `$ make test_api_local`
