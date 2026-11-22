# Keeps whkd alive if it exits during a session.
# Komorebi starts whkd at logon via `komorebic start --whkd`; this only
# recovers it afterwards, and waits until Komorebi is actually running
# so it cannot race the logon startup.
#
# game-hotkey-guard.ps1 deliberately stops whkd while Age of Empires IV runs,
# so this watchdog must not restart it during that window.
$ErrorActionPreference = 'SilentlyContinue'
$whkd = 'C:\Program Files\whkd\bin\whkd.exe'
$log = 'C:\Users\Brandon\.config\whkd\watch-whkd.log'
$intervalSeconds = 60
$misses = 0

# Give Komorebi's `start --whkd` time to launch whkd at logon.
Start-Sleep -Seconds 10

while ($true) {
    $komorebiRunning = [bool](Get-Process komorebi -ErrorAction SilentlyContinue)
    $whkdRunning = [bool](Get-Process whkd -ErrorAction SilentlyContinue)
    $gameRunning = [bool](Get-Process RelicCardinal -ErrorAction SilentlyContinue)

    if (-not $gameRunning -and $komorebiRunning -and -not $whkdRunning) {
        $misses++
        if ($misses -ge 1) {
            Start-Process -FilePath $whkd -WindowStyle Hidden
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') whkd was not running; restarted" | Out-File -FilePath $log -Append -Encoding ascii
            $misses = 0
        }
    } else {
        $misses = 0
    }

    Start-Sleep -Seconds $intervalSeconds
}
