param(
    [Parameter(Mandatory = $true)]
    [string]$AppFile,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string[]]$Environments,

    [string]$SchemaSyncMode = "Add"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $AppFile)) {
    throw "APP file not found: $AppFile"
}

#
# Get OAuth token
#
$TokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://api.businesscentral.dynamics.com/.default"
}

$TokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token

$Headers = @{
    Authorization = "Bearer $AccessToken"
}

$AppBytes = [System.IO.File]::ReadAllBytes($AppFile)

foreach ($Environment in $Environments) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host " Deploying to $Environment"
    Write-Host "========================================"

    try {

        $BaseUrl =
            "https://api.businesscentral.dynamics.com/v2.0/$Environment/api/microsoft/automation/v2.0"

        #
        # Get first available company
        #
        $Companies = Invoke-RestMethod `
            -Method Get `
            -Uri "$BaseUrl/companies" `
            -Headers $Headers

        if ($Companies.value.Count -eq 0) {
            throw "No companies found in environment $Environment"
        }

        $CompanyId = $Companies.value[0].id
        $CompanyName = $Companies.value[0].name

        Write-Host "Company: $CompanyName"

        #
        # Create Extension Upload
        #
        $UploadBody = @{
            schedule       = "Current version"
            schemaSyncMode = $SchemaSyncMode
        } | ConvertTo-Json

        $ExtensionUpload = Invoke-RestMethod `
            -Method Post `
            -Uri "$BaseUrl/companies($CompanyId)/extensionUpload" `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $UploadBody

        $ExtensionUploadId = $ExtensionUpload.systemId

        Write-Host "Extension upload created: $ExtensionUploadId"

        #
        # Upload APP binary
        #
        Invoke-RestMethod `
            -Method Patch `
            -Uri "$BaseUrl/companies($CompanyId)/extensionUpload($ExtensionUploadId)/extensionContent" `
            -Headers @{
                Authorization = "Bearer $AccessToken"
                "If-Match" = "*"
            } `
            -ContentType "application/octet-stream" `
            -Body $AppBytes

        Write-Host "APP uploaded"

        #
        # Publish / Install
        #
        Invoke-RestMethod `
            -Method Post `
            -Uri "$BaseUrl/companies($CompanyId)/extensionUpload($ExtensionUploadId)/Microsoft.NAV.upload" `
            -Headers $Headers

        Write-Host "SUCCESS: $Environment"
    }
    catch {
        Write-Host ""
        Write-Host "FAILED: $Environment"
        Write-Host $_.Exception.Message
        throw
    }
}

Write-Host ""
Write-Host "Deployment completed."