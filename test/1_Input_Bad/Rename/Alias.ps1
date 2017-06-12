dir c:\temp

ls c:\temp

gi c:\temp\asdf.txt

type c:\temp\asdf.txt

cat c:\temp\asdf.txt

del c:\temp\asdf.txt

write "asdf"

Get-ChildItem -Filter *.txt | sort LastWriteTime

Get-ChildItem | where { $_.Extension -eq '.txt' }

dir | % { write $_.Name }
