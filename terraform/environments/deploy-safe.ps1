#!/usr/bin/env pwsh
# ========================================
# Safe Terraform Deployment Script
# ========================================
# This script implements best practices for idempotent, secure, and safe Terraform deployments

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [switch]$PlanOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [string]$VarFile = 'terraform.tfvars',
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableDebug
)

# ========== Configuration ==========
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$PlanFile = "tfplan-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$LogFile = "deploy-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# ========== Functions ==========
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check Terraform installation
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        throw "Terraform is not installed. Install from https://www.terraform.io/downloads"
    }
    
    $TfVersion = (terraform version -json | ConvertFrom-Json).terraform_version
    Write-Log "Terraform version: $TfVersion"
    
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed. Install from https://aka.ms/InstallAzureCLI"
    }
    
    # Check Azure authentication
    $AzAccount = az account show 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not authenticated to Azure. Run: az login"
    }
    
    Write-Log "Azure account: $(($AzAccount | ConvertFrom-Json).name)"
    
    # Check tfvars file exists
    if (-not (Test-Path $VarFile)) {
        throw "Variable file not found: $VarFile"
    }
    
    Write-Log "Prerequisites check passed ✓"
}

function Initialize-Terraform {
    Write-Log "Initializing Terraform..."
    
    # Set log level
    if ($EnableDebug) {
        $env:TF_LOG = 'DEBUG'
        $env:TF_LOG_PATH = "terraform-debug-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    }
    
    # Initialize with upgrade to ensure latest providers
    terraform init -upgrade
    
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform initialization failed"
    }
    
    Write-Log "Terraform initialized ✓"
}

function Invoke-TerraformFormat {
    Write-Log "Formatting Terraform files..."
    
    terraform fmt -recursive
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: Some files were reformatted" -Level 'WARN'
    }
    
    Write-Log "Terraform format complete ✓"
}

function Invoke-TerraformValidate {
    if ($SkipValidation) {
        Write-Log "Skipping validation (user requested)"
        return
    }
    
    Write-Log "Validating Terraform configuration..."
    
    terraform validate
    
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed"
    }
    
    Write-Log "Terraform validation passed ✓"
}

function Invoke-TerraformPlan {
    Write-Log "Creating Terraform plan..."
    Write-Log "Environment: $Environment"
    Write-Log "Variables file: $VarFile"
    
    # Additional variables for safety
    $ExtraVars = @(
        "-var=environment_name=$Environment"
    )
    
    # Create plan
    $PlanArgs = @(
        'plan'
        "-out=$PlanFile"
        "-var-file=$VarFile"
    ) + $ExtraVars
    
    & terraform @PlanArgs | Tee-Object -FilePath $LogFile -Append
    
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform plan failed"
    }
    
    Write-Log "Terraform plan created: $PlanFile ✓"
    
    # Show plan summary
    Write-Log "Plan summary:"
    terraform show -json $PlanFile | ConvertFrom-Json | Select-Object -ExpandProperty resource_changes | 
        Group-Object -Property change_actions -NoElement | 
        ForEach-Object { Write-Log "  $($_.Name): $($_.Count)" }
}

function Show-PlanDetails {
    Write-Log "Detailed plan output:"
    Write-Log "===================="
    
    terraform show $PlanFile
    
    Write-Log "===================="
}

function Confirm-Apply {
    if ($AutoApprove) {
        Write-Log "Auto-approve enabled, skipping confirmation"
        return $true
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "REVIEW THE PLAN ABOVE CAREFULLY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "Plan file: $PlanFile" -ForegroundColor Cyan
    Write-Host "`n" -NoNewline
    
    $Response = Read-Host "Do you want to apply this plan? (yes/no)"
    
    return ($Response -eq 'yes')
}

function Invoke-TerraformApply {
    Write-Log "Applying Terraform plan..."
    
    # Apply from plan file (idempotent)
    terraform apply $PlanFile | Tee-Object -FilePath $LogFile -Append
    
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
    
    Write-Log "Terraform apply complete ✓"
}

function Save-Outputs {
    Write-Log "Saving Terraform outputs..."
    
    $OutputFile = "outputs-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    terraform output -json | Out-File -FilePath $OutputFile -Encoding UTF8
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Outputs saved to: $OutputFile ✓"
    }
}

function Remove-PlanFile {
    if (Test-Path $PlanFile) {
        Write-Log "Cleaning up plan file..."
        Remove-Item $PlanFile -Force
        Write-Log "Plan file removed ✓"
    }
}

function Show-Summary {
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "Log file: $LogFile" -ForegroundColor Cyan
    Write-Host "Status: SUCCESS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

# ========== Main Execution ==========
try {
    Write-Log "========================================" 
    Write-Log "Starting Terraform Deployment"
    Write-Log "========================================" 
    Write-Log "Environment: $Environment"
    Write-Log "Plan Only: $PlanOnly"
    Write-Log "Auto Approve: $AutoApprove"
    
    # Step 1: Prerequisites
    Test-Prerequisites
    
    # Step 2: Initialize
    Initialize-Terraform
    
    # Step 3: Format
    Invoke-TerraformFormat
    
    # Step 4: Validate
    Invoke-TerraformValidate
    
    # Step 5: Plan
    Invoke-TerraformPlan
    
    # Step 6: Show plan
    Show-PlanDetails
    
    # Stop here if plan-only mode
    if ($PlanOnly) {
        Write-Log "Plan-only mode: Deployment stopped"
        Write-Log "To apply, run: terraform apply $PlanFile"
        exit 0
    }
    
    # Step 7: Confirm
    if (-not (Confirm-Apply)) {
        Write-Log "Deployment cancelled by user"
        Remove-PlanFile
        exit 0
    }
    
    # Step 8: Apply
    Invoke-TerraformApply
    
    # Step 9: Save outputs
    Save-Outputs
    
    # Step 10: Cleanup
    Remove-PlanFile
    
    # Step 11: Summary
    Show-Summary
    
    Write-Log "Deployment completed successfully"
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "DEPLOYMENT FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check log file: $LogFile" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Red
    
    # Cleanup plan file on error
    Remove-PlanFile
    
    exit 1
} finally {
    # Reset environment variables
    if ($EnableDebug) {
        Remove-Item env:TF_LOG -ErrorAction SilentlyContinue
        Remove-Item env:TF_LOG_PATH -ErrorAction SilentlyContinue
    }
}
