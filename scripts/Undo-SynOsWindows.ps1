# Full rollback for the SYN-OS-WINDOWS setup. Safe to run at any point --
# each step checks before it acts and reports what it did.
param(
    [switch]$UninstallApps   # also winget-uninstall AutoHotkey/yasb/Flow Launcher and remove the VirtualDesktop module
)
$ErrorActionPreference = "Continue"

Write-Host "--- Stopping running processes ---"
foreach ($p in @("yasb", "AutoHotkey64")) {
    if (Get-Process $p -ErrorAction SilentlyContinue) {
        Stop-Process -Name $p -Force
        Write-Host "  stopped $p"
    }
}

Write-Host "--- Removing autostart task ---"
if (Get-ScheduledTask -TaskName "SynOsSession" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "SynOsSession" -Confirm:$false
    Write-Host "  removed scheduled task SynOsSession"
} else {
    Write-Host "  no SynOsSession task found"
}

Write-Host "--- Restoring Windows Terminal settings.json ---"
$settingsCandidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
foreach ($s in $settingsCandidates) {
    $bak = "$s.bak"
    if (Test-Path $bak) {
        Copy-Item $bak $s -Force
        Write-Host "  restored $s from backup"
    }
}

Write-Host "--- Removing yasb config ---"
$yasbDir = Join-Path $env:USERPROFILE ".config\yasb"
if (Test-Path $yasbDir) {
    Remove-Item $yasbDir -Recurse -Force
    Write-Host "  removed $yasbDir"
}

Write-Host "--- Restoring Windows accent color ---"
$Root = Split-Path -Parent $PSScriptRoot
$accentBackup = Join-Path $Root ".state\accent-color-backup.json"
if (Test-Path $accentBackup) {
    $backup = Get-Content $accentBackup -Raw | ConvertFrom-Json
    foreach ($prop in $backup.PSObject.Properties) {
        $path, $name = $prop.Name -split '\|'
        Set-ItemProperty -Path $path -Name $name -Value $prop.Value -ErrorAction SilentlyContinue
    }
    Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class SynAccentNotifyUndo {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
    [UIntPtr]$result = [UIntPtr]::Zero
    [SynAccentNotifyUndo]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "ImmersiveColorSet", 2, 100, [ref]$result) | Out-Null
    Write-Host "  restored original accent color"
} else {
    Write-Host "  no accent-color backup found (never applied, or already restored)"
}

if ($UninstallApps) {
    Write-Host "--- Uninstalling apps ---"
    winget uninstall --id AutoHotkey.AutoHotkey --silent
    winget uninstall --id AmN.yasb --silent
    winget uninstall --id Flow-Launcher.Flow-Launcher --silent
    winget uninstall --id Microsoft.PowerShell --silent
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall nerd-fonts-terminus -y
    }
    if (Get-Module -ListAvailable -Name VirtualDesktop) {
        Uninstall-Module VirtualDesktop -AllVersions -Force
        Write-Host "  removed VirtualDesktop PS module"
    }
    Write-Host "  Chocolatey itself and Windows Terminal were left installed -- likely useful independent of this project."
}

Write-Host "--- Done ---"
Write-Host "Your $PROFILE still sources profile-prompt.ps1 if you added that line -- remove it by hand if you want the stock prompt back."
Write-Host "Virtual desktops created/renamed by Set-DesktopNames.ps1 are left as-is (harmless, and Windows doesn't offer a clean 'undo' for that)."
Write-Host "Re-run with -UninstallApps to also remove AutoHotkey/yasb/Flow Launcher/PowerShell 7/the Nerd Font/VirtualDesktop module."
