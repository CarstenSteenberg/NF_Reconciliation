$ErrorActionPreference = "Stop"

#
# Project folder = parent of scripts folder
#
$ProjectFolder = Split-Path $PSScriptRoot -Parent

#
# TEST environments
#
$Environments = @(
    "TEST_NordiskFilm_DK",
    "TEST_NordiskFilm_SE",
    "TEST_NordiskFilm_NO",
    "TEST_NordiskFilm_FI"
)

#
# Tenant
#
$TenantId = "7b6a9158-8e4c-47d1-bed4-a2e25046dda1"

Write-Host ""
Write-Host "============================================"
Write-Host " NF_Basic - Deploy to all TEST sandboxes"
Write-Host "============================================"
Write-Host ""

#
# Find installed AL Language extension
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
# Find altool.exe
#
$ALTool = Get-ChildItem `
    $ALExtension.FullName `
    -Recurse `
    -Filter "altool.exe" `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -eq $ALTool) {
    throw "altool.exe was not found in the AL Language extension."
}

Write-Host "ALTool:"
Write-Host $ALTool.FullName
Write-Host ""

#
# Find app.json
#
$AppJsonPath = Join-Path $ProjectFolder "app.json"

if (-not (Test-Path $AppJsonPath)) {
    throw "app.json not found: $AppJsonPath"
}

$AppJson = Get-Content $AppJsonPath -Raw | ConvertFrom-Json

Write-Host "Application:"
Write-Host "Name      : $($AppJson.name)"
Write-Host "Publisher : $($AppJson.publisher)"
Write-Host "Version   : $($AppJson.version)"
Write-Host ""

#
# Remove old generated APP package for THIS extension.
#
# This prevents publishapp from accidentally selecting an old package.
#
$ExpectedPrefix = "$($AppJson.publisher)_$($AppJson.name)_"

$OldAppFiles = Get-ChildItem `
    $ProjectFolder `
    -Filter "*.app" `
    -File |
    Where-Object {
        $_.Name.StartsWith($ExpectedPrefix)
    }

foreach ($OldAppFile in $OldAppFiles) {
    Write-Host "Removing old package:"
    Write-Host $OldAppFile.FullName

    Remove-Item $OldAppFile.FullName -Force
}

Write-Host ""

#
# Compile/package current AL source
#
Write-Host "============================================"
Write-Host " Compiling current AL project"
Write-Host "============================================"
Write-Host ""

#
# Find alc.exe
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

Write-Host "Compiler:"
Write-Host $ALCompiler.FullName
Write-Host ""

#
# Symbol packages folder
#
$PackageCache = Join-Path $ProjectFolder ".alpackages"

if (-not (Test-Path $PackageCache)) {
    throw ".alpackages folder not found: $PackageCache"
}

#
# Output APP filename
#
$AppFileName =
    "$($AppJson.publisher)_$($AppJson.name)_$($AppJson.version).app"

$AppFile = Join-Path $ProjectFolder $AppFileName

Write-Host "Output package:"
Write-Host $AppFile
Write-Host ""

#
# Compile
#
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
Write-Host "Compilation completed."
Write-Host "Package: $AppFile"
Write-Host ""

#
# Deploy exact package to every TEST sandbox
#
foreach ($Environment in $Environments) {

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Publishing to $Environment"
    Write-Host "============================================"
    Write-Host ""

    & $ALTool.FullName publishapp `
        $AppFile `
        --environmentType Sandbox `
        --environmentName $Environment `
        --authentication AAD `
        --tenant $TenantId `
        --schemaUpdateMode ForceSync `
        --forceUpgrade

    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "============================================"
        Write-Host " FAILED: $Environment"
        Write-Host "============================================"

        throw "Deployment failed for $Environment"
    }

    Write-Host ""
    Write-Host "SUCCESS: $Environment"
}

Write-Host ""
Write-Host "============================================"
Write-Host " All TEST sandboxes deployed successfully"
Write-Host "============================================"
Write-Host ""
Write-Host "Application : $($AppJson.name)"
Write-Host "Version     : $($AppJson.version)"
Write-Host "Package     : $AppFileName"
Write-Host ""