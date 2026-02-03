@echo off
REM Deployment script for Secure Databricks Azure ML IaC (PowerShell version)
REM This script automates the deployment process with validation and testing

setlocal enabledelayedexpansion

REM Colors in PowerShell would require additional logic, so we'll use text markers
echo.
echo ========================================
echo Secure Databricks Azure ML Deployment
echo ========================================
echo.

REM Check prerequisites
echo Checking prerequisites...
where az >nul 2>nul
if errorlevel 1 (
    echo Error: Azure CLI not found. Install from https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
    exit /b 1
)
echo ^✓ Azure CLI installed

where azd >nul 2>nul
if errorlevel 1 (
    echo Error: Azure Developer CLI not found. Install from https://aka.ms/install-azd
    exit /b 1
)
echo ^✓ Azure Developer CLI installed

REM Check Azure login
az account show >nul 2>nul
if errorlevel 1 (
    echo Warning: Not logged into Azure. Running az login...
    call az login
)
echo ^✓ Azure CLI authenticated

REM Get subscription info
for /f "delims=" %%i in ('az account show --query id -o tsv') do set SUBSCRIPTION_ID=%%i
for /f "delims=" %%i in ('az ad signed-in-user show --query id -o tsv') do set ADMIN_OBJECT_ID=%%i

echo.
echo Subscription ID: %SUBSCRIPTION_ID%
echo Admin Object ID: %ADMIN_OBJECT_ID%
echo.

REM Validate Bicep
echo Validating Bicep templates...
call az bicep validate --file infra/main.bicep >nul 2>nul
if errorlevel 1 (
    echo Error: Bicep validation failed
    exit /b 1
)
echo ^✓ main.bicep validated

call az bicep build-params --file infra/main.bicepparam >nul 2>nul
if errorlevel 1 (
    echo Error: Bicep parameters validation failed
    exit /b 1
)
echo ^✓ main.bicepparam validated

REM Preview deployment
echo.
echo ========================================
echo Previewing deployment...
echo ========================================
call azd provision --preview
if errorlevel 1 (
    echo Error: Preview failed
    exit /b 1
)

REM Confirm deployment
set /p CONFIRM="Proceed with deployment? (yes/no): "
if /i not "%CONFIRM%"=="yes" (
    echo Deployment cancelled
    exit /b 0
)

REM Deploy infrastructure
echo.
echo ========================================
echo Deploying infrastructure...
echo ========================================
call azd provision
if errorlevel 1 (
    echo Error: Deployment failed
    exit /b 1
)

echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
echo View resources at: https://portal.azure.com/
echo.

endlocal
