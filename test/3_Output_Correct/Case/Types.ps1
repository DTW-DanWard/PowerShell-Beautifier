# built-in types; should be all lowercase
[string]$A = 'asdf'
[string]$AA = 'qwerty'

# type that will exist in memory; fix casing
[System.Text.Encoding]$B = $null
[System.Exception]$SW = $null

# type that won't exist in memory; use name as-is
[System.Foo.MeowMeow]$C = $null
