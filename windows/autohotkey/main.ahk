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
; See README.md in C:\Users\Brandon\Documents\dotfiles\windows\autohotkey
; for bindings, Logitech button mapping, and maintenance notes.
;
; Logitech:
;   lower thumb button -> F8 (smart add)
;   forward side button -> Ctrl
;   back side button -> MouseX1 (left untouched for AoE4)
;   Esc -> F9
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
    global CtrlGroupsArmed, LastGroup

    ; Ctrl+N assigns to group N, so N is now the "last group" too.
    SetLastGroup(key)

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
    SetLastGroup(key)
    Send("^" . key)
}

;------------------------------------------------------------
; Shift + Middle-click: detach the unit under the cursor
;
; Hover a unit on the battlefield, then press Shift+Middle-click:
;   1. Send "{Click}" is a plain left-click at the cursor. Send
;      temporarily releases the held Shift, so the unit is
;      SELECTED instead of being toggled out of your selection.
;   2. "/" removes the selected unit from ALL control groups.
;   3. Ctrl+6 assigns it to the raid group.
; The detached unit stays selected, ready for a right-click raid
; order. Change RaidGroup below to use a different number.
;
; IMPORTANT: clear the in-game "Shift+MouseMiddle" binding
; ("select all archers on screen") in Age of Empires IV. AHK
; blocks the middle-click, but AoE4 may still see it via RawInput.
;
; Physical Shift only: the Space->Shift remap above will NOT
; trigger this macro.
;------------------------------------------------------------

RaidGroup := 6

#HotIf WinActive("ahk_exe RelicCardinal.exe") && GetKeyState("Shift", "P")
+MButton:: {
    global RaidGroup
    Send("{Click}")            ; select the unit under the cursor
    Sleep(30)
    Send("/")                  ; remove it from every control group
    Sleep(30)
    Send("^" . RaidGroup)      ; assign it to the raid group
}
#HotIf WinActive("ahk_exe RelicCardinal.exe")

;------------------------------------------------------------
; Smart add: adds the current selection to the last control
; group you used, via Alt+N.
;
; Bare numbers, Ctrl+N and F10+N all update LastGroup.
; F8 = your lower thumb button, the main smart-add key.
; F10 is kept as a harmless backup trigger.
; The back side button is left untouched for AoE4's
; "cancel last production item" (MouseX1).
;------------------------------------------------------------

global LastGroup := 1

SetLastGroup(n) {
    global LastGroup
    LastGroup := n
}

TrackGroup(n, *) {
    SetLastGroup(n)
}

for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
{
    Hotkey("~" . key, TrackGroup.Bind(key))
}

SmartAdd() {
    global LastGroup
    Send("!" . LastGroup)
}

; Logitech maps the FORWARD side button (XButton2) to F10.
; Tap F10 = smart add; hold F10 + number = assign group (F10 & N above).
F10::SmartAdd()

; Lower thumb button (mapped to F8 in Logitech) = smart add.
F8::SmartAdd()

HotIfWinActive ; Reset runtime context so later dynamic hotkeys are global

#HotIf
