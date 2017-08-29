# To do:
# Script help
# Params for script
# Function for writing error info; params $Command $ErrorInfo
# Move everything to functions
# asdf error handling here in function Get-DockerContainerStatusInfo, more
# Move get container names to function
# Output parameter / run info at top of script
# Add parameter for Quiet option, returns $true or $false
#   batch info to output in case of error?
# Validate params for stuff to copy, stuff to run
# Clean up all asdf
# Params for exiting testing if one container fails
# Go through TechTasks notes for anything else missing
# Add readme.md to Automation folder

# in help describe path building of path for test folder path, test file path and option

[string]$DockerHubRepository = "microsoft/powershell"
[string[]]$TestImageTagNames = "ubuntu16.04", "centos7"
[string[]]$SourcePaths = @("C:\Code\GitHub\PowerShell-Beautifier")
[string]$ContainerTestFolderPath = "/tmp"
[string]$ContainerTestFilePath = "PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet"


# asdf need error handling in function
function Get-DockerContainerStatusInfo {
  $Pattern = "([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)"
  $ContainerInfo = docker ps -a --format "{{.ID}}`t{{.Names}}`t{{.Image}}`t{{.Status}}" | ForEach-Object {
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





#region Validate $DockerHubRepository - one slash surrounded by text
# the value for $DockerHubRepository should be: <team name>/<project name>
# i.e. it should have only 1 slash in it 'in the middle' of other characters
if ($DockerHubRepository -notmatch '^[^/]+/[^/]+$') {
  Write-Output "The format for DockerHubRepository is incorrect: $DockerHubRepository"
  Write-Output "It should be in the format: TeamName/ProjectName"
  Write-Output "i.e. it should have only 1 slash, surrounded by other text."
  exit
}
#endregion


#region Check if Docker installed
# different types of errors depending on docker not being found or --version not
# working; run in try/catch and capture error stream
$Results = $null
try {
  $Cmd = "docker"
  $Params = "--version"
  $Results = & $Cmd $Params 2>&1
  if ($? -eq $false -or $LastExitCode -ne 0) {
    Write-Output "Docker does not appear to be installed or working correctly: $Results"
    exit
  }
}
catch {
  Write-Output "Docker does not appear to be installed or working correctly: $_"
  exit
}
#endregion


#region Get Docker hub project tag info and store in new hashtable $ImageTagsData

# path to tags for Docker project
$ImageTagsUri = "https://hub.docker.com/v2/repositories/" + $DockerHubRepository + "/tags"

#region Confirm url is valid and get image tags data content
try {
  $WebRequest = Invoke-WebRequest -Uri $ImageTagsUri
}
catch {
  Write-Output "Docker hub project tags url failed."
  Write-Output "Url is:  $ImageTagsUri"
  Write-Output "Error:   $($_.Exception.Message)"
  exit
}
#endregion

# Convert $ImageTagsDataContent PSObject[] to hashtable of hashtables
$ImageTagsDataContent = (ConvertFrom-Json -InputObject $WebRequest.Content).results
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


#region Get local images for $DockerHubRepository
$Pattern = "([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)`t([^`t]+)"
$LocalDockerRepositoryImages = docker images $DockerHubRepository --format "{{.Repository}}`t{{.Tag}}`t{{.ID}}`t{{.Size}}`t{{.CreatedSince}}" | ForEach-Object {
  $Match = Select-String -InputObject $_ -Pattern $Pattern
  New-Object PSObject -Property ([ordered]@{
      Repository   = $Match.Matches.Groups[1].Value
      Tag          = $Match.Matches.Groups[2].Value
      ImageId      = $Match.Matches.Groups[3].Value
      Size         = $Match.Matches.Groups[4].Value
      CreatedSince = $Match.Matches.Groups[5].Value
    })
}
#endregion


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




$LocalContainerStatusInfo = Get-DockerContainerStatusInfo




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
      # wait a second then update local container status info
# asdf
      # Start-Sleep -Seconds 1
      $LocalContainerStatusInfo = Get-DockerContainerStatusInfo
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
      Write-Output "  Container not started; starting"
      try {
        $Cmd = "docker"
        $Params = @("start", $ContainerName)
        $Results = & $Cmd $Params 2>&1
        if ($? -eq $false -or $LastExitCode -ne 0) {
          Write-Output "Error occurred running this command:"
          Write-Output "  $Cmd $Params"
          Write-Output "Error is: $Results"
          exit
        }
        # wait a second then update local container status info
# asdf
#        Start-Sleep -Seconds 1
        $LocalContainerStatusInfo = Get-DockerContainerStatusInfo
      }
      catch {
        $ErrorInfo = $_
        Write-Output "Error occurred running this command:"
        Write-Output "  $Cmd $Params"
        Write-Output "Error is: $ErrorInfo"
        exit
      }
    }
  }



  # asdf
  # make sure /tmp exists in container with Test-Path



  #region Copy source content to container
  # docker cp C:\Code\GitHub\PowerShell-Beautifier mimi:/tmp
  Write-Output "  Copying source content to container"
  try {
    # for each source file path, copy to docker container
    $SourcePaths | ForEach-Object {
      $SourcePath = $_
      $Cmd = "docker"
      $Params = @("cp", $SourcePath, ($ContainerName + ":" + $ContainerTestFolderPath))
      $Results = & $Cmd $Params 2>&1
      if ($? -eq $false -or $LastExitCode -ne 0) {
        Write-Output "Error occurred running this command:"
        Write-Output "  $Cmd $Params"
        Write-Output "Error is: $Results"
        exit
      }
    }
  }
  catch {
    $ErrorInfo = $_
    Write-Output "Error occurred running this command:"
    Write-Output "  $Cmd $Params"
    Write-Output "Error is: $ErrorInfo"
    exit
  }
  #endregion


  #region Run test script on container
  Write-Output "  Running test script on container"

  try {
    # docker exec mimi powershell -Command { /tmp/PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 }
    $Cmd = "docker"
    $ScriptInContainerToRunTestText = Join-Path -Path $ContainerTestFolderPath -ChildPath $ContainerTestFilePath
    [scriptblock]$ScriptInContainerToRunTest = [scriptblock]::Create($ScriptInContainerToRunTestText)
    $Params = @("exec", $ContainerName, "powershell", "-Command", $ScriptInContainerToRunTest)
    $Done = & $Cmd $Params 2>&1
    # the test script (with specific param) is designed to ONLY return $true if everything worked
    # so if any error occured or if anything returned other than $true, report error results
    if ($? -eq $false -or $LastExitCode -ne 0 -or $Done -ne $true) {
      Write-Output "    Errors occurred running command:"
      Write-Output "      $Cmd $Params"
      Write-Output " "
      Write-Output "    Error info:"
      $Done | ForEach-Object { Write-Output $_ }
      Write-Output " "
    } else {
      Write-Output "    Test script completed successfully"
    }
  }
  catch {
    $ErrorInfo = $_
    Write-Output "Error occurred running this command:"
    Write-Output "  $Cmd $Params"
    Write-Output "Error is: $ErrorInfo"
    exit
  }
  #endregion


  #region Stop container
  Write-Output "  Stoping container"
  try {
    $Cmd = "docker"
    $Params = @("stop", $ContainerName)
    $Results = & $Cmd $Params 2>&1
    if ($? -eq $false -or $LastExitCode -ne 0) {
      Write-Output "Error occurred running this command:"
      Write-Output "  $Cmd $Params"
      Write-Output "Error is: $Results"
      exit
    }
    # wait a second then update local container status info
# asdf
    #    Start-Sleep -Seconds 1
    $LocalContainerStatusInfo = Get-DockerContainerStatusInfo
  }
  catch {
    $ErrorInfo = $_
    Write-Output "Error occurred running this command:"
    Write-Output "  $Cmd $Params"
    Write-Output "Error is: $ErrorInfo"
    exit
  }
  #endregion
}
#endregion

