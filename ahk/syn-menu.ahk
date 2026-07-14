#Requires AutoHotkey v2.0
#SingleInstance Force

ProjectRoot := A_ScriptDir . "\.."
ThemeScript := ProjectRoot . "\scripts\Apply-SynTheme.ps1"
ThemesDir := ProjectRoot . "\themes"

; Tool paths come from .state\tool-paths.env -- see syn-wm.ahk for why.
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

; NOTE: this uses AHK's built-in Menu control, which renders with native
; Windows chrome -- it cannot be recolored to match the SYN_* palette the
; way waybar/labwc's menu.xml could. A themed popup would need a custom
; GUI; this gets the same *tree and behavior*, not the same skin.

powerMenu := Menu()
powerMenu.Add("Lock", (*) => DllCall("user32.dll\LockWorkStation"))
powerMenu.Add("Sign out", (*) => Run("shutdown.exe /l"))
powerMenu.Add("Restart", (*) => Run("shutdown.exe /r /t 0"))
powerMenu.Add("Shut down", (*) => Run("shutdown.exe /s /t 0"))

; The bar's power button calls this script with "power" to jump straight
; to the power submenu instead of the full root menu.
if (A_Args.Length > 0 && A_Args[1] = "power") {
    powerMenu.Show()
    ExitApp()
}

ApplyTheme(name, *) {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . ThemeScript . '" -Name ' . name)
}
themesMenu := Menu()
Loop Files, ThemesDir . "\*.theme" {
    name := StrReplace(A_LoopFileName, ".theme", "")
    themesMenu.Add(name, ApplyTheme.Bind(name))
}

YasbExe := Tools["YASB_EXE"]
StopKeybindsScript := ProjectRoot . "\scripts\Stop-Keybinds.ps1"

RestartBar(*) {
    RunWait("taskkill /IM yasb.exe /F", , "Hide")
    ; taskkill.exe exiting doesn't guarantee yasb.exe has finished tearing
    ; down and released its single-instance lock yet -- a brief buffer
    ; avoids the new instance seeing the old one as still-running.
    Sleep(750)
    Run('"' . YasbExe . '"')
}
barMenu := Menu()
barMenu.Add("Restart bar", RestartBar)
barMenu.Add("Kill bar", (*) => Run("taskkill /IM yasb.exe /F", , "Hide"))
barMenu.Add("Restart keybinds", (*) => Run('"' . AhkExe . '" "' . ProjectRoot . '\ahk\syn-wm.ahk"'))
; #SingleInstance Force on syn-wm.ahk means relaunching it already replaces
; any running copy, so "restart" doesn't need to kill first.
barMenu.Add("Kill keybinds", (*) => Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . StopKeybindsScript . '"', , "Hide"))

toolsMenu := Menu()
toolsMenu.Add("Edit config files", (*) => Run('explorer.exe "' . ProjectRoot . '"'))

OpenShortcut(path, *) => Run(path)
appsMenu := Menu()
seen := Map()
for root in [A_StartMenuCommon, A_StartMenu] {
    if !DirExist(root)
        continue
    Loop Files, root . "\*.lnk", "R" {
        label := StrReplace(A_LoopFileName, ".lnk", "")
        if seen.Has(label)
            continue
        seen[label] := true
        appsMenu.Add(label, OpenShortcut.Bind(A_LoopFileFullPath))
    }
}

sysMenu := Menu()
sysMenu.Add("Volume mixer", (*) => Run("cmd.exe /c start ms-settings:apps-volume"))
sysMenu.Add("Screenshot (region)", (*) => Send("#+s"))
sysMenu.Add("Switch display", (*) => Run("C:\Windows\System32\DisplaySwitch.exe"))
sysMenu.Add("Task Manager", (*) => Run("taskmgr.exe"))

root := Menu()
root.Add("Terminal", (*) => Run("wt.exe"))
root.Add("File manager", (*) => Run("wt.exe -- spf"))
root.Add("All Applications", appsMenu)
root.Add("Tools", toolsMenu)
root.Add("System Control", sysMenu)
root.Add("Bar && Keybinds", barMenu)
root.Add("Power Options", powerMenu)
root.Add("Themes", themesMenu)
root.Show()
