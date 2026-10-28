# Move selected AL files from develop to main.
# Place in <repository>/scripts/; no application-specific settings.
# Windows PowerShell 5.1, Out-GridView required.
$ErrorActionPreference = 'Stop'
$RepositoryPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Invoke-Git {
    param([string[]]$GitArgs)
    # Git writes informational messages to stderr; avoid PowerShell 5.1 native stderr errors.
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $RepositoryPath @GitArgs 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
    if ($exitCode -ne 0) {
        throw "Git command failed ($exitCode): git $($GitArgs -join ' ')`n$($output -join "`n")"
    }
    return @($output | ForEach-Object { [string]$_ })
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git was not found.' }
    if (-not (Get-Command Out-GridView -ErrorAction SilentlyContinue)) { throw 'Out-GridView is not available. Use Windows PowerShell 5.1.' }

    $root = @(Invoke-Git @('rev-parse','--show-toplevel'))[0].Trim()
    $RepositoryPath = $root
    $branch = @(Invoke-Git @('branch','--show-current'))[0].Trim()
    if ($branch -ne 'develop') { throw "Start from develop. Current branch: '$branch'." }

    $dirty = @(Invoke-Git @('status','--porcelain','--untracked-files=all') | Where-Object { $_.Trim() })
    if ($dirty.Count) { throw "Commit or stash local changes first:`n$($dirty -join "`n")" }
    Invoke-Git @('rev-parse','--verify','main^{commit}') | Out-Null

    # Compare current snapshots; include added and modified AL files, exclude deletions.
    $paths = @(Invoke-Git @('diff','--name-only','--no-renames','--diff-filter=ACMT','main','develop','--','*.al') | Where-Object { $_.Trim() })
    if (-not $paths.Count) { Write-Host 'No changed AL files between develop and main.'; return }

    $pattern = '(?im)^\s*//\s*<(?<code>NF-[A-Za-z0-9-]+)>\s+(?<date>\d{2}\.\d{2}\.\d{4})\s+(?<description>.*?)\s+(?<release>Release_\d+)\s*$'
    $items = foreach ($path in $paths) {
        $fullPath = Join-Path $RepositoryPath ($path -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
        $content = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
        $matchesFound = [regex]::Matches($content, $pattern)
        $codes = @($matchesFound | ForEach-Object { $_.Groups['code'].Value } | Select-Object -Unique)
        $releases = @($matchesFound | ForEach-Object { $_.Groups['release'].Value } | Select-Object -Unique)
        [pscustomobject]@{
            Path = $path
            ChangeCodes = ($codes -join ', ')
            Releases = ($releases -join ', ')
            Description = (@($matchesFound | ForEach-Object { $_.Groups['description'].Value.Trim() } | Select-Object -Unique) -join '; ')
            Codes = $codes
            ReleaseIds = $releases
        }
    }
    if (-not @($items).Count) { Write-Host 'No eligible AL files found.'; return }

    $mode = @(
        [pscustomobject]@{ Mode='Objects'; Description='Select individual AL files' }
        [pscustomobject]@{ Mode='Change Code'; Description='Select all files with a Change Code' }
        [pscustomobject]@{ Mode='Release'; Description='Select all files with a Release number' }
    ) | Out-GridView -Title 'Select transfer mode' -OutputMode Single
    if (-not $mode) { Write-Host 'Cancelled.'; return }

    $selectedItems = @()
    switch ($mode.Mode) {
        'Objects' {
            $selectedItems = @($items | Select-Object Path,ChangeCodes,Releases,Description | Out-GridView -Title 'Select AL objects (Ctrl/Shift)' -PassThru)
        }
        'Change Code' {
            $choices = @($items | ForEach-Object { $_.Codes } | Sort-Object -Unique | ForEach-Object {
                $code = $_
                [pscustomobject]@{ ChangeCode=$code; Files=@($items | Where-Object { $_.Codes -contains $code }).Count }
            })
            if (-not $choices.Count) { Write-Host 'No Change Codes found.'; return }
            $choice = $choices | Out-GridView -Title 'Select Change Code' -OutputMode Single
            if (-not $choice) { return }
            $selectedItems = @($items | Where-Object { $_.Codes -contains $choice.ChangeCode })
        }
        'Release' {
            $choices = @($items | ForEach-Object { $_.ReleaseIds } | Sort-Object -Unique | ForEach-Object {
                $release = $_
                [pscustomobject]@{ Release=$release; Files=@($items | Where-Object { $_.ReleaseIds -contains $release }).Count }
            })
            if (-not $choices.Count) { Write-Host 'No Releases found.'; return }
            $choice = $choices | Out-GridView -Title 'Select Release' -OutputMode Single
            if (-not $choice) { return }
            $selectedItems = @($items | Where-Object { $_.ReleaseIds -contains $choice.Release })
        }
    }
    if (-not $selectedItems.Count) { Write-Host 'Nothing selected.'; return }

    $selectedPaths = @($selectedItems | ForEach-Object { $_.Path } | Sort-Object -Unique)
    Write-Host "`nFiles to copy from develop to main:" -ForegroundColor Cyan
    $selectedPaths | ForEach-Object { Write-Host "  $_" }
    Write-Host 'WARNING: The entire AL file is copied, including changes for other Change Codes.' -ForegroundColor Yellow
    $answer = Read-Host 'Type JA to continue'
    if ($answer -cne 'JA') { Write-Host 'Cancelled.'; return }

    Invoke-Git @('switch','--quiet','main') | Out-Null
    try {
        Invoke-Git (@('restore','--source','develop','--staged','--worktree','--') + [string[]]$selectedPaths) | Out-Null
    } catch {
        throw "Switched to main but file transfer failed. Check git status. $($_.Exception.Message)"
    }
    Write-Host "`nSelected files copied and staged on main." -ForegroundColor Green
    Write-Host 'Review: git diff --cached'
    Write-Host 'Then commit and push main manually. No deployment was performed.'
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
