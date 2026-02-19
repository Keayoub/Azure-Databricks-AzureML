#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates or updates a Databricks multi-task workflow job that runs all notebooks

.DESCRIPTION
    This script creates a comprehensive Databricks workflow with 17 tasks covering:
    - Quickstart validation
    - Core integration patterns
    - ML workflows (feature engineering, training, inference)
    - MLOps orchestration
    - Unity Catalog integration
    - Enterprise reference patterns

.PARAMETER WorkspaceUrl
    Databricks workspace URL (e.g., https://adb-xxx.azuredatabricks.net)

.PARAMETER Token
    Databricks personal access token (will prompt if not provided)

.PARAMETER ClusterId
    Existing cluster ID to use for all tasks

.PARAMETER CreateCluster
    Create a new job cluster instead of using existing cluster

.PARAMETER SecretScope
    Secret scope name for parameters (default: azureml-kv-scope)

.PARAMETER RunNow
    Trigger the workflow immediately after creation

.EXAMPLE
    .\create-complete-workflow.ps1 -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -ClusterId "0123-456789-abcdef"

.EXAMPLE
    .\create-complete-workflow.ps1 -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -CreateCluster -RunNow
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceUrl,

    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [string]$ClusterId,

    [Parameter(Mandatory=$false)]
    [switch]$CreateCluster,

    [Parameter(Mandatory=$false)]
    [string]$SecretScope = "azureml-kv-scope",

    [Parameter(Mandatory=$false)]
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"

# Get token from environment or prompt
if (-not $Token) {
    if ($env:DATABRICKS_TOKEN) {
        $Token = $env:DATABRICKS_TOKEN
        Write-Host "✓ Using token from DATABRICKS_TOKEN environment variable" -ForegroundColor Green
    } else {
        $secureToken = Read-Host "Enter Databricks token" -AsSecureString
        $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        )
    }
}

# Validate cluster configuration
if (-not $CreateCluster -and -not $ClusterId) {
    Write-Error "Either -ClusterId or -CreateCluster must be specified"
    exit 1
}

Write-Host "`n🚀 Creating Databricks Complete Workflow Job" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceUrl"
Write-Host "Secret Scope: $SecretScope"
if ($ClusterId) {
    Write-Host "Cluster ID: $ClusterId"
} else {
    Write-Host "Job Cluster: Will be created automatically"
}

# Load job definition
$jobDefinitionPath = Join-Path $PSScriptRoot "complete-workflow-job.json"
if (-not (Test-Path $jobDefinitionPath)) {
    Write-Error "Job definition not found: $jobDefinitionPath"
    exit 1
}

$jobDefinition = Get-Content $jobDefinitionPath -Raw | ConvertFrom-Json

# Replace cluster configuration
if ($CreateCluster) {
    Write-Host "`n⚙️  Configuring job cluster..." -ForegroundColor Yellow
    $jobClusterConfig = @{
        job_cluster_key = "shared-cluster"
        new_cluster = @{
            spark_version = "13.3.x-scala2.12"
            node_type_id = "Standard_DS3_v2"
            num_workers = 2
            spark_conf = @{
                "spark.databricks.delta.preview.enabled" = "true"
            }
            azure_attributes = @{
                first_on_demand = 1
                availability = "ON_DEMAND_AZURE"
            }
        }
    }
    $jobDefinition | Add-Member -NotePropertyName "job_clusters" -NotePropertyValue @($jobClusterConfig) -Force
    
    # Update tasks to use job cluster
    foreach ($task in $jobDefinition.tasks) {
        $task.PSObject.Properties.Remove('existing_cluster_id')
        $task | Add-Member -NotePropertyName "job_cluster_key" -NotePropertyValue "shared-cluster" -Force
    }
} else {
    # Replace cluster ID placeholder
    $jobJsonString = $jobDefinition | ConvertTo-Json -Depth 100
    $jobJsonString = $jobJsonString -replace '\{\{CLUSTER_ID\}\}', $ClusterId
    $jobDefinition = $jobJsonString | ConvertFrom-Json
}

# Validate secret scope exists
Write-Host "`n🔐 Validating secret scope: $SecretScope" -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

try {
    $scopeResponse = Invoke-RestMethod -Method Get -Uri "$WorkspaceUrl/api/2.0/secrets/scopes/list" -Headers $headers
    $scopeExists = $scopeResponse.scopes | Where-Object { $_.name -eq $SecretScope }
    
    if (-not $scopeExists) {
        Write-Warning "Secret scope '$SecretScope' not found. Tasks using secret parameters may fail."
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne "y") {
            exit 0
        }
    } else {
        Write-Host "✓ Secret scope '$SecretScope' found" -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not validate secret scope: $_"
}

# Check if job already exists
Write-Host "`n🔍 Checking for existing job..." -ForegroundColor Yellow
$jobName = $jobDefinition.name

try {
    $jobsResponse = Invoke-RestMethod -Method Get -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Headers $headers
    $existingJob = $jobsResponse.jobs | Where-Object { $_.settings.name -eq $jobName }
    
    if ($existingJob) {
        Write-Host "Found existing job: $($existingJob.job_id)" -ForegroundColor Yellow
        $update = Read-Host "Update existing job? (y/n)"
        
        if ($update -eq "y") {
            Write-Host "`n📝 Updating job $($existingJob.job_id)..." -ForegroundColor Cyan
            
            $updatePayload = @{
                job_id = $existingJob.job_id
                new_settings = $jobDefinition
            } | ConvertTo-Json -Depth 100
            
            $response = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/reset" `
                -Headers $headers -Body $updatePayload
            
            Write-Host "✓ Job updated successfully!" -ForegroundColor Green
            $jobId = $existingJob.job_id
        } else {
            Write-Host "Exiting without changes." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "No existing job found. Creating new job..." -ForegroundColor Green
        
        $createPayload = $jobDefinition | ConvertTo-Json -Depth 100
        $response = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/create" `
            -Headers $headers -Body $createPayload
        
        $jobId = $response.job_id
        Write-Host "✓ Job created successfully! Job ID: $jobId" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to create/update job: $_"
    Write-Error $_.Exception.Response.GetResponseStream()
    exit 1
}

# Display job URL
$jobUrl = "$WorkspaceUrl/#job/$jobId"
Write-Host "`n📊 Job Details:" -ForegroundColor Cyan
Write-Host "   Job ID: $jobId"
Write-Host "   Job URL: $jobUrl"
Write-Host "   Total Tasks: $($jobDefinition.tasks.Count)"
Write-Host ""

# Display task summary
Write-Host "📋 Workflow Tasks:" -ForegroundColor Cyan
$groupedTasks = @{
    "Quickstart" = @()
    "Core Integration" = @()
    "ML Workflows" = @()
    "MLOps" = @()
    "Unity Catalog" = @()
    "Enterprise" = @()
}

foreach ($task in $jobDefinition.tasks) {
    if ($task.task_key -like "quickstart*") {
        $groupedTasks["Quickstart"] += $task
    } elseif ($task.task_key -like "core*") {
        $groupedTasks["Core Integration"] += $task
    } elseif ($task.task_key -like "ml_*") {
        $groupedTasks["ML Workflows"] += $task
    } elseif ($task.task_key -like "mlops*") {
        $groupedTasks["MLOps"] += $task
    } elseif ($task.task_key -like "unity*") {
        $groupedTasks["Unity Catalog"] += $task
    } elseif ($task.task_key -like "enterprise*") {
        $groupedTasks["Enterprise"] += $task
    }
}

foreach ($group in $groupedTasks.Keys | Sort-Object) {
    if ($groupedTasks[$group].Count -gt 0) {
        Write-Host "`n   $group ($($groupedTasks[$group].Count) tasks):" -ForegroundColor Yellow
        foreach ($task in $groupedTasks[$group]) {
            Write-Host "      - $($task.task_key): $($task.description)" -ForegroundColor Gray
        }
    }
}

# Optionally trigger run
if ($RunNow) {
    Write-Host "`n🏃 Triggering workflow run..." -ForegroundColor Cyan
    
    try {
        $runPayload = @{
            job_id = $jobId
        } | ConvertTo-Json
        
        $runResponse = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/run-now" `
            -Headers $headers -Body $runPayload
        
        $runId = $runResponse.run_id
        $runUrl = "$WorkspaceUrl/#job/$jobId/run/$runId"
        
        Write-Host "✓ Workflow run triggered!" -ForegroundColor Green
        Write-Host "   Run ID: $runId"
        Write-Host "   Run URL: $runUrl"
        Write-Host ""
        Write-Host "⏳ This workflow will execute all 17 tasks sequentially."
        Write-Host "   Expected duration: 2-4 hours (depending on cluster performance)"
        Write-Host ""
        Write-Host "Monitor progress: $runUrl" -ForegroundColor Cyan
    } catch {
        Write-Warning "Failed to trigger run: $_"
    }
}

Write-Host "`n✅ Workflow configuration complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review job configuration: $jobUrl"
Write-Host "  2. Verify secret scope: $SecretScope"
Write-Host "  3. Run workflow manually or wait for schedule"
if (-not $RunNow) {
    Write-Host "  4. Trigger now: .\create-complete-workflow.ps1 -WorkspaceUrl '$WorkspaceUrl' -ClusterId '$ClusterId' -RunNow"
}
Write-Host ""
