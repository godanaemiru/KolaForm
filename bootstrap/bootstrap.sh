#!/usr/bin/env bash
#
# One-time bootstrap — run in Azure Cloud Shell (bash), where az is
# already authenticated. This is the ONLY manual step; everything after
# it is driven by git push.
#
# Usage:
#   GITHUB_REPO=owner/repo ./bootstrap.sh
#
# It creates:
#   1. A resource group + storage account for remote Terraform state
#      (name derived from your subscription id — the CI workflow derives
#      the same name, so no extra secret is needed).
#   2. An Entra ID app registration with GitHub OIDC federated
#      credentials — no client secret ever exists.
#   3. Role assignments so the pipeline can deploy and manage blob data.
#
# It prints the three values to store as GitHub Actions secrets.

set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO to your fork, e.g. GITHUB_REPO=alice/KolaForm}"
LOCATION="${LOCATION:-westeurope}"
APP_NAME="${APP_NAME:-kolaform-deployer}"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SUFFIX=$(echo -n "$SUB_ID" | sha256sum | cut -c1-10)
STATE_RG="kolaform-tfstate-rg"
STATE_SA="tfstate$SUFFIX"

echo "==> Subscription: $SUB_ID"
echo "==> State backend: $STATE_RG / $STATE_SA"

# --- 1. Remote state backend ------------------------------------------------
az group create --name "$STATE_RG" --location "$LOCATION" --output none

az storage account create \
  --name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --output none

# container-rm goes through the management plane, so it works even with
# shared keys disabled and no data-plane role on the current user.
az storage container-rm create \
  --storage-account "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --name tfstate \
  --output none

# --- 2. App registration + GitHub OIDC federation ----------------------------
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ] || [ "$APP_ID" = "None" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "==> Created app registration $APP_NAME ($APP_ID)"
else
  echo "==> Reusing app registration $APP_NAME ($APP_ID)"
fi

az ad sp show --id "$APP_ID" --output none 2>/dev/null || \
  az ad sp create --id "$APP_ID" --output none

create_fic() {
  local name="$1" subject="$2"
  if ! az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$name" --output none 2>/dev/null; then
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$subject\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" --output none
    echo "==> Federated credential '$name' -> $subject"
  fi
}

create_fic "github-main" "repo:${GITHUB_REPO}:ref:refs/heads/main"
create_fic "github-pr" "repo:${GITHUB_REPO}:pull_request"

# --- 3. Role assignments ------------------------------------------------------
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

# Owner: create resources AND grant the container's managed identity its
# data role. Scope it to a dedicated subscription for least blast radius.
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Owner" \
  --scope "/subscriptions/$SUB_ID" \
  --output none 2>/dev/null || true

# Data-plane access for Terraform state and blob container management
# (Owner alone carries no data-plane rights, and keys are disabled).
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Owner" \
  --scope "/subscriptions/$SUB_ID" \
  --output none 2>/dev/null || true

# --- Done ---------------------------------------------------------------------
cat <<EOF

================================================================
Bootstrap complete. Add these three GitHub Actions secrets
(repo -> Settings -> Secrets and variables -> Actions):

  AZURE_CLIENT_ID       = $APP_ID
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUB_ID

These are identifiers, not credentials — authentication happens
via OIDC token exchange. Then: git push to main and watch Actions.
================================================================
EOF
