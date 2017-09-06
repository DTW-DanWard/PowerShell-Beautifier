# To do:

# Add parameter for -Quiet option
#   returns $true if no errors, error text and $false if errors
#     batch info to output in case of error?
#     or just output container name (if -Quiet) in Write-Error function
#     with note about 

# Add readme.md to Automation folder
#   Notes about automating container script for own uses
#   Setting up test script

# Go through TechTasks notes for anything else missing

# Migrate all notes to OneNote

# go through one last time with fine toothed comb
  # Remove $ from variables in function help
# one last test of all error handling
#  start with no containers and no images
# review regions in ISE cause they still don't work in VS Code... :(
# spell check comments
# run script through beautifier

# download centos7
# Need to test on Nano Server - and all other
#  add example in Get-DockerContainerTempFolderPath
#    help with temp path
# officially test ubuntu, centos and nano


<#
.SYNOPSIS
Automates PowerShell Core script testing on local Docker containers
.DESCRIPTION
Automates testing of PowerShell Core scripts on different operating systems by using
local Docker containers running PowerShell Core images from the official Microsoft 
Docker hub. Performs these steps:
 - validates user-specified image names with local images and Docker hub versions;
 - for each valid Docker image name:
   - ensures container exists for this image, creating if necessary;
   - ensures container is running;
   - get temp folder path from container;
   - copies user's folders/files, including test script, from computer to container's
     temp folder;
   - runs test script in container;
   - stops container.
If an error occurs running the test script in one container, all processing ceases
after that container is stopped; no additional containers are tested as it's likely
the test script would just fail on those as well.
.PARAMETER SourcePaths
Folders and/or files on local machine to copy to container
.PARAMETER TestFileAndParams
Path to the test script with any params to run test; path is relative to SourcePaths;
see example for more details 
.PARAMETER TestImageNames
Docker image names to test against. Default values: "ubuntu16.04", "centos7"
.PARAMETER DockerHubRepository
Docker hub repository team/project name. Default value: "microsoft/powershell"
.EXAMPLE
.\Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths 'C:\Code\GitHub\PowerShell-Beautifier' `
  -TestFileAndParams 'PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet'
  -TestImageNames ('ubuntu16.04','centos7','nanoserver')

Key details here: 
 - C:\Code\GitHub\PowerShell-Beautifier is a folder that gets copied to each container.
 - The test script is located under that folder, so including that source folder name,
     the path is: PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1
 - -Quiet is a parameter of Invoke-DTWBeautifyScriptTests.ps1

.EXAMPLE
.\Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths ('c:\Code\Folder1','c:\Code\Folder2','c:\Code\TestFile.ps1') `
  -TestFileAndParams 'TestFile.ps1'

Key details here:
 - TestFile.ps1 is the test file to run here.
 - We are explicitly copying over that file, so it will be located in the root of 
   the temp folder in the container.  For that reason, there is no relative path
   to that script in the TestFileAndParams value.
 - That script could be anywhere, doesn't have to be in the root of c:\Code, so the
   SourcePath value could be c:\Code\TestScripts\Latest\TestFile.ps1 but the 
   TestFileAndParams value would be the same.
#>

#region Script parameters
# note: the default values below are specific to my machine and the PowerShell-Beautifier
# project. I tried to parameterize and genericize this as much as possible so that it could
# be used by others with (perferably) no code changes. See readme.md in same folder as this
# script for more information about modifying this for your own needs.
param(
  [string[]]$SourcePaths = 'C:\Code\GitHub\PowerShell-Beautifier',
  [string]$TestFileAndParams = 'PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet',
  [string[]]$TestImageNames = @('ubuntu16.04', 'centos7'),
  [string]$DockerHubRepository = 'microsoft/powershell'
)
#endregion


#region Output startup info
Write-Output " "
Write-Output "Testing with these values:"
Write-Output "  Test file:        $TestFileAndParams"
Write-Output "  Docker hub repo:  $DockerHubRepository"
Write-Output "  Images names:     $TestImageNames"
if ($SourcePaths.Count -eq 1) {
Write-Output "  Source paths:     $SourcePaths"
} else {
  Write-Output "  Source paths:"
  $SourcePaths | ForEach-Object {
    Write-Output "    $_"
  }
}
#endregion


#region Misc functions

#region Function: Out-ErrorInfo
<#
.SYNOPSIS
Write-Output error information when running a command
.DESCRIPTION
Write-Output error information when running a command
.PARAMETER Command
Command that was run
.PARAMETER Parameters
Parameters for the command
.PARAMETER ErrorInfo
Error information captured to display
.PARAMETER ErrorMessage
Optional message to display before all error info
.EXAMPLE
Out-ErrorInfo -Command "docker" -Parameters "--notaparam" -ErrorInfo $CapturedError
# Writes command, parameters and error info to output
#>
function Out-ErrorInfo {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [object[]]$Parameters,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [object[]]$ErrorInfo,
    [string]$ErrorMessage
  )
  #endregion
  process {
    if ($ErrorMessage -ne $null -and $ErrorMessage.Trim() -ne '') {
      Write-Output $ErrorMessage
    }
    Write-Output "Error occurred running this command:"
    Write-Output "  $Command $Parameters"
    Write-Output "Error info:"
    $ErrorInfo | ForEach-Object { Write-Output $_.ToString() }
  }
}
#endregion


#region Function: Invoke-RunCommand
<#
.SYNOPSIS
Runs 'legacy' command-line commands with call operator &
.DESCRIPTION
Runs 'legacy' command-line commands with call operator & in try/catch
block and tests both $? and $LastExitCode for errors. If error occurs, 
writes out using Out-ErrorInfo.
.PARAMETER Command
Command to run
.PARAMETER Parameters
Parameters to use
.PARAMETER ErrorMessage
Optional message to display if error occurs
.PARAMETER ExitOnError
If error occurs, exit script
#>
function Invoke-RunCommand {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [object[]]$Parameters,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ref]$Results,
    [string]$ErrorMessage,
    [switch]$ExitOnError
  )
  #endregion
  process {
    try {
      $Results.value = & $Command $Parameters 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Command -Parameters $Parameters -ErrorInfo $Results.value -ErrorMessage $ErrorMessage
        if ($ExitOnError -eq $true) { exit }
      }
    } catch {
      Out-ErrorInfo -Command $Command -Parameters $Parameters -ErrorInfo $_.Exception.Message -ErrorMessage $ErrorMessage
      if ($ExitOnError -eq $true) { exit }
    }
  }
}
#endregion


#region Function: Confirm-ValidateUserImageNames
<#
.SYNOPSIS
Validates script param TestImageNames entries
.DESCRIPTION
Validates script parameter TestImageNames entries by comparing against locally
installed images for repository DockerHubRepository with same name supplied
by user.  If image is found locally it is added to reference parameter ValidImageNames.
If not found locally but is valid for repository DockerHubRepository (i.e. from
the hub data, image names passed in via DockerHubRepositoryImageNames), outputs
command for user to run to download image.  If image is not found locally nor
is found at repository $DockerHubRepository, writes error info but does not
exit script.
.PARAMETER DockerHubRepositoryImageNames
Listing of valid image names direct from the Docker hub repository itself
.PARAMETER ValidImageNames
Reference parameter! Any/all valid image names found in list TestImageNames are
returned in this parameter
#>
function Confirm-ValidateUserImageNames {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DockerHubRepositoryImageNames,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ref]$ValidImageNames
  )
  #endregion
  process {
    # get local images for docker project $DockerHubRepository
    $LocalDockerRepositoryImages = Get-DockerImageStatus

    $TestImageNames | ForEach-Object {
      $TestImageTagName = $_
      if ($LocalDockerRepositoryImages.Tag -contains $TestImageTagName) {
        $ValidImageNames.value += $TestImageTagName
      }
      else {
        if ($DockerHubRepositoryImageNames -contains $TestImageTagName) {
          #region Programming note
          # if the image name is valid but not installed locally we *could* just run the 'docker pull' command
          # ourselves programmatically.  however, pulling down that much data (WindowsServerCore is 5GB!) is
          # really something the user should initiate.
          #endregion
          Write-Output " "
          Write-Output "Image $TestImageTagName is not installed locally but exists in repository $DockerHubRepository"
          Write-Output "To download and install type:"
          Write-Output ("  docker pull " + $DockerHubRepository + ":" + $TestImageTagName)
          Write-Output " "
        }
        else {
          Write-Output " "
          Write-Output "Image $TestImageTagName is not installed locally and does not exist in repository $DockerHubRepository"
          Write-Output "Do you have an incorrect image name?  Valid image names are:"
          $DockerHubRepositoryImageNames | Sort-Object | ForEach-Object {
            Write-Output "  $_"
          }
          Write-Output " "
        }
      }
    }
    
  }
}
#endregion


#region Function: Confirm-DockerHubRepositoryFormatCorrect
<#
.SYNOPSIS
Confirms script param DockerHubRepository is <team name>/<project name>
.DESCRIPTION
Confirms script param DockerHubRepository is <team name>/<project name>, 
i.e. it should have only 1 slash in it 'in the middle' of other characters.
If correct, does nothing, if incorrect writes info and exits script.
#>
function Confirm-DockerHubRepositoryFormatCorrect {
  process {
    # the value for $DockerHubRepository should be: <team name>/<project name>
    # i.e. it should have only 1 slash in it between other characters
    if ($DockerHubRepository -notmatch '^[^/]+/[^/]+$') {
      Write-Output "The format for DockerHubRepository is incorrect: $DockerHubRepository"
      Write-Output "It should be in the format: TeamName/ProjectName"
      Write-Output "That is: only 1 forward slash surrounded by other non-forward-slash text"
      exit
    }
  }
}
#endregion


#region Function: Confirm-SourcePathsValid
<#
.SYNOPSIS
Confirms script param SourcePaths paths all exist
.DESCRIPTION
Confirms script param SourcePaths paths all exist. If all paths exist, function
does nothing; if they don't, error info is displayed and script exists.
#>
function Confirm-SourcePathsValid {
  process {
    $SourcePaths | ForEach-Object {
      $SourcePath = $_
      if ($false -eq (Test-Path -Path $SourcePath)) {
        Write-Output "Source path not found: $SourcePath"
        exit
      }
    }
  }
}
#endregion


#region Function: Convert-DockerTextToPSObjects
<#
.SYNOPSIS
Converts tab-separated Docker command output text into PSObjects
.DESCRIPTION
Docker commands - like all non-PowerShell commands - return output as a string per line.
In order to be able to better use this output in PowerShell, it's best to convert this
output to PSObjects, one object per line.  This function converts output that contains
tab-separated fields into PSObjects with note properties - one PSObject per line.
Parameter FieldNames contains the list of field names - with no dot . in the name - to
break up the content into.

This function should be used in conjuntion with Get-DockerGoTemplate, which creates a 
Docker --format parameter value with tabs separating the fields.  You would use the same
array of field names for both Get-DockerGoTemplate and Convert-DockerTextToPSObjects.
.PARAMETER FieldNames
List of field names to build into template
.PARAMETER DockerText
Tab separated Docker text to parse
.EXAMPLE
Convert-DockerTextToPSObjects -FieldNames ("ID","Names","Image") -DockerText "b6e44fd9f3a7    MyContainer    MyImage"
ID           Names       Image
--           -----       -----
b6e44fd9f3a7 MyContainer MyImage

# note: returned PSObject with those values as note properties
#>
function Convert-DockerTextToPSObjects {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$FieldNames,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DockerText
  )
  #endregion
  process {
    #region Get regex for parsing a string from Docker text
    # Docker string will be field values separated by tabs so need a regex like this:
    #   ([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)
    [string]$RegEx = ""
    for ($i = 1; $i -le $FieldNames.Count; $i++) {
      if ($RegEx.Length -gt 0) { $RegEx += "`t" }
      $RegEx += "([^`t]+)"
    }
    #endregion
    $PSObjects = $null
    $DockerText | ForEach-Object {
      # break up $DockerText line into individual fields 
      $Match = Select-String -InputObject $_ -Pattern $Regex
      # create empty object PSObject to store data
      $PSObject = New-Object PSObject
      # now add property for each GoField
      for ($i = 0; $i -lt $FieldNames.Count; $i++) {
        $PSObject = Add-Member -InputObject $PSObject -NotePropertyName $FieldNames[$i] -NotePropertyValue ($Match.Matches.Groups[($i + 1)].Value) -PassThru
      }
      $PSObjects += $PSObject
    }
    $PSObjects
  }
}
#>


#region Function: Convert-ImageDataToHashTables
<#
.SYNOPSIS
Converts Docker hub project image/tags data to hashtable of hashtables
.DESCRIPTION
Converts Docker hub project image/tags data, in the form of an object array,
to hashtable of hashtables for easier lookup.  Also adds a sanitized / safe
value to use for container name, based on repository:image name.
.PARAMETER ImageDataPSObjects
Image data as array of PSObjects
#>
function Convert-ImageDataToHashTables {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [object[]]$ImageDataPSObjects
  )
  #endregion
  process {
    $ImageDataHashTable = [ordered]@{}
    # for each entry in $ImageDataPSObjects:
    #   create an entry in hash table $ImageDataHashTable
    #   the key will be the image/tag name
    #   the value will be a new hashtable containing the data from the PSObject plus
    #     a new property ContainerName, which is a sanitized name to be used as the
    #     Docker container name (which can only have certain characters)
    $ImageDataPSObjects.name | Sort-Object | ForEach-Object {
      $Name = $_
      $OneImageData = [ordered]@{}
      # get PSObject for this tag
      $TagObject = $ImageDataPSObjects | Where-Object { $_.name -eq $Name }
      
      # for each property on the PSObject, add to hashtable
      ($TagObject | Get-Member -MemberType NoteProperty).Name | Sort-Object | ForEach-Object {
        $OneImageData.$_ = $TagObject.$_
      }
    
      #region Container name information
      # when creating and using containers we want to use a specific container name; if you
      # don't specify a name, docker will create the container with a random value. it's a lot
      # easier to find/start/use/stop a container with a distinct name you know in advance. 
      # so we'll base the name on the docker standard RepositoryName:ImageName; unfortunately 
      # docker's container name only allows certain characters (no slashes or colons) so we'll
      # add a sanitized ContainerName property to the image data in $ImageDataHashTable and use
      # that later in our code.
      # per docker error message only these characters are valid for the --name parameter:
      #   [a-zA-Z0-9][a-zA-Z0-9_.-]
      #endregion
      # replace any invalid characters with underscores to get sanitized/safe name
      $OneImageData.ContainerName = ($DockerHubRepository + '_' + $Name ) -replace '[^a-z0-9_.-]', '_'
      
      # now add this image/tag's hashtable data to the main $ImageDataHashTable hashtable
      $ImageDataHashTable.$Name = $OneImageData
    }
    #return data
    $ImageDataHashTable
  }
}
#endregion


#region Function: Get-DockerGoTemplate
<#
.SYNOPSIS
Creates a tab-separated Docker --format parameter for a list of fields
.DESCRIPTION
Creates a string, to be used as a Docker --format parameter value, from a list of field
names.  The fields will be tab-separated to allow for easier parsing into PSObjects.

**NOTE: the field names should NOT include the dot . in the name; that will be added by
this function. We don't want to include the . in the actual PSObject property name
so this function will add it now rather than remove it later when we construct the PSObject.
.PARAMETER FieldNames
List of field names to build into template
.EXAMPLE
Get-DockerGoTemplate -FieldNames ("ID","Names","Image","Status")
{{.ID}}`t{{.Names}}`t{{.Image}}`t{{.Status}}
# note: dot . prefix added to each field name
#>
function Get-DockerGoTemplate {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$FieldNames
  )
  #endregion
  process {
    [string]$Template = ""
    # for each field, add to template with field surrounded in {{ }} and
    # separated by `t tabs, for example: 
    #   {{.ID}}`t{{.Names}}`t{{.Image}}`t{{.Status}}
    $FieldNames | ForEach-Object {
      if ($Template.Length -gt 0) { $Template += "`t" }
      $Template += '{{.' + $_ + '}}'
    }
    $Template
  }
}
#endregion

#region Function: Get-DockerHubProjectImageInfo
<#
.SYNOPSIS
Returns Docker hub project image/tag info for $DockerHubRepository
.DESCRIPTION
Returns Docker hub project image/tag info for $DockerHubRepository; format is PSObjects.
#>
function Get-DockerHubProjectImageInfo {
  process {
    # path to tags for Docker project
    $ImageTagsUri = "https://hub.docker.com/v2/repositories/" + $DockerHubRepository + "/tags"
    try {
      $Response = Invoke-WebRequest -Uri $ImageTagsUri
      # Convert JSON response to PSObjects and return
      (ConvertFrom-Json -InputObject $Response.Content).results
    } catch {
      Write-Output "Error occurred calling Docker hub project tags url"
      Write-Output "  Url:   $ImageTagsUri"
      Write-Output "  Error: $($_.Exception.Message)"
      exit
    }
  }
}
#endregion

#endregion


#region All Docker command functions

#region Function: Confirm-DockerInstalled
<#
.SYNOPSIS
Confirms docker is installed
.DESCRIPTION
Confirms docker is installed; if installed ('docker --version' works) then function
does nothing.  If not installed, reports error and exits script.
#>
function Confirm-DockerInstalled {
  process {
    $Cmd = "docker"
    $Params = @("--version")
    $ErrorMessage = "Docker does not appear to be installed or is not working correctly."
    # capture Results output and discard; if error, Invoke-RunCommand exits script
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ErrorMessage $ErrorMessage -ExitOnError
  }
}
#endregion


#region Function: Copy-FilesToDockerContainer
<#
.SYNOPSIS
Copies $SourcePaths files to local container ContainerName
.DESCRIPTION
Copies all $SourcePaths files to local container ContainerName putting
files under folder ContainerPath
.PARAMETER ContainerName
Name of container to copy files to.
.PARAMETER ContainerPath
Path in container to copy files to.
.EXAMPLE
Copy-FilesToDockerContainer -ContainerName MyContainer -ContainerPath /tmp
# copies files from $SourcePaths local container named MyContainer under path ContainerPath
#>
function Copy-FilesToDockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerPath

    )
  #endregion
  process {
    Write-Output "  Copying source content to container temp folder $ContainerPath"
    # for each source file path, copy to docker container
    $SourcePaths | ForEach-Object {
      $SourcePath = $_
      Write-Output "    $SourcePath"
      $Cmd = "docker"
      $Params = @("cp", $SourcePath, ($ContainerName + ":" + $ContainerPath))
      # capture output and discard; don't exit on error
      $Results = $null
      Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results)
    }
  }
}
#endregion


#region Function: Initialize-DockerContainerAndStart
<#
.SYNOPSIS
Creates local container and starts it
.DESCRIPTION
Creates local container and starts it using docker run (as opposed to explicit
docker create and start commands). Uses image $ImageName from repository 
$DockerHubRepository and creates with name $ContainerName.
If error occurs, reports error and exits script.
.PARAMETER ImageName
Name of docker image to use to create container.
.PARAMETER ContainerName
Name of container to create.
.EXAMPLE
Initialize-DockerContainerAndStart -ImageName MyImageName -ContainerName MyContainer
# Creates local container from repository $DockerHubRepository using image MyImageName
# naming it MyContainer and starts it.
#>
function Initialize-DockerContainerAndStart {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName
  )
  #endregion
  process {
    Write-Output "  Preexisting container not found; creating and starting"
    $Cmd = "docker"
    $Params = @("run", "--name", $ContainerName, "-t", "-d", ($DockerHubRepository + ":" + $ImageName))
    # capture output and discard; if error, Invoke-RunCommand exits script
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
  }
}
#endregion


#region Function: Get-DockerContainerTempFolderPath
<#
.SYNOPSIS
Gets temp folder path in container ContainerName
.DESCRIPTION
Gets temp folder path inside running container ContainerName by running
[System.IO.Path]::GetTempPath()
If container is not running exists script with error.
.PARAMETER ContainerName
Name of container to create.
.EXAMPLE
Get-DockerContainerTempFolderPath -ContainerName microsoft_powershell_ubuntu16.04
/tmp
#>
function Get-DockerContainerTempFolderPath {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,
    [Parameter(Mandatory = $true)]
    [ref]$Path
  )
  #endregion
  process {
    Write-Output "  Getting temp folder path in container"
    # get container info for $ContainerName
    $ContainerInfo = Get-DockerContainerStatus | Where-Object { $_.Names -eq $ContainerName }
    # this error handling shouldn't be needed; at this point in the script
    # the container name has been validiated and started, but just in case
    # if no container exists or container not started, exit with error
    if ($ContainerInfo -eq $null) {
      Write-Output "Container $ContainerName not found; exiting script"
      exit
    } elseif (! $ContainerInfo.Status.StartsWith("Up")) {
      Write-Output "Container $ContainerName isn't running but it should be; exiting script"
      exit
    }
    $Cmd = "docker"
    [scriptblock]$ScriptInContainerToGetTempPath = [scriptblock]::Create('[System.IO.Path]::GetTempPath()')
    $Params = @("exec", $ContainerName, "powershell", "-Command", $ScriptInContainerToGetTempPath)
    # capture output and return; if error, Invoke-RunCommand exits script
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
    $Path.value = $Results
  }
}
#endregion


#region Function: Get-DockerContainerStatus
<#
.SYNOPSIS
Returns all local docker container info as PSObjects
.DESCRIPTION
Returns all local docker container info as PSObjects with these properties:
ContainerId, Name, Image, Status
If error occurs, reports error and exits script.
.EXAMPLE
Get-DockerContainerStatus
Id           Names       Image                            Status
--           -----       -----                            ------
1c0fc1715cd8 ubuntu16.04 microsoft/powershell:ubuntu16.04 Exited (0) 17 minutes ago
422b3e0d337a test6       microsoft/powershell:ubuntu16.04 Exited (0) 5 days ago
#>
function Get-DockerContainerStatus {
  process {
    [string[]]$DockerGoFormatFields = @('ID','Names','Image','Status')
    $Cmd = "docker"
    $Params = @("ps", "-a", "--format", (Get-DockerGoTemplate -FieldNames $DockerGoFormatFields))
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
    # now parse results to get individual properties, if no data return $null
    if ($Results -ne $null -and $Results.ToString().Trim() -ne '') {
      Convert-DockerTextToPSObjects -FieldNames $DockerGoFormatFields -DockerText $Results
    } else {
      $null
    }
  }
}
#endregion


#region Function: Get-DockerImageStatus
<#
.SYNOPSIS
Returns local docker image info as PSObjects for repository $DockerHubRepository
.DESCRIPTION
Returns local docker image info (images -a) as PSObjects with these properties:
ContainerId, Name, Image, Status
If error occurs, reports error and exits script.
.EXAMPLE
Get-DockerImageStatus | Format-Table

Repository           Tag         Id           Size   CreatedSince
----------           ---         --           ----   ------------
microsoft/powershell ubuntu16.04 1c33de461473 365MB  2 months ago
#>
function Get-DockerImageStatus {
  process {
    [string[]]$DockerGoFormatFields = @('Repository','Tag','ID','Size','CreatedSince')
    $Cmd = "docker"
    $Params = @("images", $DockerHubRepository, "--format", (Get-DockerGoTemplate -FieldNames $DockerGoFormatFields))
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
    # now parse results to get individual properties, if no data return $null
    if ($Results -ne $null -and $Results.ToString().Trim() -ne '') {
      Convert-DockerTextToPSObjects -FieldNames $DockerGoFormatFields -DockerText $Results
    } else {
      $null
    }
  }
}
#endregion


#region Function: Invoke-TestScriptInDockerContainer
<#
.SYNOPSIS
Executes PowerShell script in local container
.DESCRIPTION
Executes script ScriptPath in container ContainerName; if error occurs, reports
error and sets parameter ErrorOccurred = $true.
.PARAMETER ContainerName
Name of container to use.
.PARAMETER ScriptPath
Path in container to run script.
.PARAMETER ErrorOccurred
Reference parameter! $true if an error occurred running test
.EXAMPLE
Invoke-TestScriptInDockerContainer MyContainer /tmp/MyScript.ps1 ([ref]$ErrorOccurred)
# Executes script /tmp/MyScript.ps1 in container, sets $ErrorOccurred = $true if error
#>
function Invoke-TestScriptInDockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ref]$ErrorOccurred
  )
  #endregion
  process {
    Write-Output "  Running test script on container"
    #region A handy tip
    # if you are reading this script, this next bit contains the biggest gotcha I encountered when
    # writing the docker commands to run in PowerShell. if you were to type a docker execute command in a
    # PowerShell window to execute a different PowerShell script in the container, it would look like this:
    #   docker exec containername powershell -Command { /SomeScript.ps1 }
    # the gotcha is that, when converting this to a command with array of parameters to pass to the call
    # operator & (i.e.: & $Cmd $Params), you must explicitly create " /SomeScript.ps1 " as a scriptblock 
    # first; if you try passing it in as a string it will not execute no matter how you format it.
    #endregion
    $Cmd = "docker"
    [scriptblock]$ScriptInContainerToRunTest = [scriptblock]::Create($ScriptPath)
    $Params = @("exec", $ContainerName, "powershell", "-Command", $ScriptInContainerToRunTest)

    # capture output $Results; don't exit on error
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results)
    # my test script in $TestFileAndParams when used with the -Quiet param, is designed to
    # return ONLY $true if everything worked. so if anything other than $true is returned assume 
    # error and report results
    if ($Results -ne $null -and $Results -ne $true) {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
      $ErrorOccurred.Value = $true
    } else {
      Write-Output "  Test script completed successfully"
    }
  }
}
#endregion


#region Function: Start-DockerContainer
<#
.SYNOPSIS
Starts local container
.DESCRIPTION
Starts local container. If error occurs, reports error and exits script.
.PARAMETER ContainerName
Name of container to start.
.EXAMPLE
Start-DockerContainer MyContainer
# starts local container named MyContainer
#>
function Start-DockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName
  )
  #endregion
  process {
    Write-Output "  Starting container"
    $Cmd = "docker"
    $Params = @("start", $ContainerName)
    # capture output and discard; if error, Invoke-RunCommand exits script
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
  }
}
#endregion


#region Function: Stop-DockerContainer
<#
.SYNOPSIS
Stops local container
.DESCRIPTION
Stops local container. If error occurs, reports error and exits script.
.PARAMETER ContainerName
Name of container to stop.
.EXAMPLE
Stop-DockerContainer MyContainer
# stops local container named MyContainer
#>
function Stop-DockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName
  )
  #endregion
  process {
    Write-Output "  Stopping container"
    $Cmd = "docker"
    $Params = @("stop", $ContainerName)
    # capture output and discard; if error, Invoke-RunCommand exits script
    $Results = $null
    Invoke-RunCommand -Command $Cmd -Parameters $Params -Results ([ref]$Results) -ExitOnError
  }
}
#endregion
#endregion


# ################ 'main' begins here




# Programming note: to improve simplicity and readability, if any of the below functions
# generates an error, info is written and the script is exited from within the function.
# There are some exceptions: if an error occurs in Copy-FilesToDockerContainer or 
# Invoke-TestScriptInDockerContainer, the script does not exit so processing can continue
# and the container will be stopped.


# make sure Docker is installed, 'docker' is in the path and is working
# no point in continuing if Docker isn't working
Confirm-DockerInstalled

#region Get Docker hub image/tag data and validate script parameters

# confirm script parameter $DockerHubRepository is <team name>/<project name>
Confirm-DockerHubRepositoryFormatCorrect

# confirm all the user-supplied paths exist
Confirm-SourcePathsValid

# for project $DockerHubRepository, get Docker image names and other details from online Docker hub
# project tags data (format of data is PSObjects)
[object[]]$HubImageDataPSObject = Get-DockerHubProjectImageInfo

# now convert data in $HubImageDataPSObject to a hash table of hash tables for easier lookup/usage
# *plus* add an entry for ContainerName - a safe/sanitized name to re/use for the container
[hashtable]$HubImageDataHashTable = Convert-ImageDataToHashTables -ImageDataPSObjects $HubImageDataPSObject

#region If user didn't specify any values for TestImageNames, display valid values and exit
if ($TestImageNames.Count -eq 0) {
  Write-Output "No image/tag name specified for TestImageTagName; please use a value below:"
  $HubImageDataHashTable.Keys | Sort-Object | ForEach-Object {
    Write-Output "  $_"
  }
  exit
}
#endregion

#region Validate script param TestImageNames
# listing of valid, locally installed image names
[string[]]$ValidTestImageTagNames = $null
# check user supplied images names, if valid will be stored in ValidTestImageTagNames 
Confirm-ValidateUserImageNames -DockerHubRepositoryImageNames ($HubImageDataHashTable.Keys) -ValidImageNames ([ref]$ValidTestImageTagNames)
# check if no valid image names - exit
if ($ValidTestImageTagNames -eq $null) {
  Write-Output "No locally installed images to test against; exiting."
  exit
}
#endregion
#endregion

#region Loop through valid local images, create/start container, copy code to it, run test and stop container
Write-Output "Testing on these containers: $ValidTestImageTagNames"

$ValidTestImageTagNames | ForEach-Object {
  $ValidTestImageTagName = $_
  Write-Output " "
  Write-Output $ValidTestImageTagName

  # get sanitized container name (based on repository + image name) for this image
  $ContainerName = ($HubImageDataHashTable[$ValidTestImageTagName]).ContainerName
  # get container info for $ContainerName
  $ContainerInfo = Get-DockerContainerStatus | Where-Object { $_.Names -eq $ContainerName }
  # if no container exists, create one and start it
  if ($ContainerInfo -eq $null) {
    # create docker container and start it
    Initialize-DockerContainerAndStart -ImageName $ValidTestImageTagName -ContainerName $ContainerName
  }
  else {
    Write-Output "  Preexisting container found"
    # if container not started, start it
    if ($ContainerInfo.Status.StartsWith("Up")) {
      Write-Output "  Container already started"
    }
    else {
      # start local container
      Start-DockerContainer -ContainerName $ContainerName
    }
  }

  # temp folder path inside container
  [string]$ContainerTestFolderPath = $null
  Get-DockerContainerTempFolderPath -ContainerName $ContainerName ([ref]$ContainerTestFolderPath)

  # copy items in script param $SourcePaths to container $ContainerName to location
  # under folder $ContainerTestFolderPath
  # does not exit if error so container can be stopped
  Copy-FilesToDockerContainer -ContainerName $ContainerName -ContainerPath $ContainerTestFolderPath

  # run test script in container $ContainerName at path $ContainerTestFolderPath/$TestFileAndParams  
  # if error does not exit so container can be stopped after
  $ContainerScriptPath = Join-Path -Path $ContainerTestFolderPath -ChildPath $TestFileAndParams
  [bool]$ErrorOccurred = $false
  Invoke-TestScriptInDockerContainer -ContainerName $ContainerName -ScriptPath $ContainerScriptPath -ErrorOccurred ([ref]$ErrorOccurred)

  # stop local container
  Stop-DockerContainer -ContainerName $ContainerName

  # if error occurred running test in container, exit now (i.e. after the container has been stopped)
  if ($ErrorOccurred -eq $true) { exit }
}
#endregion
