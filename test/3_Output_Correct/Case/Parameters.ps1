# standard params
$A = Get-ChildItem -Path c:\temp

$B = Join-Path -Path c:\temp -ChildPath asdf.txt

# params that won't be found in memory - keep same case
Get-FooMeowMeow -Bite 3 -HISS
