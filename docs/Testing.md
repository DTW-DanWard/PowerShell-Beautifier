# Testing the PowerShell Beautifier

## The easiest way to test
Back up your file first to a temp location (can't say this enough) or use the DestinationPath parameter:
```
Edit-DTWBeautifyScript -SourcePath C:\temp\Before.ps1 -DestinationPath c:\temp\After.ps1
```

Once you have a before and after file, diff them to see what changed.  If you are new to file comparison tools and are looking for a recommendation, check out [ExamDiff](http://download.cnet.com/ExamDiff/3000-2248_4-10059626.html).

What works?  What doesn't?  What could be better?  Let me know!  Also, if you can contribute some full scripts to CompleteFiles (see below), that would be helpful.


## Using the test scripts - high level
In the *test* folder are some test before/after .ps1 files along with script to test and compare them.
1. In the 1_Input_Bad folder are a bunch of .ps1 files that have known formatting or upper/lower casing issues.  (Things fixed by the beautifier.)  These issues are broken out into separate files and folders.
2. In the 3_Output_Correct folder are the same .ps1 files with the same basic content **but** all of the issues have been corrected.
3. The Invoke-DTWBeautifyScriptTests.ps1 runs the tests:
	1. It loops through the files under 1_Input_Bad;
	2. It runs the beautifier using the file from 1_Input_Bad as SourcePath and with a DestinationPath located under a new folder 2_Output_Test but with the same file name.
	3. It then compares the new 2_Output_Test file with the corresponding file under 3_Output_Correct.
	4. If the files are the same, cool, it worked.  If they are different if runs a diff and shows the results.


## Two more things to know about Invoke-DTWBeautifyScriptTests.ps1

### If you are running the test script repeatedly without changing beautifier code, use option -SkipModuleReload
If you are running Invoke-DTWBeautifyScriptTests.ps1 over and over without making any code changes to the beautifier itself then specify parameter *-SkipModuleReload*.  By default Invoke-DTWBeautifyScriptTests.ps1 force reloads PowerShell-Beautifier.psd1 each time to make sure you are using the latest code.  However if you are only testing some changes under 1_Input_Bad and 3_Output_Correct, there's no need to reload the module.  Using -SkipModuleReload will make it run much faster.

```
.\Invoke-DTWBeautifyScriptTests.ps1 -SkipModuleReload
```

### If you want to specify a custom diff utility, set the path in a global variable $DTW_PS_Beautifier_DiffViewer
By default, if the file from 2_Output_Test is different from the one in 3_Output_Correct, it will output the differences in the same PowerShell window using Compare-Object.  If you want to use a different diff util (either command-line or windows-based), fill in the full path to the utility in a global variable $DTW_PS_Beautifier_DiffViewer.  **Please don't** set this value in the script itself (in case you accidentally commit it); you can set this value in the shell or your profile before running the script.  For example:

```
$DTW_PS_Beautifier_DiffViewer = 'C:\Program Files\ExamDiff Pro\ExamDiff.exe'

.\Invoke-DTWBeautifyScriptTests.ps1
<this time something doesn't match so it opens the two files in ExamDiff>

... then make some test script changes ...
.\Invoke-DTWBeautifyScriptTests.ps1
<this time something doesn't match so it opens the two files in ExamDiff>

... then make some test script changes ...
.\Invoke-DTWBeautifyScriptTests.ps1
<this time everything matches so no diff viewer opens>
```


## Contributing to the test scripts

**First and foremost - ignore folder FileEncoding and file Whitespace\Indentation.ps1 for now - more on those later.**  These are the folders:

| Folder Name | Description |
| :--- | :--- |
| Case | Content with upper/lower case issues, broken down by Commands (cmdlets), Members (methods), ParameterAttributes (like Mandatory or ValueFromPipeline), Parameters (i.e. -Path) and Types ([string] or [System.Text.Encoding]) |
| CompleteFiles | Complete, realistic files with real script.  We need more examples - please contribute. |
| FileEncoding | Very simple PS files with same content but different file encodings and a BOM or no BOM. Please don't modify these files. |
| Rename | Examples of commands getting renamed/replaced (i.e. dir -> Get-Childitem) |
| Whitespace | Whitespace changes.  WithinLine has examples of bad whitespace between tokens; Indentation has indentation (tabs vs. spaces) tests.  Ignore Indentation for now; see below. |


### FileEncoding folder
See the [FAQ](FAQ.md) section about the byte order mark.  Basically these files exist to confirm the encoding detection and BOM adding functionality works correctly.  It should be unnecessary to modify these files.

### Whitespace\Indentation test
Whitespace\Indentation.ps1 is processed differently from the other files.  It is run three times, each time specifying a different indent text step: 2 spaces, 4 spaces, and tabs.  For each of these different indentation tests, the output test result files are compared with these existing output correct files in folder 3_Output_Correct\Whitespace:
 - Indentation_2space.ps1
 - Indentation_4space.ps1
 - Indentation_tab.ps1.


## Want more info?
Please review the source for Invoke-DTWBeautifyScriptTests.ps1.
