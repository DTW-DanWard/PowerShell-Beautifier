# Change Log

## v 1.0.0
Initial version released
## v 1.0.1
Issue #1 Cache lookup table values after initial load (big performance improvement)
## v 1.0.2
Issue #2 Optionally output updated script via stdout (and not updating source/destination files) by using -StandardOutput parameter
## v 1.0.3
Issue #7 Initial support for PowerShell Core
## v 1.0.4
Issue #13 Add space after . when dot-sourcing a command
## v 1.0.5
Issue #7 and #16 - missing aliases across OSes
## v 1.0.6
Issue #7 Core - only support known safe cross-OS aliases

Tested on Windows PowerShell, (Windows OS) PowerShell Core, Ubuntu 16.04 (Docker image)
## v 1.0.7
Issue #12 Override host line-ending (need for running test script on Core non-Windows OS)
## v 1.0.8
Issue #16 Ensure file always ends with NewLine
## v 1.0.9
Issue #18 Do not indent function help descriptions when inside function definition
## v 1.0.10
Issue #8 Improve output; hide default beautifier text (available via Verbose), invoke test script returns success bool when Quiet
## v 1.0.11
Issue #19 Automate local testing for PowerShell Core in Docker containers
## v 1.0.12
Issue #24 Make parameter types for [System.IO.File]::WriteAllLines more explicit (error on NanoServer)
## v 1.0.13
Issue #25 PowerShell Core Native OSX version has issues passing scriptblocks as parameters to new PowerShell sessions; change to -Command "& { script here }" notation
## v 1.0.14
Issue #26 During testing when comparing files, ignore Unix vs Window line ending differences
## v 1.0.15
Issue #33 Support either Get-Content -Encoding byte or Get-Content -AsByteStream (PS Core Beta 9+)
with this Core MR: https://github.com/PowerShell/PowerShell/pull/5080
## v 1.2.0
Updates for PowerShell Gallery: rename PSD1 name to match module, move PSD1 to root
## v 1.2.1
Additional update for PowerShell Gallery: module manifest data
## v 1.2.2
Final PowerShell Gallery updates
## v 1.2.3
Final PowerShell Gallery updates - part 2
## v 1.2.4
Numerous fixes from user @m-kostrzewa - many thanks!
* Add support (don't break) custom PowerShell class definitions
* Don't add space after @(
* Support for dot-sourcing file paths in quotes
* Add space after redirection operator if followed by additional text
* Separate return statements followed by comma (when returning an array)
## v 1.2.5
Fixed all errors in PSScriptAnalyzer
