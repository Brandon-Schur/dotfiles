$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'

$monitor = [int]((& $komorebic query focused-monitor-index) -join '').Trim()
$workspace = [int]((& $komorebic query focused-workspace-index) -join '').Trim()

$state = (& $komorebic state | Out-String | ConvertFrom-Json)
$ws = $state.monitors.elements[$monitor].workspaces.elements[$workspace]

if ($ws.monocle_container -or $ws.maximized_window) {
    # U+26F6 SQUARE FOUR CORNERS; constructed so the script stays ASCII-only.
    [string][char]0x26F6
}
