# PowerShell script to sign Windows application with self-signed certificate
# This script can use either a provided certificate (from GitHub Secrets) or create a self-signed certificate

param(
    [string]$AppPath = "dist\SearchAPIWebUI\SearchAPIWebUI.exe",
    [string]$CertSubject = "CN=QUERIT PRIVATE LIMITED, O=QUERIT PRIVATE LIMITED, C=SG",
    [string]$CertificateBase64 = "",
    [string]$CertificatePassword = "",
    [switch]$ExportCert = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

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

# Check if running as Administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create self-signed certificate
function New-CodeSigningCert {
    Write-Section "Creating Self-Signed Certificate"

    Write-ColorOutput "Certificate Subject: $CertSubject" "Blue"

    try {
        # Check if certificate already exists
        $existingCert = Get-ChildItem -Path Cert:\CurrentUser\My |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) }

        if ($existingCert) {
            Write-ColorOutput "Found existing valid certificate" "Yellow"
            Write-ColorOutput "Thumbprint: $($existingCert.Thumbprint)" "Yellow"
            Write-ColorOutput "Expires: $($existingCert.NotAfter)" "Yellow"

            # In CI environment or non-interactive mode, automatically reuse existing certificate
            if ($env:CI -eq "true" -or -not [Environment]::UserInteractive) {
                Write-ColorOutput "Running in CI/non-interactive mode, reusing existing certificate" "Yellow"
                return $existingCert
            }

            $reuse = Read-Host "Reuse existing certificate? (Y/n)"
            if ($reuse -ne "n" -and $reuse -ne "N") {
                return $existingCert
            }
        }

        # Create new certificate
        Write-ColorOutput "Creating new self-signed certificate..." "Blue"

        $cert = New-SelfSignedCertificate `
            -Subject $CertSubject `
            -Type CodeSigningCert `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddYears(3) `
            -KeyUsage DigitalSignature `
            -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")

        Write-ColorOutput "Certificate created successfully!" "Green"
        Write-ColorOutput "Thumbprint: $($cert.Thumbprint)" "Green"
        Write-ColorOutput "Expires: $($cert.NotAfter)" "Green"

        return $cert
    }
    catch {
        Write-ColorOutput "Error creating certificate: $_" "Red"
        exit 1
    }
}


# Import certificate from base64 string (for CI/CD)
function Import-CertificateFromBase64 {
    param(
        [string]$Base64String,
        [string]$Password
    )

    Write-Section "Importing Certificate from Secret"

    try {
        # Decode base64 to bytes
        Write-ColorOutput "Decoding certificate..." "Blue"
        $certBytes = [System.Convert]::FromBase64String($Base64String)

        # Save to temporary file
        $tempCertPath = Join-Path $env:TEMP "imported-cert.pfx"
        [System.IO.File]::WriteAllBytes($tempCertPath, $certBytes)

        # Import certificate
        Write-ColorOutput "Importing certificate to CurrentUser store..." "Blue"
        $securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
        $cert = Import-PfxCertificate -FilePath $tempCertPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $securePassword -Exportable

        # Clean up temp file
        Remove-Item $tempCertPath -Force

        Write-ColorOutput "Certificate imported successfully!" "Green"
        Write-ColorOutput "Thumbprint: $($cert.Thumbprint)" "Green"
        Write-ColorOutput "Subject: $($cert.Subject)" "Green"
        Write-ColorOutput "Expires: $($cert.NotAfter)" "Green"

        return $cert
    }
    catch {
        Write-ColorOutput "Error importing certificate: $_" "Red"
        exit 1
    }
}

# Export certificate for distribution
function Export-SigningCertificate {
    param($Certificate)

    Write-Section "Exporting Certificate"

    $certDir = Join-Path $ProjectRoot "dist"
    $certPath = Join-Path $certDir "QUERIT-CodeSigning.cer"

    try {
        Microsoft.PowerShell.Security\Export-Certificate -Cert $Certificate -FilePath $certPath -Force | Out-Null
        Write-ColorOutput "Certificate exported to: $certPath" "Green"
        Write-ColorOutput "" "White"
        Write-ColorOutput "Users can install this certificate to trust the application:" "Yellow"
        Write-ColorOutput "  1. Double-click QUERIT-CodeSigning.cer" "Yellow"
        Write-ColorOutput "  2. Click 'Install Certificate'" "Yellow"
        Write-ColorOutput "  3. Select 'Local Machine' (requires admin)" "Yellow"
        Write-ColorOutput "  4. Place in 'Trusted Root Certification Authorities'" "Yellow"
    }
    catch {
        Write-ColorOutput "Warning: Failed to export certificate: $_" "Yellow"
    }
}

# Sign the application
function Sign-Application {
    param(
        $Certificate,
        [string]$FilePath
    )

    Write-Section "Signing Application"

    $fullPath = Join-Path $ProjectRoot $FilePath

    if (-not (Test-Path $fullPath)) {
        Write-ColorOutput "Error: Application not found at $fullPath" "Red"
        Write-ColorOutput "Please build the application first" "Red"
        exit 1
    }

    Write-ColorOutput "Signing: $fullPath" "Blue"

    try {
        # Sign the executable
        $result = Set-AuthenticodeSignature -FilePath $fullPath `
            -Certificate $Certificate `
            -TimestampServer "http://timestamp.digicert.com" `
            -HashAlgorithm SHA256

        if ($result.Status -eq "Valid") {
            Write-ColorOutput "Application signed successfully!" "Green"
            Write-ColorOutput "Status: $($result.Status)" "Green"
            Write-ColorOutput "Signature Type: $($result.SignatureType)" "Green"
        }
        else {
            Write-ColorOutput "Warning: Signature status is $($result.Status)" "Yellow"
            if ($result.StatusMessage) {
                Write-ColorOutput "Message: $($result.StatusMessage)" "Yellow"
            }
        }

        return $result
    }
    catch {
        Write-ColorOutput "Error signing application: $_" "Red"
        exit 1
    }
}

# Verify signature
function Test-Signature {
    param([string]$FilePath)

    Write-Section "Verifying Signature"

    $fullPath = Join-Path $ProjectRoot $FilePath

    try {
        $signature = Get-AuthenticodeSignature -FilePath $fullPath

        Write-ColorOutput "Signature Status: $($signature.Status)" "Blue"
        Write-ColorOutput "Signer: $($signature.SignerCertificate.Subject)" "Blue"
        Write-ColorOutput "Timestamp: $($signature.TimeStamperCertificate.NotAfter)" "Blue"

        if ($signature.Status -eq "Valid") {
            Write-ColorOutput "Signature is VALID" "Green"
        }
        else {
            Write-ColorOutput "Signature verification: $($signature.Status)" "Yellow"
            Write-ColorOutput "This is normal for self-signed certificates" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Error verifying signature: $_" "Red"
    }
}

# Main process
function Main {
    Write-ColorOutput "=========================================" "Green"
    Write-ColorOutput "Windows Application Code Signing Tool" "Green"
    Write-ColorOutput "=========================================" "Green"
    Write-Host ""

    # Check administrator privileges (recommended but not required)
    if (-not (Test-Administrator)) {
        Write-ColorOutput "Note: Running without administrator privileges" "Yellow"
        Write-ColorOutput "This is fine, but the certificate will be user-scoped only" "Yellow"
        Write-Host ""
    }

    # Determine certificate source
    $cert = $null
    if ($CertificateBase64 -and $CertificatePassword) {
        Write-ColorOutput "Using certificate from environment/secrets" "Blue"
        $cert = Import-CertificateFromBase64 -Base64String $CertificateBase64 -Password $CertificatePassword
    }
    else {
        Write-ColorOutput "Using self-signed certificate" "Blue"
        $cert = New-CodeSigningCert
    }

    # Sign the application
    $signResult = Sign-Application -Certificate $cert -FilePath $AppPath

    # Verify signature
    Test-Signature -FilePath $AppPath

    # Export certificate if requested
    if ($ExportCert) {
        Export-SigningCertificate -Certificate $cert
    }

    Write-Section "Signing Complete!"
    Write-ColorOutput "Your application has been signed" "Green"
    Write-Host ""

    Write-ColorOutput "Important Notes:" "Yellow"
    Write-ColorOutput "  - This is a self-signed certificate" "Yellow"
    Write-ColorOutput "  - Users will still see SmartScreen warnings" "Yellow"
    Write-ColorOutput "  - However, the application will show publisher info" "Yellow"
    Write-ColorOutput "  - For production, consider purchasing a code signing certificate" "Yellow"
    Write-Host ""

    if ($ExportCert) {
        Write-ColorOutput "Next Steps:" "Cyan"
        Write-ColorOutput "  1. Distribute QUERIT-CodeSigning.cer with your application" "Cyan"
        Write-ColorOutput "  2. Instruct users to install the certificate (see above)" "Cyan"
        Write-ColorOutput "  3. After installation, SmartScreen warnings will be reduced" "Cyan"
    }
    Write-Host ""
}

# Run main
Main
