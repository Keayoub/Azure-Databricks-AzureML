# PowerShell script to create/update Databricks job for KeyVault integration test
# Usage: .\create-databricks-job.ps1 -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" -Token "dapi..."

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$Token,
    
    [Parameter(Mandatory=$false)]
    [string]$NotebookPath = "/Workspace/tutorials/02-core-integration/Databricks_KeyVault_Integration_Test",
    
    [Parameter(Mandatory=$false)]
    [string]$JobName = "AzureML-KeyVault-Integration-Test",
    
    [Parameter(Mandatory=$false)]
    [string]$SecretScope = "azureml-kv-scope",
    
    [Parameter(Mandatory=$false)]
    [switch]$Update
)

Write-Host "`nCreating Databricks Job for AzureML KeyVault Integration Test"

# Get token if not provided
if (-not $Token) {
    Write-Host "Token not provided. Checking environment variables..."
    $Token = $env:DATABRICKS_TOKEN
    
    if (-not $Token) {
        Write-Host "Checking Azure CLI for token..."
        try {
            $Token = az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv
        } catch {
            Write-Error "Could not get token. Set DATABRICKS_TOKEN environment variable or provide -Token parameter"
            exit 1
        }
    }
}

# Validate workspace URL
$WorkspaceUrl = $WorkspaceUrl.TrimEnd('/')
Write-Host "Workspace URL: $WorkspaceUrl"

# Load job definition
$jobDefinition = Get-Content "job-definition.json" -Raw | ConvertFrom-Json

# Update job definition with parameters
$jobDefinition.name = $JobName
$jobDefinition.tasks[0].notebook_task.notebook_path = $NotebookPath
$jobDefinition.tasks[0].notebook_task.base_parameters.DATABRICKS_SECRET_SCOPE = $SecretScope

# Check if job already exists
Write-Host "`nChecking if job already exists..."

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

try {
    $listResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Method Get -Headers $headers
    $existingJob = $listResponse.jobs | Where-Object { $_.settings.name -eq $JobName }
    
    if ($existingJob) {
        Write-Host "Found existing job: $($existingJob.job_id)"
        
        if ($Update) {
            Write-Host "Updating existing job..."
            
            $updateBody = @{
                job_id = $existingJob.job_id
                new_settings = $jobDefinition
            } | ConvertTo-Json -Depth 10
            
            $updateResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/update" -Method Post -Headers $headers -Body $updateBody
            
            Write-Host "Job updated successfully"
            $jobId = $existingJob.job_id
        } else {
            Write-Host "Job already exists. Use -Update to update it."
            $jobId = $existingJob.job_id
        }
    } else {
        Write-Host "Job not found. Creating new job..."
        
        $createBody = $jobDefinition | ConvertTo-Json -Depth 10
        $createResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/create" -Method Post -Headers $headers -Body $createBody
        
        $jobId = $createResponse.job_id
        Write-Host "Job created successfully"
    }
    
    # Get job details
    $jobDetails = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/get?job_id=$jobId" -Method Get -Headers $headers
    
    Write-Host "`nJOB DETAILS"
    Write-Host "Job Name:       $($jobDetails.settings.name)"
    Write-Host "Job ID:         $jobId"
    Write-Host "Notebook Path:  $NotebookPath"
    Write-Host "Cluster Type:   Single Node (Standard_DS3_v2)"
    Write-Host "Schedule:       Every Monday at 09:00 UTC (PAUSED)"
    Write-Host "Secret Scope:   $SecretScope"
    Write-Host "`nOpen in Databricks: $WorkspaceUrl/jobs/$jobId"
    
    # Ask if user wants to run now
    $runNow = Read-Host "`nWould you like to run the job now? (y/n)"
    if ($runNow -eq 'y' -or $runNow -eq 'Y') {
        Write-Host "`nStarting job run..."
        $runResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/run-now" -Method Post -Headers $headers -Body (ConvertTo-Json @{job_id=$jobId})
        
        Write-Host "Job run started"
        Write-Host "Run ID: $($runResponse.run_id)"
        Write-Host "Monitor: $WorkspaceUrl/jobs/$jobId/runs/$($runResponse.run_id)"
    }
    
} catch {
    Write-Error "Failed to create/update job: $_"
    Write-Error $_.Exception.Response
    exit 1
}

Write-Host "`nDone"
