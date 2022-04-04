while getopts g:l: flag; do
    case "${flag}" in
    g) RG_NAME=${OPTARG} ;;
    l) LOCATION=${OPTARG} ;;
    esac
done

az deployment group create \
    --resource-group $RG_NAME \
    --name 'infra-deployment' \
    --template-file ../infra/main.bicep \
    --parameters location=$LOCATION \
    --parameters imageTag=$TAG
