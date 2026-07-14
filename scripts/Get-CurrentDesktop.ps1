# Requires: Install-Module VirtualDesktop -Scope CurrentUser
#
# Two independent Windows PowerShell 5.1 encoding bugs, both required to
# fix together (confirmed by testing each alone -- neither is sufficient
# by itself):
#  1. This file must be saved with a UTF-8 BOM, or PowerShell 5.1 assumes
#     the system ANSI codepage and mangles the glyphs below before any
#     code even runs.
#  2. Even with the source read correctly, output through a redirected/
#     piped stdout (exactly how yasb captures this) still gets mangled by
#     the normal Write-Output pipeline -- neither [Console]::OutputEncoding
#     nor $OutputEncoding fixes this. Replacing [Console]::Out with an
#     explicit UTF-8 StreamWriter and writing to that directly does.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$stdout = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdout.AutoFlush = $true
[Console]::SetOut($stdout)

# The original SYN-OS glyph for desktop 1 was a playing-card suit symbol
# (U+1F0C1), but that needs a UTF-16 surrogate pair and gets mangled even
# with both fixes above (a separate, genuine limitation) -- using a
# BMP-safe spade symbol instead.
$ErrorActionPreference = "Stop"
try {
    Import-Module VirtualDesktop -ErrorAction Stop -WarningAction SilentlyContinue
    $current = Get-CurrentDesktop
    $index = Get-DesktopIndex $current
    $name = Get-DesktopName $current

    $glyphs = @('♠', 'ℐ', 'ℕ', '⌘')
    $glyph = if ($index -ge 0 -and $index -lt $glyphs.Count) { $glyphs[$index] } else { '•' }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = "Desktop $($index + 1)" }

    $json = [PSCustomObject]@{ text = $glyph; tooltip = $name } | ConvertTo-Json -Compress
} catch {
    $json = [PSCustomObject]@{ text = '•'; tooltip = "Error: $($_.Exception.Message)" } | ConvertTo-Json -Compress
}
[Console]::Out.Write($json)
