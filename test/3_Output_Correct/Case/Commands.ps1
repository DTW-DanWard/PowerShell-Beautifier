# standard cmdlets
$A = Get-ChildItem c:\temp

$B = Get-ChildItem c:\temp

$C = Get-Content c:\temp\asdf.txt

# cmdlet that won't be found in memory - keep same case
Get-FooMeowMeow -Path c:\temp
