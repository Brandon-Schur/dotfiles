# Disables whkd (and therefore all tiling hotkeys) while Age of Empires IV runs.
#
# whkd registers global hotkeys with RegisterHotKey, which swallows the keys
# before the foreground app sees them even when an `Ignore` app rule matches.
# Stopping whkd releases those registrations so the game receives alt+1..4 etc.
#
# The regular watch-whkd.ps1 watchdog is told to leave whkd alone while the
# game is running; this script restarts whkd as soon as the game exits.
$ErrorActionPreference = 'SilentlyContinue'
$game = 'RelicCardinal'
$whkdExe = 'C:\Program Files\whkd\bin\whkd.exe'
$log = 'C:\Users\Brandon\.config\whkd\game-guard.log'
$intervalSeconds = 2

# Let Komorebi's `start --whkd` bring whkd up at logon before we manage it.
Start-Sleep -Seconds 10

$gameWasRunning = $false

while ($true) {
    $gameRunning = [bool](Get-Process -Name $game -ErrorAction SilentlyContinue)
    $whkdRunning = [bool](Get-Process -Name whkd -ErrorAction SilentlyContinue)

    if ($gameRunning -and $whkdRunning) {
        Stop-Process -Name whkd -Force
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $game running; stopped whkd" |
            Out-File -FilePath $log -Append -Encoding ascii
    }
    elseif (-not $gameRunning -and -not $whkdRunning -and $gameWasRunning) {
        Start-Process -FilePath $whkdExe -WindowStyle Hidden
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $game closed; restarted whkd" |
            Out-File -FilePath $log -Append -Encoding ascii
    }

    $gameWasRunning = $gameRunning
    Start-Sleep -Seconds $intervalSeconds
}
