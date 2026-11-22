#SingleInstance Force

; Explorer owns win+1..4 before whkd can see them, so handle these here.
; Workspaces: 1,3 on monitor 0 and 2,4 on monitor 1 (key N = workspace N).
#1::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 0 0', , "Hidden")
#2::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 1 0', , "Hidden")
#3::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 0 1', , "Hidden")
#4::Run('"C:\Program Files\komorebi\bin\komorebic.exe" move-to-monitor-workspace 1 1', , "Hidden")
