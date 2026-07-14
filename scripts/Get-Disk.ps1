$d = Get-PSDrive C
"{0:N1}G/{1:N0}G" -f ($d.Used / 1GB), (($d.Used + $d.Free) / 1GB)
