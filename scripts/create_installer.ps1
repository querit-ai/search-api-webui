# PowerShell script to create Windows installer using Inno Setup
# This script should be run after build_windows_app.sh

param(
    [string]$Arch = "x64"  # x64 or x86
)

# Configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $ProjectRoot "dist"
$AppDir = Join-Path $DistDir "SearchAPIWebUI"
$InnoSetupScript = Join-Path $ProjectRoot "installer_config.iss"

# Colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput $Title "Cyan"
    Write-ColorOutput "========================================" "Cyan"
}

# Get version from pyproject.toml
function Get-Version {
    Write-Section "Getting Version Information"

    $PyProjectPath = Join-Path $ProjectRoot "pyproject.toml"
    if (-not (Test-Path $PyProjectPath)) {
        Write-ColorOutput "Error: pyproject.toml not found" "Red"
        exit 1
    }

    $content = Get-Content $PyProjectPath -Raw
    if ($content -match 'version\s*=\s*"([^"]+)"') {
        $version = $Matches[1]
        Write-ColorOutput "Version: $version" "Green"
        return $version
    } else {
        Write-ColorOutput "Error: Could not extract version from pyproject.toml" "Red"
        exit 1
    }
}

# Check if app directory exists
function Test-AppBuild {
    Write-Section "Checking App Build"

    if (-not (Test-Path $AppDir)) {
        Write-ColorOutput "Error: App directory not found at $AppDir" "Red"
        Write-ColorOutput "Please run build_windows_app.sh first" "Red"
        exit 1
    }

    # Check for main executable
    $exePath = Join-Path $AppDir "SearchAPIWebUI.exe"
    if (-not (Test-Path $exePath)) {
        Write-ColorOutput "Error: SearchAPIWebUI.exe not found in $AppDir" "Red"
        Write-ColorOutput "Please rebuild the app using build_windows_app.sh" "Red"
        exit 1
    }

    Write-ColorOutput "App build found: $AppDir" "Green"
    Write-ColorOutput "Main executable: SearchAPIWebUI.exe" "Green"
}

# Check if Inno Setup is installed
function Test-InnoSetup {
    Write-Section "Checking Inno Setup Installation"

    $InnoSetupPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        "C:\Program Files\Inno Setup 5\ISCC.exe"
    )

    foreach ($path in $InnoSetupPaths) {
        if (Test-Path $path) {
            Write-ColorOutput "Found Inno Setup at: $path" "Green"
            return $path
        }
    }

    Write-ColorOutput "Error: Inno Setup not found" "Red"
    Write-ColorOutput "Please install Inno Setup from: https://jrsoftware.org/isdl.php" "Yellow"
    exit 1
}

# Create installer using Inno Setup
function New-Installer {
    param(
        [string]$Version,
        [string]$InnoSetupPath
    )

    Write-Section "Creating Windows Installer"

    if (-not (Test-Path $InnoSetupScript)) {
        Write-ColorOutput "Error: Inno Setup script not found at $InnoSetupScript" "Red"
        Write-ColorOutput "Please ensure installer_config.iss exists in project root" "Red"
        exit 1
    }

    Write-ColorOutput "Building installer with Inno Setup..." "Blue"
    Write-ColorOutput "Architecture: $Arch" "Blue"

    # Run Inno Setup compiler
    $arguments = @(
        "/DMyAppVersion=$Version",
        "/DMyAppArch=$Arch",
        $InnoSetupScript
    )

    try {
        & $InnoSetupPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-ColorOutput "Error: Failed to create installer" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        exit 1
    }

    Write-ColorOutput "Installer created successfully" "Green"
}

# Get installer info
function Get-InstallerInfo {
    param([string]$Version)

    Write-Section "Installer Information"

    $installerName = "SearchAPIWebUI-${Version}-Windows-${Arch}-Setup.exe"
    $installerPath = Join-Path $DistDir $installerName

    if (Test-Path $installerPath) {
        $size = (Get-Item $installerPath).Length / 1MB
        $sizeFormatted = "{0:N2} MB" -f $size

        Write-ColorOutput "Installer Name: $installerName" "Green"
        Write-ColorOutput "Installer Size: $sizeFormatted" "Green"
        Write-ColorOutput "Location: $installerPath" "Green"
    } else {
        Write-ColorOutput "Warning: Installer file not found at expected location" "Yellow"
        Write-ColorOutput "Expected: $installerPath" "Yellow"
    }
}

# Main process
function Main {
    Write-ColorOutput "=========================================" "Green"
    Write-ColorOutput "Search API WebUI - Installer Creator" "Green"
    Write-ColorOutput "=========================================" "Green"
    Write-ColorOutput "Architecture: $Arch" "Blue"

    $version = Get-Version
    Test-AppBuild
    $innoSetupPath = Test-InnoSetup
    New-Installer -Version $version -InnoSetupPath $innoSetupPath
    Get-InstallerInfo -Version $version

    Write-Section "Installer Creation Complete!"
    Write-ColorOutput "Your installer is ready in the dist/ folder" "Green"
    Write-Host ""
    Write-ColorOutput "To test the installer:" "Yellow"
    Write-ColorOutput "  1. Run the setup executable from dist/" "Yellow"
    Write-ColorOutput "  2. Follow the installation wizard" "Yellow"
    Write-ColorOutput "  3. Launch Search API WebUI from Start Menu" "Yellow"
    Write-Host ""
}

# Run main
Main
