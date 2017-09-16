# PowerShell Beautifier Roadmap

## Near-term

Here's a tentative roadmap:
* Done - Fix any immediate pressing issues.
* Done - [Add support for text editors.](ExternalEditors.md) Support via file system and StandardOutput; additional editor support available upon request.
* Done - [automate local testing on Core](/test/Automation/README.md) using Docker containers (other OSes).
* Add PowerShell-Beautifier to PowerShell Gallery.
* Automate testing on commit.
* Add Pester testing.
* Add JSON config file for fine-grained, user-controllable whitespace configuration.
* Move Byte Order Mark / encoding functions to new separate project (a number of useful functions for handling BOM/BOM-less files were created for the PS Beautifier).



## Long-term

**Rewrite to use abstract syntax trees**

This beautifier utility was originally written years ago in PowerShell v2.  Since PS v3 came out a number of APIs have been added, including support for abstract syntax trees, that can better help with intelligent parsing of the code.

With more intelligent parsing, additional interesting functionality can be added:
* Automatically [change curly brace styles](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81)
* Determine cmdlet for a parameter name to determine full/correct name of parameter (change Get-ChildItem "-Pa" to "-Path") 
* Condense short statements to single line if less than X characters total.  For example, the beautifier could do something like this:

```
<# before #>
while (Test-WaitUntilDone) { 
	Start-Sleep -Seconds 5
}

<# after #>
while (Test-WaitUntilDone) { Start-Sleep -Seconds 5 }
```

I'm sure there are a lot more interesting changes that could take place once the parsing logic can be more advanced.
