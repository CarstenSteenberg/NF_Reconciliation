# Compare AL files in main and develop without switching branches.
# Compatible with Windows PowerShell 5.1.
[CmdletBinding()]
param(
    [string]$ProjectFolder,
    [string]$MainRef = 'main',
    [string]$DevelopRef = 'develop',
    [switch]$ExportCsv,
    [string]$CsvPath,
    [switch]$NoGridView
)
if ([string]::IsNullOrWhiteSpace($ProjectFolder)) {
    $ProjectFolder = Split-Path -Parent $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

function Invoke-GitLines {
    param([string[]]$GitArgs)
    $output = @(& git -C $ProjectFolder @GitArgs 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($GitArgs -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return @($output)
}

if (-not (Test-Path -LiteralPath $ProjectFolder -PathType Container)) {
    throw "Project folder does not exist: $ProjectFolder"
}
$ProjectFolder = (Resolve-Path -LiteralPath $ProjectFolder).Path
$null = Invoke-GitLines -GitArgs @('rev-parse', '--show-toplevel')
$null = Invoke-GitLines -GitArgs @('rev-parse', '--verify', "${MainRef}^{commit}")
$null = Invoke-GitLines -GitArgs @('rev-parse', '--verify', "${DevelopRef}^{commit}")

# Git's three-dot diff uses a merge base; we want the exact branch tips.
# --name-status and -z preserve names containing whitespace and special characters.
# Windows PowerShell splits native stdout at line breaks, and cannot reliably
# preserve NUL-delimited output. Use newline-based output instead, with tab
# separating status from path (AL paths normally have no embedded newlines).
$lines = Invoke-GitLines -GitArgs @('diff', '--name-status', '--no-renames', $MainRef, $DevelopRef, '--', '*.al')
$rows = foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t", 2
    if ($parts.Count -ne 2) { continue }
    $status = $parts[0]
    $path = $parts[1]
    $description = switch -Regex ($status) {
        '^M' { 'Different in main and develop'; break }
        '^A' { 'Only in develop'; break }
        '^D' { 'Only in main'; break }
        '^T' { 'Changed file type'; break }
        default { "Git status: $status" }
    }
    [pscustomobject]@{
        Status = $description
        File = $path
        GitStatus = $status
    }
}
$rows = @($rows | Sort-Object Status, File)
Write-Host "Project: $ProjectFolder" -ForegroundColor Cyan
Write-Host "Comparing $MainRef -> $DevelopRef (committed .al files only)" -ForegroundColor Cyan
Write-Host "Different AL files: $($rows.Count)" -ForegroundColor Yellow
if ($rows.Count -gt 0) { $rows | Format-Table -AutoSize | Out-Host }

if ($ExportCsv) {
    if ([string]::IsNullOrWhiteSpace($CsvPath)) {
        $CsvPath = Join-Path $ProjectFolder 'AL-Branch-Differences.csv'
    }
    $rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "CSV saved: $CsvPath" -ForegroundColor Green
}
if (-not $NoGridView -and $rows.Count -gt 0) {
    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $rows | Out-GridView -Title "AL differences: $MainRef vs $DevelopRef - $(Split-Path $ProjectFolder -Leaf)"
    } else {
        Write-Warning 'Out-GridView is not available. Results are shown in the terminal.'
    }
}
