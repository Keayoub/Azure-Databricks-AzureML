#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates or updates a Databricks multi-task workflow job

.PARAMETER WorkspaceUrl
    Databricks workspace URL

.PARAMETER ClusterId
    Existing cluster ID to use

.PARAMETER Token
    Databricks access token (optional, uses DATABRICKS_TOKEN env var)

.PARAMETER SecretScope
    Secret scope name (default: azureml-kv-scope)

.PARAMETER RunNow
    Trigger the workflow immediately

.EXAMPLE
    .\create-complete-workflow.ps1 -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -ClusterId "0123-456789-abcdef" -RunNow
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceUrl,

    [Parameter(Mandatory=$true)]
    [string]$ClusterId,

    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [string]$SecretScope = "azureml-kv-scope",

    [Parameter(Mandatory=$false)]
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"

# Get token
if (-not $Token) {
    if ($env:DATABRICKS_TOKEN) {
        $Token = $env:DATABRICKS_TOKEN
        Write-Host "Using token from DATABRICKS_TOKEN environment variable"
    } else {
        $secureToken = Read-Host "Enter Databricks token" -AsSecureString
        $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        )
    }
}

Write-Host "`nCreating Databricks workflow..."
Write-Host "Workspace: $WorkspaceUrl"
Write-Host "Cluster: $ClusterId"
Write-Host "Secret Scope: $SecretScope"

# Load job definition
$jobDefinitionPath = Join-Path $PSScriptRoot "complete-workflow-job.json"
if (-not (Test-Path $jobDefinitionPath)) {
    Write-Error "Job definition not found: $jobDefinitionPath"
    exit 1
}

$jobDefinition = Get-Content $jobDefinitionPath -Raw | ConvertFrom-Json

# Replace cluster ID
$jobJsonString = $jobDefinition | ConvertTo-Json -Depth 100
$jobJsonString = $jobJsonString -replace '\{\{CLUSTER_ID\}\}', $ClusterId
$jobDefinition = $jobJsonString | ConvertFrom-Json

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

# Check if job exists
Write-Host "`nChecking for existing job..."
$jobName = $jobDefinition.name

try {
    $jobsResponse = Invoke-RestMethod -Method Get -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Headers $headers
    $existingJob = $jobsResponse.jobs | Where-Object { $_.settings.name -eq $jobName }
    
    if ($existingJob) {
        Write-Host "Found existing job ID: $($existingJob.job_id)"
        $update = Read-Host "Update existing job? (y/n)"
        
        if ($update -eq "y") {
            Write-Host "Updating job..."
            $updatePayload = @{
                job_id = $existingJob.job_id
                new_settings = $jobDefinition
            } | ConvertTo-Json -Depth 100
            
            $response = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/reset" `
                -Headers $headers -Body $updatePayload
            
            Write-Host "Job updated successfully"
            $jobId = $existingJob.job_id
        } else {
            Write-Host "Cancelled"
            exit 0
        }
    } else {
        Write-Host "Creating new job..."
        $createPayload = $jobDefinition | ConvertTo-Json -Depth 100
        $response = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/create" `
            -Headers $headers -Body $createPayload
        
        $jobId = $response.job_id
        Write-Host "Job created. ID: $jobId"
    }
} catch {
    Write-Error "Failed to create/update job: $_"
    exit 1
}

$jobUrl = "$WorkspaceUrl/#job/$jobId"
Write-Host "`nJob ID: $jobId"
Write-Host "Job URL: $jobUrl"
Write-Host "Total Tasks: $($jobDefinition.tasks.Count)"

# Trigger run if requested
if ($RunNow) {
    Write-Host "`nTriggering workflow run..."
    try {
        $runPayload = @{ job_id = $jobId } | ConvertTo-Json
        $runResponse = Invoke-RestMethod -Method Post -Uri "$WorkspaceUrl/api/2.1/jobs/run-now" `
            -Headers $headers -Body $runPayload
        
        $runId = $runResponse.run_id
        $runUrl = "$WorkspaceUrl/#job/$jobId/run/$runId"
        
        Write-Host "Run triggered. ID: $runId"
        Write-Host "Monitor: $runUrl"
    } catch {
        Write-Warning "Failed to trigger run: $_"
    }
}

Write-Host "`nComplete. Job URL: $jobUrl"
