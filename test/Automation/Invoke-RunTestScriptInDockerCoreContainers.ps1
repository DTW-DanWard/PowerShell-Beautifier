# To do:
# Confirm-ValidateUserImageNames - pass in image data
# Params for script
# Script help
# Write-Output parameter / run info at top of script

# Add optional param Message to Out-ErrorInfo
# New function: Invoke-RunCommand: [string]$Cmd, [object[]]$Params
#   runs 'legacy' command line commands with call operator &
#   outputs errors if occur and exits script
# Refactor all code to use
#   Some code outside/after of try/catch 
#   Some code pass optional message

# move all main processing code to Invoke-Main so no 'global' variables besides script parameters
# spell check comments
# one last test of all error handling
# review regions in ISE cause they still don't work in VS Code... :(
# Add readme.md to Automation folder


# Add parameter for Quiet option, returns $true or $false
#   batch info to output in case of error?
# Validate params for stuff to copy, stuff to run
# Note in main about call function, if error exits
# run script through beautifier

# No? Params for exiting testing if one container fails (assume always test all?)
#   Or exit after first failure?  Probably exit after first
# Go through TechTasks notes for anything else missing


# in help describe path building of path for test folder path, test file path and option

[string]$DockerHubRepository = "microsoft/powershell"
[string[]]$TestImageNames = "ubuntu16.04", "centos7"
[string[]]$SourcePaths = @("C:\Code\GitHub\PowerShell-Beautifier")
[string]$ContainerTestFolderPath = "/tmp"
[string]$ContainerTestFilePath = "PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet"


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
    [object[]]$ErrorInfo
  )
  #endregion
  process {
    Write-Output "Error occurred running this command:"
    Write-Output "  $Command $Parameters"
    Write-Output "Error info:"
    $ErrorInfo | ForEach-Object { Write-Output $_.ToString() }
  }
}
#endregion


#region Functions: Confirm-ValidateUserImageNames
<#
.SYNOPSIS
Validates script param TestImageNames entries
.DESCRIPTION
Validates script param $TestImageNames entries by comparing against locally
installed images for repository $DockerHubRepository with same name supplied
by user.  If image is found locally it is added to reference parameter ValidImageNames.
If not found locally but is valid for repository $DockerHubRepository, outputs
command for user to run to download image.  If image is not found locally nor
is found at repository $DockerHubRepository, writes error info but does not
exit script.
.PARAMETER ValidImageNames
Reference parameter!  Valid image names from $TestImageNames are returned here
#>
function Confirm-ValidateUserImageNames {
  #region Function parameters
  [CmdletBinding()]
  param(
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
        if ($HubImageDataHashTable.Keys -contains $TestImageTagName) {
          #region Programming note
          # if the image name is valid and not installed locally we could just run the 'docker pull' command
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
          $HubImageDataHashTable.Keys | Sort-Object | ForEach-Object {
            Write-Output "  $_"
          }
          Write-Output " "
        }
      }
    }
    
  }
}
#endregion


#region Functions: Confirm-DockerHubRepositoryFormatCorrect
<#
.SYNOPSIS
Confirms script param $DockerHubRepository is <team name>/<project name>
.DESCRIPTION
Confirms script param $DockerHubRepository is <team name>/<project name>, 
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


#region Functions: Convert-ImageDataToHashTables
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
      # don't specify a name, docker will create the container with a random name. it's a lot
      # easier to find/start/use/stop a container with a distinct name you know in advance. 
      # so we'll base the name on the docker standard RepositoryName:ImageName; unfortunately 
      # docker's container name only allows certain characters (no slashes or colons) so we'll
      # add a sanitized ContainerName property to the image data in $ImageDataHashTable and use
      # that in our code.
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


#region Functions: Get-DockerHubProjectImageInfo
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
    try {
      $Cmd = "docker"
      $Params = @("--version")
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Write-Output "Docker does not appear to be installed or working correctly."
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
    } catch {
      Write-Output "Docker does not appear to be installed or working correctly."
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
  }
}
#endregion


#region Function: Copy-FilesToDockerContainer
<#
.SYNOPSIS
Copies $SourcePaths files to local container $ContainerName
.DESCRIPTION
Copies all $SourcePaths files to local container $ContainerName putting
files under folder $ContainerTestFolderPath
.PARAMETER ContainerName
Name of container to copy files to.
.EXAMPLE
Copy-FilesToDockerContainer MyContainer
# copies files from $SourcePaths local container named MyContainer under path $ContainerTestFolderPath
#>
function Copy-FilesToDockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName
  )
  #endregion
  process {
    Write-Output "  Copying source content to container under $ContainerTestFolderPath"
    try {
      # for each source file path, copy to docker container
      $SourcePaths | ForEach-Object {
        $SourcePath = $_
        Write-Output "    $SourcePath"
        $Cmd = "docker"
        $Params = @("cp", $SourcePath, ($ContainerName + ":" + $ContainerTestFolderPath))
        $Results = & $Cmd $Params 2>&1
        if ($? -eq $false -or $LastExitCode -ne 0) {
          Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        }
      }
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
    }
  }
}
#endregion


#region Function: Create-DockerContainerAndStart
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
Create-DockerContainerAndStart -ImageName MyImageName -ContainerName MyContainer
# Creates local container from repository $DockerHubRepository using image MyImageName
# naming it MyContainer and starts it.
#>
function Create-DockerContainerAndStart {
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
    try {
      $Cmd = "docker"
      $Params = @("run", "--name", $ContainerName, "-t", "-d", ($DockerHubRepository + ":" + $ImageName))
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
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
ContainerId  Name        Image                            Status
-----------  ----        -----                            ------
1c0fc1715cd8 ubuntu16.04 microsoft/powershell:ubuntu16.04 Exited (0) 17 minutes ago
422b3e0d337a test6       microsoft/powershell:ubuntu16.04 Exited (0) 5 days ago
#>
function Get-DockerContainerStatus {
  process {
    # regex to extract 4 items from docker format output
    $Pattern = "([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)"
    $ContainerInfo = $null
    try {
      $Cmd = "docker"
      $Params = @("ps", "-a", "--format", "{{.ID}}`t{{.Names}}`t{{.Image}}`t{{.Status}}")
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
      # now parse results to get individual properties
      $ContainerInfo = $Results | ForEach-Object {
        $Match = Select-String -InputObject $_ -Pattern $Pattern
        New-Object PSObject -Property ([ordered]@{
            ContainerId = $Match.Matches.Groups[1].Value
            Name        = $Match.Matches.Groups[2].Value
            Image       = $Match.Matches.Groups[3].Value
            Status      = $Match.Matches.Groups[4].Value
          })
        }
      $ContainerInfo
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
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

Repository           Tag         ImageId      Size   CreatedSince
----------           ---         -------      ----   ------------
microsoft/powershell ubuntu16.04 1c33de461473 365MB  2 months ago
#>
function Get-DockerImageStatus {
  process {
    # regex to extract 5 items from docker format output
    $Pattern = "([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)"
    $ImageInfo = $null
    try {
      $Cmd = "docker"
      $Params = @("images", $DockerHubRepository, "--format", "{{.Repository}}`t{{.Tag}}`t{{.ID}}`t{{.Size}}`t{{.CreatedSince}}")
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
      # now parse results to get individual properties
      $ImageInfo = $Results | ForEach-Object {
        $Match = Select-String -InputObject $_ -Pattern $Pattern
        New-Object PSObject -Property ([ordered]@{
            Repository   = $Match.Matches.Groups[1].Value
            Tag          = $Match.Matches.Groups[2].Value
            ImageId      = $Match.Matches.Groups[3].Value
            Size         = $Match.Matches.Groups[4].Value
            CreatedSince = $Match.Matches.Groups[5].Value
          })
        }
      $ImageInfo
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
  }
}
#endregion


#region Function: Invoke-TestScriptInDockerContainer
<#
.SYNOPSIS
Executes PowerShell script on local container
.DESCRIPTION
Executes script $ContainerTestFilePath on container $ContainerName at path $ContainerTestFolderPath
If error occurs, reports error and exits script.
.PARAMETER ContainerName
Name of container to use.
.EXAMPLE
Invoke-TestScriptInDockerContainer MyContainer
# Executes script $ContainerTestFilePath on container MyContainer at path $ContainerTestFolderPath
#>
function Invoke-TestScriptInDockerContainer {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName
  )
  #endregion
  process {
    Write-Output "  Running test script on container"
    try {
      $Cmd = "docker"
      $ScriptInContainerToRunTestText = Join-Path -Path $ContainerTestFolderPath -ChildPath $ContainerTestFilePath
      #region A handy tip
      # if you are reading this script, this next bit contains the biggest gotcha I encountered when
      # writing the docker commands to run in PowerShell. if you were to type a docker execute command in a
      # PowerShell window to execute a different PowerShell script in the container, it would look like this:
      #   docker exec containername powershell -Command { /SomeScript.ps1 }
      # the gotcha is that, when converting this to a string command with array of parameters
      # to pass to the call operator & (i.e.: & $Cmd $Params), you must explicitly create " /SomeScript.ps1 "
      # as a scriptblock first; if you try passing it in as a string it will not execute no matter how
      # you format it.
      #endregion
      [scriptblock]$ScriptInContainerToRunTest = [scriptblock]::Create($ScriptInContainerToRunTestText)
      $Params = @("exec", $ContainerName, "powershell", "-Command", $ScriptInContainerToRunTest)
      $Results = & $Cmd $Params 2>&1
      # when used with the -Quiet param my test script is designed to return ONLY $true if everything
      # worked. so if any error occurred or if some type of error message is returned (i.e. anything other
      # than $true) call it an error and report results
      if ($? -eq $false -or $LastExitCode -ne 0 -or $Results -ne $true) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
      } else {
        Write-Output "    Test script completed successfully"
      }
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
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
    try {
      $Cmd = "docker"
      $Params = @("start", $ContainerName)
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
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
    try {
      $Cmd = "docker"
      $Params = @("stop", $ContainerName)
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $Results
        exit
      }
    } catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
  }
}
#endregion

#endregion


#region Define 'global' (script-level) variables
# besides the script parameters, these are the other 'global' (script-level) variables
# but they are only used in the code below here

# Docker image information from Docker hub for project $DockerHubRepository stored
# as an array of PSObjects
$HubImageDataPSObject = $null

# same data as in $HubImageDataPSObject but in a hash table of hash tables (easier
# lookup) plus additional entry added for ContainerName (safe/sanitized name for container)
$HubImageDataHashTable = $null

#endregion

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

# get Docker image names and other details from online Docker hub project tags data (format PSObjects)
$HubImageDataPSObject = Get-DockerHubProjectImageInfo
# convert $HubImageDataPSObject to hashtable of hashtables (easier lookup) and 
# add sanitized ContainerName for each container
$HubImageDataHashTable = Convert-ImageDataToHashTables -ImageDataPSObjects $HubImageDataPSObject

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
Confirm-ValidateUserImageNames -ValidImageNames ([ref]$ValidTestImageTagNames)
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
  $ContainerInfo = Get-DockerContainerStatus | Where-Object { $_.Name -eq $ContainerName }
  # if no container exists, create one and start it
  if ($ContainerInfo -eq $null) {
    # create docker container and start it
    Create-DockerContainerAndStart -ImageName $ValidTestImageTagName -ContainerName $ContainerName
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

  # copy items in script param $SourcePaths to container $ContainerName to location
  # under folder $ContainerTestFolderPath
  # does not exit if error so container can be stopped
  Copy-FilesToDockerContainer -ContainerName $ContainerName

  # run test script $ContainerTestFilePath in container $ContainerName at path $ContainerTestFolderPath
  # does not exit if error so container can be stopped
  Invoke-TestScriptInDockerContainer -ContainerName $ContainerName

  # stop local container
  Stop-DockerContainer -ContainerName $ContainerName
}
#endregion
