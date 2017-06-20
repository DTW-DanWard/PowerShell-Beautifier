# built-in types; should be all lowercase
[STRING]$A = 'asdf'
[strING]$AA = 'qwerty'

# type that will exist in memory; fix casing
[system.TEXT.encoding]$B = $null
[sysTEM.exCEPtion]$SW = $null

# type that won't exist in memory; use name as-is
[System.Foo.MeowMeow]$C = $null
