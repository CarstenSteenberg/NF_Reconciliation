# Release Overview - Windows PowerShell 5.1
# Searches five NF repositories without changing checked-out branches.
param(
    [string]$RootPath = 'C:\Github\Nordisk_Film'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$repoNames = @('NF_Basic','NF_Integration','NF_Reconciliation','NF_BusinessIntelligence','NF_EPM')
$markerRegex = '(?m)^\s*//\s*<(?<ChangeCode>NF-\d+)>\s+(?<Date>\d{2}\.\d{2}\.\d{4})\s+(?<Description>.*?)\s+(?<Release>Release_\d+)\s*$'
$objectRegex = '(?im)^\s*(?:(?:internal|local|protected|public)\s+)?(?<ObjectType>tableextension|pageextension|reportextension|enumextension|permissionsetextension|table|page|codeunit|report|query|xmlport|enum|interface|permissionset|controladdin|profile)\s+(?<ObjectID>\d+)?\s*(?<ObjectName>"[^"]+"|[\w.]+)'

function Invoke-GitLines([string]$Repo, [string[]]$GitArgs) {
    $output = & git -C $Repo @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($output)
}
function Read-ALMarkers([string]$Content, [string]$App, [string]$Branch, [string]$Path, [string]$Commit) {
    $obj = [regex]::Match($Content, $script:objectRegex)
    $type = if ($obj.Success) { $obj.Groups['ObjectType'].Value } else { '' }
    $id = if ($obj.Success) { $obj.Groups['ObjectID'].Value } else { '' }
    $name = if ($obj.Success) { $obj.Groups['ObjectName'].Value.Trim('"') } else { '' }
    foreach ($m in [regex]::Matches($Content, $script:markerRegex)) {
        [pscustomobject]@{
            App = $App; Branch = $Branch; ObjectType = $type; ObjectID = $id
            ObjectName = $name; ChangeCode = $m.Groups['ChangeCode'].Value
            Release = $m.Groups['Release'].Value; Date = $m.Groups['Date'].Value
            Description = $m.Groups['Description'].Value.Trim(); File = $Path; Commit = $Commit
        }
    }
}
function Search-Branch([string]$Branch, [string]$SearchValue, [string]$Mode) {
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($app in $script:repoNames) {
        $repo = Join-Path $script:RootPath $app
        if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { continue }
        $check = Invoke-GitLines $repo @('rev-parse','--verify',"refs/heads/$Branch")
        if ($check.Count -eq 0) { continue }
        $paths = Invoke-GitLines $repo @('ls-tree','-r','--name-only',$Branch,'--')
        foreach ($path in $paths) {
            $path = [string]$path
            if (-not $path.EndsWith('.al',[StringComparison]::OrdinalIgnoreCase)) { continue }
            $content = (& git -C $repo show "${Branch}:$path" 2>$null) -join "`n"
            if ($LASTEXITCODE -ne 0) { continue }
            foreach ($row in @(Read-ALMarkers $content $app $Branch $path '')) {
                if ($Mode -eq 'Change Code' -and $row.ChangeCode -notlike "*$SearchValue*") { continue }
                if ($Mode -eq 'Release' -and $row.Release -notlike "*$SearchValue*") { continue }
                $found.Add($row)
            }
        }
    }
    return @($found.ToArray())
}
function Search-History([string]$SearchValue, [string]$Mode) {
    $found = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($app in $script:repoNames) {
        $repo = Join-Path $script:RootPath $app
        if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { continue }
        # -G finds commits where matching lines were added/removed. --all includes all local refs.
        $logArgs = @('log','--all','--format=COMMIT:%H','--name-only','-G', [regex]::Escape($SearchValue),'--','*.al')
        $log = Invoke-GitLines $repo $logArgs
        $commit = ''
        foreach ($line in $log) {
            $line = [string]$line
            if ($line.StartsWith('COMMIT:')) { $commit = $line.Substring(7); continue }
            if (-not $commit -or -not $line.EndsWith('.al',[StringComparison]::OrdinalIgnoreCase)) { continue }
            $path = $line.Trim()
            $content = (& git -C $repo show "${commit}:$path" 2>$null) -join "`n"
            if ($LASTEXITCODE -ne 0) { continue } # file may have been deleted in that commit
            foreach ($row in @(Read-ALMarkers $content $app 'History' $path $commit)) {
                if ($Mode -eq 'Change Code' -and $row.ChangeCode -notlike "*$SearchValue*") { continue }
                if ($Mode -eq 'Release' -and $row.Release -notlike "*$SearchValue*") { continue }
                $key = "$app|$path|$($row.ChangeCode)|$($row.Release)"
                if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $found.Add($row) }
            }
        }
    }
    return @($found.ToArray())
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'NF Release Overview - All Apps'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1320,750)
$form.MinimumSize = New-Object System.Drawing.Size(900,500)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Text = 'Search by:'; $modeLabel.SetBounds(12,17,70,22)
$form.Controls.Add($modeLabel)
$modeBox = New-Object System.Windows.Forms.ComboBox
$modeBox.DropDownStyle = 'DropDownList'; $modeBox.Items.AddRange(@('Change Code','Release')); $modeBox.SelectedIndex = 0
$modeBox.SetBounds(82,13,135,26); $form.Controls.Add($modeBox)

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.SetBounds(228,14,245,26); $form.Controls.Add($searchBox)

$devButton = New-Object System.Windows.Forms.Button
$devButton.Text = 'Search DEVELOP'; $devButton.SetBounds(490,12,140,30); $form.Controls.Add($devButton)
$mainButton = New-Object System.Windows.Forms.Button
$mainButton.Text = 'Search MAIN'; $mainButton.SetBounds(638,12,125,30); $form.Controls.Add($mainButton)
$histButton = New-Object System.Windows.Forms.Button
$histButton.Text = 'Search HISTORY'; $histButton.SetBounds(771,12,140,30); $form.Controls.Add($histButton)
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = 'Export CSV'; $exportButton.SetBounds(919,12,110,30); $form.Controls.Add($exportButton)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Enter a Change Code or Release, then choose a search.'
$status.SetBounds(12,53,1250,22); $status.Anchor = 'Top,Left,Right'; $form.Controls.Add($status)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.SetBounds(12,82,1280,610)
$grid.Anchor = 'Top,Bottom,Left,Right'
$grid.ReadOnly = $true; $grid.AllowUserToAddRows = $false; $grid.AllowUserToDeleteRows = $false
$grid.SelectionMode = 'FullRowSelect'; $grid.AutoSizeColumnsMode = 'DisplayedCells'
$form.Controls.Add($grid)

$script:resultRows = @()
$runSearch = {
    param([string]$Target)
    $term = $searchBox.Text.Trim()
    if (-not $term) { [System.Windows.Forms.MessageBox]::Show('Enter a Change Code or Release first.','Release Overview') | Out-Null; return }
    try {
        $form.UseWaitCursor = $true
        $status.Text = "Searching $Target across five apps ..."
        $form.Refresh()
        $rows = if ($Target -eq 'HISTORY') { @(Search-History $term ([string]$modeBox.SelectedItem)) } else { @(Search-Branch $Target.ToLowerInvariant() $term ([string]$modeBox.SelectedItem)) }
        $script:resultRows = @($rows | Sort-Object App,ObjectType,ObjectID,ChangeCode,Release)
        $table = New-Object System.Data.DataTable
        foreach ($column in @('App','Branch','ObjectType','ObjectID','ObjectName','ChangeCode','Release','Date','Description','File','Commit')) { [void]$table.Columns.Add($column) }
        foreach ($row in $script:resultRows) {
            $dr = $table.NewRow()
            foreach ($column in $table.Columns) { $dr[$column.ColumnName] = [string]$row.($column.ColumnName) }
            $table.Rows.Add($dr)
        }
        $grid.DataSource = $table
        $status.Text = "$($script:resultRows.Count) results in $Target (five NF apps)."
    } catch {
        $status.Text = "ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.ToString(),'Search error') | Out-Null
    } finally { $form.UseWaitCursor = $false }
}
$devButton.Add_Click({ & $runSearch 'DEVELOP' })
$mainButton.Add_Click({ & $runSearch 'MAIN' })
$histButton.Add_Click({ & $runSearch 'HISTORY' })
$exportButton.Add_Click({
    if ($script:resultRows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('No results to export.','Release Overview') | Out-Null; return }
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'CSV for Excel (*.csv)|*.csv'; $dialog.FileName = 'NF-Release-Overview.csv'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:resultRows | Export-Csv -LiteralPath $dialog.FileName -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        $status.Text = "Exported $($script:resultRows.Count) rows to $($dialog.FileName)"
    }
})
[void]$form.ShowDialog()
$form.Dispose()
