# standard cmdlets
$A = get-childitem c:\temp

$B = gET-cHILDITEM c:\temp

$C = get-conTENT c:\temp\asdf.txt

# cmdlet that won't be found in memory - keep same case
Get-FooMeowMeow -Path c:\temp
