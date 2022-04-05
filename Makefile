RG_NAME := 'container-app-dapr-1-rg'
LOCATION := 'canadacentral'
ENVIRONMENT := dev
VERSION := 0.1.0
TAG := ${ENVIRONMENT}-${VERSION}

build:
	# deploy acr
	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'acr-deployment' \
		--parameters anonymousPullEnabled=true \
		--template-file ./infra/modules/acr.bicep

	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${TAG} --build-arg SERVICE_NAME="frontend"  -f Dockerfile .
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${TAG} --build-arg SERVICE_NAME="backend"  -f Dockerfile .

deploy:
	az group create --location ${LOCATION} --name ${RG_NAME}

	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'infra-deployment' \
		--template-file ./infra/main.bicep \
		--parameters imageTag=${TAG} \
		--parameters acrName=$(shell az deployment group show --resource-group ${RG_NAME} --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)

build_local:
	docker build -t frontend:${TAG} --build-arg SERVICE_NAME="frontend" .
	docker build -t backend:${TAG} --build-arg SERVICE_NAME="backend" .

test:
	curl "$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.frontendFqdn.value -o tsv)/checkin" -d '{"user_id":"123","location_id":"5"}'

test_local:
	curl http://localhost:8080/checkin -d '{"user_id":"123","location_id":"5"}'