#Requires AutoHotkey v2.0
#SingleInstance Force

ProjectRoot := A_ScriptDir . "\.."
MenuScript := ProjectRoot . "\ahk\syn-menu.ahk"
SetDesktopScript := ProjectRoot . "\scripts\Set-Desktop.ps1"

; Tool paths come from .state\tool-paths.env (written by Resolve-Tools.ps1 /
; Setup.ps1) rather than being hardcoded here -- install locations aren't
; guaranteed identical across machines, and this machine specifically has
; an older Chocolatey-installed AHK earlier in PATH than the real one, so a
; bare "AutoHotkey64.exe" can resolve to the wrong binary.
LoadToolPaths(root) {
    paths := Map("AHK_EXE", "AutoHotkey64.exe", "YASB_EXE", "yasb.exe", "PWSH_EXE", "pwsh.exe")
    envFile := root . "\.state\tool-paths.env"
    if FileExist(envFile) {
        Loop Read, envFile {
            if RegExMatch(A_LoopReadLine, '^(\w+)="?([^"]*)"?$', &m)
                paths[m[1]] := m[2]
        }
    }
    return paths
}
Tools := LoadToolPaths(ProjectRoot)
AhkExe := Tools["AHK_EXE"]

; --- Close / maximize toggle (labwc W-q / W-Tab) ---
#q::WinClose "A"
#Tab:: {
    if !WinExist("A")
        return
    if WinGetMinMax("A") = 1
        WinRestore "A"
    else
        WinMaximize "A"
}

; --- Launch terminal / launcher (labwc W-Return / W-a) ---
#Enter::Run "wt.exe"
#a::Send("!{Space}")   ; Flow Launcher's default hotkey is Alt+Space

; --- Root menu (labwc W-Space -> ShowMenu) ---
#Space::Run('"' . AhkExe . '" "' . MenuScript . '"')

; --- Reload keybinds (labwc W-Escape -> Reconfigure) ---
#Escape::Reload()

; --- Virtual desktop switching (labwc C-A-Left/Right) ---
^!Left::Send("^#{Left}")
^!Right::Send("^#{Right}")

; --- Jump to desktop N (labwc W-1..4), needs the VirtualDesktop PS module ---
#1::RunDesktop(1)
#2::RunDesktop(2)
#3::RunDesktop(3)
#4::RunDesktop(4)
RunDesktop(n) {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . SetDesktopScript . '" -Index ' . n, , "Hide")
}

; --- Move window flush to a screen edge, no resize (labwc W-Shift-Arrow) ---
#+Left::MoveToEdge("left")
#+Right::MoveToEdge("right")
#+Up::MoveToEdge("up")
#+Down::MoveToEdge("down")

MoveToEdge(dir) {
    if !WinExist("A")
        return
    WinGetPos(&x, &y, &w, &h, "A")
    mon := GetWindowMonitor("A")
    MonitorGetWorkArea(mon, &mL, &mT, &mR, &mB)
    switch dir {
        case "left":  WinMove(mL, y, w, h, "A")
        case "right": WinMove(mR - w, y, w, h, "A")
        case "up":    WinMove(x, mT, w, h, "A")
        case "down":  WinMove(x, mB - h, w, h, "A")
    }
}

GetWindowMonitor(winTitle) {
    WinGetPos(&x, &y, &w, &h, winTitle)
    cx := x + w // 2
    cy := y + h // 2
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (cx >= mL && cx < mR && cy >= mT && cy < mB)
            return A_Index
    }
    return MonitorGetPrimary()
}

; --- Region screenshot (labwc W-p -> grim+slurp) ---
#p::Send("#+s")
