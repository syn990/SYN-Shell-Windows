# Finds the real, absolute paths to the external tools this project shells
# out to (AutoHotkey v2, yasb, PowerShell 7), and writes them to
# .state\tool-paths.env in the same KEY="value" shape as a .theme file.
#
# Why this exists: install locations aren't guaranteed the same across
# machines (winget/choco defaults usually match, but not always), and this
# machine specifically has an older Chocolatey-installed AutoHotkey that
# shadows the real one in PATH -- bare exe names aren't safe to trust.
# Everything that needs one of these paths (Apply-SynTheme.ps1, the AHK
# scripts) reads this file instead of hardcoding a guess.
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$StateDir = Join-Path $Root ".state"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Find-Exe {
    param([string[]]$Candidates, [string]$CommandName)
    foreach ($c in $Candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$ahkExe = Find-Exe -CommandName "AutoHotkey64.exe" -Candidates @(
    "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
)
$yasbExe = Find-Exe -CommandName "yasb.exe" -Candidates @(
    "C:\Program Files\YASB\yasb.exe",
    "$env:LOCALAPPDATA\Programs\YASB\yasb.exe"
)
$pwshExe = Find-Exe -CommandName "pwsh.exe" -Candidates @(
    "C:\Program Files\PowerShell\7\pwsh.exe"
)

$missing = @()
if (-not $ahkExe) { $missing += "AutoHotkey v2" }
if (-not $yasbExe) { $missing += "yasb" }
if (-not $pwshExe) { $missing += "PowerShell 7" }
if ($missing.Count -gt 0) {
    Write-Warning "Could not find: $($missing -join ', '). Run Setup.ps1 first, or install manually."
}

@"
AHK_EXE="$ahkExe"
YASB_EXE="$yasbExe"
PWSH_EXE="$pwshExe"
"@ | Set-Content (Join-Path $StateDir "tool-paths.env") -Encoding utf8

Write-Host "Resolved tool paths:"
Write-Host "  AutoHotkey v2: $(if ($ahkExe) { $ahkExe } else { 'NOT FOUND' })"
Write-Host "  yasb:          $(if ($yasbExe) { $yasbExe } else { 'NOT FOUND' })"
Write-Host "  PowerShell 7:  $(if ($pwshExe) { $pwshExe } else { 'NOT FOUND' })"
