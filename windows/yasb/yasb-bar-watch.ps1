# Per-monitor YASB bar visibility, with no game/process list.
#
# Hides the bar on the monitor hosting a maximized or borderless-fullscreen
# window, so the game gets the whole monitor. Other monitors keep their bars.
# Only one bar is hidden at a time.
#
# The bar is changed only when the actual app-bar state differs from the desired
# state. There is no periodic show-all resync and no arbitrary fallback, so the
# game resizes exactly once on start and once on exit - never during play.
# A short focus dwell prevents brief focus blips from toggling anything.
#
# Use the pause file to suspend the watcher without changing bar state:
#   C:\Users\Brandon\.config\yasb\yasb-bar-watch.pause

$ErrorActionPreference = 'SilentlyContinue'

$log = 'C:\Users\Brandon\.config\yasb\yasb-bar-watch.log'
$yasbc = 'C:\Program Files\YASB\yasbc.exe'
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

function Write-WatchLog([string]$message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $message" | Out-File -FilePath $log -Append -Encoding ascii
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

# True when a monitor has a live app-bar reservation. This is the actual state
# we compare against, so commands are issued only on real transitions.
function Test-Reservation([IntPtr]$hMonitor) {
    $mi = New-Object YasbBarWatchWin32+MONITORINFO
    $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
    if (-not [YasbBarWatchWin32]::GetMonitorInfo($hMonitor, [ref]$mi)) { return $true }
    return -not (
        $mi.rcWork.Left -eq $mi.rcMonitor.Left -and
        $mi.rcWork.Top -eq $mi.rcMonitor.Top -and
        $mi.rcWork.Right -eq $mi.rcMonitor.Right -and
        $mi.rcWork.Bottom -eq $mi.rcMonitor.Bottom
    )
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
    $cb = [YasbBarWatchWin32+EnumProc] {
        param($hWnd, $data)
        if (Test-ImmersiveWindow $hWnd) {
            $script:filled[[YasbBarWatchWin32]::MonitorFromWindow($hWnd, 2)] = $true
        }
        return $true
    }
    [void][YasbBarWatchWin32]::EnumWindows($cb, [IntPtr]::Zero)
    return $script:filled
}

$screens = Get-Screens
$activeHandle = [IntPtr]::Zero
$hasCandidate = $false
$candidateHandle = [IntPtr]::Zero
$candidateTicks = 0
$lastYasbId = 0

while ($true) {
    if (-not (Test-Path $pauseFile)) {
        $yasb = Get-Process -Name yasb -ErrorAction SilentlyContinue | Select-Object -First 1
        $yasbId = if ($yasb) { $yasb.Id } else { 0 }
        $script:yasbIds = @(Get-Process -Name yasb -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        if ($screens.Count -eq 0) { $screens = Get-Screens }

        if ($yasbId -ne $lastYasbId) {
            # A fresh YASB may have reset bar state; let the state checks below
            # reconcile it without a blind show-all.
            $lastYasbId = $yasbId
            if ($yasbId -ne 0) { Write-WatchLog "YASB process $yasbId; re-evaluating bars" }
        }

        if ($yasbId -ne 0) {
            $filled = Get-ImmersiveMonitors
            $fg = [YasbBarWatchWin32]::GetForegroundWindow()
            $fgMonitor = [IntPtr]::Zero
            if (Test-ImmersiveWindow $fg) {
                $fgMonitor = [YasbBarWatchWin32]::MonitorFromWindow($fg, 2)
            }

            # Only the focused immersive window can select a monitor. Otherwise
            # stay with the current one while its immersive window still exists.
            # No arbitrary fallback, so the second monitor is never grabbed.
            if ($fgMonitor -ne [IntPtr]::Zero -and $filled[$fgMonitor]) {
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
                $hasReservation = Test-Reservation $s.Handle

                if ($desiredHidden -and $hasReservation) {
                    & $yasbc hide-bar --screen $s.Name | Out-Null
                    Write-WatchLog "$($s.Name): immersive window; bar hidden"
                }
                elseif (-not $desiredHidden -and -not $hasReservation) {
                    & $yasbc show-bar --screen $s.Name | Out-Null
                    Write-WatchLog "$($s.Name): no immersive window; bar shown"
                }
            }
        }
    }
    Start-Sleep -Milliseconds $intervalMs
}
