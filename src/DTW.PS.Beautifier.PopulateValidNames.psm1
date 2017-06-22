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
  [CmdletBinding()]
  param()
  #endregion
  process {
    $CacheData = Import-Clixml -Path $ValidValuesCacheFilePath
    $MyInvocation.MyCommand.Module.PrivateData.ValidCommandNames = $CacheData.ValidCommandNames
    $MyInvocation.MyCommand.Module.PrivateData.ValidCommandParameterNames = $CacheData.ValidCommandParameterNames
    $MyInvocation.MyCommand.Module.PrivateData.ValidAttributeNames = $CacheData.ValidAttributeNames
    $MyInvocation.MyCommand.Module.PrivateData.ValidMemberNames = $CacheData.ValidMemberNames
    $MyInvocation.MyCommand.Module.PrivateData.ValidVariableNames = $CacheData.ValidVariableNames
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
  [CmdletBinding()]
  param()
  #endregion
  process {
    Set-LookupTableValuesFromMemory
    Save-LookupTableValuesToFile
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
  [CmdletBinding()]
  param()
  #endregion
  process {
    $MyInvocation.MyCommand.Module.PrivateData['ValidCommandNames'] = Initialize-ValidCommandNames
    $MyInvocation.MyCommand.Module.PrivateData['ValidCommandParameterNames'] = Initialize-ValidCommandParameterNames
    $MyInvocation.MyCommand.Module.PrivateData['ValidAttributeNames'] = Initialize-ValidAttributeNames
    $MyInvocation.MyCommand.Module.PrivateData['ValidMemberNames'] = Initialize-ValidMemberNames
    $MyInvocation.MyCommand.Module.PrivateData['ValidVariableNames'] = Initialize-ValidVariableNames
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

    # for each alias, check its definition and loop until definition command type isn't an
    # alias; then add with original Alias name as key and 'final' definition as value
    Get-Alias | ForEach-Object {
      $OriginalAlias = $_.Name
      $Cmd = $_.Definition
      while ((Get-Command -Name $Cmd).CommandType -eq 'Alias') { $Cmd = (Get-Command -Name $Cmd).Definition }
      # add alias name as key and definition as value
      $CommandNames.Item($OriginalAlias) = $Cmd
    }

    # also, we want the ForEach Command (i.e. the ForEach-Object Cmdlet used in a 
    # pipeline, not to be confused with the foreach Keyword) to map to the name
    # ForEach-Object.  So, let's add it.
    $CommandNames.'foreach' = 'ForEach-Object'

    # last but not least - let's add any other manual mappings to handle issues
    # where Core does not contain all aliases across all OSes
    $MissingEntries = Get-AdditionalAliasesForCore
    $MissingEntries.Keys | ForEach-Object {
      $Key = $_
      if (!$CommandNames.ContainsKey($Key)) {
        $CommandNames.Add($Key,$MissingEntries.$Key)
      }
    }

    # return our valid command names
    $CommandNames
  }
}

<#
.SYNOPSIS
Gets lookup hashtable of alias/cmdlet mappings inconsistent across all OSes.
.DESCRIPTION
With PowerShell Core alias mappings will no longer be consistent across OSes.
This poses significant issues in the likely scenario where a script was edited
on one OS but is then being beautified on another.  Consider 'cat'; on Windows
this maps to 'Get-Content' but on other Unix-based OSes this will map to the
native executable. The only safe solution is to map ALL these aliases to their
cmdlets (we are beautifying PowerShell scripts after all, not Unix-shell scripts)
to make sure the scripts keep working consistently.

The fix: add a bunch of aliases that might potentially be missing.  This function
returns the likely questionable aliases, it will probably get modified over time
as Core is upgraded.
#>
function Get-AdditionalAliasesForCore {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    [hashtable]$MissingAliasMappings = @{}
    $MissingAliasMappings.Add('ac','Add-Content')
    $MissingAliasMappings.Add('asnp','Add-PSSnapIn')
    $MissingAliasMappings.Add('cat','Get-Content')
    $MissingAliasMappings.Add('cfs','ConvertFrom-String')
    $MissingAliasMappings.Add('compare','Compare-Object')
    $MissingAliasMappings.Add('cp','Copy-Item')
    $MissingAliasMappings.Add('cpp','Copy-ItemProperty')
    $MissingAliasMappings.Add('curl','Invoke-WebRequest')
    $MissingAliasMappings.Add('diff','Compare-Object')
    $MissingAliasMappings.Add('epsn','Export-PSSession')
    $MissingAliasMappings.Add('gcb','Get-Clipboard')
    $MissingAliasMappings.Add('gsnp','Get-PSSnapIn')
    $MissingAliasMappings.Add('gsv','Get-Service')
    $MissingAliasMappings.Add('gwmi','Get-WmiObject')
    $MissingAliasMappings.Add('ipsn','Import-PSSession')
    $MissingAliasMappings.Add('ise','powershell_ise.exe')
    $MissingAliasMappings.Add('iwmi','Invoke-WMIMethod')
    $MissingAliasMappings.Add('lp','Out-Printer')
    $MissingAliasMappings.Add('ls','Get-ChildItem')
    $MissingAliasMappings.Add('man','help')
    $MissingAliasMappings.Add('mount','New-PSDrive')
    $MissingAliasMappings.Add('mv','Move-Item')
    $MissingAliasMappings.Add('npssc','New-PSSessionConfigurationFile')
    $MissingAliasMappings.Add('ogv','Out-GridView')
    $MissingAliasMappings.Add('ps','Get-Process')
    $MissingAliasMappings.Add('rm','Remove-Item')
    $MissingAliasMappings.Add('rmdir','Remove-Item')
    $MissingAliasMappings.Add('rsnp','Remove-PSSnapin')
    $MissingAliasMappings.Add('rujb','Resume-Job')
    $MissingAliasMappings.Add('rwmi','Remove-WMIObject')
    $MissingAliasMappings.Add('sasv','Start-Service')
    $MissingAliasMappings.Add('scb','Set-Clipboard')
    $MissingAliasMappings.Add('shcm','Show-Command')
    $MissingAliasMappings.Add('sleep','Start-Sleep')
    $MissingAliasMappings.Add('sort','Sort-Object')
    $MissingAliasMappings.Add('spsv','Stop-Service')
    $MissingAliasMappings.Add('start','Start-Process')
    $MissingAliasMappings.Add('sujb','Suspend-Job')
    $MissingAliasMappings.Add('swmi','Set-WMIInstance')
    $MissingAliasMappings.Add('tee','Tee-Object')
    $MissingAliasMappings.Add('trcm','Trace-Command')
    $MissingAliasMappings.Add('wget','Invoke-WebRequest')
    $MissingAliasMappings.Add('write','Write-Output')
    $MissingAliasMappings
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
