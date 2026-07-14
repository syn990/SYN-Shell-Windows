$b = Get-CimInstance Win32_Battery
if ($b) { $b.EstimatedChargeRemaining }
