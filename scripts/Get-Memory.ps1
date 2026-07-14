$o = Get-CimInstance Win32_OperatingSystem
[math]::Round((($o.TotalVisibleMemorySize - $o.FreePhysicalMemory) / $o.TotalVisibleMemorySize) * 100)
