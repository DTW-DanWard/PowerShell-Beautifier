# Frequently Asked Questions


## What's the most important thing to know about the PowerShell Beautifier?
Back up your files before using it!  Sorry, but I can't stress this enough.  I don't want anyone to lose any work or special formatting when using this tool.


## How does it work
It breaks up your entire script into a series of tokens (ignoring all whitespace) then writes the content for those tokens back to the file using rules about when to when not to add space and indent.  Also, depending on the token type and content, it might *change* the value when it writes the value back.  For example, if it sees an alias like 'dir', it will change it to the full cmdlet name 'Get-ChildItem'.  It will also change cmdlet 'get-childitem' to 'Get-ChildItem', fixing the case.  It will also attempt to fix the case for cmdlet parameters, [type] references and methods.

This PowerShell Beautifier is both smarter and dumber than you might think.  For more information, please see [how it works](HowItWorks.md)


## I got an error...?
The error you are most likely to get is a result of a syntax error in your script.  The first thing you'll see is something like: *Invoke-TokenizeSourceScriptContent : An error occurred; is there invalid PowerShell or some formatting / syntax issue in the script?*  Following that will be more specific error information.

When the beautifier breaks up your script into tokens, the script **must** have a valid syntax.  If it doesn't this error will occur and will be reported to you.

If you are getting a different error, please submit a ticket.


## The Beautifier added a Byte Order Mark to my file that wasn't there before
A Byte Order Mark (or BOM) is a small identifier that *might* be found at the beginning of files to identify the file content encoding as being Unicode (UTF-8, UTF-16, etc.).  I say *'might'*  because the BOM might be missing.  In a perfect world every Unicode text file **would always** have a BOM (IMHO), but because it doesn't, a utility that works on text files (like this utility) is often left guessing about what content encoding is.

The BOM being missing could drive you to drink; trust me.  

In this utility the tokenize method call ([System.Management.Automation.PSParser]::Tokenize) **will fail** if the content of the file has Unicode but the BOM is missing.  To work around this:
* if there is no BOM on the PowerShell file, the utility attempts to detect the encoding by scanning the file content byte by byte;
* if the file turns out to have Unicode content, it rewrites the file (in a temp location) with the correct BOM now present;
* it then re-reads the (temp) file - with the BOM - and everything works;
* the beautifier then runs and writes the cleaned content back to the file system and the clean file will now have the BOM.

#### The side effect: if the source file didn't have the BOM before but had Unicode content, the BOM is added whether you wanted it or not.
I'm hoping this isn't a huge issue for you.  I know the PowerShell Core dev team is working through issues like this with non-Windows systems and there isn't a simple, easy answer.  Currently, for Windows machines, if you are trying to run a UTF-16 file that is missing a BOM in PowerShell itself it most likely *will fail entirely*.  If it's UTF-8, it might work, it might not; it depends which Unicode characters you have in there.  

Fun, right?  I'm sure by now you are regretting even reading this section.  But as PowerShell Core moves forward all PowerShell users are going to have to become more familiar with the Byte Order Mark and it's importance.


## The beautifier didn't change my file exactly the way I expected; I thought it would do [this] but it did [that]...
Please send feedback!  The formatting rules that were implemented were based on best practices that were available at the time.  This was a few years ago... and there really weren't any good rules around at the time.

If there is a specific type of formatting you would see, or some official best practice rules to put in place, or something you'd like to see configurable, please let me know!
