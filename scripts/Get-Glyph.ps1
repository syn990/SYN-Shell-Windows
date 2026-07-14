# This file must be saved with a UTF-8 BOM, and output must go through an
# explicit UTF-8 StreamWriter -- see Get-CurrentDesktop.ps1 for why both
# are required together (confirmed by testing, not a guess).
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$stdout = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdout.AutoFlush = $true
[Console]::SetOut($stdout)

$glyphs = @('◆', '◇', '◈', '✦')
$i = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 20) % $glyphs.Count
[Console]::Out.Write($glyphs[$i])
