# Windows equivalent of SYN-OS's syn-theme-apply: one palette file drives
# every color-bearing config through simple token substitution.
param(
    [Parameter(Mandatory)][string]$Name
)
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$StateDir = Join-Path $Root ".state"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

$PaletteFile = Join-Path $Root "themes\$Name.theme"
if (-not (Test-Path $PaletteFile)) {
    $available = (Get-ChildItem "$Root\themes\*.theme" -ErrorAction SilentlyContinue).BaseName -join ", "
    throw "No such theme: $Name. Available: $available"
}

$palette = @{}
Get-Content $PaletteFile -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^(SYN_\w+)="?([^"]*)"?$') {
        $palette[$Matches[1]] = $Matches[2]
    }
}

# Tool paths (AutoHotkey/yasb/pwsh) aren't guaranteed to be in the same
# place on every machine -- Resolve-Tools.ps1 discovers them once and
# writes .state\tool-paths.env; regenerate it if it's missing so this
# script works standalone too, not just after Setup.ps1.
$toolPathsFile = Join-Path $StateDir "tool-paths.env"
if (-not (Test-Path $toolPathsFile)) {
    & (Join-Path $PSScriptRoot "Resolve-Tools.ps1")
}
$tools = @{}
Get-Content $toolPathsFile | ForEach-Object {
    if ($_ -match '^(\w+)="?([^"]*)"?$') {
        $tools[$Matches[1]] = $Matches[2]
    }
}

# Longest/most-specific keys first so e.g. SYN_PANEL_HOVER substitutes
# before the shorter SYN_PANEL does.
$orderedKeys = @(
    'SYN_PANEL_HOVER', 'SYN_ACCENT_DIM', 'SYN_BG_ALT', 'SYN_URGENT',
    'SYN_ACCENT', 'SYN_BORDER', 'SYN_PANEL', 'SYN_TEXT', 'SYN_BG'
)

function Render([string]$TemplatePath) {
    $content = Get-Content $TemplatePath -Raw -Encoding UTF8
    foreach ($key in $orderedKeys) {
        if ($palette.ContainsKey($key)) {
            $content = $content -replace $key, $palette[$key]
        }
    }
    if ($palette.ContainsKey('SYN_THEME_NAME')) {
        $content = $content -replace 'SYN_THEME_NAME', $palette['SYN_THEME_NAME']
    }
    $content = $content -replace 'PROJECT_ROOT', $Root
    foreach ($t in $tools.Keys) {
        $content = $content -replace $t, $tools[$t]
    }
    return $content
}

Write-Host "Applying theme: $($palette['SYN_THEME_NAME'])"

# --- yasb ---
$yasbDir = Join-Path $env:USERPROFILE ".config\yasb"
New-Item -ItemType Directory -Force -Path $yasbDir | Out-Null
Render "$Root\templates\yasb-style.css.tmpl" | Set-Content "$yasbDir\styles.css" -Encoding utf8
Render "$Root\templates\yasb-config.yaml.tmpl" | Set-Content "$yasbDir\config.yaml" -Encoding utf8
if (Get-Process yasb -ErrorAction SilentlyContinue) {
    Write-Host "  yasb: live (styles.css hot-reloads)"
} else {
    Write-Host "  yasb: written (not running)"
}

# --- Windows Terminal ---
$schemeObj = Render "$Root\templates\windows-terminal-scheme.json.tmpl" | ConvertFrom-Json
$settingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$settingsPath = $settingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $existingSchemes = @($settings.schemes | Where-Object { $_.name -ne $schemeObj.name })
    $settings.schemes = $existingSchemes + $schemeObj
    if ($settings.profiles -and $settings.profiles.defaults) {
        $settings.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $schemeObj.name -Force
    }
    ($settings | ConvertTo-Json -Depth 30) | Set-Content $settingsPath -Encoding utf8
    Write-Host "  Windows Terminal: live (new tabs pick it up immediately)"
} else {
    Write-Warning "  Windows Terminal settings.json not found - skipped"
}

# --- Wallpaper ---
if ($palette.ContainsKey('SYN_WALLPAPER')) {
    $wallpaperPath = Join-Path $Root $palette['SYN_WALLPAPER']
    if (Test-Path $wallpaperPath) {
        Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class SynWallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        [SynWallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperPath, 0x01 -bor 0x02) | Out-Null
        Write-Host "  Wallpaper: set"
    } else {
        Write-Host "  Wallpaper: skipped (no file at $wallpaperPath)"
    }
}

# --- Windows accent color (title bars, Start menu, taskbar highlights) ---
if ($palette.ContainsKey('SYN_ACCENT')) {
    $hex = $palette['SYN_ACCENT'].TrimStart('#')
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)

    # Windows stores accent colors as 0xAABBGGRR (alpha, then B/G/R swapped).
    $dword = [Convert]::ToUInt32(("FF{0:X2}{1:X2}{2:X2}" -f $b, $g, $r), 16)

    $accentPaths = @(
        "HKCU:\Software\Microsoft\Windows\DWM",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
    )
    $accentValues = @("AccentColor", "ColorizationColor", "AccentColorMenu", "StartColorMenu", "AccentColorInactive")
    # Controls "Show accent color on title bars and window borders" -- this
    # is what colors the outline around the active window, not just the
    # Start menu/taskbar swatches.
    $colorPrevalencePath = "HKCU:\Software\Microsoft\Windows\DWM"
    $colorPrevalenceName = "ColorPrevalence"

    # Merge-backup: fills in any key not already captured, rather than an
    # all-or-nothing "only back up on first ever run" -- so keys added to
    # this script later (like ColorPrevalence) still get captured on the
    # next apply even if a backup file already exists from before.
    $backupFile = Join-Path $StateDir "accent-color-backup.json"
    $backup = @{}
    if (Test-Path $backupFile) {
        (Get-Content $backupFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $backup[$_.Name] = $_.Value }
    }
    foreach ($p in $accentPaths) {
        foreach ($v in $accentValues) {
            $key = "$p|$v"
            if ($backup.ContainsKey($key)) { continue }
            $existing = Get-ItemProperty -Path $p -Name $v -ErrorAction SilentlyContinue
            if ($existing) { $backup[$key] = $existing.$v }
        }
    }
    $prevalenceKey = "$colorPrevalencePath|$colorPrevalenceName"
    if (-not $backup.ContainsKey($prevalenceKey)) {
        $existingPrevalence = Get-ItemProperty -Path $colorPrevalencePath -Name $colorPrevalenceName -ErrorAction SilentlyContinue
        $backup[$prevalenceKey] = if ($existingPrevalence) { $existingPrevalence.$colorPrevalenceName } else { 0 }
    }
    $backup | ConvertTo-Json | Set-Content $backupFile -Encoding utf8

    New-ItemProperty -Path $colorPrevalencePath -Name $colorPrevalenceName -Value 1 -PropertyType DWord -Force | Out-Null

    foreach ($p in $accentPaths) {
        New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null
        foreach ($v in $accentValues) {
            if ($v -in @("AccentColor", "ColorizationColor") -and $p -notmatch "DWM") { continue }
            if ($v -in @("AccentColorMenu", "StartColorMenu", "AccentColorInactive") -and $p -notmatch "Accent$") { continue }
            New-ItemProperty -Path $p -Name $v -Value $dword -PropertyType DWord -Force | Out-Null
        }
    }

    # 8 repeated 4-byte RGBA slots -- the small color-swatch palette shown
    # in the Start menu / taskbar flyouts reads from this, separately from
    # the single-color DWORDs above.
    $palette32 = New-Object byte[] 32
    for ($i = 0; $i -lt 8; $i++) {
        $palette32[$i * 4] = $r
        $palette32[$i * 4 + 1] = $g
        $palette32[$i * 4 + 2] = $b
        $palette32[$i * 4 + 3] = 0xFF
    }
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentPalette" -Value $palette32 -PropertyType Binary -Force | Out-Null
    New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoColorization" -Value 0 -PropertyType DWord -Force | Out-Null

    Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class SynAccentNotify {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    [UIntPtr]$result = [UIntPtr]::Zero
    [SynAccentNotify]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "ImmersiveColorSet", 2, 100, [ref]$result) | Out-Null

    Write-Host "  Windows accent color: live (title bars need 'Show accent color on title bars and window borders' enabled in Settings > Personalization > Colors)"
}

$palette['SYN_THEME_NAME'] | Set-Content (Join-Path $StateDir "current-theme") -Encoding utf8
Write-Host "Theme applied: $($palette['SYN_THEME_NAME'])"
