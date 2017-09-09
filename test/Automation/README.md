# Testing Automation

## Testing Across OSes using Docker Containers
By using Docker with the [PowerShell Core images](https://hub.docker.com/r/microsoft/powershell/tags/) provided by PowerShell team, it's easy to automate PowerShell testing across operating systems.  This has been done in Invoke-RunTestScriptInDockerCoreContainers.ps1.  While this script was originally set up for testing the PowerShell Beautifier, it should be easy to reuse for testing any PowerShell code - possibly without any modifications to Invoke-RunTestScriptInDockerCoreContainers.ps1.

**A quick note about Docker Server OS and Image OS**

Run ```docker version``` and check out the Server value for OS/Arch; unless you've changed it, the value will be *linux/amd64*.  This means the Docker server currently can only support Linux OS images, like ubuntu, centos and opensuse.  It is possible to support Windows images, like nanoserver and windowsservercore, but not simultaneously with the Linux ones.  Keep in mind that Docker provides isolation, not full machine virtualization.

To change the OS currently supported, there is a Docker command line tool.  Also Docker for Windows has a system tray icon with an option to *Switch to Windows Containers*.  [Read this](https://blog.docker.com/2016/09/build-your-first-docker-windows-server-container/) for more information.


### Testing the Beautifier
To use this script to test the Beautifier:
* Fork or download the beautifier.
* [Install Docker](https://www.docker.com/)
* Pick a [PowerShell Core image](https://hub.docker.com/r/microsoft/powershell/tags/) to download
* Download that image; for example: ```docker pull microsoft/powershell:ubuntu16.04```
* Run the test script:
Windows systems:
```
.\Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths 'C:\Path\To\PowerShell-Beautifier' `
  -TestFileAndParams 'PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet' `
  -TestImageNames ubuntu16.04
```

Non-Windows systems:
```
./Invoke-RunTestScriptInDockerCoreContainers.ps1 `
  -SourcePaths '/Path/To/PowerShell-Beautifier' `
  -TestFileAndParams 'PowerShell-Beautifier/test/Invoke-DTWBeautifyScriptTests.ps1 -Quiet' `
  -TestImageNames ubuntu16.04
```

Note: If you don't specify parameter TestImageNames it will attempt to test against these default images: ubuntu16.04, centos7, and opensuse42.1.



### Testing Your Own Code
You should be able to reuse Invoke-RunTestScriptInDockerCoreContainers.ps1 to test your own PowerShell in a Docker container:
* Create a single script to run your tests.  If the test runs successfully the script should return only $true.
* Pass SourcePaths to match the one or more paths to copy your code and test script into the container.
* Pass TestFileAndParams to specify the relative path to your test script and specify any necessary parameters to it.
* Pass TestImageNames if you want to test a particular image.
* If you are testing someone else's containers on Docker hub, pass a value parameter DockerHubRepository (default is microsoft/powershell).
* Pass switch parameter Quiet if you are sick of all the helpful text.
