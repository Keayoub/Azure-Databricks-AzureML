# Install All Prerequisites for Secure Azure Databricks Deployment
# Cross-platform PowerShell script (Windows, macOS, Linux)
# Installs: Python, Azure CLI, Azure Developer CLI, and Databricks CLI
# Requires: PowerShell 7.0+ (https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

#Requires -Version 7.0

param(
    [switch]$Upgrade,
    [switch]$SkipVerify,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Verify PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7.0 or later" -ForegroundColor Red
    Write-Host "Download from: https://learn.microsoft.com/powershell/scripting/install/installing-powershell"
    exit 1
}

# Color output helpers
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-InfoMsg {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# ========== Detect OS ==========
function Get-OSType {
    if ($IsWindows) {
        return "Windows"
    }
    elseif ($IsMacOS) {
        return "macOS"
    }
    elseif ($IsLinux) {
        return "Linux"
    }
    else {
        return "Unknown"
    }
}

$osType = Get-OSType
Write-InfoMsg "Detected OS: $osType"

# ========== Check Command Exists ==========
function Test-CommandExists {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# ========== Execute Command (Cross-platform) ==========
function Invoke-Command-Safe {
    param([string]$Command, [string]$Description)
    
    try {
        Write-InfoMsg $Description
        Invoke-Expression $Command
        return $true
    }
    catch {
        Write-ErrorMsg "Failed: $_"
        return $false
    }
}

# ========== Main Installation ==========
Write-Host "`n================================"
Write-Host "Prerequisites Installation Script"
Write-Host "================================`n"

$installCount = 0
$skipCount = 0

# ========== 1. Python ==========
Write-Host "[1/4] Checking Python..." -ForegroundColor Blue
if (Test-CommandExists python3) {
    $pythonVersion = python3 --version 2>&1
    Write-Success "Python already installed: $pythonVersion"
    $skipCount++
}
elseif (Test-CommandExists python) {
    $pythonVersion = python --version 2>&1
    Write-Success "Python already installed: $pythonVersion"
    $skipCount++
}
else {
    Write-WarningMsg "Python not found. Please install manually:"
    switch ($osType) {
        "Windows" {
            Write-InfoMsg "  Option 1: https://www.python.org/downloads/"
            Write-InfoMsg "  Option 2: choco install python"
            Write-InfoMsg "  Option 3: winget install Python.Python.3.11"
        }
        "macOS" {
            Write-InfoMsg "  brew install python@3.11"
        }
        "Linux" {
            Write-InfoMsg "  Ubuntu/Debian: sudo apt-get install python3 python3-pip"
            Write-InfoMsg "  Fedora: sudo dnf install python3 python3-pip"
            Write-InfoMsg "  Arch: sudo pacman -S python python-pip"
        }
    }
    Write-WarningMsg "After installing Python, run this script again"
    exit 1
}

# ========== 2. Azure CLI ==========
Write-Host "`n[2/4] Checking Azure CLI..." -ForegroundColor Blue
if (Test-CommandExists az) {
    try {
        $azVersion = (az version --output json 2>&1 | ConvertFrom-Json).'azure-cli'
        Write-Success "Azure CLI already installed: v$azVersion"
    }
    catch {
        Write-Success "Azure CLI already installed"
    }
    $skipCount++
}
else {
    Write-WarningMsg "Azure CLI not found. Installing..."
    try {
        switch ($osType) {
            "Windows" {
                Write-InfoMsg "Installing via MSI installer..."
                $installerUrl = "https://aka.ms/installazurecliwindows"
                $installerPath = [System.IO.Path]::GetTempFileName() + ".msi"
                Write-InfoMsg "Downloading installer (this may take a minute)..."
                Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
                Write-InfoMsg "Running installer..."
                Start-Process msiexec.exe -ArgumentList "/I `"$installerPath`" /quiet /norestart" -Wait
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                Write-Success "Azure CLI installed"
                Write-WarningMsg "Please restart PowerShell and run this script again"
            }
            "macOS" {
                Write-InfoMsg "Installing via Homebrew..."
                & brew install azure-cli
                Write-Success "Azure CLI installed"
            }
            "Linux" {
                Write-InfoMsg "Installing via package manager..."
                & sudo bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
                Write-Success "Azure CLI installed"
            }
        }
        $installCount++
    }
    catch {
        Write-ErrorMsg "Failed to install Azure CLI: $_"
        Write-WarningMsg "Install manually from: https://learn.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    }
}

# ========== 3. Azure Developer CLI ==========
Write-Host "`n[3/4] Checking Azure Developer CLI..." -ForegroundColor Blue
if (Test-CommandExists azd) {
    $azdVersion = azd version 2>&1
    Write-Success "Azure Developer CLI already installed: $azdVersion"
    $skipCount++
}
else {
    Write-WarningMsg "Azure Developer CLI not found. Installing..."
    try {
        switch ($osType) {
            "Windows" {
                Write-InfoMsg "Installing via winget..."
                if (Test-CommandExists winget) {
                    & winget install Microsoft.AzureDeveloperCLI -e
                }
                else {
                    Write-InfoMsg "winget not found, using MSI installer..."
                    $installerUrl = "https://aka.ms/azd-install-windows"
                    $installerPath = [System.IO.Path]::GetTempFileName() + ".msi"
                    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
                    Start-Process msiexec.exe -ArgumentList "/I `"$installerPath`" /quiet /norestart" -Wait
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                }
                Write-Success "Azure Developer CLI installed"
                Write-WarningMsg "Please restart PowerShell and run this script again"
            }
            "macOS" {
                Write-InfoMsg "Installing via Homebrew..."
                & brew tap azure/dev
                & brew install azd
                Write-Success "Azure Developer CLI installed"
            }
            "Linux" {
                Write-InfoMsg "Installing azd..."
                & sudo bash -c "curl -fsSL https://aka.ms/install-azd.sh | bash"
                Write-Success "Azure Developer CLI installed"
            }
        }
        $installCount++
    }
    catch {
        Write-ErrorMsg "Failed to install Azure Developer CLI: $_"
        Write-WarningMsg "Install manually from: https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd"
        exit 1
    }
}

# ========== 4. Databricks CLI ==========
Write-Host "`n[4/4] Checking Databricks CLI..." -ForegroundColor Blue
if (Test-CommandExists databricks) {
    $dbVersion = databricks --version 2>&1
    Write-Success "Databricks CLI already installed: $dbVersion"
    if ($Upgrade) {
        Write-InfoMsg "Upgrading Databricks CLI..."
        & python3 -m pip install --upgrade databricks-cli
        Write-Success "Databricks CLI upgraded"
    }
    $skipCount++
}
else {
    Write-WarningMsg "Databricks CLI not found. Installing..."
    try {
        Write-InfoMsg "Installing via pip..."
        & python3 -m pip install databricks-cli
        Write-Success "Databricks CLI installed"
        $installCount++
    }
    catch {
        Write-ErrorMsg "Failed to install Databricks CLI: $_"
        exit 1
    }
}

# ========== Install Additional Dependencies ==========
Write-Host "`n[Additional] Installing Python dependencies..." -ForegroundColor Blue
try {
    Write-InfoMsg "Installing: requests, pyyaml, azure-cli-core..."
    & python3 -m pip install --quiet requests pyyaml azure-cli-core
    Write-Success "Dependencies installed"
}
catch {
    Write-WarningMsg "Could not install all Python dependencies (non-critical)"
}

# ========== Verification ==========
if (-not $SkipVerify) {
    Write-Host "`n[Verification] Testing installations..." -ForegroundColor Blue
    
    $failures = @()
    
    # Verify Azure CLI
    if (Test-CommandExists az) {
        Write-Success "Azure CLI: Available"
    }
    else {
        Write-ErrorMsg "Azure CLI: Not found"
        $failures += "Azure CLI"
    }
    
    # Verify Azure Developer CLI
    if (Test-CommandExists azd) {
        Write-Success "Azure Developer CLI: Available"
    }
    else {
        Write-ErrorMsg "Azure Developer CLI: Not found"
        $failures += "Azure Developer CLI"
    }
    
    # Verify Databricks CLI
    if (Test-CommandExists databricks) {
        Write-Success "Databricks CLI: Available"
    }
    else {
        Write-ErrorMsg "Databricks CLI: Not found"
        $failures += "Databricks CLI"
    }
    
    if ($failures.Count -gt 0) {
        Write-ErrorMsg "`nFailed to verify: $($failures -join ', ')"
        Write-WarningMsg "You may need to restart your terminal or add tools to PATH"
        exit 1
    }
}

# ========== Summary ==========
Write-Host "`n================================"
Write-Host "Installation Summary" -ForegroundColor Green
Write-Host "================================"
Write-Host "Installed: $installCount tools"
Write-Host "Already present: $skipCount tools"
Write-Host ""
Write-Success "All prerequisites installed successfully!"

Write-Host "`n[Next Steps]" -ForegroundColor Cyan
Write-Host "1. Log in to Azure:"
Write-Host "   az login"
Write-Host ""
Write-Host "2. Initialize Azure Developer CLI:"
Write-Host "   azd init"
Write-Host ""
Write-Host "3. Configure Databricks CLI (when ready):"
Write-Host "   databricks configure --token"
Write-Host ""
Write-Host "4. Deploy infrastructure:"
Write-Host "   azd provision"
Write-Host ""
Write-Host "================================`n"
