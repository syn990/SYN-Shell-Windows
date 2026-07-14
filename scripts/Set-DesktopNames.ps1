# One-time setup: creates/names 4 virtual desktops to match labwc's
# 🃁 [Terminal] / ℐ [Web] / ℕ [Media] / ⌘ [External] layout.
# Requires: Install-Module VirtualDesktop -Scope CurrentUser
$ErrorActionPreference = "Stop"
Import-Module VirtualDesktop -ErrorAction Stop

$names = @("Terminal", "Web", "Media", "External")

while ((Get-DesktopCount) -lt $names.Count) {
    New-Desktop | Out-Null
}

for ($i = 0; $i -lt $names.Count; $i++) {
    Set-DesktopName $i $names[$i]
}

Write-Host "Named desktops 1-$($names.Count): $($names -join ', ')"
