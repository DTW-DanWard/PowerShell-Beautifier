# standard params
$A = Get-ChildItem -path c:\temp

$B = Join-Path -PATH c:\temp -childPATH asdf.txt

# params that won't be found in memory - keep same case
Get-FooMeowMeow -Bite 3 -HISS
