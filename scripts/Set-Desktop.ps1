# Requires: Install-Module VirtualDesktop -Scope CurrentUser
param(
    [Parameter(Mandatory)][int]$Index   # 1-based, matches Win+1..4
)
$ErrorActionPreference = "Stop"
Import-Module VirtualDesktop -ErrorAction Stop -WarningAction SilentlyContinue
Switch-Desktop ($Index - 1)
