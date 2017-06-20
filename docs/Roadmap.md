# PowerShell Beautifier Roadmap

## Near-term

Here's a tentative roadmap:
* Fix any immediate pressing issues.
* [Add support for text editors](ExternalEditors.md) - Atom, Sublime, VS Code, what else?
* Add configuration for better whitespace control.
* Move Byte Order Mark / encoding functions to new separate project (a number of useful functions for handling BOM/BOM-less files were created for the PS Beautifier).
* Add PowerShell-Beautifier to package managers.


## Long-term

**Rewrite to use abstract syntax trees**

This beautifier utility was originally written years ago in PowerShell v2.  Since PS v3 came out a number of APIs have been added, including support for abstract syntax trees, that can better help with intelligent parsing of the code.

With more intelligent parsing, additional interesting functionality can be added:
* Determine cmdlet for a parameter name to determine full/correct name of parameter (change Get-ChildItem "-Pa" to "-Path") 
* Move group openings (like "{") to next or previous line based on user preference.
* Condense short clauses to single line if less than X characters total.  For example, the beautifier could do something like this:

```
<# before #>
while (Test-WaitUntilDone) { 
	Start-Sleep -Seconds 5 
}

<# after #>
while (Test-WaitUntilDone) { Start-Sleep -Seconds 5 }
```

I'm sure there are a lot more interesting changes that could take place once the parsing logic can be more advanced.
