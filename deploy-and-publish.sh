#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! -f "$script_dir/.env" ]]; then
	echo "Please create a .env file (using sample.env as a starter)" 1>&2
	exit 1
fi
source "$script_dir/.env"

LOCATION=${LOCATION:-eastus}
STORAGE_CONTAINER_NAME="deployment"

# Check that required values are set
if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
	echo 'RESOURCE_GROUP_NAME not set - ensure you have specifed a value for it in your .env file' 1>&2
	exit 6
fi
if [[ -z "$LINUX_FX_VERSION" ]]; then
	echo 'LINUX_FX_VERSION not set - ensure you have specifed a value for it in your .env file' 1>&2
	exit 6
fi
if [[ -z "$EVENT_HUB_NAME" ]]; then
	echo 'EVENT_HUB_NAME not set - ensure you have specifed a value for it in your .env file' 1>&2
	exit 6
fi


az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

cat << EOF > "$script_dir/main.parameters.json"
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "linuxFxVersion": {
      "value": "${LINUX_FX_VERSION}"
    },
    "eventHubName":{
        "value": "${EVENT_HUB_NAME}"
    },
    "packageUri": {
        "value": ""
    }
  }
}
EOF

echo -e "\n== Deploying main resources to $RESOURCE_GROUP_NAME in $LOCATION"

# Create a datetime stamp in the format of 'Year-Month-Day_Hour:Minute:Second'
DATETIME_STAMP=$(date '+%Y%m%d%H%M%S')

# Print the datetime stamp
# echo $DATETIME_STAMP

az deployment group create \
	--resource-group $RESOURCE_GROUP_NAME \
	--name "func-deployment$DATETIME_STAMP" \
	--template-file "$script_dir/main.bicep" \
	--parameters "@$script_dir/main.parameters.json" \
	--output json \
	| jq "[.properties.outputs | to_entries | .[] | {key:.key, value: .value.value}] | from_entries" > "$script_dir/main.output.json"


STORAGE_ACCOUNT_NAME=$(jq -r '.storageAccountName' < "$script_dir/main.output.json")
if [[ ${#STORAGE_ACCOUNT_NAME} -eq 0 ]]; then
  echo 'ERROR: Missing output value storageAccountName' 1>&2
  exit 6
fi

STORAGE_ACCOUNT_ID=$(jq -r '.storageResourceId' < "$script_dir/main.output.json")
if [[ ${#STORAGE_ACCOUNT_ID} -eq 0 ]]; then
  echo 'ERROR: Missing output value storageResourceId' 1>&2
  exit 6
fi

FUNCTION_APP_NAME=$(jq -r '.functionName' < "$script_dir/main.output.json")
if [[ ${#FUNCTION_APP_NAME} -eq 0 ]]; then
  echo 'ERROR: Missing output value functionName' 1>&2
  exit 6
fi

# Create the package
pushd src

pip install --target "./.python_packages/lib/site-packages" -r ./requirements.txt --upgrade

zip -r function.zip . \
    -x ".devcontainer/*" \
    -x ".vscode/*" \
    -x ".venv/*" \
    -x "*.sh" \
    -x ".gitignore" \
    -x "local.settings.json" \
    -x "function/*"


# Upload and set the package

PACKAGE_URL="https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$STORAGE_CONTAINER_NAME/function.zip"
STORAGE_ROLE_NAME="Storage Blob Data Contributor"

echo -e "\n== Assigning $STORAGE_ROLE_NAME role to $USER_PRINCIPAL_NAME in order to upload deployment package."

# Assign self the 'Storage Blob Data Contributor' role
az role assignment create \
    --assignee "$USER_PRINCIPAL_NAME" \
    --role "$STORAGE_ROLE_NAME" \
    --scope "$STORAGE_ACCOUNT_ID"

# Sleep to give AAD time to replicate data.
echo -e "\n== Sleeping for 15 seconds . . ."
sleep 15

az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$STORAGE_CONTAINER_NAME" \
    --name function.zip \
    --file function.zip \
    --overwrite \
    --auth-mode login

az functionapp config appsettings set \
    -g "$RESOURCE_GROUP_NAME" \
    -n "$FUNCTION_APP_NAME" \
    --settings WEBSITE_RUN_FROM_PACKAGE="$PACKAGE_URL"

popd