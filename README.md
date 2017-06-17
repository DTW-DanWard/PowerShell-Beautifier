# PowerShell Beautifier

PowerShell Beautifier: a whitespace reformatter and code cleaner for PowerShell.

## Formatting Matters

Tabs or spaces; spaces or tabs?  If spaces, how many?  We sure do take whitespace seriously.  But when writing 'commit-worthy' PowerShell code, there's more than just whitespace to think about.  Shouldn't you use cmdlet names instead of aliases?  And shouldn't you have correct casing for cmdlets, methods and types?

PowerShell Beautifier is a PowerShell command-line utility for cleaning and reformatting PowerShell script files, written in PowerShell.  Sure, it will change all indentation to tabs or spaces for you - but it will do more than just that.  A picture is worth 1KB words; here's a before/after showing all types of changes including spaces & tabs:

![Before and after - casing](docs/Compare_Whitespace.png)

Here's a simpler pic focusing on the alias-replacement and casing changes:

![Before and after - whitespace](docs/Compare_CaseChanges.png)


The PowerShell Beautifier makes these changes:
* properly indents code inside {}, [], () and $() groups
* cleans/rearranges all whitespace within a line
* replaces aliases with the command names: dir → Get-ChildItem
* fixes command name casing: get-childitem → Get-ChildItem
* fixes parameter name casing: Test-Path -path → Test-Path -Path
* fixes [type] casing
	* changes all PowerShell shortcuts to lower: [STRING] → [string]
	* changes other types (if in memory): [system.exception] → [System.Exception]


## Table of Contents
* [Setup](#setup)
* [Usage](#usage)
	* [Run on single file updating in place with 2 spaces indentation](#run-on-single-file-updating-in-place-with-2-spaces-indentation)
	* [Run on single file but indent with tabs](#run-on-single-file-but-indent-with-tabs)
	* [Run on single file outputting to new file with 2 spaces indentation](#run-on-single-file-outputting-to-new-file-with-2-spaces-indentation)
	* [Run on multiple files in a directory structure](#run-on-multiple-files-in-a-directory-structure)
    * [Get cleaned content via standard output rather than updating file](#get-cleaned-content-via-standard-output-rather-than-updating-file)
* [Want to Know More](#want-to-know-more)
* [Contributing](#contributing)
* [Credits](#credits)
* [License](#license)


## Setup
1. Download the PowerShell Beautifier utility.
2. Change directory to the module.
3. Import the module.  (This takes a few seconds the first time but is fast thereafter.)
```
Import-Module .\DTW.PS.Beautifier.psd1
```

And confirm it is loaded correctly:
```
PS C:\> Get-Help Edit-DTWBeautifyScript

NAME
    Edit-DTWBeautifyScript

SYNOPSIS
    Cleans PowerShell script: re-indents code with spaces or tabs, cleans
    and rearranges all whitespace within a line, replaces aliases with
    cmdlet names, replaces parameter names with proper casing, fixes case for
    [types], etc.


SYNTAX
    Edit-DTWBeautifyScript [-SourcePath] <String> [[-DestinationPath] <String>] [[-IndentText] <String>] [-Quiet]
    [<CommonParameters>]

...more text...

```


## Usage

### Before using this utility on any file, back up your file!  
Commit your file, run a backup, run the beautify utility on a copy first, whatever you have to do!  **If you don't use the DestinationPath parameter, it will rewrite your file in place!** I've run this utility on *many* script now but I don't know if something funky in your script might throw off the utility.  Be safe and back it up first!

(FYI, the beautifier *only* rewrites your script at the end of processing if no errors occur.  However better safe than sorry - back it up!)


So, assuming you've imported the module, how do you use it?

### Run on single file updating in place with 2 spaces indentation
This rewrites the source file in place.  Two spaces is the default indent step so IndentText is not specified.
```
Edit-DTWBeautifyScript C:\temp\MyFile.ps1
```

### Run on single file but indent with tabs
This rewrites the source file in place using a tab at the indent step.
```
Edit-DTWBeautifyScript C:\temp\MyFile.ps1 -IndentText "`t"
```

### Run on single file outputting to new file with 2 spaces indentation
This doesn't modify the source file; it outputs the clean version to a new file.  Also uses the default indent step (2 spaces).
```
Edit-DTWBeautifyScript -SourcePath C:\temp\MyFile.ps1 -DestinationPath c:\temp\MyFile_AFTER.ps1
```

### Run on multiple files in a directory structure
Time for the pipeline.
```
Get-ChildItem -Path c:\temp -Include *.ps1,*.psm1 -Recurse | Edit-DTWBeautifyScript
```

Note: if you don't include the file extension filtering you'll need some other way to ignore folders (i.e. ignore PSIsContainer -eq $true) as Edit-DTWBeautifyScript will error for those.

### Get cleaned content via standard output rather than updating file
If you want to receive the beautified content via stdout (most likely if you are calling from an external editor), use the -StandardOutput (or -StdOut) parameter:
```
Edit-DTWBeautifyScript C:\temp\MyFile.ps1 -StandardOutput
```

When using -StandardOutput, the SourcePath is used for content but not updated, DestinationPath is ignored (if passed).  If an error occurs (syntax error in user script), no content is returned via stdout but stderr will have a concise error that can be displayed to the user.


## Want to Know More
* [FAQ](docs/FAQ.md)
* [How it works](docs/HowItWorks.md)
* [How to test and add test cases](docs/Testing.md)
* [Help add support for text editors](docs/ExternalEditors.md) like Atom and others
* [Project roadmap](docs/Roadmap.md) - enhancements, external editors, Core support, BOM/encoding functions and more
* [Change Log](docs/ChangeLog.md)


## Contributing
There are several ways to contribute: 
* [test it and identify what works and what could be better](docs/Testing.md);
* help with [adding support for text editors](docs/ExternalEditors.md);
* and maybe even contribute code changes!


## Credits
[Dan Ward](http://dtwconsulting.com/) started the PowerShell Beautifier as a pet project back in 2011 but only recently added it to Github.


## License
The PowerShell Beautifier is licensed under the [MIT license](LICENSE).
