#!/bin/bash

while getopts "g:s:c:a:i:t:" opt; do
    case $opt in
        g) GROUP_NAME="$OPTARG";;
        s) SERVICE_PRINCIPAL_NAME="$OPTARG";;
        c) ACR_NAME="$OPTARG";;
        a) APP_NAME="$OPTARG";;
        i) APP_IMAGE="$OPTARG";;
        t) TAG="$OPTARG";;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1;; 
    esac
done

if [ -z "$GROUP_NAME" ] || [ -z "$SERVICE_PRINCIPAL_NAME" ] || [ -z "$ACR_NAME" ] || [ -z "$APP_NAME" ] || [ -z "$APP_IMAGE" ] || [ -z "$TAG" ]; then
    echo "Error: You must provide arguments for the -g, -s, -c, -a, -i and -t options."
    exit 1
fi

for i in $(az group list --output tsv | awk '{print $4}')
do
    if [ "$GROUP_NAME" == "$i" ]; then
        echo "$GROUP_NAME al ready exists."
        GROUP_EXISTS="yes" 
    fi
done

if [ "$GROUP_EXISTS" != "yes" ]; then
    echo "creating group $GROUP_NAME..."
    az group create --name "$GROUP_NAME" --location eastus
fi

echo "creating container registry..."
az acr create --resource-group "$GROUP_NAME" --name "$ACR_NAME" --sku Basic --admin-enabled true

echo "logging into the container registry..."
az acr login --name "$ACR_NAME"

echo "getting acr registry id.."
ACR_REGISTRY_ID=$(az acr show --name "$ACR_NAME" --query "id" --output tsv)

echo "getting username..."
USER_NAME=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query "[].appId" --output tsv)

echo "getting password..."
PASSWORD=$(az ad sp create-for-rbac --name "$SERVICE_PRINCIPAL_NAME" --scopes "$ACR_REGISTRY_ID" --role acrpull --query "password" --output tsv)

echo "building image..."
docker build -t "$APP_IMAGE":"$TAG" .

echo "uploading tag to container registry..."
docker tag "$APP_IMAGE":"$TAG" "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG"

echo "container list: "
docker images

echo "uploading image to container registry..."
docker push "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG"

echo "getting repository list from container registry..."
az acr repository list --name "$ACR_NAME" --output table

echo "creating instance..."
az container create --resource-group "$GROUP_NAME" --name "$APP_NAME" --image "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG" --cpu 1 --memory 1 --registry-login-server "$ACR_NAME".azurecr.io --registry-username "$USER_NAME" --registry-password "$PASSWORD" --ip-address Public --dns-name-label dns-um-"$RANDOM" --ports 5000

echo "done."
