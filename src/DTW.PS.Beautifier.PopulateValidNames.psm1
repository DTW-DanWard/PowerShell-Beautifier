<#
PowerShell script beautifier by Dan Ward.

IMPORTANT NOTE: this utility rewrites your script in place!  Before running this
on your script make sure you back up your script or commit any changes you have
or run this on a copy of your script.

This file contains functions for populating the ValidNames hashtables.

See https://github.com/DTW-DanWard/PowerShell-Beautifier or http://dtwconsulting.com
for more information.  I hope you enjoy using this utility!
-Dan Ward
#>


Set-StrictMode -Version 2

#region Function: Set-LookupTableValuesFromFile

<#
.SYNOPSIS
Populates the values of the lookup tables from cache file.
.DESCRIPTION
Populates the values of the lookup tables from cache file.
#>
function Set-LookupTableValuesFromFile {
  #region Function parameters
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'Low')]
  param()
  #endregion
  process {
    if ($PSCmdlet.ShouldProcess("ShouldProcess?")) {
      $CacheData = Import-Clixml -Path $ValidValuesCacheFilePath
      $MyInvocation.MyCommand.Module.PrivateData.ValidCommandNames = $CacheData.ValidCommandNames
      $MyInvocation.MyCommand.Module.PrivateData.ValidCommandParameterNames = $CacheData.ValidCommandParameterNames
      $MyInvocation.MyCommand.Module.PrivateData.ValidAttributeNames = $CacheData.ValidAttributeNames
      $MyInvocation.MyCommand.Module.PrivateData.ValidMemberNames = $CacheData.ValidMemberNames
      $MyInvocation.MyCommand.Module.PrivateData.ValidVariableNames = $CacheData.ValidVariableNames
    }
  }
}
#endregion

#region Function: Save-LookupTableValuesToFile

<#
.SYNOPSIS
Saves the in-memory lookup tables values to cache file.
.DESCRIPTION
Saves the in-memory lookup tables values to cache file.
#>
function Save-LookupTableValuesToFile {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    Export-Clixml -InputObject $MyInvocation.MyCommand.Module.PrivateData -Path $ValidValuesCacheFilePath -Depth 10
  }
}
#endregion

#region Function: Update-DTWRegenerateLookupTableValuesFile

<#
.SYNOPSIS
Gets lookup values currently in memory and saves cache file.
.DESCRIPTION
Gets lookup values currently in memory and saves cache file.
#>
function Update-DTWRegenerateLookupTableValuesFile {
  #region Function parameters
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'Low')]
  param()
  #endregion
  process {
    if ($PSCmdlet.ShouldProcess("ShouldProcess?")) {
      Set-LookupTableValuesFromMemory
      Save-LookupTableValuesToFile
    }
  }
}
Export-ModuleMember -Function Update-DTWRegenerateLookupTableValuesFile
#endregion

#region Function: Set-LookupTableValuesFromMemory

<#
.SYNOPSIS
Populates the values of the lookup tables from values currently in memory.
.DESCRIPTION
Populates the values of the lookup tables from values currently in memory.
#>
function Set-LookupTableValuesFromMemory {
  #region Function parameters
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'Low')]
  param()
  #endregion
  process {
    if ($PSCmdlet.ShouldProcess("ShouldProcess?")) {
      $MyInvocation.MyCommand.Module.PrivateData['ValidCommandNames'] = Initialize-ValidCommandNames
      $MyInvocation.MyCommand.Module.PrivateData['ValidCommandParameterNames'] = Initialize-ValidCommandParameterNames
      $MyInvocation.MyCommand.Module.PrivateData['ValidAttributeNames'] = Initialize-ValidAttributeNames
      $MyInvocation.MyCommand.Module.PrivateData['ValidMemberNames'] = Initialize-ValidMemberNames
      $MyInvocation.MyCommand.Module.PrivateData['ValidVariableNames'] = Initialize-ValidVariableNames
    }
  }
}
#endregion

#region Functions: Initialize-ValidCommandNames, Get-AdditionalAliasesForCore

<#
.SYNOPSIS
Gets lookup hashtable of existing cmdlets, functions and aliases.
.DESCRIPTION
Gets lookup hashtable of existing cmdlets, functions and aliases.  Specifically
it gets every cmdlet and function name and creates a hashtable entry with the
name as both the key and value; for aliases the key is the alias and the value
is the command name.
When you look up an alias (by accessing the hashtable by alias name for the key,
it returns the command name.  For functions and cmdlet, it returns the same value
BUT the value is the name with the correct case but the lookup is case-insensitive.
Lastly, when the aliases -> are gathered, each alias definition is checked to make
sure it isn't another alias but an actual cmdlet or function name (in the event
that you have an alias that points to an alias and so on).
#>
function Initialize-ValidCommandNames {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    [hashtable]$CommandNames = @{}
    # get list of all cmdlets and functions in memory, however we want to sort the
    # commands by CommandType Descending so Cmdlets come first.  The reason we want
    # Cmdlet to come first is so they get recorded first; in the event that you have
    # a proxy function (function with same name as a cmdlet), you want to use the
    # value of the Cmdlet name as the lookup value, not the proxy function.
    Get-Command -CommandType Cmdlet,Function | Sort-Object -Property CommandType -Descending | ForEach-Object {
      # only add if doesn't already exist (might not if proxy functions exist)
      if (!($CommandNames.ContainsKey($_.Name))) {
        $CommandNames.($_.Name) = $_.Name
      }
    }

    # manually add Aliases that are known to be safe for Core - across all OSes
    $Aliases = Get-CoreSafeAliases
    $Aliases.Keys | ForEach-Object {
      $Key = $_
      if (!$CommandNames.ContainsKey($Key)) {
        $CommandNames.Add($Key,$Aliases.$Key)
      }
    }

    # return our valid command names
    $CommandNames
  }
}

<#
.SYNOPSIS
Gets lookup hashtable of alias known to exist across OSes for PowerShell core.
.DESCRIPTION
With PowerShell Core, alias mappings will not be consistent across OSes.
This poses significant issues in the likely scenario where a script was edited
on one OS but is then being beautified on another.  Consider 'curl'; in Windows
PowerShell this is a lesser-used alias for Invoke-WebRequest but outside of
Windows PowerShell curl is a popular native executable.  The only safe solution
is to only replace aliases known to be the same across all OSes.  If there are
aliases that don't get replaced, that's OK; it's better than accidentally breaking
someone's script.
#>
function Get-CoreSafeAliases {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    [hashtable]$Aliases = @{}
    $Aliases.Add('?','Where-Object')
    $Aliases.Add('%','ForEach-Object')
    $Aliases.Add('cd','Set-Location')
    $Aliases.Add('chdir','Set-Location')
    $Aliases.Add('clc','Clear-Content')
    $Aliases.Add('clear','Clear-Host')
    $Aliases.Add('clhy','Clear-History')
    $Aliases.Add('cli','Clear-Item')
    $Aliases.Add('clp','Clear-ItemProperty')
    $Aliases.Add('cls','Clear-Host')
    $Aliases.Add('clv','Clear-Variable')
    $Aliases.Add('cnsn','Connect-PSSession')
    $Aliases.Add('copy','Copy-Item')
    $Aliases.Add('cpi','Copy-Item')
    $Aliases.Add('cvpa','Convert-Path')
    $Aliases.Add('dbp','Disable-PSBreakpoint')
    $Aliases.Add('del','Remove-Item')
    $Aliases.Add('dir','Get-ChildItem')
    $Aliases.Add('dnsn','Disconnect-PSSession')
    $Aliases.Add('ebp','Enable-PSBreakpoint')
    $Aliases.Add('echo','Write-Output')
    $Aliases.Add('epal','Export-Alias')
    $Aliases.Add('epcsv','Export-Csv')
    $Aliases.Add('erase','Remove-Item')
    $Aliases.Add('etsn','Enter-PSSession')
    $Aliases.Add('exsn','Exit-PSSession')
    $Aliases.Add('fc','Format-Custom')
    $Aliases.Add('fhx','Format-Hex')
    $Aliases.Add('fl','Format-List')
    $Aliases.Add('foreach','ForEach-Object')
    $Aliases.Add('ft','Format-Table')
    $Aliases.Add('fw','Format-Wide')
    $Aliases.Add('gal','Get-Alias')
    $Aliases.Add('gbp','Get-PSBreakpoint')
    $Aliases.Add('gc','Get-Content')
    $Aliases.Add('gci','Get-ChildItem')
    $Aliases.Add('gcm','Get-Command')
    $Aliases.Add('gcs','Get-PSCallStack')
    $Aliases.Add('gdr','Get-PSDrive')
    $Aliases.Add('ghy','Get-History')
    $Aliases.Add('gi','Get-Item')
    $Aliases.Add('gjb','Get-Job')
    $Aliases.Add('gl','Get-Location')
    $Aliases.Add('gm','Get-Member')
    $Aliases.Add('gmo','Get-Module')
    $Aliases.Add('gp','Get-ItemProperty')
    $Aliases.Add('gps','Get-Process')
    $Aliases.Add('gpv','Get-ItemPropertyValue')
    $Aliases.Add('group','Group-Object')
    $Aliases.Add('gsn','Get-PSSession')
    $Aliases.Add('gtz','Get-TimeZone')
    $Aliases.Add('gu','Get-Unique')
    $Aliases.Add('gv','Get-Variable')
    $Aliases.Add('h','Get-History')
    $Aliases.Add('history','Get-History')
    $Aliases.Add('icm','Invoke-Command')
    $Aliases.Add('iex','Invoke-Expression')
    $Aliases.Add('ihy','Invoke-History')
    $Aliases.Add('ii','Invoke-Item')
    $Aliases.Add('ipal','Import-Alias')
    $Aliases.Add('ipcsv','Import-Csv')
    $Aliases.Add('ipmo','Import-Module')
    $Aliases.Add('irm','Invoke-RestMethod')
    $Aliases.Add('iwr','Invoke-WebRequest')
    $Aliases.Add('kill','Stop-Process')
    $Aliases.Add('md','mkdir')
    $Aliases.Add('measure','Measure-Object')
    $Aliases.Add('mi','Move-Item')
    $Aliases.Add('move','Move-Item')
    $Aliases.Add('mp','Move-ItemProperty')
    $Aliases.Add('nal','New-Alias')
    $Aliases.Add('ndr','New-PSDrive')
    $Aliases.Add('ni','New-Item')
    $Aliases.Add('nmo','New-Module')
    $Aliases.Add('nsn','New-PSSession')
    $Aliases.Add('nv','New-Variable')
    $Aliases.Add('oh','Out-Host')
    $Aliases.Add('popd','Pop-Location')
    $Aliases.Add('pushd','Push-Location')
    $Aliases.Add('pwd','Get-Location')
    $Aliases.Add('r','Invoke-History')
    $Aliases.Add('rbp','Remove-PSBreakpoint')
    $Aliases.Add('rcjb','Receive-Job')
    $Aliases.Add('rcsn','Receive-PSSession')
    $Aliases.Add('rd','Remove-Item')
    $Aliases.Add('rdr','Remove-PSDrive')
    $Aliases.Add('ren','Rename-Item')
    $Aliases.Add('ri','Remove-Item')
    $Aliases.Add('rjb','Remove-Job')
    $Aliases.Add('rmo','Remove-Module')
    $Aliases.Add('rni','Rename-Item')
    $Aliases.Add('rnp','Rename-ItemProperty')
    $Aliases.Add('rp','Remove-ItemProperty')
    $Aliases.Add('rsn','Remove-PSSession')
    $Aliases.Add('rv','Remove-Variable')
    $Aliases.Add('rvpa','Resolve-Path')
    $Aliases.Add('sajb','Start-Job')
    $Aliases.Add('sal','Set-Alias')
    $Aliases.Add('saps','Start-Process')
    $Aliases.Add('sbp','Set-PSBreakpoint')
    $Aliases.Add('sc','Set-Content')
    $Aliases.Add('select','Select-Object')
    $Aliases.Add('set','Set-Variable')
    $Aliases.Add('si','Set-Item')
    $Aliases.Add('sl','Set-Location')
    $Aliases.Add('sls','Select-String')
    $Aliases.Add('sp','Set-ItemProperty')
    $Aliases.Add('spjb','Stop-Job')
    $Aliases.Add('spps','Stop-Process')
    $Aliases.Add('sv','Set-Variable')
    $Aliases.Add('type','Get-Content')
    $Aliases.Add('where','Where-Object')
    $Aliases.Add('wjb','Wait-Job')
    $Aliases
  }
}
#endregion

#region Function: Initialize-ValidCommandParameterNames

<#
.SYNOPSIS
Gets lookup hashtable of existing parameter names on cmdlets and functions.
.DESCRIPTION
Gets lookup hashtable of existing parameter names on cmdlets and functions.
Specifically it gets a unique list of the parameter names on every cmdlet and
function name and creates a hashtable entry with the name as both the key and
value. When you look up a value, it essentially returns the same value BUT
the value is the name with the correct case but the lookup is case-insensitive.
#>
function Initialize-ValidCommandParameterNames {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    [hashtable]$CommandParameterNames = @{}
    #region Parameter casing dilemma
    # Load hashtable with known valid cmdlet and function parameter names
    # In a future version We will attempt to match a parameter to it's cmdlet/function
    # definition so we can match the actual value but regardless we will need this fallback
    # mechanism in case the cmdlet/function in question isn't loaded into memory.

    # All that said: I have see casing inconsistencies across various modules
    # (NoNewLine vs. NoNewline, Force vs. force, etc.) so we will load the
    # Microsoft.PowerShell parameter names first as we consider these the most important
    # ones.
    #endregion

    # get list of all unique parameter names on all cmdlets and functions in memory, MS.PowerShell first
    $Params = Get-Command -CommandType Cmdlet | Where-Object { $_.ModuleName.StartsWith('Microsoft.PowerShell.') } | Where-Object { $null -ne $_.Parameters } | ForEach-Object { $_.Parameters.Keys } | Select-Object -Unique | Sort-Object
    $Name = $null
    $Params | ForEach-Object {
      # param name appears with - in front
      $Name = '-' + $_
      # for each param, add to hash table with name as both key and value
      $CommandParameterNames.Item($Name) = $Name
    }
    # now get all params for cmdlets and functions; the Microsoft.PowerShell ones will already be in
    # the hashtable; add other ones not found yet
    $Params = Get-Command -CommandType Cmdlet,Function | Where-Object { $null -ne $_.Parameters } | ForEach-Object { $_.Parameters.Keys } | Select-Object -Unique | Sort-Object
    $Name = $null
    $Params | ForEach-Object {
      # param name appears with - in front
      $Name = '-' + $_
      # if doesn't exist, add to hash table with name as both key and value
      if (!$CommandParameterNames.Contains($Name)) {
        $CommandParameterNames.Item($Name) = $Name
      }
    }
    $CommandParameterNames
  }
}
#endregion

#region Function: Initialize-ValidAttributeNames

<#
.SYNOPSIS
Gets lookup hashtable of known valid attribute names.
.DESCRIPTION
Gets lookup hashtable of known valid attribute names.  Attributes
as created by the PSParser Tokenize method) include function parameter
attributes.
#>
function Initialize-ValidAttributeNames {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    [hashtable]$AttributeNames = @{
      #region Values for parameter attributes
      <#
      Value below taken from:
        Windows PowerShell Language Specification Version 3.0.docx
        Chapter 12 Attributes
      Not sure how to get these value programmatically; is there a type upon
      which they are defined?
      #>
      Alias = 'Alias';
      AllowEmptyCollection = 'AllowEmptyCollection';
      AllowEmptyString = 'AllowEmptyString';
      AllowNull = 'AllowNull';
      CmdletBinding = 'CmdletBinding';
      ConfirmImpact = 'ConfirmImpact';
      CredentialAttribute = 'CredentialAttribute';
      DefaultParameterSetName = 'DefaultParameterSetName';
      OutputType = 'OutputType';
      Parameter = 'Parameter';
      PositionalBinding = 'PositionalBinding';
      PSDefaultValue = 'PSDefaultValue';
      PSTypeName = 'PSTypeName';
      SupportsShouldProcess = 'SupportsShouldProcess';
      SupportsWildcards = 'SupportsWildcards';
      ValidateCount = 'ValidateCount';
      ValidateLength = 'ValidateLength';
      ValidateNotNull = 'ValidateNotNull';
      ValidateNotNullOrEmpty = 'ValidateNotNullOrEmpty';
      ValidatePattern = 'ValidatePattern';
      ValidateRange = 'ValidateRange';
      ValidateScript = 'ValidateScript';
      ValidateSet = 'ValidateSet';
      #endregion
    }
    $AttributeNames
  }
}
#endregion

#region Function: Initialize-ValidMemberNames

<#
.SYNOPSIS
Gets lookup hashtable of known valid member names.
.DESCRIPTION
Gets lookup hashtable of known valid member names.  Members (Member tokens
as created by the PSParser Tokenize method) include function parameter
properties as well as methods on objects.
#>
function Initialize-ValidMemberNames {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    # The code below seeds the MemberNames hashtable with correct values (from a
    # spelling and case perspective) from common types used in PowerShell scripts.
    # It's likely that more types need to be added - please add what you feel is missing!
    # It would be nice to have many, many types or to programmatically search all types
    # and grab all their values but that would require a long start-up time.  Perhaps in a later v1
    # iteration of the beautifier script (when these values are cached to a text file and
    # quickly read into memory rather than being programmatically looked up each time
    # the beautifier is first used) then it can iterate through more/all types.
    # A better longer term solution is to actually determine the type and the properties
    # on that type but that will have to wait for V2.

    [hashtable]$MemberNames = @{}
    $TypesToCheck = [System.Management.Automation.ParameterAttribute],`
       [string],[char],[byte],`
       [int],[long],[decimal],[single],[double],`
       [bool],[datetime],[guid],[hashtable],[xml],[array],`
       [System.IO.File],[System.IO.FileInfo],[System.IO.FileAttributes],[System.IO.FileOptions],`
       (Get-Item -Path $PSHOME),`
       [System.IO.Directory],[System.IO.DirectoryInfo],[System.Exception]

    $TypesToCheck | ForEach-Object {
      ($_ | Get-Member).Name;
      ($_ | Get-Member -Static).Name;
    } | Sort-Object | Select-Object -Unique | ForEach-Object {
      $MemberNames.Add($_,$_)
    }
    $MemberNames
  }
}
#endregion

#region Function: Initialize-ValidVariableNames

<#
.SYNOPSIS
Gets lookup hashtable of known valid variables names.
.DESCRIPTION
Gets lookup hashtable of known valid variable names with the correct case.
It is seeded with some well known values (true, false, etc.) but will grow
as the parser walks through the script, adding user variables as they are
encountered.
#>
function Initialize-ValidVariableNames {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()
  #endregion
  process {
    # This list could be updated with other known values.  However we won't
    # seed the values from the global variable: drive as those values are probably
    # ad-hoc values from the user shell and less-likely to have correct casing.
    [hashtable]$VariableNames = @{
      #region Values for known variables
      true = 'true';
      false = 'false';
      HOME = 'HOME';
      #endregion
    }
    $VariableNames
  }
}
#endregion

#region 'Main' - loads cache lookup table values upon module load

function Invoke-Main {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {

    # set path to the 'valid values' cache file
    [string]$script:ValidValuesCacheFilePath = Join-Path -Path $PSScriptRoot -ChildPath "DTW.PS.BeautifierValidValuesCache.txt"

    # if cache file exists, load cache values from file
    # else generate from memory then save those values to file
    # side note: calling $MyInvocation.MyCommand.Module.PrivateData only works from within a function
    # so we need to have a 'main' function
    if ($true -eq (Test-Path -Path $ValidValuesCacheFilePath)) {
      Set-LookupTableValuesFromFile
    } else {
      Update-DTWRegenerateLookupTableValuesFile
    }
  }
}
#endregion

# call 'main'
Invoke-Main
