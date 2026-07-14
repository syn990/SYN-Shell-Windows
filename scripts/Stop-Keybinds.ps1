# Kills only the AutoHotkey process running syn-wm.ahk, not any other
# AutoHotkey script you might have running.
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
    Where-Object { $_.CommandLine -match 'syn-wm\.ahk' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
