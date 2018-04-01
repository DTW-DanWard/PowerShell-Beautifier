# How it Works

The PowerShell Beautifier is both smarter and dumber than it looks.  It does do some clever things but, at the same time, is somewhat limited in what it can do.

## High-level overview
Here's what happens at a high level:
1. Populates lookup (hash) tables filled with *known correct values*.  This includes *Get-ChildItem* as the name of that cmdlet with correct casing but also includes a mapping for aliases to cmdlets like *dir* to *Get-ChildItem*.  More info below.
2. Copies the source script to a temp location; it's in the same folder as source but unique (time stamp) extension.  (FYI it does all its work on this temp file and only re/writes to the final destination if everything worked correctly.  This minimizes any chance of your script being inadvertently damaged.)
3. Adds BOM to temp file if necessary - see [FAQ BOM rant](FAQ.md).
4. Reads entire file into memory and tokenizes content.  More on this below.
5. For each token. writes it content back to a temporary stream, possibly changing its value (*dir* -> *Get-ChildItem*).  More on this below.  As it writes tokens it uses its own internal rules about whether or not to add whitespace.  It also uses the IndentType parameter (default two spaces) for indenting within sections like loops, if/then sections, multi-line hash table declarations, etc.
6. If the previous step completed successfully, writes the stream back to the temp file.  If *that* worked correctly, copies/overwrites temp file overwriting the source or the destination, if specified.

### Populate lookup hash tables
The first time the module is loaded it finds all the valid lookup values currently in memory (cmdlet names and functions) along with alias mapping values that are safe across OSes (for PowerShell Core)  and then writes these to a cache file.  Finding all these values in memory takes a few seconds.  Thereafter when loading the module the cache file is used, increasing the performance.

The cache files can be regenerated at any time.  If you have a number of custom modules and/or 3rd-party modules that you use often, you may want to have the exported functions and aliases added to the cache file.  This is easy to do:
1. Import all your custom and 3rd-party modules
2. Import the PowerShell Beautifier
3. Run function: Update-DTWRegenerateLookupTableValuesFile
That will recreate the cache file.

### Tokenize talk
The [System.Management.Automation.PSParser]::Tokenize method is pretty nifty; let's see an actual example for some very simple script: 

```
DIR -path c:\temp -Recur
```

The Tokenize method produces these tokens (this is a simplified listing of the token info):

| Type | Content |
| :--- | :--- |
| Command | DIR |
| CommandParameter | -path |
| CommandArgument | c:\temp |
| CommandParameter | -Recur |
| NewLine | |

*Want to try this yourself?  It's actually [real simple](TokenizeExample.md).*

Wow, we immediately can learn a lot from this.  There are different token types like Command and CommandParameter (full list [here](http://msdn.microsoft.com/en-us/library/system.management.automation.pstokentype(v=VS.85).aspx)) and we can see the text content of each token, like *DIR*.  Also, there are no tokens for whitespace other than the NewLine token. This is handy - we don't have to worry about manually parsing extraneous whitespace in the code, or tab vs. space issues, or incorrect/missing indenting in a section, etc - but it *does* mean we have to implement those whitespace rules ourselves.

### So how does it replace text?
Looking at the example, the token of type Command represents all commands (duh), which includes cmdlets and aliases. In the beautifier, there is a lookup table *just* for Command tokens content (ValidCommandNames) that contains all the cmdlet names in memory plus aliases -> cmdlet mappings for every alias in memory.  Specifically there is a key/value entry for *dir* -> *Get-ChildItem*.  When the beautifier is looping through the tokens, for the Command token *DIR* it looks up in ValidCommandNames (which is **not** case-sensitive), finds key *dir* gets its value *Get-ChildItem* and uses that instead of *DIR*.

Had the Content value of the Command *not* been found in ValidCommandNames, that value would be used as-is when rewriting **but** would also be added to ValidCommandNames for possible future lookups of that same command text.

#### Looking up and replacing [type] references
Handling/rewriting [type] references is slightly more interesting:
1. If the type text is a built-in shortcut / type accelerator, it will use the casing/value as defined.  Most of the time this means setting the text to all lower case - although not all type accelerators are all lower (DscLocalConfigurationManager).  You can see all values with:
```([psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")::Get).Keys```
2. Else if a period is found in the type text, like [SYSTEM.IO.streamwriter], the beautifier attempts to get a reference to the type and, if successful, gets its FullName, which will have the correct casing - i.e. [System.IO.StreamWriter].
3. Otherwise if the type isn't found (not in memory? typo?) it uses the type token content text as-is.


While all this seems smart, there are limitations.

### So how is the utility 'dumb'?
Using just Tokenize with lookup tables has a few deficiencies.

#### Method call name lookups don't know the underlying type
When looking at methods, specifically token type *Member*, we generally won't know the underlying type.  Consider this code:

```
(Get-Item c:\).TOSTRING()
```

By looking at the tokens alone we won't known what type the *TOSTRING* is being called on.  It's System.IO.DirectoryInfo - but we wouldn't know that without evaluating Get-Item c:\.  So we can't programmatically confirm the type and thus can't check the casing on the method. **But all is not lost!**  What we *can* do is preload the ValidMemberNames lookup table with common method names with correct casing.  It's better than nothing.


#### It is difficult to know if braces can/should be moved
One common use of beautifiers / pretty printers is to change the location of braces to match your preferred style.  For example changing this:

```
if ($Something -eq $true)
{
  "Hey now!"
}
```

to this:

```
if ($Something -eq $true) {
  "Hey now!"
}
```
With the current implementation, supporting this change would probably be very ugly.  Using newer technologies (abstract syntax trees), this might be a lot easier.  This could be a feature for version 2 of this utility.

#### Also hard to determine the source cmdlet for expanding/resolving parameter names
In the initial example there is a CommandParameter token with text *-Recur*.  Wouldn't it be great if it expanded it to the proper *-Recurse* value?  Hells yeah!  But again, this will be easier when using AST technology.  Our provided sample is very easy to parse but as you know PowerShell can get real ugly real fast.


## More minutiae, if you are curious

### Here are the lookup tables and how to access them outside of the code

Here are the lookup tables:

| Lookup table name | Notes |
| :--- | :--- |
| ValidCommandNames | Commands, prepopulated with cmdlets and functions in memory and aliases known to work across OSes (for PowerShell core). |
| ValidCommandParameterNames | Parameter names, prepopulated with existing parameter names for all cmdlets and functions in memory. |
| ValidAttributeNames | Parameter attribute names, like Alias, AllowNull, etc., prepopulated with attributes from PowerShell Language Specification Version 3.0 Chapter 12. |
| ValidMemberNames | Method names, prepopulated with methods existing on common types used in PowerShell such as System.Management.Automation.ParameterAttribute, string, int, datetime, etc. See Get-ValidMemberNames for more info. |
| ValidVariableNames | Variables used in the script; prepopulated only with true, false and HOME.  More default PS variables could be added here. | 

These lookup hash tables are stored as PrivateData variables in the module.  This gives us a pseudo 'module-scope', allowing us to help split up functions using this data across multiple files.  It also allows us to access the contents of these lookup tables from outside the module for debugging purposes.

When the module is loaded, the lookup tables are created but are empty.  It's not until Edit-DTWBeautifyScript is first called that they are populated.  Note: you can import the module and force the population by calling the function *Initialize-DTWBeautifyValidNames*.

Once populated you can see the values in the module's PrivateData, i.e.
```
(Get-Module PowerShell-Beautifier).PrivateData
(Get-Module PowerShell-Beautifier).PrivateData.ValidCommandNames
```


### Write content from token or byte array?
One last 'fun' thing I discovered when writing this utility: you can't read string values directly from the tokens without accidentally changing the source code.  Consider this seemingly very simple example:

```
Write-Host "Hello`tworld"
```

This code produces these tokens (this token display includes Start and Length)

| Type | Content | Start | Length |
| :--- | :--- | :--- | :--- |
| Command | Write-Host | 0 | 10 |
| String | Hello	world | 11 | 14 |
| NewLine | | 25 | 2 |

Do you see the difference?  It changed the `t after Hello to an actual tab.  Doh!  And there's no way to know, just by looking at the token item content, what the original value was.  Thankfully the token information includes the Start and Length fields which identifies the starting byte index and length of the string so we can manually read the string from the original and write to the new output, ignoring what's in the token Content.

Note: this special string copy processing isn't just used for String-type tokens, it's also used for CommandArgument and Variable tokens.
