#!/bin/bash

TF_STORAGE_SUBSCRIPTION=${1:-f3b504bb-826e-46c7-a1b7-674a5a0ae43a}
TF_STORAGE_RESOURCE_GROUP=${2:-aks-dev-global}
TF_STORAGE_ACCOUNT_NAME=${3:-aksterraformstoragedev}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]];  then 
  echo "# this script is intended to set a var in calling env"
  echo "# you can source it or call as"
  echo "# eval \"\$($0 $@)\""
  echo "# but merely calling it will not have the intended effect"
fi

exec 3>&1
exec 1>&2

printf "Fetching storage account access key for $TF_STORAGE_ACCOUNT_NAME: "
export ARM_ACCESS_KEY="$(az storage account keys list \
  --subscription $TF_STORAGE_SUBSCRIPTION  \
  --resource-group $TF_STORAGE_RESOURCE_GROUP \
  --account-name  $TF_STORAGE_ACCOUNT_NAME \
  -o json  \
| jq -r '.[0].value')"


printf "\xe2\x9c\x94\n"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] ; then
  echo "export ARM_ACCESS_KEY=\"${ARM_ACCESS_KEY}\"" >&3
fi

