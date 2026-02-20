#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simplified Databricks job management for AzureML integration tests

.PARAMETER Action
    Action to perform: create, run, list, delete

.PARAMETER JobName
    Job name (default: AzureML-Integration-Test)

.PARAMETER NotebookPath
    Notebook path in Databricks workspace

.PARAMETER ClusterId
    Cluster ID (optional - will create new cluster if not specified)

.PARAMETER WorkspaceUrl
    Databricks workspace URL

.PARAMETER Token
    Databricks token (uses DATABRICKS_TOKEN env var if not provided)

.EXAMPLE
    # Create and run job
    .\databricks-azureml-job.ps1 -Action create -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -NotebookPath "/Users/user@example.com/tutorials/Databricks_AzureML_Integration_Unified"

    # Run existing job
    .\databricks-azureml-job.ps1 -Action run -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -JobName "AzureML-Integration-Test"

    # List all jobs
    .\databricks-azureml-job.ps1 -Action list -WorkspaceUrl "https://adb-xxx.azuredatabricks.net"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "run", "list", "delete")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceUrl,

    [Parameter(Mandatory=$false)]
    [string]$JobName = "AzureML-Integration-Test",

    [Parameter(Mandatory=$false)]
    [string]$NotebookPath,

    [Parameter(Mandatory=$false)]
    [string]$ClusterId,

    [Parameter(Mandatory=$false)]
    [string]$Token
)

$ErrorActionPreference = "Stop"

# Get token
if (-not $Token) {
    if ($env:DATABRICKS_TOKEN) {
        $Token = $env:DATABRICKS_TOKEN
    } else {
        Write-Host "Enter Databricks token (or set DATABRICKS_TOKEN env var):"
        $secureToken = Read-Host -AsSecureString
        $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
    }
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

# Normalize workspace URL
$WorkspaceUrl = $WorkspaceUrl.TrimEnd('/')

Write-Host "`n=== Databricks AzureML Integration Job Manager ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceUrl"
Write-Host "Job Name: $JobName"
Write-Host "Action: $Action`n"

# ============================================================
# ACTION: LIST
# ============================================================
if ($Action -eq "list") {
    Write-Host "Fetching jobs..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Headers $headers -Method Get
        
        if ($response.jobs) {
            Write-Host "Found $($response.jobs.Count) job(s):`n" -ForegroundColor Green
            $response.jobs | ForEach-Object {
                Write-Host "  Job ID: $($_.job_id)"
                Write-Host "  Name: $($_.settings.name)"
                Write-Host "  Created: $($_.created_time)"
                Write-Host ""
            }
        } else {
            Write-Host "No jobs found." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error listing jobs: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# ACTION: CREATE
# ============================================================
elseif ($Action -eq "create") {
    if (-not $NotebookPath) {
        Write-Error "NotebookPath is required for create action"
    }
    
    Write-Host "Creating job..." -ForegroundColor Yellow
    
    # Build job configuration
    $jobConfig = @{
        name = $JobName
        description = "Unified Databricks-AzureML integration test notebook"
        notebook_task = @{
            notebook_path = $NotebookPath
            source = "WORKSPACE"
        }
        email_notifications = @{
            on_failure = @()
            on_success = @()
        }
        timeout_seconds = 0
        max_concurrent_runs = 1
        format = "SINGLE_TASK"
        tags = @{
            purpose = "integration-testing"
            service = "azureml"
        }
    }
    
    # Add cluster configuration
    if ($ClusterId) {
        $jobConfig["existing_cluster_id"] = $ClusterId
    } else {
        $jobConfig["new_cluster"] = @{
            spark_version = "13.3.x-scala2.12"
            node_type_id = "Standard_DS3_v2"
            num_workers = 1
            aws_attributes = @{
                availability = "SPOT_WITH_FALLBACK"
            }
        }
    }
    
    $jobJson = $jobConfig | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/create" `
            -Headers $headers `
            -Method Post `
            -Body $jobJson
        
        Write-Host "✓ Job created successfully!" -ForegroundColor Green
        Write-Host "  Job ID: $($response.job_id)"
        Write-Host "`nNext steps:"
        Write-Host "  1. View job: $WorkspaceUrl/jobs/$($response.job_id)"
        Write-Host "  2. Run job: .\databricks-azureml-job.ps1 -Action run -WorkspaceUrl '$WorkspaceUrl' -JobName '$JobName'"
    }
    catch {
        Write-Host "Error creating job: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# ACTION: RUN
# ============================================================
elseif ($Action -eq "run") {
    Write-Host "Finding job by name..." -ForegroundColor Yellow
    
    try {
        $jobsResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Headers $headers -Method Get
        $job = $jobsResponse.jobs | Where-Object { $_.settings.name -eq $JobName } | Select-Object -First 1
        
        if (-not $job) {
            Write-Host "Job not found: $JobName" -ForegroundColor Red
            Write-Host "Available jobs:"
            $jobsResponse.jobs | ForEach-Object { Write-Host "  - $($_.settings.name)" }
            exit 1
        }
        
        Write-Host "Found job ID: $($job.job_id)" -ForegroundColor Yellow
        Write-Host "Triggering run..." -ForegroundColor Yellow
        
        $runResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/run-now" `
            -Headers $headers `
            -Method Post `
            -Body (ConvertTo-Json @{ job_id = $job.job_id })
        
        Write-Host "✓ Job triggered successfully!" -ForegroundColor Green
        Write-Host "  Run ID: $($runResponse.run_id)"
        Write-Host "  View progress: $WorkspaceUrl/jobs/$($job.job_id)/runs/$($runResponse.run_id)"
    }
    catch {
        Write-Host "Error running job: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# ACTION: DELETE
# ============================================================
elseif ($Action -eq "delete") {
    Write-Host "Finding job by name..." -ForegroundColor Yellow
    
    try {
        $jobsResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Headers $headers -Method Get
        $job = $jobsResponse.jobs | Where-Object { $_.settings.name -eq $JobName } | Select-Object -First 1
        
        if (-not $job) {
            Write-Host "Job not found: $JobName" -ForegroundColor Red
            exit 1
        }
        
        $confirm = Read-Host "Delete job '$JobName' (ID: $($job.job_id))? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "Cancelled." -ForegroundColor Yellow
            exit 0
        }
        
        Write-Host "Deleting job..." -ForegroundColor Yellow
        
        Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/delete" `
            -Headers $headers `
            -Method Post `
            -Body (ConvertTo-Json @{ job_id = $job.job_id })
        
        Write-Host "✓ Job deleted successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error deleting job: $_" -ForegroundColor Red
        exit 1
    }
}
