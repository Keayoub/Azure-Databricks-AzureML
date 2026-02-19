#!/bin/bash
# Bash script to create/update Databricks job for KeyVault integration test
# Usage: ./create-databricks-job.sh --workspace-url "https://adb-xxx.azuredatabricks.net" --token "dapi..."

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
            echo -e "${RED}Unknown parameter: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$WORKSPACE_URL" ]]; then
    echo -e "${RED}Error: --workspace-url is required${NC}"
    exit 1
fi

# Get token if not provided
if [[ -z "$TOKEN" ]]; then
    echo -e "${YELLOW}ℹ️  Token not provided. Checking environment variables...${NC}"
    TOKEN="$DATABRICKS_TOKEN"
    
    if [[ -z "$TOKEN" ]]; then
        echo -e "${YELLOW}ℹ️  Checking Azure CLI for token...${NC}"
        TOKEN=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv 2>/dev/null || true)
        
        if [[ -z "$TOKEN" ]]; then
            echo -e "${RED}❌ Could not get token. Set DATABRICKS_TOKEN environment variable or provide --token parameter${NC}"
            exit 1
        fi
    fi
fi

WORKSPACE_URL="${WORKSPACE_URL%/}"

echo -e "${CYAN}🚀 Creating Databricks Job for AzureML KeyVault Integration Test${NC}"
echo "================================================================================"
echo -e "${GREEN}✅ Workspace URL: $WORKSPACE_URL${NC}"

# Update job definition
TEMP_JOB_DEF=$(mktemp)
jq --arg name "$JOB_NAME" \
   --arg path "$NOTEBOOK_PATH" \
   --arg scope "$SECRET_SCOPE" \
   '.name = $name | .tasks[0].notebook_task.notebook_path = $path | .tasks[0].notebook_task.base_parameters.DATABRICKS_SECRET_SCOPE = $scope' \
   job-definition.json > "$TEMP_JOB_DEF"

# Check if job exists
echo -e "\n${CYAN}🔍 Checking if job already exists...${NC}"

EXISTING_JOB=$(curl -s -X GET "$WORKSPACE_URL/api/2.1/jobs/list" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | \
    jq -r --arg name "$JOB_NAME" '.jobs[] | select(.settings.name == $name) | .job_id')

if [[ -n "$EXISTING_JOB" ]]; then
    echo -e "${GREEN}✅ Found existing job: $EXISTING_JOB${NC}"
    
    if [[ "$UPDATE" == true ]]; then
        echo -e "${YELLOW}🔄 Updating existing job...${NC}"
        
        UPDATE_PAYLOAD=$(jq -n --argjson job_id "$EXISTING_JOB" --slurpfile settings "$TEMP_JOB_DEF" '{job_id: $job_id, new_settings: $settings[0]}')
        
        curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/update" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_PAYLOAD" > /dev/null
        
        echo -e "${GREEN}✅ Job updated successfully!${NC}"
        JOB_ID="$EXISTING_JOB"
    else
        echo -e "${YELLOW}⚠️  Job already exists. Use --update to update it.${NC}"
        JOB_ID="$EXISTING_JOB"
    fi
else
    echo -e "${YELLOW}ℹ️  Job not found. Creating new job...${NC}"
    
    CREATE_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/create" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_JOB_DEF")
    
    JOB_ID=$(echo "$CREATE_RESPONSE" | jq -r '.job_id')
    echo -e "${GREEN}✅ Job created successfully!${NC}"
fi

# Get job details
JOB_DETAILS=$(curl -s -X GET "$WORKSPACE_URL/api/2.1/jobs/get?job_id=$JOB_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

echo -e "\n================================================================================"
echo -e "${CYAN}JOB DETAILS${NC}"
echo "================================================================================"
echo -e "Job Name:       $(echo "$JOB_DETAILS" | jq -r '.settings.name')"
echo -e "Job ID:         $JOB_ID"
echo -e "Notebook Path:  $NOTEBOOK_PATH"
echo -e "Cluster Type:   Single Node (Standard_DS3_v2)"
echo -e "${YELLOW}Schedule:       Every Monday at 09:00 UTC (PAUSED)${NC}"
echo -e "Secret Scope:   $SECRET_SCOPE"
echo "================================================================================"

echo -e "\n${CYAN}🌐 Open in Databricks:${NC}"
echo -e "   ${BLUE}$WORKSPACE_URL/jobs/$JOB_ID${NC}"

echo -e "\n${CYAN}▶️  Run job now:${NC}"
echo -e "   curl -X POST \"$WORKSPACE_URL/api/2.1/jobs/run-now\" -H \"Authorization: Bearer \$TOKEN\" -H \"Content-Type: application/json\" -d '{\"job_id\": $JOB_ID}'"

# Ask if user wants to run now
read -p "$(echo -e ${CYAN}Would you like to run the job now? \(y/n\): ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${CYAN}▶️  Starting job run...${NC}"
    
    RUN_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/run-now" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"job_id\": $JOB_ID}")
    
    RUN_ID=$(echo "$RUN_RESPONSE" | jq -r '.run_id')
    
    echo -e "${GREEN}✅ Job run started!${NC}"
    echo -e "   Run ID: $RUN_ID"
    echo -e "   Monitor: ${BLUE}$WORKSPACE_URL/jobs/$JOB_ID/runs/$RUN_ID${NC}"
fi

# Cleanup
rm -f "$TEMP_JOB_DEF"

echo -e "\n${GREEN}✅ Done!${NC}"
