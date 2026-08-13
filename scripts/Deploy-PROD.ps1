$ErrorActionPreference = "Stop"

#
# ============================================================
# NF_Basic - Deploy to all PROD environments
# ============================================================
#

$ProjectFolder = Split-Path $PSScriptRoot -Parent

#
# Authentication
#
$TenantId = "7b6a9158-8e4c-47d1-bed4-a2e25046dda1"
$ClientId = "82828c4f-5454-4739-9e27-2f36883324b2"
$ClientSecret = "hgo8Q~ZzyFJylpRAhjZ6WESqHX5jk2ami2NnnakN"

#
# Client Secret is stored as Windows User Environment Variable:
# BC_CLIENT_SECRET
#

if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw "BC_CLIENT_SECRET environment variable is not configured."
}

#
# Production environments
#
$Environments = @(
    "PROD_NordiskFilm_DK",
    "PROD_NordiskFilm_SE",
    "PROD_NordiskFilm_NO",
    "PROD_NordiskFilm_FI"
)

Write-Host ""
Write-Host "======================================================"
Write-Host " NF_Basic - Deploy to all PROD environments"
Write-Host "======================================================"
Write-Host ""

#
# ============================================================
# Find app.json
# ============================================================
#

$AppJsonPath = Join-Path $ProjectFolder "app.json"

if (-not (Test-Path $AppJsonPath)) {
    throw "app.json not found: $AppJsonPath"
}

$AppJson = Get-Content $AppJsonPath -Raw | ConvertFrom-Json

Write-Host "Application : $($AppJson.name)"
Write-Host "Publisher   : $($AppJson.publisher)"
Write-Host "Version     : $($AppJson.version)"
Write-Host ""

#
# ============================================================
# Increment version
#
# Example:
# 1.0.0.7 -> 1.0.0.8
# ============================================================
#

$CurrentVersion = [version]$AppJson.version

$NewVersion = [version]::new(
    $CurrentVersion.Major,
    $CurrentVersion.Minor,
    $CurrentVersion.Build,
    $CurrentVersion.Revision + 1
)

$AppJson.version = $NewVersion.ToString()

$AppJson |
    ConvertTo-Json -Depth 100 |
    Set-Content $AppJsonPath -Encoding UTF8

Write-Host "======================================================"
Write-Host " Version changed"
Write-Host "======================================================"
Write-Host ""
Write-Host "$CurrentVersion -> $NewVersion"
Write-Host ""

#
# ============================================================
# Find Microsoft AL Language extension
# ============================================================
#

$ALExtension = Get-ChildItem `
    "$env:USERPROFILE\.vscode\extensions" `
    -Directory `
    -Filter "ms-dynamics-smb.al-*" |
    Sort-Object Name -Descending |
    Select-Object -First 1

if ($null -eq $ALExtension) {
    throw "Microsoft AL Language extension was not found."
}

Write-Host "AL extension:"
Write-Host $ALExtension.FullName
Write-Host ""

#
# ============================================================
# Find AL compiler (alc.exe)
# ============================================================
#

$ALCompiler = Get-ChildItem `
    $ALExtension.FullName `
    -Recurse `
    -Filter "alc.exe" `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -eq $ALCompiler) {
    throw "alc.exe was not found in the AL Language extension."
}

Write-Host "AL compiler:"
Write-Host $ALCompiler.FullName
Write-Host ""

#
# ============================================================
# Package cache
# ============================================================
#

$PackageCache = Join-Path $ProjectFolder ".alpackages"

if (-not (Test-Path $PackageCache)) {
    throw ".alpackages folder not found: $PackageCache"
}

#
# ============================================================
# Determine new APP filename
# ============================================================
#

$AppFileName =
    "$($AppJson.publisher)_$($AppJson.name)_$NewVersion.app"

$AppFile = Join-Path $ProjectFolder $AppFileName

Write-Host "New APP package:"
Write-Host $AppFile
Write-Host ""

#
# Remove existing package with same filename if present
#
if (Test-Path $AppFile) {

    Write-Host "Removing existing package:"
    Write-Host $AppFile

    Remove-Item $AppFile -Force

    Write-Host ""
}

#
# ============================================================
# Compile current AL source
# ============================================================
#

Write-Host "======================================================"
Write-Host " Compiling NF_Basic $NewVersion"
Write-Host "======================================================"
Write-Host ""

& $ALCompiler.FullName `
    "/project:$ProjectFolder" `
    "/packagecachepath:$PackageCache" `
    "/out:$AppFile"

if ($LASTEXITCODE -ne 0) {
    throw "AL compilation failed."
}

if (-not (Test-Path $AppFile)) {
    throw "Compilation completed but APP file was not created: $AppFile"
}

Write-Host ""
Write-Host "Compilation successful."
Write-Host ""
Write-Host "Package:"
Write-Host $AppFile
Write-Host ""

#
# ============================================================
# Show deployment information
# ============================================================
#

Write-Host "======================================================"
Write-Host " READY FOR PRODUCTION DEPLOYMENT"
Write-Host "======================================================"
Write-Host ""
Write-Host "Application : $($AppJson.name)"
Write-Host "Publisher   : $($AppJson.publisher)"
Write-Host "Old version : $CurrentVersion"
Write-Host "New version : $NewVersion"
Write-Host ""
Write-Host "Environments:"
Write-Host ""

foreach ($Environment in $Environments) {
    Write-Host "  $Environment"
}

Write-Host ""
Write-Host "======================================================"
Write-Host " Starting production deployment"
Write-Host "======================================================"
Write-Host ""

#
# ============================================================
# Deploy using existing Deploy-BC.ps1
# ============================================================
#

& "$PSScriptRoot\Deploy-BC.ps1" `
    -AppFile $AppFile `
    -TenantId $TenantId `
    -ClientId $ClientId `
    -ClientSecret $ClientSecret `
    -Environments $Environments `
    -SchemaSyncMode "Add"

#
# Check whether Deploy-BC.ps1 failed
#
if ($LASTEXITCODE -ne 0) {
    throw "Production deployment failed."
}

#
# Clear secret from current PowerShell variable
#
$ClientSecret = $null

Write-Host ""
Write-Host "======================================================"
Write-Host " PROD deployment completed successfully"
Write-Host "======================================================"
Write-Host ""
Write-Host "Application : $($AppJson.name)"
Write-Host "Version     : $NewVersion"
Write-Host ""