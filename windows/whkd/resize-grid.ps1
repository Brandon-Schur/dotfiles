param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('horizontal', 'vertical')]
    [string]$Axis,

    [Parameter(Mandatory = $true)]
    [ValidateSet('increase', 'decrease')]
    [string]$Direction
)

$ErrorActionPreference = 'SilentlyContinue'
$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'
$step = 0.02

$monitor = [int]((& $komorebic query focused-monitor-index) -join '').Trim()
$workspace = [int]((& $komorebic query focused-workspace-index) -join '').Trim()

$state = (& $komorebic state | Out-String | ConvertFrom-Json)
$options = $state.monitors.elements[$monitor].workspaces.elements[$workspace].layout_options

$columns = @()
$rows = @()
if ($options.column_ratios) { $columns = @($options.column_ratios | ForEach-Object { [double]$_ }) }
if ($options.row_ratios) { $rows = @($options.row_ratios | ForEach-Object { [double]$_ }) }

$delta = if ($Direction -eq 'increase') { $step } else { -$step }

if ($Axis -eq 'horizontal') {
    if ($columns.Count -eq 0) { $columns = @(0.5) }
    $value = [math]::Max(0.1, [math]::Min(0.9, $columns[0] + $delta))
    $columns[0] = [math]::Round($value, 3)
} else {
    if ($rows.Count -eq 0) { $rows = @(0.5) }
    $value = [math]::Max(0.1, [math]::Min(0.9, $rows[0] + $delta))
    $rows[0] = [math]::Round($value, 3)
}

$ratioArgs = @()
if ($columns.Count -gt 0) {
    $ratioArgs += @('--columns')
    $ratioArgs += @($columns | ForEach-Object { $_.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture) })
}
if ($rows.Count -gt 0) {
    $ratioArgs += @('--rows')
    $ratioArgs += @($rows | ForEach-Object { $_.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture) })
}

& $komorebic layout-ratios @ratioArgs 2>$null | Out-Null
