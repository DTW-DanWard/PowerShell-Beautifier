Get-ChildItem c:\temp

Get-ChildItem c:\temp

Get-Item c:\temp\asdf.txt

Get-Content c:\temp\asdf.txt

Get-Content c:\temp\asdf.txt

Remove-Item c:\temp\asdf.txt

Write-Output "asdf"

Get-ChildItem -Filter *.txt | Sort-Object LastWriteTime

Get-ChildItem | Where-Object { $_.Extension -eq '.txt' }

Get-ChildItem | ForEach-Object { Write-Output $_.Name }
