# One-shot setup / re-setup for SYN-OS-WINDOWS. Safe to run more than once
# -- every step checks before it acts. Assumes NOTHING is installed and
# verifies what actually landed rather than trusting exit codes blindly.
#
# What this does NOT do: start the bar/keybinds now, or turn on autostart.
# It leaves the scheduled task DISABLED on purpose (work PC). See the end
# of this file's output for how to turn things on.
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$results = [ordered]@{}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$isAdmin = Test-Admin

Write-Host "=== 1. Checking package managers ===" -ForegroundColor Cyan

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if (-not $hasWinget) {
    Write-Warning "winget not found. Most of this setup needs it -- install 'App Installer' from the Microsoft Store, then re-run."
}
$results["winget"] = if ($hasWinget) { "present" } else { "MISSING - stop and install App Installer" }

$hasChoco = [bool](Get-Command choco -ErrorAction SilentlyContinue)
if (-not $hasChoco) {
    if ($isAdmin) {
        Write-Host "Chocolatey not found -- installing (needs admin, which this session has)..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        try {
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $hasChoco = [bool](Get-Command choco -ErrorAction SilentlyContinue)
            $results["Chocolatey"] = if ($hasChoco) { "installed" } else { "install ran but choco still not on PATH - open a new shell" }
        } catch {
            $results["Chocolatey"] = "install failed: $_"
        }
    } else {
        Write-Warning "Chocolatey not found and this session isn't elevated -- Chocolatey's installer needs admin rights (it writes to C:\ProgramData). Re-run this script as Administrator to get it, or skip -- only the Nerd Font step below needs it."
        $results["Chocolatey"] = "MISSING - needs an elevated run to install"
    }
} else {
    $results["Chocolatey"] = "already present"
}

Write-Host "=== 2. Backing up Windows Terminal settings ===" -ForegroundColor Cyan
$settingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
foreach ($p in $settingsPaths) {
    if ((Test-Path $p) -and -not (Test-Path "$p.bak")) {
        Copy-Item $p "$p.bak"
        Write-Host "  backed up $p"
    }
}

Write-Host "=== 3. Installing apps (winget) ===" -ForegroundColor Cyan
if ($hasWinget) {
    $wingetApps = @(
        @{ Id = "AutoHotkey.AutoHotkey"; Scope = "user"; Name = "AutoHotkey v2" },
        @{ Id = "AmN.yasb"; Scope = $null; Name = "yasb" },
        @{ Id = "Flow-Launcher.Flow-Launcher"; Scope = "user"; Name = "Flow Launcher" },
        @{ Id = "Microsoft.PowerShell"; Scope = $null; Name = "PowerShell 7" },
        @{ Id = "Microsoft.WindowsTerminal"; Scope = $null; Name = "Windows Terminal" }
    )
    foreach ($app in $wingetApps) {
        $args = @("install", "--id", $app.Id, "--accept-package-agreements", "--accept-source-agreements", "--silent")
        if ($app.Scope) { $args += @("--scope", $app.Scope) }
        Write-Host "  installing $($app.Name)..."
        & winget @args | Out-Null
        $installed = winget list --id $app.Id 2>$null | Select-String $app.Id
        $results[$app.Name] = if ($installed) { "installed" } else { "FAILED - check manually: winget install --id $($app.Id)" }
    }
} else {
    foreach ($n in @("AutoHotkey v2", "yasb", "Flow Launcher", "PowerShell 7", "Windows Terminal")) {
        $results[$n] = "skipped - no winget"
    }
}

Write-Host "=== 4. Installing VirtualDesktop PowerShell module ===" -ForegroundColor Cyan
try {
    Install-Module VirtualDesktop -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    $results["VirtualDesktop module"] = "installed"
} catch {
    $results["VirtualDesktop module"] = "FAILED: $_"
}

Write-Host "=== 5. Installing the Terminus Nerd Font (needs Chocolatey) ===" -ForegroundColor Cyan
if ($hasChoco) {
    choco install nerd-fonts-terminus -y | Out-Null
    $fontInstalled = Get-ChildItem "C:\Windows\Fonts" -Filter "TerminessNerdFontMono-Regular.ttf" -ErrorAction SilentlyContinue
    $results["Terminus Nerd Font"] = if ($fontInstalled) { "installed" } else { "FAILED - check manually: choco install nerd-fonts-terminus" }
} else {
    $results["Terminus Nerd Font"] = "skipped - no Chocolatey (bar will fall back to a system font, icons may show as boxes)"
}

Write-Host "=== 6. Resolving real tool install paths ===" -ForegroundColor Cyan
& "$Root\scripts\Resolve-Tools.ps1"

Write-Host "=== 7. Naming the 4 virtual desktops ===" -ForegroundColor Cyan
try {
    & "$Root\scripts\Set-DesktopNames.ps1" -ErrorAction Stop
    $results["Virtual desktop names"] = "set"
} catch {
    $results["Virtual desktop names"] = "FAILED (needs the VirtualDesktop module from step 4): $_"
}

Write-Host "=== 8. Applying the default theme ===" -ForegroundColor Cyan
try {
    & "$Root\scripts\Apply-SynTheme.ps1" -Name SYN-OS-RED -ErrorAction Stop
    $results["Theme"] = "applied"
} catch {
    $results["Theme"] = "FAILED: $_"
}

Write-Host "=== 9. Registering the autostart task (left DISABLED) ===" -ForegroundColor Cyan
try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -File `"$Root\scripts\Start-SynSession.ps1`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    if (Get-ScheduledTask -TaskName "SynOsSession" -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName "SynOsSession" -Confirm:$false
    }
    Register-ScheduledTask -TaskName "SynOsSession" -Action $action -Trigger $trigger -Description "SYN-OS-WINDOWS session start" | Out-Null
    Disable-ScheduledTask -TaskName "SynOsSession" | Out-Null
    $results["Autostart task"] = "registered (disabled)"
} catch {
    $results["Autostart task"] = "FAILED: $_"
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
foreach ($k in $results.Keys) {
    $v = $results[$k]
    $color = if ($v -match "FAILED|MISSING") { "Red" } elseif ($v -match "skipped") { "Yellow" } else { "Gray" }
    Write-Host ("  {0,-22} {1}" -f $k, $v) -ForegroundColor $color
}
Write-Host ""
Write-Host "Nothing is running and nothing auto-starts yet."
Write-Host "  Start it now (this session only):  & `"$Root\scripts\Start-SynSession.ps1`""
Write-Host "  Turn on autostart for every login:  Enable-ScheduledTask -TaskName SynOsSession"
Write-Host "Anything marked FAILED or MISSING above needs a manual look before those pieces will work."
