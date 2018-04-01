# built-in types; view list with:
# ([psobject].assembly.gettype("System.Management.Automation.TypeAccelerators")::Get).Keys
[string]$A = 'asdf'
[string]$AA = 'qwerty'
[CmdletBinding]
[DscLocalConfigurationManager]

# type that will exist in memory; fix casing
[System.Text.Encoding]$B = $null
[System.Exception]$SW = $null

# type that won't exist in memory; use name as-is
[System.Foo.MeowMeow]$C = $null

# make sure we don't put class name in square brackets
class DontBreakClassDef{}
$Instance = [DontBreakClassDef]::new()
