# built-in types; view list with:
# ([psobject].assembly.gettype("System.Management.Automation.TypeAccelerators")::Get).Keys
[STRING]$A = 'asdf'
[strING]$AA = 'qwerty'
[CMDLetBinding]
[DSCLocalConfigurationManager]

# type that will exist in memory; fix casing
[system.TEXT.encoding]$B = $null
[sysTEM.exCEPtion]$SW = $null

# type that won't exist in memory; use name as-is
[System.Foo.MeowMeow]$C = $null

# make sure we don't put class name in square brackets
class DontBreakClassDef{}
$Instance = [DontBreakClassDef]::new()
