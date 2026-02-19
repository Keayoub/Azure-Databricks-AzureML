#!/bin/bash
# Bash script to create/update Databricks job for KeyVault integration test
# Usage: ./create-databricks-job.sh --workspace-url "https://adb-xxx.azuredatabricks.net" --token "dapi..."

set -e

# Default values
NOTEBOOK_PATH="/Workspace/tutorials/02-core-integration/Databricks_KeyVault_Integration_Test"
JOB_NAME="AzureML-KeyVault-Integration-Test"
SECRET_SCOPE="azureml-kv-scope"
UPDATE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace-url)
            WORKSPACE_URL="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --notebook-path)
            NOTEBOOK_PATH="$2"
            shift 2
            ;;
        --job-name)
            JOB_NAME="$2"
            shift 2
            ;;
        --secret-scope)
            SECRET_SCOPE="$2"
            shift 2
            ;;
        --update)
            UPDATE=true
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$WORKSPACE_URL" ]]; then
    echo "Error: --workspace-url is required"
    exit 1
fi

# Get token if not provided
if [[ -z "$TOKEN" ]]; then
    echo "Token not provided. Checking environment variables..."
    TOKEN="$DATABRICKS_TOKEN"
    
    if [[ -z "$TOKEN" ]]; then
        echo "Checking Azure CLI for token..."
        TOKEN=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv 2>/dev/null || true)
        
        if [[ -z "$TOKEN" ]]; then
            echo "Could not get token. Set DATABRICKS_TOKEN environment variable or provide --token parameter"
            exit 1
        fi
    fi
fi

WORKSPACE_URL="${WORKSPACE_URL%/}"

echo ""
echo "Creating Databricks Job for AzureML KeyVault Integration Test"
echo "Workspace URL: $WORKSPACE_URL"

# Update job definition without jq
TEMP_JOB_DEF=$(mktemp)
cp job-definition.json "$TEMP_JOB_DEF"
sed -i "s|\"name\": \".*\"|\"name\": \"$JOB_NAME\"|" "$TEMP_JOB_DEF"
sed -i "s|\"notebook_path\": \".*\"|\"notebook_path\": \"$NOTEBOOK_PATH\"|" "$TEMP_JOB_DEF"
sed -i "s|\"DATABRICKS_SECRET_SCOPE\": \".*\"|\"DATABRICKS_SECRET_SCOPE\": \"$SECRET_SCOPE\"|" "$TEMP_JOB_DEF"

# Check if job exists
echo ""
echo "Checking if job already exists..."

LIST_RESPONSE=$(curl -s -X GET "$WORKSPACE_URL/api/2.1/jobs/list" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

EXISTING_JOB=$(echo "$LIST_RESPONSE" | grep -o "\"job_id\"[[:space:]]*:[[:space:]]*[0-9]*" | head -1 | grep -o '[0-9]*')

if [[ -n "$EXISTING_JOB" ]]; then
    echo "Found existing job: $EXISTING_JOB"
    
    if [[ "$UPDATE" == true ]]; then
        echo "Updating existing job..."
        
        UPDATE_PAYLOAD="{\"job_id\": $EXISTING_JOB, \"new_settings\": $(cat "$TEMP_JOB_DEF")}"
        
        curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/update" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_PAYLOAD" > /dev/null
        
        echo "Job updated successfully"
        JOB_ID="$EXISTING_JOB"
    else
        echo "Job already exists. Use --update to update it."
        JOB_ID="$EXISTING_JOB"
    fi
else
    echo "Job not found. Creating new job..."
    
    CREATE_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/create" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_JOB_DEF")
    
    JOB_ID=$(echo "$CREATE_RESPONSE" | grep -o '"job_id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
    echo "Job created successfully"
fi

# Get job details
echo ""
echo "JOB DETAILS"
echo "Job Name:       $JOB_NAME"
echo "Job ID:         $JOB_ID"
echo "Notebook Path:  $NOTEBOOK_PATH"
echo "Cluster Type:   Single Node (Standard_DS3_v2)"
echo "Schedule:       Every Monday at 09:00 UTC (PAUSED)"
echo "Secret Scope:   $SECRET_SCOPE"
echo ""
echo "Open in Databricks: $WORKSPACE_URL/jobs/$JOB_ID"

# Ask if user wants to run now
read -p "Would you like to run the job now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting job run..."
    
    RUN_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/run-now" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"job_id\": $JOB_ID}")
    
    RUN_ID=$(echo "$RUN_RESPONSE" | grep -o '"run_id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
    
    echo "Job run started"
    echo "Run ID: $RUN_ID"
    echo "Monitor: $WORKSPACE_URL/jobs/$JOB_ID/runs/$RUN_ID"
fi

# Cleanup
rm -f "$TEMP_JOB_DEF"

echo ""
echo "Done"
