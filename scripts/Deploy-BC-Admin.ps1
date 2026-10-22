[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AppFile,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string[]]$Environments,
    [ValidateSet('Add','ForceSync')][string]$SchemaSyncMode = 'Add',
    [ValidateSet('Immediate','UpdateWindow')][string]$DeploymentSchedule = 'Immediate',
    [int]$TimeoutMinutes = 20,
    [int]$PollSeconds = 15,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
# Required for HttpClient and MultipartFormDataContent
Add-Type -AssemblyName System.Net.Http

function Get-HttpErrorDetails {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $message = $ErrorRecord.Exception.Message
    $response = $ErrorRecord.Exception.Response
    if ($null -ne $response) {
        try {
            $code = [int]$response.StatusCode
            $message = "HTTP ${code}: $message"
            # PowerShell 7 may expose the response body via ErrorDetails.
            if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
                $message += " | $($ErrorRecord.ErrorDetails.Message)"
            }
        } catch { }
    }
    return $message
}

function Show-TokenDiagnostics {
    param([string]$AccessToken)
    try {
        $parts = $AccessToken.Split('.')
        if ($parts.Count -lt 2) { throw 'Token is not a JWT.' }
        $payload = $parts[1].Replace('-', '+').Replace('_', '/')
        $payload = $payload.PadRight($payload.Length + ((4 - ($payload.Length % 4)) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        Write-Host "Token audience: $($claims.aud)"
        Write-Host "Token tenant:   $($claims.tid)"
        Write-Host "Token roles:    $($claims.roles -join ', ')"
        if (@($claims.roles) -notcontains 'AdminCenter.ReadWrite.All') {
            Write-Warning 'AdminCenter.ReadWrite.All is missing from the access token. Admin Center API access may fail.'
        }
    } catch {
        Write-Warning "Could not inspect token claims: $($_.Exception.Message)"
    }
}

if (-not (Test-Path -LiteralPath $AppFile -PathType Leaf)) { throw "APP not found: $AppFile" }
$AppFile = (Resolve-Path -LiteralPath $AppFile).ProviderPath
if ([IO.Path]::GetExtension($AppFile) -ine '.app') { throw 'Expected .app file.' }
if ((Get-Item -LiteralPath $AppFile).Length -gt 50MB) { throw 'APP exceeds 50 MB limit.' }
if ($TimeoutMinutes -le 0 -or $PollSeconds -le 0) { throw 'TimeoutMinutes and PollSeconds must be greater than zero.' }

if ($WhatIf) {
    foreach ($environment in $Environments) { Write-Host "WhatIf: would upload $AppFile to $environment" }
    return
}

# Deploy-PROD.ps1 loads BC-Config.ps1 and passes the secret via a process environment variable.
$ClientSecret = [Environment]::GetEnvironmentVariable('BC_CLIENT_SECRET', 'Process')
if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw 'BC_CLIENT_SECRET is missing. Run this script via Deploy-PROD.ps1, which loads BC-Config.ps1.'
}

Write-Host 'Requesting Business Central OAuth token...'
try {
    $token = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            grant_type    = 'client_credentials'
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = 'https://api.businesscentral.dynamics.com/.default'
        }
} catch {
    throw "OAuth token request failed: $(Get-HttpErrorDetails $_)"
} finally {
    $ClientSecret = $null
}

if ([string]::IsNullOrWhiteSpace($token.access_token)) { throw 'OAuth response contains no access token.' }
Show-TokenDiagnostics -AccessToken $token.access_token

$headers = @{ Authorization = "Bearer $($token.access_token)" }
$base = 'https://api.businesscentral.dynamics.com/admin/v2.29/applications/BusinessCentral/environments'
$results = @()
$abortAfterAuthError = $false

foreach ($environment in $Environments) {
    $operationId = ''
    $appId = ''
    $status = 'Failed'
    $details = ''

    if ($abortAfterAuthError) {
        $results += [pscustomobject]@{
            Environment = $environment; Status = 'Skipped'; OperationId = ''; AppId = ''
            Details = 'Skipped after HTTP 401/403 in previous environment.'
        }
        continue
    }

    try {
        Write-Host "`n=== $environment ==="
        $root = "$base/$([uri]::EscapeDataString($environment))"

        Write-Host "[GET environment] $root"
        try {
            $envInfo = Invoke-RestMethod -Method Get -Uri $root -Headers $headers
            Write-Host '[GET environment] OK' -ForegroundColor Green
        } catch {
            throw "GET environment failed: $(Get-HttpErrorDetails $_)"
        }

        $envRecord = if ($envInfo.value) { @($envInfo.value)[0] } else { $envInfo }
        if ($envRecord.type -ne 'Production') {
            throw "Environment is not Production (reported: $($envRecord.type))."
        }

        $uri = "$root/apps/pteInstall"
        Write-Host "[POST pteInstall] $uri"
        $http = $null
        $multipart = $null
        $fileStream = $null
        try {
            $http = [System.Net.Http.HttpClient]::new()
            $http.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $token.access_token)
            $http.Timeout = [TimeSpan]::FromMinutes(5)

            $multipart = [System.Net.Http.MultipartFormDataContent]::new()
            $fileStream = [IO.File]::OpenRead($AppFile)
            $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
            $multipart.Add($fileContent, 'extensionFile', [IO.Path]::GetFileName($AppFile))

            foreach ($item in @{
                deploymentSchedule = $DeploymentSchedule
                syncMode = $SchemaSyncMode
                languageId = 'en-US'
                acceptIsvEula = 'true'
                installOrUpdateNeededDependencies = 'false'
            }.GetEnumerator()) {
                $multipart.Add([System.Net.Http.StringContent]::new([string]$item.Value), $item.Key)
            }

            $response = $http.PostAsync($uri, $multipart).GetAwaiter().GetResult()
            $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) {
                throw "POST pteInstall failed: HTTP $([int]$response.StatusCode) ($($response.ReasonPhrase)): $responseText"
            }
            $operation = $responseText | ConvertFrom-Json
        } finally {
            if ($multipart) { $multipart.Dispose() }
            if ($fileStream) { $fileStream.Dispose() }
            if ($http) { $http.Dispose() }
        }

        $operationId = [string]$operation.id
        $appId = [string]$operation.appId
        if (-not $operationId -or -not $appId) {
            throw 'Upload response did not contain operation id and appId.'
        }
        Write-Host "Accepted: App $appId; Operation $operationId; Status $($operation.status)"

        if ($DeploymentSchedule -ne 'Immediate') {
            $status = 'Scheduled'
            $details = 'Installation scheduled for update window.'
        } else {
            $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
            do {
                $opUrl = "$root/apps/$appId/operations/$operationId"
                try {
                    $current = Invoke-RestMethod -Method Get -Uri $opUrl -Headers $headers
                } catch {
                    throw "GET operation status failed ($opUrl): $(Get-HttpErrorDetails $_)"
                }
                if ($current.value) { $current = @($current.value)[0] }
                $status = [string]$current.status
                $details = [string]$current.errorMessage
                Write-Host "  Status: $status"
                if ($status -in @('Succeeded','Failed','Canceled','Skipped')) { break }
                if ((Get-Date) -ge $deadline) {
                    $status = 'Timeout'
                    $details = 'Check Admin Center for final status.'
                    break
                }
                Start-Sleep -Seconds $PollSeconds
            } while ($true)
        }
    } catch {
        $status = 'Failed'
        $details = $_.Exception.Message
        Write-Warning "${environment}: $details"
        if ($details -match 'HTTP\s+(401|403)\b|\(401\)|\(403\)') {
            $abortAfterAuthError = $true
            Write-Warning 'Authorization error detected. Remaining environments will be skipped.'
        }
    }

    $results += [pscustomobject]@{
        Environment = $environment
        Status = $status
        OperationId = $operationId
        AppId = $appId
        Details = $details
    }
}

Write-Host "`nDeployment summary:"
$results | Format-Table -AutoSize -Wrap
if (@($results | Where-Object { $_.Status -notin @('Succeeded','Scheduled') }).Count -gt 0) {
    throw 'One or more deployments failed, were skipped, or could not be confirmed.'
}
