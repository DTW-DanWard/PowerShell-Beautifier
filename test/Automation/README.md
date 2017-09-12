# Testing Automation

## Testing Across OSes using Docker Containers
By using Docker with the [PowerShell Core images](https://hub.docker.com/r/microsoft/powershell/tags/) provided by PowerShell team, it's easy to automate PowerShell testing across operating systems.  This has been done in Invoke-RunTestScriptInDockerCoreContainers.ps1.  While this script was originally set up for testing the PowerShell Beautifier, it should be easy to reuse for testing any PowerShell code - possibly without any modifications to Invoke-RunTestScriptInDockerCoreContainers.ps1.

**A quick note about Docker Server OS and Image OSes**

Run ```docker version``` and check out the Server value for OS/Arch; unless you've changed it, the value will be *linux/amd64*.  This means the Docker server currently can only support Linux OS images, like Ubuntu, CentOS 7 & openSUSE.  It is possible to support Windows images, like nanoserver and windowsservercore, but not simultaneously with the Linux ones.  Keep in mind that Docker provides isolation, not full machine virtualization.

To change the Server OS currently supported, there is a Docker command line tool.  Also Docker for Windows has a system tray icon with an option to *Switch to Windows Containers*.  [Read this](https://blog.docker.com/2016/09/build-your-first-docker-windows-server-container/) for more information.


### Testing the Beautifier using Containers
To use Invoke-RunTestScriptInDockerCoreContainers.ps1 to test the Beautifier:
* Fork or download the beautifier.
* [Install Docker](https://www.docker.com/)
* Pick a [PowerShell Core image](https://hub.docker.com/r/microsoft/powershell/tags/) or more to download.
* Download image(s) using pull; for example:  ```docker pull microsoft/powershell:ubuntu16.04```
* Run the test script - below.

**Run Container script with all defaults images**
```
Invoke-RunTestScriptInDockerCoreContainers.ps1
```
If you don't specify parameter TestImageNames it will attempt to test against these default images: ubuntu16.04, centos7, and opensuse42.1.



**Specify particular images to use**
```
Invoke-RunTestScriptInDockerCoreContainers.ps1 -TestImageNames ubuntu16.04
```


### Testing Your Own Code
You can reuse Invoke-RunTestScriptInDockerCoreContainers.ps1 to test your own PowerShell in a Docker container:
* Create a single test script in your codebase to run your tests.  If the test runs successfully the script should return only $true.
* Specify one or more SourcePaths to match the one or more paths to copy your code and test script into the container.
* Specify TestFileAndParams to identify the relative path to your test script and specify any necessary parameters to it.
* Specify TestImageNames if you want to test a particular image.
* If you are testing someone else's Core containers on Docker hub, pass a value parameter DockerHubRepository (default is microsoft/powershell).
* Specify switch parameter -Quiet if you are sick of all the helpful text.

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
