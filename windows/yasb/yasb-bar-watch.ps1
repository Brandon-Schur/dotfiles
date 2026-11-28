# Per-monitor YASB bar visibility, with no game/process list.
#
# Hides the bar on the monitor hosting a maximized or borderless-fullscreen
# window. The primary bar runs with windows_app_bar: false so games can use the
# whole monitor; while that bar is visible, this script applies the equivalent
# komorebi work-area offset so normal windows still start below it. The offset
# is removed when the bar hides. The secondary bar reserves space through
# Windows itself. Only one bar is hidden at a time.
#
# Bar visibility is tracked locally because yasbc has no "query" command. State
# is reset when YASB restarts, which also refreshes the cached screen handles.
# A short focus dwell prevents brief focus blips from toggling anything.
#
# Use the pause file to suspend the watcher without changing bar state:
#   C:\Users\Brandon\.config\yasb\yasb-bar-watch.pause

$ErrorActionPreference = 'SilentlyContinue'

# The logon launcher, the Startup-folder fallback, and the watchdog can all
# try to start this script. Only the first instance is allowed to run.
$script:mutex = New-Object System.Threading.Mutex($false, 'Local\YasbBarWatch')
if (-not $script:mutex.WaitOne(0)) { exit }

$log = 'C:\Users\Brandon\.config\yasb\yasb-bar-watch.log'
$yasbc = 'C:\Program Files\YASB\yasbc.exe'
$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'
$pauseFile = 'C:\Users\Brandon\.config\yasb\yasb-bar-watch.pause'
$intervalMs = 700
$switchDwellTicks = 3          # ~2.1s of stable focus before switching monitors

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class YasbBarWatchWin32 {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonProc cb, IntPtr data);
  public delegate bool MonProc(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr data);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public uint cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
}
'@

$script:excludedClasses = @(
    'Progman', 'WorkerW', 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd',
    'XamlWindow', 'Windows.UI.Core.CoreWindow', 'CEF-OSC-WIDGET', 'CEFCLIENT'
)
$script:yasbIds = @()
# WoW's fullscreen-windowed mode is a normal overlapped window, not WS_POPUP,
# so the generic immersive test misses it. These processes get a coverage-based
# exemption when they fill most of a monitor.
$script:immersiveProcessNames = @('Wow', 'WowClassic', 'Wow-64', 'WoW')
$script:immersiveIds = @()

function Write-WatchLog([string]$message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $message" | Out-File -FilePath $log -Append -Encoding ascii
}

# The primary bar does not reserve space through Windows, so komorebi would
# tile normal windows underneath it. Reproduce the old reserved band with a
# runtime work-area offset while the bar is visible. 54 physical px is 36
# logical px on this 150%-scaled monitor; equal top/bottom keeps padding even.
function Set-PrimaryWorkAreaOffset([bool]$BarHidden, [bool]$Force = $false) {
    $offset = if ($BarHidden) { 0 } else { 54 }
    if (-not $Force -and $script:primaryOffset -eq $offset) { return }
    & $komorebic monitor-work-area-offset 0 0 $offset 0 $offset 2>$null | Out-Null
    $script:primaryOffset = $offset
}

# Screen names and monitor handles come from YASB and Win32 respectively.
function Get-Screens {
    $raw = (& $yasbc monitor-information 2>&1 | Out-String) -replace "\x1b\[[0-9;]*m", ''
    $found = @()
    $name = $null
    foreach ($line in ($raw -split "\r?\n")) {
        if ($line -match '^\s*Name:\s*(.+?)\s*$') {
            $name = $Matches[1]
        }
        elseif ($name -and $line -match '^\s*Position:\s*\((\d+),\s*(\d+)\)\s*to\s*\((\d+),\s*(\d+)\)') {
            $x = [int]$Matches[1]; $y = [int]$Matches[2]
            $found += [pscustomobject]@{
                Name = $name
                X = $x
                Y = $y
                Handle = [IntPtr]::Zero
            }
            $name = $null
        }
    }

    $script:screensForHandles = $found
    $monCb = [YasbBarWatchWin32+MonProc] {
        param($hMonitor, $hdc, [ref]$r, $data)
        # GetMonitorInfo, not the callback rect: mixed DPI scaling can put the
        # callback rect in a different coordinate space than YASB's positions.
        $mi = New-Object YasbBarWatchWin32+MONITORINFO
        $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
        if ([YasbBarWatchWin32]::GetMonitorInfo($hMonitor, [ref]$mi)) {
            foreach ($s in $script:screensForHandles) {
                if ($s.X -eq $mi.rcMonitor.Left -and $s.Y -eq $mi.rcMonitor.Top) {
                    $s.Handle = $hMonitor
                    break
                }
            }
        }
        return $true
    }
    [void][YasbBarWatchWin32]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $monCb, [IntPtr]::Zero)
    return $script:screensForHandles
}

function Test-ImmersiveWindow([IntPtr]$hWnd) {
    if ($hWnd -eq [IntPtr]::Zero) { return $false }
    if (-not [YasbBarWatchWin32]::IsWindowVisible($hWnd)) { return $false }

    $title = New-Object System.Text.StringBuilder 256
    [void][YasbBarWatchWin32]::GetWindowText($hWnd, $title, 256)
    if ($title.Length -eq 0) { return $false }

    $class = New-Object System.Text.StringBuilder 256
    [void][YasbBarWatchWin32]::GetClassName($hWnd, $class, 256)
    $cls = $class.ToString()
    if (($script:excludedClasses -contains $cls) -or $cls.EndsWith('QWindowIcon')) { return $false }

    $wpid = 0
    [void][YasbBarWatchWin32]::GetWindowThreadProcessId($hWnd, [ref]$wpid)
    if ($script:yasbIds -contains $wpid) { return $false }

    $rect = New-Object YasbBarWatchWin32+RECT
    [void][YasbBarWatchWin32]::GetWindowRect($hWnd, [ref]$rect)
    $monitor = [YasbBarWatchWin32]::MonitorFromWindow($hWnd, 2)
    $mi = New-Object YasbBarWatchWin32+MONITORINFO
    $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
    if (-not [YasbBarWatchWin32]::GetMonitorInfo($monitor, [ref]$mi)) { return $false }

    $monW = $mi.rcMonitor.Right - $mi.rcMonitor.Left
    $monH = $mi.rcMonitor.Bottom - $mi.rcMonitor.Top
    $winW = $rect.Right - $rect.Left
    $winH = $rect.Bottom - $rect.Top

    # Maximized windows are always immersive.
    if ([YasbBarWatchWin32]::IsZoomed($hWnd)) { return $true }

    # Fullscreen games whose window style is not WS_POPUP still deserve the
    # whole monitor. Require 80% coverage so small windowed instances do not
    # hide the bar.
    if ($script:immersiveIds -contains $wpid -and
        $winW -ge ($monW * 0.8) -and $winH -ge ($monH * 0.8)) {
        return $true
    }

    # A window that merely covers its monitor only counts when it is a WS_POPUP
    # window (true borderless fullscreen). This keeps a normal near-fullscreen
    # window (editor, browser) from accidentally hiding the bar.
    if ($winW -lt ($monW - 8) -or $winH -lt ($monH - 8)) { return $false }

    $style = [YasbBarWatchWin32]::GetWindowLong($hWnd, -16)
    # WS_POPUP = 0x80000000. Use the decimal literal so PowerShell parses it as
    # Int64 instead of a negative Int32 (which breaks uint32 masking).
    return ((($style -band 2147483648) -ne 0))
}

function Get-ImmersiveMonitors {
    $script:filled = @{}
    $script:gameFilled = @{}
    $cb = [YasbBarWatchWin32+EnumProc] {
        param($hWnd, $data)
        if (Test-ImmersiveWindow $hWnd) {
            $hMon = [YasbBarWatchWin32]::MonitorFromWindow($hWnd, 2)
            $script:filled[$hMon] = $true
            $wpid = 0
            [void][YasbBarWatchWin32]::GetWindowThreadProcessId($hWnd, [ref]$wpid)
            if ($script:immersiveIds -contains $wpid) {
                $script:gameFilled[$hMon] = $true
            }
        }
        return $true
    }
    [void][YasbBarWatchWin32]::EnumWindows($cb, [IntPtr]::Zero)
    return @{ All = $script:filled; Game = $script:gameFilled }
}

$screens = Get-Screens
$activeHandle = [IntPtr]::Zero
$hasCandidate = $false
$candidateHandle = [IntPtr]::Zero
$candidateTicks = 0
$lastYasbId = 0
$lastKomorebiId = 0
$script:barHidden = @{}
$script:primaryOffset = $null
$script:settleUntil = [datetime]::MinValue

while ($true) {
    if (-not (Test-Path $pauseFile)) {
        $yasb = Get-Process -Name yasb -ErrorAction SilentlyContinue | Select-Object -First 1
        $yasbId = if ($yasb) { $yasb.Id } else { 0 }
        $script:yasbIds = @(Get-Process -Name yasb -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        $script:immersiveIds = @(Get-Process -Name $script:immersiveProcessNames -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        if ($screens.Count -eq 0) { $screens = Get-Screens }

        $komorebi = Get-Process -Name komorebi -ErrorAction SilentlyContinue | Select-Object -First 1
        $komorebiId = if ($komorebi) { $komorebi.Id } else { 0 }
        if ($komorebiId -ne $lastKomorebiId) {
            $lastKomorebiId = $komorebiId
            if ($komorebiId -ne 0) {
                # A fresh komorebi loses runtime offsets, so re-apply the one
                # that matches the current primary bar state.
                Set-PrimaryWorkAreaOffset -BarHidden ([bool]$script:barHidden['Odyssey G7']) -Force $true
            }
        }

        if ($yasbId -ne $lastYasbId) {
            # A fresh YASB shows all bars and may re-number screens. Refresh the
            # cached handles and reset local visibility state so nothing is left
            # stuck in the old state.
            $lastYasbId = $yasbId
            if ($yasbId -ne 0) {
                Write-WatchLog "YASB process $yasbId; re-evaluating bars"
                $screens = Get-Screens
                $script:barHidden = @{}
                foreach ($s in $screens) { $script:barHidden[$s.Name] = $false }
                # A fresh YASB shows its bar, so reserve space again until an
                # immersive window proves otherwise.
                Set-PrimaryWorkAreaOffset -BarHidden $false
                # A fresh YASB creates its bar windows after the CLI is ready.
                # Wait before issuing hide/show so commands are not lost.
                $script:settleUntil = (Get-Date).AddSeconds(3)
            }
        }

        if ((Get-Date) -lt $script:settleUntil) {
            Start-Sleep -Milliseconds $intervalMs
            continue
        }

        if ($yasbId -ne 0) {
            $immersive = Get-ImmersiveMonitors
            $filled = $immersive.All
            $fg = [YasbBarWatchWin32]::GetForegroundWindow()
            $fgMonitor = [IntPtr]::Zero
            if (Test-ImmersiveWindow $fg) {
                $fgMonitor = [YasbBarWatchWin32]::MonitorFromWindow($fg, 2)
            }

            $gameMonitor = [IntPtr]::Zero
            foreach ($hMon in $immersive.Game.Keys) {
                $gameMonitor = $hMon
                break
            }

            # A known fullscreen game gets priority even when it is not focused;
            # otherwise only the focused immersive window can select a monitor.
            # Stay with the current one while its immersive window still exists.
            if ($gameMonitor -ne [IntPtr]::Zero) {
                $target = $gameMonitor
            }
            elseif ($fgMonitor -ne [IntPtr]::Zero -and $filled[$fgMonitor]) {
                $target = $fgMonitor
            }
            elseif ($activeHandle -ne [IntPtr]::Zero -and $filled[$activeHandle]) {
                $target = $activeHandle
            }
            else {
                $target = [IntPtr]::Zero
            }

            # Hysteresis: require the target to hold steady before switching.
            if ($target -eq $activeHandle) {
                $hasCandidate = $false
                $candidateTicks = 0
            }
            elseif ($hasCandidate -and $target -eq $candidateHandle) {
                $candidateTicks++
            }
            else {
                $hasCandidate = $true
                $candidateHandle = $target
                $candidateTicks = 1
            }
            if ($hasCandidate -and $candidateTicks -ge $switchDwellTicks) {
                $activeHandle = $candidateHandle
                $hasCandidate = $false
                $candidateTicks = 0
            }

            foreach ($s in $screens) {
                if ($s.Handle -eq [IntPtr]::Zero) { continue }
                $desiredHidden = ($activeHandle -ne [IntPtr]::Zero -and $s.Handle -eq $activeHandle)
                $isHidden = [bool]$script:barHidden[$s.Name]

                if ($desiredHidden -and -not $isHidden) {
                    & $yasbc hide-bar --screen $s.Name | Out-Null
                    $script:barHidden[$s.Name] = $true
                    if ($s.Name -eq 'Odyssey G7') { Set-PrimaryWorkAreaOffset -BarHidden $true }
                    Write-WatchLog "$($s.Name): immersive window; bar hidden"
                }
                elseif (-not $desiredHidden -and $isHidden) {
                    & $yasbc show-bar --screen $s.Name | Out-Null
                    $script:barHidden[$s.Name] = $false
                    if ($s.Name -eq 'Odyssey G7') { Set-PrimaryWorkAreaOffset -BarHidden $false }
                    Write-WatchLog "$($s.Name): no immersive window; bar shown"
                }
            }
        }
    }
    Start-Sleep -Milliseconds $intervalMs
}
