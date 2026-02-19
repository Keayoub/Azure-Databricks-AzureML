#!/bin/bash
#
# Creates or updates a Databricks multi-task workflow job
#
# Usage:
#   ./create-complete-workflow.sh -w <workspace-url> -c <cluster-id> [-t <token>] [-r]
#
# Options:
#   -w    Databricks workspace URL
#   -c    Existing cluster ID
#   -t    Databricks access token (optional, uses DATABRICKS_TOKEN env var)
#   -r    Run workflow immediately
#   -h    Show help

set -e

RUN_NOW=false

# Parse arguments
while getopts "w:c:t:rh" opt; do
    case $opt in
        w) WORKSPACE_URL="$OPTARG" ;;
        c) CLUSTER_ID="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        r) RUN_NOW=true ;;
        h)
            echo "Usage: $0 -w <workspace-url> -c <cluster-id> [-t <token>] [-r]"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Validate parameters
if [ -z "$WORKSPACE_URL" ]; then
    echo "Error: Workspace URL required (-w)" >&2
    exit 1
fi

if [ -z "$CLUSTER_ID" ]; then
    echo "Error: Cluster ID required (-c)" >&2
    exit 1
fi

# Get token
if [ -z "$TOKEN" ]; then
    if [ -n "$DATABRICKS_TOKEN" ]; then
        TOKEN="$DATABRICKS_TOKEN"
        echo "Using token from DATABRICKS_TOKEN"
    else
        echo -n "Enter Databricks token: "
        read -s TOKEN
        echo ""
    fi
fi

echo ""
echo "Creating Databricks workflow..."
echo "Workspace: $WORKSPACE_URL"
echo "Cluster: $CLUSTER_ID"

# Load job definition
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_DEFINITION_PATH="$SCRIPT_DIR/complete-workflow-job.json"

if [ ! -f "$JOB_DEFINITION_PATH" ]; then
    echo "Error: Job definition not found: $JOB_DEFINITION_PATH" >&2
    exit 1
fi

# Read and replace cluster ID
JOB_JSON=$(cat "$JOB_DEFINITION_PATH" | sed "s/{{CLUSTER_ID}}/$CLUSTER_ID/g")

# Extract job name using grep and sed
JOB_NAME=$(echo "$JOB_JSON" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

echo ""
echo "Checking for existing job..."

JOBS_RESPONSE=$(curl -s -X GET "$WORKSPACE_URL/api/2.1/jobs/list" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

# Extract existing job ID using grep and sed
EXISTING_JOB_ID=$(echo "$JOBS_RESPONSE" | grep -o "\"job_id\"[[:space:]]*:[[:space:]]*[0-9]*" | head -1 | grep -o "[0-9]*")

if [ -n "$EXISTING_JOB_ID" ]; then
    echo "Found existing job ID: $EXISTING_JOB_ID"
    echo -n "Update existing job? (y/n): "
    read -r UPDATE
    
    if [ "$UPDATE" = "y" ]; then
        echo "Updating job..."
        
        UPDATE_PAYLOAD="{\"job_id\": $EXISTING_JOB_ID, \"new_settings\": $JOB_JSON}"
        
        curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/reset" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_PAYLOAD" > /dev/null
        
        echo "Job updated"
        JOB_ID=$EXISTING_JOB_ID
    else
        echo "Cancelled"
        exit 0
    fi
else
    echo "Creating new job..."
    
    CREATE_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/create" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$JOB_JSON")
    
    JOB_ID=$(echo "$CREATE_RESPONSE" | grep -o '"job_id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
    
    if [ -z "$JOB_ID" ]; then
        echo "Error creating job" >&2
        echo "$CREATE_RESPONSE" >&2
        exit 1
    fi
    
    echo "Job created. ID: $JOB_ID"
fi

JOB_URL="$WORKSPACE_URL/#job/$JOB_ID"

echo ""
echo "Job ID: $JOB_ID"
echo "Job URL: $JOB_URL"

# Trigger run if requested
if [ "$RUN_NOW" = true ]; then
    echo ""
    echo "Triggering workflow run..."
    
    RUN_PAYLOAD="{\"job_id\": $JOB_ID}"
    
    RUN_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/run-now" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$RUN_PAYLOAD")
    
    RUN_ID=$(echo "$RUN_RESPONSE" | grep -o '"run_id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
    
    if [ -z "$RUN_ID" ]; then
        echo "Warning: Failed to trigger run" >&2
    else
        RUN_URL="$WORKSPACE_URL/#job/$JOB_ID/run/$RUN_ID"
        echo "Run triggered. ID: $RUN_ID"
        echo "Monitor: $RUN_URL"
    fi
fi

echo ""
echo "Complete. Job URL: $JOB_URL"
