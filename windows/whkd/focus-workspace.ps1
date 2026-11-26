param(
    [Parameter(Mandatory = $true)]
    [int]$Monitor,

    [Parameter(Mandatory = $true)]
    [int]$Workspace
)

# Komorebi reports monitor geometry in physical pixels. Per-monitor DPI
# awareness makes SetCursorPos use that same coordinate space on this mixed-DPI
# setup (SetProcessDPIAware would scale through the 150% primary monitor).
$win32Source = @'
using System;
using System.Runtime.InteropServices;
public static class FocusWorkspaceWin32 {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(int value);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
$win32Dll = Join-Path $PSScriptRoot 'FocusWorkspaceWin32.dll'
if (Test-Path $win32Dll) {
    Add-Type -Path $win32Dll
} else {
    Add-Type -TypeDefinition $win32Source
}
if (-not [FocusWorkspaceWin32]::SetProcessDpiAwarenessContext(-4)) {
    [void][FocusWorkspaceWin32]::SetProcessDPIAware()
}

$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'

# One state read for the geometry; workspace switches do not change it.
$state = & $komorebic state | ConvertFrom-Json
$monitors = @($state.monitors.elements)
if ($Monitor -lt 0 -or $Monitor -ge $monitors.Count) { exit 1 }

$work = $monitors[$Monitor].work_area_size
if ($null -eq $work) { exit 1 }

# Komorebi's rect fields are left/top plus width/height, not edge coordinates.
$x = [int]($work.left + $work.right / 2)
$y = [int]($work.top + $work.bottom / 2)

# Suppress mouse_follows_focus so it cannot pull the cursor to a window after
# we center it; restore the user's setting immediately afterwards.
$mouseFollowsFocus = [bool]$state.mouse_follows_focus
if ($mouseFollowsFocus) {
    & $komorebic mouse-follows-focus disable | Out-Null
}

try {
    & $komorebic focus-monitor-workspace $Monitor $Workspace | Out-Null
    [void][FocusWorkspaceWin32]::SetCursorPos($x, $y)
}
finally {
    if ($mouseFollowsFocus) {
        & $komorebic mouse-follows-focus enable | Out-Null
    }
}
