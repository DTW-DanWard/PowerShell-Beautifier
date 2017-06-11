# Support for Text Editors
Once of the best ways to get this beautifier functionality into the hands of people who need it is to make it easily accessible from text editors like Atom, PowerShell ISE, Sublime, VS Code and others.  At the moment, no work has been done yet towards this goal.

There are two things you can do to help get the PowerShell Beautifier working with your favorite text editor:
1. [Test the beautifier as it currently exists](Testing.md) from the PowerShell command-line.  The more that bugs get fixed and enhancements added now, the better it will be for the masses when your particular text editor works with it.
2. Help solve the problems below for your particular editor.


These are some of the anticipated challenges to add support for any particular text editor:


## Launch separate process from within editor
This beautifier runs from *within* PowerShell; it requires PowerShell to work.  So the first step to getting this to work from within an editor will be to figure out how to launch a PowerShell instance with a specific command from the editor.  It will look something like this:

```powershell
powershell.exe -NoProfile -Command "Import-Module <path to>\DTW.PS.Beautifier.psd1; Edit-DTWBeautifyScript -SourcePath <path to current file> <-WhichOptions>"
```

Some beautifier code tweaks might be required to make sure it can be run like this.  

Note: the beautifier should work in PowerShell v2 and up so it *should* be usable by most if not all end-users that develop PowerShell.  That said we might need a quick check of the host version to be safe.


## Ensure file is saved within editor
Because the most likely usage of the beautifier from an editor will be to update a file in place, the editor needs to ensure that the file is saved *before* the beautifier is called.


## Passing back error messages to editor
Errors can occur when running the beautifier.  (Don't worry; it won't overwrite your source file unless everything completes successfully!)  Currently the beautifier passes error information back to the host via Write-Error.  This most likely won't be sufficient for text editors, we will probably have to pass back information as strings.  To handle this: 
* we change the default behavior to pass back strings instead of Write-Error (but this impacts folks using the beautifier from the command-line);
* we specify the error output type by using a switch (not too bad);
* we somehow detect how it was launched so we can dynamically handle this (would be cool, might not be possible, might not work 100% of the time).

FYI: the most common error likely to occur is because of a syntax error in your source file.  If your PowerShell file has incorrect syntax, the beautifier can't process it.


## Performance
The way the beautifier changes aliases to cmdlets and fixes cmdlet and method casing is by loading known correct values into lookup tables in memory the first time it is run.  This initial load doesn't take long (a few seconds or so) but that lag will be noticeable by end-users of editors because the module/lookup tables will be reloaded *each time* it is run - because a separate PowerShell instance will be launched each time.  This is different from running the beautifier manually at the command-line multiple times, where it only loads the lookup tables once.

There is a ticket for this (saving lookup values to a text file) that will fix this issue.
