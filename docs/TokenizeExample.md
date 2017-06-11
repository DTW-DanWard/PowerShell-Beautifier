# Tokenize Example
Want to see the tokens for your own PowerShell code? Save a script to C:\temp\TestTokens.ps1 and run the code below (or change the path to your own script):

```
[System.Management.Automation.PSParser]::Tokenize([System.IO.File]::ReadAllText("C:\temp\TestTokens.ps1"),[ref]$null)
```
