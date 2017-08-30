# To do:
# Script help
# Params for script
# Function for writing error info; params $Command $ErrorInfo
# Move everything to functions

# Move get container names to function
# ?make sure /tmp exists in container with Test-Path
# Output parameter / run info at top of script
# Add parameter for Quiet option, returns $true or $false
#   batch info to output in case of error?
# Validate params for stuff to copy, stuff to run
# Clean up all asdf
# Note in main about call function, if error exits
# Add readme.md to Automation folder
# run script through beautifier

# No? Params for exiting testing if one container fails (assume always test all?)
#   Or exit after first failure?  Probably exit after first
# Go through TechTasks notes for anything else missing


# in help describe path building of path for test folder path, test file path and option

[string]$DockerHubRepository = "microsoft/powershell"
[string[]]$TestImageTagNames = "ubuntu16.04", "centos7"
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
    # i.e. it should have only 1 slash in it 'in the middle' of other characters
    if ($DockerHubRepository -notmatch '^[^/]+/[^/]+$') {
      Write-Output "The format for DockerHubRepository is incorrect: $DockerHubRepository"
      Write-Output "It should be in the format: TeamName/ProjectName"
      Write-Output "i.e. it should have only 1 slash, surrounded by other text."
      exit
    }
  }
}
#endregion


#region Functions: Get-DockerHubProjectTagInfo
<#
.SYNOPSIS
Returns Docker hub project tag info for $DockerHubRepository
.DESCRIPTION
Returns Docker hub project tag info for $DockerHubRepository; format is PSObjects.
#>
function Get-DockerHubProjectTagInfo {
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
    }
    catch {
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
    }
    catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
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
    }
    catch {
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
    }
    catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
  }
}
#endregion


#region Function: Invoke-TestScriptInContainer
<#
.SYNOPSIS
Executes script on local container
.DESCRIPTION
Executes script $ContainerTestFilePath on container $ContainerName at path $ContainerTestFolderPath
If error occurs, reports error and exits script.
.PARAMETER ContainerName
Name of container to use.
.EXAMPLE
Invoke-TestScriptInContainer MyContainer
# Executes script $ContainerTestFilePath on container MyContainer at path $ContainerTestFolderPath
#>
function Invoke-TestScriptInContainer {
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
      # writing the docker commands to run in PowerShell. if you were to type a docker execute command
      # in a PowerShell window to execute a PowerShell script in the container, it would look like this:
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
    }
    catch {
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
    }
    catch {
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
    }
    catch {
      Out-ErrorInfo -Command $Cmd -Parameters $Params -ErrorInfo $_.Exception.Message
      exit
    }
  }
}
#endregion

#endregion



# Programming note: to improve simplicity and readability, if any of the below functions
# generates an error, info is written and the script is exited from within the function.
# There are some exceptions: if an error occurs in Copy-FilesToDockerContainer or 
# Invoke-TestScriptInContainer, the script does not exit so processing can continue i.e.
# the container will be stopped.

Confirm-DockerInstalled

# confirm script parameter $DockerHubRepository is <team name>/<project name>
Confirm-DockerHubRepositoryFormatCorrect

# get Docker image names and other details from Docker hub project tags data (format PSObjects)
$ImageTagsDataContent = Get-DockerHubProjectTagInfo


#region Get Docker hub project tag info and store in new hashtable $ImageTagsData




# for each tag, create an entry in hash table $ImageTagsData
#   the key will be the tag name
#   the value will be a new hashtable containing the data from the PSObject plus
#     a new property ContainerName, which is a sanitized name to be used as the
#     Docker container name (which can only have certain characters)
$ImageTagsData = [ordered]@{}
$ImageTagsDataContent.name | Sort-Object | ForEach-Object {
  $Name = $_
  $OneTagData = [ordered]@{}
  # get PSObject data
  $TagObject = $ImageTagsDataContent | Where-Object { $_.name -eq $Name }
  
  # for each property on the PSObject, add to hashtable
  ($TagObject | Get-Member -MemberType NoteProperty).Name | Sort-Object | ForEach-Object {
    $OneTagData.$_ = $TagObject.$_
  }

  # add sanitizied container name to $OneTagData that we can use to find/start/stop container name
  # per docker error message only these characters are valid for --name: [a-zA-Z0-9][a-zA-Z0-9_.-]
  # replace any invalid characters with underscores
  $OneTagData.ContainerName = ($DockerHubRepository + '_' + $Name ) -replace '[^a-z0-9_.-]', '_'
  
  # now add this tag's hashtagdata to the main $ImageTagsData hashtable
  $ImageTagsData.$Name = $OneTagData
}
#endregion


#region If no images specified as params, display valid list
if ($TestImageTagNames.Count -eq 0) {
  Write-Output "No image/tag name specified for TestImageTagName; please use a value below:"
  $ImageTagsData.Keys | Sort-Object | ForEach-Object {
    Write-Output "  $_"
  }
  exit
}
#endregion







# get local images for docker project $DockerHubRepository
$LocalDockerRepositoryImages = Get-DockerImageStatus




# listing of valid, locally installed image names
[string[]]$ValidTestImageTagNames = $null



# asdf write-output with tags url for size info, etc.
# asdf put in note about auto pulling down image
  # we do have size info

#region Identify valid local images, valid images not installed locally and invalid image names
# for each image in $TestImageTagNames
#  check if locally installed
#    if so add to valid list
#    if not
#      check if in tags data from repository
#        if so output how to download
#        if not, output invalid info to user
$TestImageTagNames | ForEach-Object {
  $TestImageTagName = $_
  if ($LocalDockerRepositoryImages.Tag -contains $TestImageTagName) {
    $ValidTestImageTagNames += $TestImageTagName
  }
  else {
    if ($ImageTagsData.Keys -contains $TestImageTagName) {
      Write-Output " "
      Write-Output "Image $TestImageTagName is not installed locally but exists in repository $DockerHubRepository"
      Write-Output "To download it type:"
      Write-Output ("  docker pull " + $DockerHubRepository + ":" + $TestImageTagName)
      Write-Output " "
    }
    else {
      Write-Output " "
      Write-Output "Image $TestImageTagName is not installed locally and does not exist in repository $DockerHubRepository"
      Write-Output "Do you have an incorrect image name?  Valid image names are:"
      $ImageTagsData.Keys | Sort-Object | ForEach-Object {
        Write-Output "  $_"
      }
      Write-Output " "
    }
  }
}
#endregion


#region If no valid local images, exit
if ($ValidTestImageTagNames -eq $null) {
  Write-Output "No locally installed images to test against; exiting."
  exit
}
#endregion



Write-Output "Getting container status"
$LocalContainerStatusInfo = Get-DockerContainerStatus




#region Loop through each valid local image and test
Write-Output "Testing on these containers: $ValidTestImageTagNames"


$ValidTestImageTagNames | ForEach-Object {
  $ValidTestImageTagName = $_
  Write-Output " "
  Write-Output $ValidTestImageTagName
  #region Container name information
  # we want to use a specific container name for our containers because
  # if you don't specify a name, docker will create one with a random name.
  # it's a lot easier to find/start/stop a container with a distinct name you 
  # know in advance; in this case we'll base it on the RepositoryName:ImageName
  # but docker's container name only allows certain characters (no slashes or 
  # colons) so we'll the sanitized ContainerName value that added top the 
  # image data in $ImageTagsData
  #endregion
  # get sanitized container name for this image
  $ContainerName = ($ImageTagsData[$ValidTestImageTagName]).ContainerName
  # get test container info
  $ContainerInfo = $LocalContainerStatusInfo | Where-Object { $_.Name -eq $ContainerName }
  # if no container exists, create one and start it
  if ($ContainerInfo -eq $null) {
    Write-Output "  Preexisting container not found; creating..."
    try {
      $Cmd = "docker"
      $Params = @("run", "--name", $ContainerName, "-t", "-d", ($DockerHubRepository + ":" + $ValidTestImageTagName))
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Write-Output "Error occurred running this command:"
        Write-Output "  $Cmd $Params"
        Write-Output "Error is: $Results"
        exit
      }
      # update local container status info
      $LocalContainerStatusInfo = Get-DockerContainerStatus
    }
    catch {
      $ErrorInfo = $_
      Write-Output "Error occurred running this command:"
      Write-Output "  $Cmd $Params"
      Write-Output "Error is: $ErrorInfo"
      exit
    }
  }
  else {
    Write-Output "  Preexisting container found"
    # if container not started, start it
    if ($ContainerInfo.Status.StartsWith("Up")) {
      Write-Output "  Container already started"
    }
    else {
      # start local container and update container status
      Start-DockerContainer -ContainerName $ContainerName
      $LocalContainerStatusInfo = Get-DockerContainerStatus
    }
  }

  # copy items in script param $SourcePaths to container $ContainerName to location
  # under folder $ContainerTestFolderPath
  # does not exit if error so container can be stopped
  Copy-FilesToDockerContainer -ContainerName $ContainerName

  # run test script $ContainerTestFilePath in container $ContainerName at path $ContainerTestFolderPath
  # does not exit if error so container can be stopped
  Invoke-TestScriptInContainer -ContainerName $ContainerName

  # stop local container and update container status
  Stop-DockerContainer -ContainerName $ContainerName
  $LocalContainerStatusInfo = Get-DockerContainerStatus
}
#endregion
