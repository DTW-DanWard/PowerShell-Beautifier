<#
.SYNOPSIS
Runs PowerShell beautifier testing process
.DESCRIPTION
Runs PowerShell beautifier testing process:
 - takes all script files in 1_Input_Bad,
 - processes each file with beautifier, outputting to 2_Output_Test
 - compares files in 2_Output_Test with correct result file in 3_Output_Correct
   - if files aren't the same, displays diff results in shell or user diff viewer.

To use a diff utility besides Compare-Object, specify a valid diff utility EXE
path in the variable $DTW_PS_Beautifier_DiffViewer.  You could specify this in
your $profile (if you run this a lot) or specify it once in the shell before
running the test script.

There are a lot more details; see script source and documentation on Github for
more information.
.PARAMETER SkipModuleReload
Skips reloading the PowerShell-Beautifier module.  If you aren't making beautifier
code changes but have made changes to the input bad and/or output correct files
and want to quickly retest without reloading module, specify this.
.PARAMETER Quiet
If specified:
 - only output text if errors are found
 - when terminating script, return $true if all tests passed else $false
#>

#region Script parameters
param(
  [Parameter(Mandatory = $false)]
  [switch]$SkipModuleReload,
  [Parameter(Mandatory = $false)]
  [switch]$Quiet
)
#endregion


Set-StrictMode -Version 2


<#
Some additional notes:

First off - if you are reading this: THANK YOU for your interest in this project!

There are 3 folders to know about:
1_Input_Bad - in the repo.  Has example of files with bad formatting to be fixed.
2_Output_Test - NOT in repo, created by test process.  Stores files from 1_Input_Bad
  that have been processed by beautifier.
3_Output_Correct - in the repo.  Contains the files found in 1_Input_Bad that have the
  correct formatting (hand-edited).

Here is how this test script works:
1. Find every file under 1_Input_Bad (except Whitespace\Indentation.ps1*)
2. For each file, run the beautifier on the input/bad file and output the result
   to the 2_Output_Test folder using the sub-folder name and test script name.
3. For the newly created file in 2_Output_Test, compare it with file under
   3_Output_Correct with the sub-folder name and test script name.

 - processes each file with beautifier, outputting to 2_Output_Test
 - compares files in 2_Output_Test with correct result file in 3_Output_Correct
   - if files aren't the same, displays diff results in shell or user diff viewer.

Whitespace\Indentation.ps1 is processed differently.  It is run three times, each time
specifying a different indent step: 2 spaces, 4 spaces and tabs.  For each of these
different indentation tests, the output test result files are compared with these
existing output correct files in folder 3_Output_Correct\Whitespace:
 - Indentation_2space.ps1
 - Indentation_4space.ps1
 - Indentation_tab.ps1.

ONE OTHER THING TO KNOW:

If a result file in 2_Output_Test does not match the corresponding file in folder
3_Output_Correct, a diff is launched to show the difference to the user.  If you
don't make any changes, the test script will use the PowerShell cmdlet Compare-Object
and output the results in the console.  However, if you want to use a different
diff utility, especially a visual diff tool like ExamDiff, you can enable this by
setting a variable named $DTW_PS_Beautifier_DiffViewer to the path of the utility, i.e.

$DTW_PS_Beautifier_DiffViewer = 'C:\Program Files\ExamDiff Pro\ExamDiff.exe'

PLEASE DON'T set this value directly within your copy of the test script in the
event you ever want to push changes back to the project.  (I'm sure others will have
different utilities they prefer.)  So instead you can set that variable
$DTW_PS_Beautifier_DiffViewer in your $profile or in your shell right before running
the test script.
#>


#region Function: Invoke-DTWFileDiff

<#
.SYNOPSIS
Launches diff for 2 files.  Either uses Compare-Object or diff editor
if variable defined and valid.
.DESCRIPTION
Launches diff for 2 files.  If the user has specified a file system path for the
variable DTW_PS_Beautifier_DiffViewer, this is assumed to be an EXE and that is
used.  If that hasn't been defined, diffs with Compare-Object.

Rather than edit this file to fill in a path for variable
$DTW_PS_Beautifier_DiffViewer that is specific to your machine (it will be
different for different users), this can be specified in your profile or in the
shell right before running this test script.
.PARAMETER Path1
Path to first file.
.PARAMETER Path2
Path to second file.
#>
function Invoke-DTWFileDiff {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path1,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path2
  )
  #endregion
  process {
    #region Parameter validation
    #region $Path1 must exist
    if ($false -eq (Test-Path -Path $Path1)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path1"
      return
    }
    #endregion
    # make sure we have the full path
    $Path1 = (Resolve-Path -Path $Path1).Path

    #region $Path1 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path1).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path1"
      return
    }
    #endregion

    #region $Path2 must exist
    if ($false -eq (Test-Path -Path $Path2)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path2"
      return
    }
    #endregion
    # make sure we have the full path
    $Path2 = (Resolve-Path -Path $Path2).Path

    #region $Path2 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path2).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path2"
      return
    }
    #endregion
    #endregion

    # if user has defined the path of a diff viewer in $DTW_PS_Beautifier_DiffViewer
    # then use that utility otherwise use Compare-Object
    if ((Get-ChildItem -Path variable: | Where-Object { $_.Name -eq 'DTW_PS_Beautifier_DiffViewer' }) -and
      ($null -ne $DTW_PS_Beautifier_DiffViewer) -and
      ($true -eq (Test-Path -Path $DTW_PS_Beautifier_DiffViewer))) {
      [string]$Cmd = $DTW_PS_Beautifier_DiffViewer
      [string[]]$Params = $Path1,$Path2
      & $Cmd $Params
    } else {
      $File1Content = Get-Content -Path $Path1 -Encoding (Get-DTWFileEncodingSystemProviderNameFromTypeName -Name ((Get-DTWFileEncoding $Path1).EncodingName))
      $File2Content = Get-Content -Path $Path2 -Encoding (Get-DTWFileEncodingSystemProviderNameFromTypeName -Name ((Get-DTWFileEncoding $Path2).EncodingName))
      Compare-Object $File1Content $File2Content -CaseSensitive | ForEach-Object { Write-Output "        $($_.InputObject + '   ' + $_.SideIndicator)" }
    }
  }
}
#endregion


#region Function: Test-DTWProcessFileCompareOutputTestCorrect

<#
.SYNOPSIS
Runs a full beautify test for a single file.
.DESCRIPTION
Runs a full beautify test for a single file.  Takes the file $InputBadPath,
runs through Edit-DTWBeautifyScript saving result to $OutputTestPath.  Then
compares files contents at $OutputTestPath and $OutputCorrectPath; if not the
same, launches diff.
.PARAMETER InputBadPath
Path to source bad file.
.PARAMETER OutputTestPath
Path to output result file - result of InputBadPath run through beautifier.
.PARAMETER OutputCorrectPath
Path to output correct file - file with correct results.
#>
function Test-DTWProcessFileCompareOutputTestCorrect {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$InputBadPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputTestPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputCorrectPath,
    [Parameter(Mandatory = $false)]
    $IndentText
  )
  #endregion
  process {
    #region Parameter validation

    # only $InputBadPath and $OutputCorrectPath must exist beforehand

    #region $InputBadPath must exist
    if ($false -eq (Test-Path -Path $InputBadPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $InputBadPath"
      return
    }
    #endregion
    # make sure we have the full path
    $InputBadPath = (Resolve-Path -Path $InputBadPath).Path

    #region $InputBadPath must be a file, not a folder
    if ($true -eq ((Get-Item -Path $InputBadPath).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $InputBadPath"
      return
    }
    #endregion

    #region $OutputCorrectPath must exist
    if ($false -eq (Test-Path -Path $OutputCorrectPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $OutputCorrectPath"
      return
    }
    #endregion
    # make sure we have the full path
    $OutputCorrectPath = (Resolve-Path -Path $OutputCorrectPath).Path

    #region $OutputCorrectPath must be a file, not a folder
    if ($true -eq ((Get-Item -Path $OutputCorrectPath).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $OutputCorrectPath"
      return
    }
    #endregion
    #endregion

    # if output test path file exists (test has been run before), remove it first
    if (Test-Path -Path $OutputTestPath) { Remove-Item -Path $OutputTestPath -Force }

    try {
      #region Specify parameters for Edit-DTWBeautifyScript call
      # note: we are specifying Unix standard LF as newline; for any machine pulling the test files
      # from git, the line endings will most likely be LF and not Windows CRLF
      # regardless, the file comparison functionality will ignore the LF / CRLF difference
      [hashtable]$Params = @{
        SourcePath = $InputBadPath
        DestinationPath = $OutputTestPath
        NewLine = "LF"
      }
      # if $IndentText passed, add that to params
      if ($null -ne $IndentText) {
        $Params.IndentType = $IndentText
      }
      # finally: take the source file, run through beautifier and output in test folder
      if (!$Quiet) { Write-Output ('  File: ' + (Split-Path -Path $InputBadPath -Leaf)) }
      #endregion

      Edit-DTWBeautifyScript @Params

      # compare result in test folder with correct folder
      if ($false -eq (Compare-DTWFilesIncludingBOM -Path1 $OutputTestPath -Path2 $OutputCorrectPath)) {
        $script:AllTestsPassed = $false
        Write-Output '    Files do not match. Opening diff of these files:'
        Write-Output "      $OutputTestPath"
        Write-Output "      $OutputCorrectPath"
        Invoke-DTWFileDiff -Path1 $OutputTestPath -Path2 $OutputCorrectPath
      }
    } catch {
      Write-Output 'An error occurred during processing files'
      Write-Output $_
    }
  }
}
#endregion


#region Get current script name and parent folder
# path of current script parent folder
[string]$ScriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
#endregion


#region Re/load beautifier module
# name of this module
$ModuleName = 'PowerShell-Beautifier'
# module is located one folder up
[string]$ModulePath = Join-Path -Path (Split-Path $ScriptFolder -Parent) -ChildPath ($ModuleName + '.psd1')
# make sure it's actually there
if ($false -eq (Test-Path -Path $ModulePath)) {
  Write-Error "Beautifier module not found at path: $ModulePath"
  exit
}
# if module not loaded at all, load now
if ($null -eq (Get-Module -Name $ModuleName)) {
  if (!$Quiet) { Write-Output "Importing beautifier module: $ModuleName" }
  Import-Module $ModulePath
} else {
  # if doing development on the module, it is safest to force a reload of the module
  # each time the test script is run; by default we will do this unless the user
  # specified -SkipModuleReload - which makes sense if a user is only modified test files
  if ($SkipModuleReload) {
    if (!$Quiet) { Write-Output 'Skipping beautifier module reload' }
  } else {
    if (!$Quiet) { Write-Output 'Reloading beautifier module' }
    # use -Force to make sure reloaded if already in memory
    Import-Module $ModulePath -Force
  }
}
#endregion


#region Get full paths to various testing folders
[string]$InputBadFolderName = '1_Input_Bad'
[string]$OutputTestFolderName = '2_Output_Test'
[string]$CorrectFolderName = '3_Output_Correct'

# this root path contains the before/bad files - the files with issues
[string]$RootInputBadFolderPath = Join-Path -Path $ScriptFolder -ChildPath $InputBadFolderName
# this root path contains the files produced by the cleanup tests; the files that need to be tested
[string]$RootOutputTestFolderPath = Join-Path -Path $ScriptFolder -ChildPath $OutputTestFolderName
# this root path contains the correct files - the files to compare with After_Test
[string]$RootOutputCorrectFolderPath = Join-Path -Path $ScriptFolder -ChildPath $CorrectFolderName

#create After_Test root folder if it does not exist; this folder should NOT exist in the repo
if ($false -eq (Test-Path -Path $RootOutputTestFolderPath)) {
  $Results = New-Item -Path $RootOutputTestFolderPath -ItemType 'Directory' 2>&1
  if ($? -eq $false) {
    Write-Error -Message "Error occurred attempting to create root test result folder: $RootOutputTestFolderPath"
    Write-Error -Message ($Results.ToString())
    exit
  }
}
#endregion

# assume all tests passed, set to false (in Test-DTWProcessFileCompareOutputTestCorrect) if one fails
[bool]$AllTestsPassed = $true

#region Main folder processing
# $IndentationTestFileName is the name of the test file specifically used for
# testing different indentation i.e. spaces vs. tabs; it will be processed
# differently than the normal tests - which will use the default indentation
# of 2 spaces - so identifying test file here in order to skip it in normal processing
# FYI, this file is located in the Whitespace folder
$IndentationTestFileName = 'Indentation.ps1'

# test folders to process - list all of them here
[string[]]$TestFolders = 'Case','CompleteFiles','FileEncoding','Rename','Whitespace'
# this structure was originally designed to test just one or two folders at a time
# (via script parameters); turns out running all scripts in all test folders is pretty
# darn fast so there's no real need for the granularity; let's just run them all
# however, if you really want you can easily override which folders by uncommenting
# and modifying the following line with just a subset of the folders
# [string[]]$TestFolders = 'Case','Rename'

# loop through all specified test folders
$TestFolders | ForEach-Object {
  $FolderName = $_
  if (!$Quiet) { Write-Output ("Processing folder: $FolderName") }

  # process a single source folder
  $InputBadFolderPath = Join-Path -Path $RootInputBadFolderPath -ChildPath $FolderName
  $OutputTestFolderPath = Join-Path -Path $RootOutputTestFolderPath -ChildPath $FolderName
  $OutputCorrectFolderPath = Join-Path -Path $RootOutputCorrectFolderPath -ChildPath $FolderName

  # create individual test folder if does not exist; may not if first time running or test results purged
  if ($false -eq (Test-Path -Path $OutputTestFolderPath)) {
    $Results = New-Item -Path $OutputTestFolderPath -ItemType 'Directory' 2>&1
    if ($? -eq $false) {
      Write-Error -Message "Error occurred attempting to create indvidual test result folder: $OutputTestFolderPath"
      Write-Error -Message ($Results.ToString())
      exit
    }
  }

  # loop through all files in folder EXCEPT file named $IndentationTestFileName
  # skip that file, we will processing that file later with different indentation values
  Get-ChildItem -LiteralPath $InputBadFolderPath | Where-Object { $_.Name -ne $IndentationTestFileName } | ForEach-Object {

    $SourceFile = $_
    $SourceFileName = $SourceFile.Name

    # paths to process
    $InputBadPath = $SourceFile.FullName
    $OutputTestPath = Join-Path -Path $OutputTestFolderPath -ChildPath $SourceFileName
    $OutputCorrectPath = Join-Path -Path $OutputCorrectFolderPath -ChildPath $SourceFileName

    Test-DTWProcessFileCompareOutputTestCorrect -InputBadPath $InputBadPath -OutputTestPath $OutputTestPath -OutputCorrectPath $OutputCorrectPath
  }
}
#endregion


#region Process spaces/tabs indentation tests
#only do spaces/tabs indentation tests if processing Whitespace folder tests
if ($TestFolders -contains 'Whitespace') {
  # get source file
  $InputBadIndentationFile = Join-Path -Path $RootInputBadFolderPath -ChildPath ('Whitespace\' + $IndentationTestFileName)

  # this code could be a lot more elegant; in a rush to get this done
  # get destination test file paths for different cases
  $OutputTestIndentationFileTwoSpace = Join-Path -Path $RootOutputTestFolderPath -ChildPath 'Whitespace\Indentation_2space.ps1'
  $OutputTestIndentationFileFourspace = Join-Path -Path $RootOutputTestFolderPath -ChildPath 'Whitespace\Indentation_4space.ps1'
  $OutputTestIndentationFileTab = Join-Path -Path $RootOutputTestFolderPath -ChildPath 'Whitespace\Indentation_tab.ps1'
  # get correct file paths for different cases; same as OutputTest names but OutputCorrect folder
  $CorrectIndentationFileTwoSpace = $OutputTestIndentationFileTwoSpace.Replace($OutputTestFolderName,$CorrectFolderName)
  $CorrectIndentationFileFourspace = $OutputTestIndentationFileFourspace.Replace($OutputTestFolderName,$CorrectFolderName)
  $CorrectIndentationFileTab = $OutputTestIndentationFileTab.Replace($OutputTestFolderName,$CorrectFolderName)

  Test-DTWProcessFileCompareOutputTestCorrect -InputBadPath $InputBadIndentationFile -OutputTestPath $OutputTestIndentationFileTwoSpace -OutputCorrectPath $CorrectIndentationFileTwoSpace -IndentText TwoSpaces
  Test-DTWProcessFileCompareOutputTestCorrect -InputBadPath $InputBadIndentationFile -OutputTestPath $OutputTestIndentationFileFourspace -OutputCorrectPath $CorrectIndentationFileFourspace -IndentText FourSpaces
  Test-DTWProcessFileCompareOutputTestCorrect -InputBadPath $InputBadIndentationFile -OutputTestPath $OutputTestIndentationFileTab -OutputCorrectPath $CorrectIndentationFileTab -IndentText Tabs

}
#endregion


#region Output success/failure message or, if Quiet, return $true if all passed else $false
if ($Quiet) {
  # return $true if all tests passed, false otherwise
  $AllTestsPassed
} else {
  if ($true -eq $AllTestsPassed) {
    Write-Output "`nAll tests passed - woo-hoo!`n"
  } else {
    Write-Output "`nTest failed!`n"
  }
}
#endregion
