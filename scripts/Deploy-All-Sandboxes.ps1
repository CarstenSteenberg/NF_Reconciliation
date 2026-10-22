$ErrorActionPreference = 'Stop'

# ============================================================
# Shared configuration
# Expected: Nordisk_Film\BC-Config.ps1
#           Nordisk_Film\NF_Basic\scripts\Deploy-All-Sandboxes.ps1
# ============================================================
$ConfigFile = Join-Path $PSScriptRoot 'BC-Config.ps1'
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Configuration file not found: $ConfigFile"
}
. $ConfigFile

$ProjectFolder = Split-Path -Path $PSScriptRoot -Parent
$Environments = @($TestEnvironments)

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    throw 'TenantId is missing in BC-Config.ps1.'
}
if ($Environments.Count -eq 0 -or @($Environments | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw 'TestEnvironments is missing or invalid in BC-Config.ps1.'
}
if ([string]::IsNullOrWhiteSpace($SchemaSyncMode)) {
    throw 'SchemaSyncMode is missing in BC-Config.ps1.'
}
if ($SchemaSyncMode -notin @('Add', 'ForceSync')) {
    throw "Unsupported SchemaSyncMode: $SchemaSyncMode"
}

Write-Host ''
Write-Host '============================================'
Write-Host " $($AppJson.name) - Deploy to all TEST sandboxes"
Write-Host '============================================'
Write-Host "Schema mode: $SchemaSyncMode"
Write-Host ''

# ============================================================
# Find installed AL Language extension
# ============================================================
$ALExtension = Get-ChildItem `
    "$env:USERPROFILE\.vscode\extensions" `
    -Directory `
    -Filter 'ms-dynamics-smb.al-*' |
    Sort-Object Name -Descending |
    Select-Object -First 1

if ($null -eq $ALExtension) {
    throw 'Microsoft AL Language extension was not found.'
}
Write-Host 'AL extension:'
Write-Host $ALExtension.FullName
Write-Host ''

# ============================================================
# Find altool.exe
# ============================================================
$ALTool = Get-ChildItem `
    $ALExtension.FullName `
    -Recurse `
    -Filter 'altool.exe' `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -eq $ALTool) {
    throw 'altool.exe was not found in the AL Language extension.'
}
Write-Host 'ALTool:'
Write-Host $ALTool.FullName
Write-Host ''

# ============================================================
# Read app.json (do not change version for TEST)
# ============================================================
$AppJsonPath = Join-Path $ProjectFolder 'app.json'
if (-not (Test-Path -LiteralPath $AppJsonPath -PathType Leaf)) {
    throw "app.json not found: $AppJsonPath"
}
$AppJson = Get-Content -LiteralPath $AppJsonPath -Raw | ConvertFrom-Json

Write-Host 'Application:'
Write-Host "Name      : $($AppJson.name)"
Write-Host "Publisher : $($AppJson.publisher)"
Write-Host "Version   : $($AppJson.version)"
Write-Host ''

# ============================================================
# Remove locally generated APP packages for THIS extension
# (does not remove published apps in Business Central)
# ============================================================
$ExpectedPrefix = "$($AppJson.publisher)_$($AppJson.name)_"
$OldAppFiles = Get-ChildItem -LiteralPath $ProjectFolder -Filter '*.app' -File |
    Where-Object { $_.Name.StartsWith($ExpectedPrefix, [StringComparison]::OrdinalIgnoreCase) }

foreach ($OldAppFile in $OldAppFiles) {
    Write-Host "Removing old local package: $($OldAppFile.FullName)"
    Remove-Item -LiteralPath $OldAppFile.FullName -Force
}
Write-Host ''

# ============================================================
# Find AL compiler
# ============================================================
$ALCompiler = Get-ChildItem `
    $ALExtension.FullName `
    -Recurse `
    -Filter 'alc.exe' `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -eq $ALCompiler) {
    throw 'alc.exe was not found in the AL Language extension.'
}
Write-Host 'Compiler:'
Write-Host $ALCompiler.FullName
Write-Host ''

# ============================================================
# Compile current AL source, using unchanged app.json version
# ============================================================
$PackageCache = Join-Path $ProjectFolder '.alpackages'
if (-not (Test-Path -LiteralPath $PackageCache -PathType Container)) {
    throw ".alpackages folder not found: $PackageCache"
}

$AppFileName = "$($AppJson.publisher)_$($AppJson.name)_$($AppJson.version).app"
$AppFile = Join-Path $ProjectFolder $AppFileName

Write-Host '============================================'
Write-Host ' Compiling current AL project'
Write-Host '============================================'
Write-Host "Output package: $AppFile"
Write-Host ''

& $ALCompiler.FullName `
    "/project:$ProjectFolder" `
    "/packagecachepath:$PackageCache" `
    "/out:$AppFile"

if ($LASTEXITCODE -ne 0) {
    throw 'AL compilation failed.'
}
if (-not (Test-Path -LiteralPath $AppFile -PathType Leaf)) {
    throw "Compilation completed but APP file was not created: $AppFile"
}

Write-Host ''
Write-Host 'Compilation completed.'
Write-Host "Package: $AppFile"
Write-Host ''

# ============================================================
# Publish exact package to each TEST sandbox
# ============================================================
foreach ($Environment in $Environments) {
    Write-Host ''
    Write-Host '============================================'
    Write-Host " Publishing to $Environment"
    Write-Host '============================================'
    Write-Host ''

    & $ALTool.FullName publishapp `
        $AppFile `
        --environmentType Sandbox `
        --environmentName $Environment `
        --authentication AAD `
        --tenant $TenantId `
        --schemaUpdateMode $SchemaSyncMode `
        --forceUpgrade

    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '============================================'
        Write-Host " FAILED: $Environment"
        Write-Host '============================================'
        throw "Deployment failed for $Environment"
    }
    Write-Host ''
    Write-Host "SUCCESS: $Environment"
}

Write-Host ''
Write-Host '============================================'
Write-Host ' All TEST sandboxes deployed successfully'
Write-Host '============================================'
Write-Host "Application : $($AppJson.name)"
Write-Host "Version     : $($AppJson.version)"
Write-Host "Package     : $AppFileName"
Write-Host ''
