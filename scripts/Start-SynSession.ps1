# Windows equivalent of labwc's autostart file: apply the last-used theme
# (or the hard-coded first-boot default), then launch the bar and the
# keybind daemon. Meant to run at logon (see README for wiring it up).
$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent $PSScriptRoot
$currentFile = Join-Path $Root "current-theme"

$theme = "SYN-OS-RED"
if (Test-Path $currentFile) {
    $stored = (Get-Content $currentFile -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($stored)) { $theme = $stored }
}

& (Join-Path $Root "scripts\Apply-SynTheme.ps1") -Name $theme

$AhkExe = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
$YasbExe = "C:\Program Files\YASB\yasb.exe"

try { Start-Process $YasbExe } catch { Write-Warning "Could not start yasb: $_" }
try { Start-Process $AhkExe -ArgumentList "`"$Root\ahk\syn-wm.ahk`"" } catch { Write-Warning "Could not start AutoHotkey: $_" }
