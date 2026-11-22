#Requires AutoHotkey v2.0
#SingleInstance Force

;============================================================
; Komorebi workspaces
;============================================================

; Explorer owns win+1..4 before whkd can see them, so handle these here.
; Workspaces: 1,3 on monitor 0 and 2,4 on monitor 1 (key N = workspace N).
#1::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 0 0', , "Hidden")
#2::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 1 0', , "Hidden")
#3::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 0 1', , "Hidden")
#4::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 1 1', , "Hidden")


#h:: {
    DllCall("PowrProf\SetSuspendState", "Int", 1, "Int", 0, "Int", 0)
}

#+h:: {
    DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
}

; send window to next monitor
#^x::Send("#+{Right}")

; remap alt+f4 to alt+shift+z
!+z::
{
    Send "!{F4}"
}

#w::
{
if WinExist("ahk_exe vivaldi.exe")
    WinActivate ; Uses the window found by WinExist
else
    Run "C:\Users\Brandon\AppData\Local\Vivaldi\Application\vivaldi.exe"
return
}

#s::
{
if WinExist("ahk_exe steam.exe")
    WinActivate ; Uses the window found by WinExist
else
    Run "C:\Program Files (x86)\Steam\Steam.exe"
return
}

#x::
{
    if WinExist("ahk_exe Spotify.exe")
        WinActivate "ahk_exe Spotify.exe"
    else
        Run "Spotify.exe"
}

; Win+E -> File Pilot instead of Explorer
#e::
{
    if WinExist("ahk_exe FPilot.exe")
        WinActivate "ahk_exe FPilot.exe"
    else
        Run "C:\Users\Brandon\AppData\Local\Voidstar\FilePilot\FPilot.exe"
}

;============================================================
; AoE4 Simple Hotkey Script
;
; Logitech:
;   XButton2 -> F10
;
; F10 is used as the AHK mouse modifier.
;============================================================

#HotIf WinActive("ahk_exe RelicCardinal.exe")
HotIfWinActive "ahk_exe RelicCardinal.exe" ; #HotIf only applies to :: hotkeys; HotIfWinActive scopes Hotkey() calls

;------------------------------------------------------------
; Space behaves as Shift
;------------------------------------------------------------

*Space::Send("{Shift Down}")
*Space Up::Send("{Shift Up}")

;------------------------------------------------------------
; Backslash behaves as Space
;------------------------------------------------------------

*\::Send("{Space}")

;------------------------------------------------------------
; Ctrl + Number
;
; Hold Ctrl and press multiple numbers:
;   1. Send "/" only on the first number
;   2. Assign selected units to each number pressed
;   3. Reset when Ctrl is released
;------------------------------------------------------------

global CtrlGroupsArmed := false

~Ctrl Up::
{
    global CtrlGroupsArmed
    CtrlGroupsArmed := false
}

CtrlNumberKeys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

for key in CtrlNumberKeys
{
    Hotkey("$^" . key, HandleCtrlNumber.Bind(key))
}

HandleCtrlNumber(key, *)
{
    global CtrlGroupsArmed

    ; Remove from all groups only on the first number
    if (!CtrlGroupsArmed)
    {
        CtrlGroupsArmed := true
        Send("/")
        Sleep(10)
    }

    ; Assign to each requested control group
    Send("^" . key)
}


;------------------------------------------------------------
; Ctrl + Focus Key
;
; Ctrl + A, S, D, F, G:
;   1. Send Ctrl + key
;   2. Wait 20 ms
;   3. Send "." to focus the selected unit
;------------------------------------------------------------

FocusKeys := ["a", "s", "d", "f", "g","q","w"]

for key in FocusKeys
{
    Hotkey("$^" . key, HandleCtrlKey.Bind(key))
}

HandleCtrlKey(key, *)
{
    Send("^" . key)
    Sleep(10)
    Send(".")
}

;------------------------------------------------------------
; Keys that trigger themselves, then focus
;
; F9:
;   1. Send F9
;   2. Wait 50 ms
;   3. Send "."
;------------------------------------------------------------

FocusTriggerKeys := ["F9"]

for key in FocusTriggerKeys
{
    Hotkey("$" . key, SendKeyThenFocus.Bind(key))
}

SendKeyThenFocus(key, *)
{
    Send("{" . key . "}")
    Sleep(10)
    Send(".")
}

;------------------------------------------------------------
; F10 + Number
;
; Assign selected units to a control group WITHOUT sending "/"
;------------------------------------------------------------

ControlGroupKeys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

for key in ControlGroupKeys
{
    Hotkey("F10 & " . key, HandleControlGroup.Bind(key))
}

HandleControlGroup(key, *)
{
    Send("^" . key)
}

HotIfWinActive ; Reset runtime context so later dynamic hotkeys are global

#HotIf
