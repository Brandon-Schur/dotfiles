<#
.SYNOPSIS
    Removes the upstream Spotify tray_and_multi_window rule from applications.json.

.DESCRIPTION
    Komorebi's upstream applications.json marks Spotify as a tray/multi-window app,
    which keeps a minimized Spotify window in the tiling layout and leaves an empty
    half-screen tile. Run this after `komorebic fetch-app-specific-configuration`.

    The script is idempotent: if the rule is already gone, it does nothing.
#>
param(
    [string] $ApplicationsPath
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $Env:USERPROFILE 'komorebi.json'

if (-not $ApplicationsPath) {
    if (Test-Path -LiteralPath $configPath) {
        $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
        if ($config.app_specific_configuration_path) {
            $ApplicationsPath = $config.app_specific_configuration_path `
                -replace '\$Env:USERPROFILE', $Env:USERPROFILE `
                -replace '%USERPROFILE%', $Env:USERPROFILE `
                -replace '/', '\'
        }
    }

    if (-not $ApplicationsPath) {
        $ApplicationsPath = Join-Path $Env:USERPROFILE 'applications.json'
    }
}

if (-not (Test-Path -LiteralPath $ApplicationsPath)) {
    throw "applications.json not found at: $ApplicationsPath"
}

$apps = Get-Content -Raw -LiteralPath $ApplicationsPath | ConvertFrom-Json
$spotify = $apps.PSObject.Properties['Spotify']

if (-not $spotify -or -not $spotify.Value.PSObject.Properties['tray_and_multi_window']) {
    Write-Host 'Spotify tray rule already absent; nothing to do.'
} else {
    $spotify.Value.PSObject.Properties.Remove('tray_and_multi_window')
    $json = $apps | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText(
        $ApplicationsPath,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Removed Spotify tray_and_multi_window rule from: $ApplicationsPath"
}

if ((Get-Command komorebic -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $configPath)) {
    & komorebic replace-configuration $configPath | Out-Null
    Write-Host 'Reloaded the running Komorebi instance.'
}
