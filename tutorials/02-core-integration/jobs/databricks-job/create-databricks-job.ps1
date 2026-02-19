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

Write-Host "🚀 Creating Databricks Job for AzureML KeyVault Integration Test" -ForegroundColor Cyan
Write-Host "=" * 80

# Get token if not provided
if (-not $Token) {
    Write-Host "ℹ️  Token not provided. Checking environment variables..." -ForegroundColor Yellow
    $Token = $env:DATABRICKS_TOKEN
    
    if (-not $Token) {
        Write-Host "ℹ️  Checking Azure CLI for token..." -ForegroundColor Yellow
        try {
            $Token = az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv
        } catch {
            Write-Error "❌ Could not get token. Set DATABRICKS_TOKEN environment variable or provide -Token parameter"
            exit 1
        }
    }
}

# Validate workspace URL
$WorkspaceUrl = $WorkspaceUrl.TrimEnd('/')
Write-Host "✅ Workspace URL: $WorkspaceUrl" -ForegroundColor Green

# Load job definition
$jobDefinition = Get-Content "job-definition.json" -Raw | ConvertFrom-Json

# Update job definition with parameters
$jobDefinition.name = $JobName
$jobDefinition.tasks[0].notebook_task.notebook_path = $NotebookPath
$jobDefinition.tasks[0].notebook_task.base_parameters.DATABRICKS_SECRET_SCOPE = $SecretScope

# Check if job already exists
Write-Host "`n🔍 Checking if job already exists..." -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

try {
    $listResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/list" -Method Get -Headers $headers
    $existingJob = $listResponse.jobs | Where-Object { $_.settings.name -eq $JobName }
    
    if ($existingJob) {
        Write-Host "✅ Found existing job: $($existingJob.job_id)" -ForegroundColor Green
        
        if ($Update) {
            Write-Host "🔄 Updating existing job..." -ForegroundColor Yellow
            
            $updateBody = @{
                job_id = $existingJob.job_id
                new_settings = $jobDefinition
            } | ConvertTo-Json -Depth 10
            
            $updateResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/update" -Method Post -Headers $headers -Body $updateBody
            
            Write-Host "✅ Job updated successfully!" -ForegroundColor Green
            $jobId = $existingJob.job_id
        } else {
            Write-Host "⚠️  Job already exists. Use -Update to update it." -ForegroundColor Yellow
            $jobId = $existingJob.job_id
        }
    } else {
        Write-Host "ℹ️  Job not found. Creating new job..." -ForegroundColor Yellow
        
        $createBody = $jobDefinition | ConvertTo-Json -Depth 10
        $createResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/create" -Method Post -Headers $headers -Body $createBody
        
        $jobId = $createResponse.job_id
        Write-Host "✅ Job created successfully!" -ForegroundColor Green
    }
    
    # Get job details
    $jobDetails = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/get?job_id=$jobId" -Method Get -Headers $headers
    
    Write-Host "`n" + ("=" * 80)
    Write-Host "JOB DETAILS" -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host "Job Name:       $($jobDetails.settings.name)" -ForegroundColor White
    Write-Host "Job ID:         $jobId" -ForegroundColor White
    Write-Host "Notebook Path:  $NotebookPath" -ForegroundColor White
    Write-Host "Cluster Type:   Single Node (Standard_DS3_v2)" -ForegroundColor White
    Write-Host "Schedule:       Every Monday at 09:00 UTC (PAUSED)" -ForegroundColor Yellow
    Write-Host "Secret Scope:   $SecretScope" -ForegroundColor White
    Write-Host ("=" * 80)
    
    Write-Host "`n🌐 Open in Databricks:" -ForegroundColor Cyan
    Write-Host "   $WorkspaceUrl/jobs/$jobId" -ForegroundColor Blue
    
    Write-Host "`n▶️  Run job now:" -ForegroundColor Cyan
    Write-Host "   Invoke-RestMethod -Uri '$WorkspaceUrl/api/2.1/jobs/run-now' -Method Post -Headers @{'Authorization'='Bearer `$Token'} -Body (ConvertTo-Json @{job_id=$jobId})" -ForegroundColor Gray
    
    Write-Host "`n📊 List job runs:" -ForegroundColor Cyan
    Write-Host "   Invoke-RestMethod -Uri '$WorkspaceUrl/api/2.1/jobs/runs/list?job_id=$jobId' -Method Get -Headers @{'Authorization'='Bearer `$Token'}" -ForegroundColor Gray
    
    # Ask if user wants to run now
    $runNow = Read-Host "`nWould you like to run the job now? (y/n)"
    if ($runNow -eq 'y' -or $runNow -eq 'Y') {
        Write-Host "`n▶️  Starting job run..." -ForegroundColor Cyan
        $runResponse = Invoke-RestMethod -Uri "$WorkspaceUrl/api/2.1/jobs/run-now" -Method Post -Headers $headers -Body (ConvertTo-Json @{job_id=$jobId})
        
        Write-Host "✅ Job run started!" -ForegroundColor Green
        Write-Host "   Run ID: $($runResponse.run_id)" -ForegroundColor White
        Write-Host "   Monitor: $WorkspaceUrl/jobs/$jobId/runs/$($runResponse.run_id)" -ForegroundColor Blue
    }
    
} catch {
    Write-Error "❌ Failed to create/update job: $_"
    Write-Error $_.Exception.Response
    exit 1
}

Write-Host "`n✅ Done!" -ForegroundColor Green
