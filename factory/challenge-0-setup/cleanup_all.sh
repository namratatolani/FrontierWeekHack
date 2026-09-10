#!/bin/bash
set -euo pipefail

# =============================================================================
# Foundry Hackathon — Infrastructure Teardown & Purge Script
# Targets all resource groups starting with the prefix: foundry-hackathon-rg-
# =============================================================================

PREFIX="foundry-hackathon-rg-"

echo "=============================================="
echo "  Foundry Hackathon — Infrastructure Cleanup  "
echo "=============================================="

# 1. Fetch all resource groups matching the script's prefix
echo ">>> Scanning for resource groups starting with '$PREFIX'..."
RG_LIST=$(az group list --query "[?starts_with(name, '$PREFIX')].name" -o tsv)

if [ -z "$RG_LIST" ]; then
    echo "No resource groups found matching prefix '$PREFIX'. Execution halted."
    exit 0
fi

echo "Found the following resource groups to delete:"
echo "$RG_LIST"
echo "----------------------------------------------"

# 2. Iterate and delete resource groups concurrently
for rg in $RG_LIST; do
    echo ">>> Deleting resource group: $rg (non-blocking)..."
    # --no-wait executes these concurrently so you don't wait 10+ minutes for each one.
    az group delete --name "$rg" --yes --no-wait
done

echo ">>> Deletion commands sent to Azure. Active removal is running in the background."

# 3. Handle Soft-Deleted Cognitive / AI Foundry Services
# Azure Cognitive Services protects resources from accidental deletion.
# We fetch soft-deleted assets in 'swedencentral' and purge them so names can be reused.
echo ">>> Checking for soft-deleted AI Foundry/Cognitive resources to purge..."
sleep 5 # Brief pause to let the deletion pipeline register the soft-deletes

DELETED_ACCOUNTS=$(az cognitiveservices account list-deleted --query "[?properties.location=='swedencentral'].name" -o tsv)

if [ -n "$DELETED_ACCOUNTS" ]; then
    for account in $DELETED_ACCOUNTS; do
        # Filter for accounts matching your script's foundry resource name structure
        if [[ "$account" == foundry-hack-* ]]; then
            echo ">>> Purging soft-deleted AI resource: $account from swedencentral..."
            az cognitiveservices account purge \
                --name "$account" \
                --location "swedencentral" \
                --resource-group "$(az cognitiveservices account list-deleted --query "[?name=='$account'].properties.resourceVerificationData.resourceGroup" -o tsv)" \
                --no-wait || true
        fi
    done
else
    echo "    ✓ No matching soft-deleted resources require manual purging."
fi

echo "=============================================="
echo "Cleanup Initiated Successfully!"
echo "Monitor progress in the Azure Portal or using: az group list"
echo "=============================================="
