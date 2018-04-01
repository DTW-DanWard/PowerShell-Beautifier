# Testing Automation

## Testing Across OSes using Docker Containers
By using Docker with the [PowerShell Core images](https://hub.docker.com/r/microsoft/powershell/tags/) provided by PowerShell team, it's easy to automate PowerShell testing across operating systems.  This has been done in Invoke-RunTestScriptInDockerCoreContainers.ps1.  While this script was originally set up for testing the PowerShell Beautifier, it should be easy to reuse for testing any PowerShell code - possibly without any modifications to Invoke-RunTestScriptInDockerCoreContainers.ps1.

**A quick note about Docker Server OS and image OSes**

Run ```docker version``` and check out the Server value for OS/Arch; unless you've changed it, the value will be *linux/amd64*.  This means the Docker Server currently can only support Linux OS images, like Ubuntu, CentOS & openSUSE.  It is possible to support Windows images, like Nano Server and Windows Server Core, but not simultaneously with the Linux ones.  Keep in mind that Docker provides isolation, not full machine virtualization.

To change the Server OS currently supported, there is a Docker command line tool.  Also Docker for Windows has a system tray icon with an option to *Switch to Windows Containers*.  [Read this](https://blog.docker.com/2016/09/build-your-first-docker-windows-server-container/) for more information.


### Testing the Beautifier using Containers
To use Invoke-RunTestScriptInDockerCoreContainers.ps1 to test the Beautifier:
* Fork, clone or download the beautifier.
* [Install Docker](https://www.docker.com/)
* Pick a [PowerShell Core image](https://hub.docker.com/r/microsoft/powershell/tags/) or more to download.
* Download image(s) using pull; for example:  ```docker pull microsoft/powershell:ubuntu16.04```
* Run the test script - below.

**Run script with just one test image**
```
Invoke-RunTestScriptInDockerCoreContainers.ps1 -TestImageNames ubuntu16.04

Testing with these values:
  Test file:        PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet
  Docker hub repo:  microsoft/powershell
  Images names:     ubuntu16.04
  Source paths:     C:\code\GitHub\PowerShell-Beautifier

Testing on these containers: ubuntu16.04

ubuntu16.04
  Preexisting container found
  Starting container
  Getting temp folder path in container
  Copying source content to container temp folder /tmp/
    C:\code\GitHub\PowerShell-Beautifier
  Running test script on container
  Test script completed successfully
  Stopping container
```

**Run Container script with all defaults images**

If you don't specify parameter -TestImageNames it will attempt to test against these default images: ubuntu16.04 and centos7.  Also, the script has logic for handling some different situations:
* Missing image - the script gives you the command to pull it down.
* Container already running (ubuntu16.04 in this example) - reuses existing container.
* Image with no container yet (centos7 in this example) - it will create it for you.
```
Invoke-RunTestScriptInDockerCoreContainers.ps1

Testing with these values:
  Test file:        PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet
  Docker hub repo:  microsoft/powershell
  Images names:     ubuntu16.04 centos7 opensuse42.1
  Source paths:     C:\code\GitHub\PowerShell-Beautifier

Image opensuse42.1 is not installed locally but exists in repository microsoft/powershell
To download and install type:
  docker pull microsoft/powershell:opensuse42.1

Testing on these containers: ubuntu16.04 centos7

ubuntu16.04
  Preexisting container found
  Container already started
  Getting temp folder path in container
  Copying source content to container temp folder /tmp/
    C:\code\GitHub\PowerShell-Beautifier
  Running test script on container
  Test script completed successfully
  Stopping container

centos7
  Preexisting container not found; creating and starting
  Getting temp folder path in container
  Copying source content to container temp folder /tmp/
    C:\code\GitHub\PowerShell-Beautifier
  Running test script on container
  Test script completed successfully
  Stopping container
```


**Run quietly**

If you don't want all that helpful text, specify -Quiet; if it runs successfully, it only returns $true.  Note, if you *do* get an error, rerun without -Quiet to get more context about what failed.
```
Invoke-RunTestScriptInDockerCoreContainers.ps1 -Quiet
True
```


### Testing Your Own Code
You can reuse Invoke-RunTestScriptInDockerCoreContainers.ps1 to test your own PowerShell in a Docker container:
* Create a single test script in your code base to run your tests.  If the test runs successfully the script should return only $true.
* Specify one or more SourcePaths to match the one or more paths to copy your code and test script into the container.
* Specify TestFileAndParams to identify the relative path to your test script and specify any necessary parameters to it.
* Specify TestImageNames if you want to test a particular image.
* If you are testing someone else's Core containers on Docker hub, pass a value parameter DockerHubRepository (default is microsoft/powershell).

**Some examples**

```
# Copy multiple source paths, including separate test file
Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths ('c:\Code\Folder1','c:\Code\Folder2','c:\Code\TestFile.ps1') `
  -TestFileAndParams 'TestFile.ps1'

# Copy one folder containing everything, specify Test file located under folder
Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths 'c:\Code\BigFolder' `
  -TestFileAndParams 'BigFolder\test\TestFile.ps1'

# Same as previous, only test centos7
Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths 'c:\Code\BigFolder' `
  -TestFileAndParams 'BigFolder\test\TestFile.ps1' `
  -TestImageNames centos7
```
