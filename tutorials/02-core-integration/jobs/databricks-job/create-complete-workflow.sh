#!/bin/bash
#
# Creates or updates a Databricks multi-task workflow job that runs all notebooks
#
# Usage:
#   ./create-complete-workflow.sh -w <workspace-url> -c <cluster-id> [-t <token>] [-s <secret-scope>] [-r]
#
# Options:
#   -w    Databricks workspace URL (e.g., https://adb-xxx.azuredatabricks.net)
#   -c    Existing cluster ID to use for all tasks
#   -t    Databricks personal access token (optional, will use DATABRICKS_TOKEN env var)
#   -s    Secret scope name (default: azureml-kv-scope)
#   -n    Create new job cluster instead of using existing cluster
#   -r    Run workflow immediately after creation
#   -h    Show this help message

set -e

# Default values
SECRET_SCOPE="azureml-kv-scope"
CREATE_CLUSTER=false
RUN_NOW=false

# Parse arguments
while getopts "w:c:t:s:nrh" opt; do
    case $opt in
        w) WORKSPACE_URL="$OPTARG" ;;
        c) CLUSTER_ID="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        s) SECRET_SCOPE="$OPTARG" ;;
        n) CREATE_CLUSTER=true ;;
        r) RUN_NOW=true ;;
        h)
            echo "Usage: $0 -w <workspace-url> -c <cluster-id> [-t <token>] [-s <secret-scope>] [-r]"
            echo ""
            echo "Creates a comprehensive Databricks workflow with 17 tasks covering:"
            echo "  - Quickstart validation"
            echo "  - Core integration patterns"
            echo "  - ML workflows (feature engineering, training, inference)"
            echo "  - MLOps orchestration"
            echo "  - Unity Catalog integration"
            echo "  - Enterprise reference patterns"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$WORKSPACE_URL" ]; then
    echo "❌ Error: Workspace URL is required (-w)" >&2
    exit 1
fi

if [ "$CREATE_CLUSTER" = false ] && [ -z "$CLUSTER_ID" ]; then
    echo "❌ Error: Either -c <cluster-id> or -n (create cluster) must be specified" >&2
    exit 1
fi

# Get token from environment or prompt
if [ -z "$TOKEN" ]; then
    if [ -n "$DATABRICKS_TOKEN" ]; then
        TOKEN="$DATABRICKS_TOKEN"
        echo "✓ Using token from DATABRICKS_TOKEN environment variable"
    else
        echo -n "Enter Databricks token: "
        read -s TOKEN
        echo ""
    fi
fi

echo ""
echo "🚀 Creating Databricks Complete Workflow Job"
echo "Workspace: $WORKSPACE_URL"
echo "Secret Scope: $SECRET_SCOPE"
if [ -n "$CLUSTER_ID" ]; then
    echo "Cluster ID: $CLUSTER_ID"
else
    echo "Job Cluster: Will be created automatically"
fi

# Load job definition
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_DEFINITION_PATH="$SCRIPT_DIR/complete-workflow-job.json"

if [ ! -f "$JOB_DEFINITION_PATH" ]; then
    echo "❌ Error: Job definition not found: $JOB_DEFINITION_PATH" >&2
    exit 1
fi

# Read and modify job definition
JOB_JSON=$(cat "$JOB_DEFINITION_PATH")

if [ "$CREATE_CLUSTER" = true ]; then
    echo ""
    echo "⚙️  Configuring job cluster..."
    
    # Create job cluster configuration
    JOB_CLUSTER_CONFIG='{
        "job_clusters": [{
            "job_cluster_key": "shared-cluster",
            "new_cluster": {
                "spark_version": "13.3.x-scala2.12",
                "node_type_id": "Standard_DS3_v2",
                "num_workers": 2,
                "spark_conf": {
                    "spark.databricks.delta.preview.enabled": "true"
                },
                "azure_attributes": {
                    "first_on_demand": 1,
                    "availability": "ON_DEMAND_AZURE"
                }
            }
        }]
    }'
    
    # Modify tasks to use job cluster (replace existing_cluster_id with job_cluster_key)
    JOB_JSON=$(echo "$JOB_JSON" | jq --argjson jc "$JOB_CLUSTER_CONFIG" '
        .job_clusters = $jc.job_clusters |
        .tasks |= map(
            del(.existing_cluster_id) |
            .job_cluster_key = "shared-cluster"
        )
    ')
else
    # Replace cluster ID placeholder
    JOB_JSON=$(echo "$JOB_JSON" | sed "s/{{CLUSTER_ID}}/$CLUSTER_ID/g")
fi

# Validate secret scope
echo ""
echo "🔐 Validating secret scope: $SECRET_SCOPE"
SCOPE_RESPONSE=$(curl -s -X GET "$WORKSPACE_URL/api/2.0/secrets/scopes/list" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

if echo "$SCOPE_RESPONSE" | jq -e ".scopes[] | select(.name == \"$SECRET_SCOPE\")" > /dev/null; then
    echo "✓ Secret scope '$SECRET_SCOPE' found"
else
    echo "⚠️  Warning: Secret scope '$SECRET_SCOPE' not found. Tasks using secret parameters may fail."
    echo -n "Continue anyway? (y/n): "
    read -r CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 0
    fi
fi

# Check if job already exists
echo ""
echo "🔍 Checking for existing job..."
JOB_NAME=$(echo "$JOB_JSON" | jq -r '.name')

JOBS_RESPONSE=$(curl -s -X GET "$WORKSPACE_URL/api/2.1/jobs/list" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

EXISTING_JOB_ID=$(echo "$JOBS_RESPONSE" | jq -r ".jobs[] | select(.settings.name == \"$JOB_NAME\") | .job_id")

if [ -n "$EXISTING_JOB_ID" ]; then
    echo "Found existing job: $EXISTING_JOB_ID"
    echo -n "Update existing job? (y/n): "
    read -r UPDATE
    
    if [ "$UPDATE" = "y" ]; then
        echo ""
        echo "📝 Updating job $EXISTING_JOB_ID..."
        
        UPDATE_PAYLOAD=$(jq -n --argjson settings "$JOB_JSON" --argjson job_id "$EXISTING_JOB_ID" '{
            job_id: $job_id,
            new_settings: $settings
        }')
        
        curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/reset" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_PAYLOAD" > /dev/null
        
        echo "✓ Job updated successfully!"
        JOB_ID=$EXISTING_JOB_ID
    else
        echo "Exiting without changes."
        exit 0
    fi
else
    echo "No existing job found. Creating new job..."
    
    CREATE_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/create" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$JOB_JSON")
    
    JOB_ID=$(echo "$CREATE_RESPONSE" | jq -r '.job_id')
    
    if [ "$JOB_ID" = "null" ] || [ -z "$JOB_ID" ]; then
        echo "❌ Error creating job:" >&2
        echo "$CREATE_RESPONSE" | jq '.' >&2
        exit 1
    fi
    
    echo "✓ Job created successfully! Job ID: $JOB_ID"
fi

# Display job details
JOB_URL="$WORKSPACE_URL/#job/$JOB_ID"
TASK_COUNT=$(echo "$JOB_JSON" | jq '.tasks | length')

echo ""
echo "📊 Job Details:"
echo "   Job ID: $JOB_ID"
echo "   Job URL: $JOB_URL"
echo "   Total Tasks: $TASK_COUNT"
echo ""

# Display task summary
echo "📋 Workflow Tasks:"
echo ""
echo "   Quickstart (2 tasks):"
echo "      - quickstart_integration_guide: Introduction and integration overview"
echo "      - quickstart_test_models: Quick test of Azure ML models from Databricks"
echo ""
echo "   Core Integration (3 tasks):"
echo "      - core_complete_integration: Complete reference for Databricks-AzureML integration"
echo "      - core_databricks_to_azureml: Call AzureML endpoints from Databricks"
echo "      - core_keyvault_integration: Test Key Vault integration from Databricks"
echo ""
echo "   ML Workflows (5 tasks):"
echo "      - ml_feature_engineering: Feature engineering and data preparation"
echo "      - ml_model_training: Model training pipeline"
echo "      - ml_batch_prediction: Batch prediction and scoring"
echo "      - ml_realtime_inference: Real-time inference patterns"
echo "      - ml_testing_models: Testing AzureML models"
echo ""
echo "   MLOps (3 tasks):"
echo "      - mlops_orchestration: MLOps orchestration patterns"
echo "      - mlops_powershell: PowerShell orchestration examples"
echo "      - mlops_integration_guide: Comprehensive Databricks-AzureML integration guide"
echo ""
echo "   Unity Catalog (3 tasks):"
echo "      - unity_catalog_integration: Unity Catalog integration patterns"
echo "      - unity_deploy_endpoints: Deploy model to three endpoints"
echo "      - unity_track_deploy: Track with Databricks, deploy to AzureML"
echo ""
echo "   Enterprise (1 task):"
echo "      - enterprise_reference: Enterprise reference integration patterns"
echo ""

# Optionally trigger run
if [ "$RUN_NOW" = true ]; then
    echo "🏃 Triggering workflow run..."
    
    RUN_PAYLOAD=$(jq -n --argjson job_id "$JOB_ID" '{job_id: $job_id}')
    
    RUN_RESPONSE=$(curl -s -X POST "$WORKSPACE_URL/api/2.1/jobs/run-now" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$RUN_PAYLOAD")
    
    RUN_ID=$(echo "$RUN_RESPONSE" | jq -r '.run_id')
    
    if [ "$RUN_ID" = "null" ] || [ -z "$RUN_ID" ]; then
        echo "⚠️  Warning: Failed to trigger run:" >&2
        echo "$RUN_RESPONSE" | jq '.' >&2
    else
        RUN_URL="$WORKSPACE_URL/#job/$JOB_ID/run/$RUN_ID"
        
        echo "✓ Workflow run triggered!"
        echo "   Run ID: $RUN_ID"
        echo "   Run URL: $RUN_URL"
        echo ""
        echo "⏳ This workflow will execute all 17 tasks sequentially."
        echo "   Expected duration: 2-4 hours (depending on cluster performance)"
        echo ""
        echo "Monitor progress: $RUN_URL"
    fi
fi

echo ""
echo "✅ Workflow configuration complete!"
echo "Next steps:"
echo "  1. Review job configuration: $JOB_URL"
echo "  2. Verify secret scope: $SECRET_SCOPE"
echo "  3. Run workflow manually or wait for schedule"
if [ "$RUN_NOW" != true ]; then
    echo "  4. Trigger now: ./create-complete-workflow.sh -w '$WORKSPACE_URL' -c '$CLUSTER_ID' -r"
fi
echo ""
