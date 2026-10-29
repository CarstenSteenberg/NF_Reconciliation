$ErrorActionPreference = 'Stop'

# SECURITY: PROD deployment is only allowed from MAIN
# ============================================================
$ProjectFolder = Split-Path -Parent $PSScriptRoot

$Branch = git -C $ProjectFolder branch --show-current

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Branch)) {
    throw "Unable to determine the current Git branch."
}

$Branch = $Branch.Trim()

if ($Branch -ne 'main') {
    throw "PROD deployment is blocked! Current branch: '$Branch'. Only 'main' is allowed."
}

Write-Host "Git branch verified: $Branch" -ForegroundColor Green

# ============================================================
# SECURITY: Verify clean Git working tree
# ============================================================

$GitStatus = @(
    git -C $ProjectFolder status --porcelain --untracked-files=normal
)

if ($LASTEXITCODE -ne 0) {
    throw "Unable to check Git working tree."
}

if ($GitStatus.Count -gt 0) {
    Write-Host "Uncommitted changes detected:" -ForegroundColor Red
    $GitStatus | ForEach-Object { Write-Host $_ }

    throw "PROD deployment blocked! Commit or discard local changes first."
}

Write-Host "Git working tree verified: CLEAN" -ForegroundColor Green


# ============================================================
# SECURITY: Verify local MAIN matches origin/main
# ============================================================

Write-Host "Checking origin/main..." -ForegroundColor Cyan

git -C $ProjectFolder fetch origin main --quiet

if ($LASTEXITCODE -ne 0) {
    throw "Unable to fetch origin/main. PROD deployment blocked."
}

$LocalCommit = (git -C $ProjectFolder rev-parse main).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine local main commit."
}

$RemoteCommit = (git -C $ProjectFolder rev-parse refs/remotes/origin/main).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine origin/main commit."
}

if ($LocalCommit -ne $RemoteCommit) {
    throw @"
PROD deployment blocked!

Local main and origin/main are different.

Local : $LocalCommit
Remote: $RemoteCommit

Commit and push your changes, or pull the latest main.
"@
}

Write-Host "Git synchronization verified: MAIN = ORIGIN/MAIN" -ForegroundColor Green


# ============================================================
# Load shared configuration
# ============================================================
$ConfigFile = Join-Path $PSScriptRoot 'BC-Config.ps1'
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Configuration file not found: $ConfigFile"
}
. $ConfigFile

if ([string]::IsNullOrWhiteSpace($TenantId)) { throw 'TenantId is missing in BC-Config.ps1.' }
if ([string]::IsNullOrWhiteSpace($ClientId)) { throw 'ClientId is missing in BC-Config.ps1.' }
if ([string]::IsNullOrWhiteSpace($ClientSecret)) { throw 'ClientSecret is missing in BC-Config.ps1.' }
if (-not $ProdEnvironments -or @($ProdEnvironments).Count -eq 0) {
    throw 'ProdEnvironments is missing in BC-Config.ps1.'
}

# Deploy-BC-Admin.ps1 reads the secret from the process environment.
$env:BC_CLIENT_SECRET = $ClientSecret
$ClientSecret = $null

# Restore app.json unless all selected deployments succeed.
$originalJson = $null
$versionChanged = $false
$deploymentSucceeded = $false

try {
    # ============================================================
    # Initialization and app.json (before creating the dialog)
    # ============================================================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $ProjectFolder = Split-Path $PSScriptRoot -Parent
    $names = @($ProdEnvironments)
    
    # Ensure only PROD environments are selected
    foreach ($name in $names) {
        if ($name -notlike 'PROD_*') {
            throw "Invalid PROD environment: $name"
        }
    }
    $appJsonPath = Join-Path $ProjectFolder 'app.json'

    if (-not (Test-Path -LiteralPath $appJsonPath -PathType Leaf)) {
        throw "Missing $appJsonPath"
    }

    $appJson = Get-Content -LiteralPath $appJsonPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($appJson.name)) {
        throw "App name is missing in $appJsonPath"
    }
    $appName = [string]$appJson.name

    # ============================================================
    # Select PROD environments
    # ============================================================
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$appName - PROD deployment (Admin API)"
    $form.Size = New-Object System.Drawing.Size(485,370)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Select production environments:'
    $label.SetBounds(20,15,400,25)
    $form.Controls.Add($label)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.SetBounds(20,45,430,125)
    $list.CheckOnClick = $true
    foreach ($name in $names) {
        [void]$list.Items.Add($name,$true)
    }
    $form.Controls.Add($list)

    # ============================================================
    # Deployment mode
    # ============================================================
    $compile = New-Object System.Windows.Forms.RadioButton
    $compile.Text = 'Increment version, compile and deploy'
    $compile.SetBounds(20,185,430,25)
    $compile.Checked = $true
    $form.Controls.Add($compile)

    $reuse = New-Object System.Windows.Forms.RadioButton
    $reuse.Text = 'Deploy existing APP'
    $reuse.SetBounds(20,215,430,25)
    $form.Controls.Add($reuse)

    # ============================================================
    # Buttons
    # ============================================================
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Deploy'
    $ok.SetBounds(245,270,95,32)
    $ok.DialogResult = 'OK'
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.SetBounds(350,270,95,32)
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    # ============================================================
    # Show dialog
    # ============================================================
    try {
        if ($form.ShowDialog() -ne 'OK') {
            Write-Host 'Deployment cancelled.'
            return
        }
        $environments = @($list.CheckedItems | ForEach-Object { [string]$_ })
        $useExisting = $reuse.Checked
    }
    finally {
        $form.Dispose()
    }

    if ($environments.Count -eq 0) { throw 'No environments selected.' }

    Write-Host ''
    Write-Host '=========================================='
    Write-Host " $appName - PROD Deployment"
    Write-Host '=========================================='
    Write-Host "Application : $appName"
    Write-Host "Publisher   : $($appJson.publisher)"
    Write-Host "Version     : $($appJson.version)"
    Write-Host ''

    # ============================================================
    # Select existing APP or compile new version
    # ============================================================
    if ($useExisting) {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = 'Business Central APP (*.app)|*.app'
        $dialog.InitialDirectory = $ProjectFolder
        $dialog.CheckFileExists = $true

        if ($dialog.ShowDialog() -ne 'OK') {
            Write-Host 'Deployment cancelled.'
            return
        }
        $appFile = $dialog.FileName
        Write-Host "Using existing APP: $appFile"
    }
    else {
        $originalJson = [IO.File]::ReadAllText($appJsonPath)
        $oldVersion = [version]$appJson.version
        $newVersion = [version]::new(
            $oldVersion.Major,
            $oldVersion.Minor,
            $oldVersion.Build,
            $oldVersion.Revision + 1
        )
        $appJson.version = $newVersion.ToString()
        Write-Host "Version: $oldVersion -> $newVersion"

        $extensions = Get-ChildItem `
            "$env:USERPROFILE\.vscode\extensions" `
            -Directory `
            -Filter 'ms-dynamics-smb.al-*' |
            Sort-Object Name -Descending

        $compiler = $extensions |
            ForEach-Object {
                Get-ChildItem $_.FullName `
                    -Recurse `
                    -Filter 'alc.exe' `
                    -ErrorAction SilentlyContinue
            } |
            Select-Object -First 1

        if (-not $compiler) { throw 'AL compiler not found.' }

        $cache = Join-Path $ProjectFolder '.alpackages'
        if (-not (Test-Path $cache)) { throw '.alpackages not found.' }

        $appFile = Join-Path $ProjectFolder `
            "$($appJson.publisher)_$appName`_$newVersion.app"

        if (Test-Path -LiteralPath $appFile) {
            throw "Package already exists: $appFile"
        }

        try {
            $appJson |
                ConvertTo-Json -Depth 100 |
                Set-Content -LiteralPath $appJsonPath -Encoding UTF8
            $versionChanged = $true

            Write-Host "Compiling $appName $newVersion..."
            & $compiler.FullName `
                "/project:$ProjectFolder" `
                "/packagecachepath:$cache" `
                "/out:$appFile"

            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $appFile)) {
                throw 'AL compilation failed.'
            }
            Write-Host "Compilation successful: $appFile"
        }
        catch {
            # Outer finally restores app.json if it was changed.
            throw
        }
    }

    # ============================================================
    # Confirm PROD deployment
    # ============================================================
    $confirmation = [System.Windows.Forms.MessageBox]::Show(
        "Application: $appName`r`nAPP: $appFile`r`n`r`nTargets:`r`n$($environments -join "`r`n")`r`n`r`nDeploy using Admin Center API?",
        "Confirm $appName PROD deployment",
        'YesNo',
        'Warning'
    )

    if ($confirmation -ne 'Yes') {
        Write-Host 'Cancelled before upload.'
        return
    }

    # ============================================================
    # Deploy using Admin Center API
    # ============================================================
    try {
        & (Join-Path $PSScriptRoot 'Deploy-BC-Admin.ps1') `
            -AppFile $appFile `
            -TenantId $TenantId `
            -ClientId $ClientId `
            -Environments $environments `
            -SchemaSyncMode $SchemaSyncMode `
            -TimeoutMinutes $TimeoutMinutes `
            -PollSeconds $PollSeconds `
            -ErrorAction Stop

        if (-not $?) {
            throw 'Deploy-BC-Admin.ps1 reported a PowerShell error.'
        }

        # Success assumes Deploy-BC-Admin.ps1 throws for any failed environment.
        $deploymentSucceeded = $true
        Write-Host ''
        Write-Host '=========================================='
        Write-Host " $appName - PROD deployment completed successfully"
        Write-Host '=========================================='
    }
    catch {
        Write-Host ''
        Write-Host "PROD deployment failed for $appName`:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}
finally {
    try {
        if ($versionChanged -and -not $deploymentSucceeded) {
            [IO.File]::WriteAllText(
                $appJsonPath,
                $originalJson,
                [Text.UTF8Encoding]::new($false)
            )
            Write-Host 'Deployment was not fully successful: app.json restored.' -ForegroundColor Yellow
        }
        elseif ($versionChanged -and $deploymentSucceeded) {
            Write-Host 'Deployment successful: new app.json version retained.' -ForegroundColor Green
            Write-Host 'Remember to commit and push app.json before the next PROD deployment.' -ForegroundColor Yellow
        }
    }
    finally {
        Remove-Item Env:\BC_CLIENT_SECRET -ErrorAction SilentlyContinue
    }
}
