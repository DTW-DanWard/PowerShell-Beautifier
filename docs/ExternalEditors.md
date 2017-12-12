# Support for Text Editors
Once of the best ways to get this beautifier functionality into the hands of people who need it is to make it easily accessible from text editors like Atom, VS Code, Sublime, PowerShell ISE and others.

Contact me if you want to help get this beautifier working from your favorite editor.  So far changes have been made to support the Atom-Beautify project (#2 StandardOutput parameter changes).  Since the PowerShell Beautifier can save to original file, save to new file and/or return to stdout, all the basic access should be complete.  But again, let me know if it doesn't.

These are some of the anticipated challenges to add support for any particular text editor:


## Launch separate PowerShell process from within editor
This beautifier runs from *within* PowerShell; it requires PowerShell to work.  So the first step to getting this to work from within an editor will be to figure out how to launch a PowerShell instance with a specific command from the editor.  It will look something like this:

```
powershell.exe -NoProfile -NoLogo -Command "Import-Module <path to>\PowerShell-Beautifier.psd1; Edit-DTWBeautifyScript -SourcePath <path to current file>"
```

If you want content via stdout, it will look like:
```
powershell.exe -NoProfile -NoLogo -Command "Import-Module <path to>\PowerShell-Beautifier.psd1; Edit-DTWBeautifyScript -StandardOutput -SourcePath <path to current file>"
```


## Ensure file is saved within editor
Because the most likely usage of the beautifier from an editor will be to update a file in place, the editor needs to ensure that the file is saved *before* the beautifier is called.


## Passing back error messages to editor
Errors can occur when running the beautifier.  (Don't worry; it won't overwrite your source file unless everything completes successfully!)  Currently the beautifier passes error information back to the host via Write-Error.  This most likely won't be sufficient for text editors.  If you use the -StandardOutput parameter, cleaned script is passed back via stdout and error info (more concise than Write-Error) is passed back via stderr.  Another Parameter option (-StandardError) might be required to pass back the concise info via stderr but still allow the Beautifier to write the completed content to the source or destination path (if specified).

FYI: the most common error likely to occur is because of a syntax error in your source file.  If the source PowerShell file has incorrect syntax, the beautifier can't process it.
