<#
PowerShell script beautifier by Dan Ward.

IMPORTANT NOTE: this utility rewrites your script in place!  Before running this
on your script make sure you back up your script or commit any changes you have
or run this on a copy of your script.

This file contains functions for detecting / handling / modify file encodings.  It will
get moved to its own project at some point.

See https://github.com/DTW-DanWard/PowerShell-Beautifier or http://dtwconsulting.com
for more information.  I hope you enjoy using this utility!
-Dan Ward
#>


Set-StrictMode -Version 2

#region Functions: Add-DTWFileEncodingByteOrderMarker, Get-DTWFileEncoding

#region Function: Add-DTWFileEncodingByteOrderMarker

<#
.SYNOPSIS
Adds a byte order marker file encoding to a file
.DESCRIPTION
Adds a byte order marker file encoding to a file.
.PARAMETER Name
Number of bytes to check, by default check first 10000 character.
Depending on the size of your file, this might be the entire content of your file.
.EXAMPLE
Add-DTWFileEncodingByteOrderMarker 'c:\temp\testfile.ps1' [System.Text.Encoding]:UTF8
<Adds UTF8 encoding to file testfile.ps1>
#>
function Add-DTWFileEncodingByteOrderMarker {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('FullName')]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [System.Text.Encoding]$FileEncoding
  )
  #endregion
  process {
    [string]$EncodingFileSystemProvider = Get-DTWFileEncodingSystemProviderNameFromTypeName $FileEncoding.EncodingName
    [string[]]$Content = Get-Content -Path $Path -Encoding $EncodingFileSystemProvider
    # get new file encoding object - this one will have BOM - and use it for rewriting the file back in place
    [System.Text.Encoding]$NewFileEncoding = Get-DTWFileEncodingTypeFromName -Name $FileEncoding.EncodingName
    [System.IO.File]::WriteAllLines($Path,$Content,$NewFileEncoding)
  }
}
Export-ModuleMember -Function Add-DTWFileEncodingByteOrderMarker
#endregion


#region Function: Get-DTWFileEncoding

<#
.SYNOPSIS
Returns the encoding type of the file
.DESCRIPTION
Returns the encoding type of the file.  It first attempts to determine the
encoding by detecting the Byte Order Marker using Lee Holmes' algorithm
(http://poshcode.org/2153).  However, if the file does not have a BOM
it makes an attempt to determine the encoding by analyzing the file content
(does it 'appear' to be UNICODE, does it have characters outside the ASCII
range, etc.).  If it can't tell based on the content analyzed, then
it assumes it's ASCII.  Note: it does not correctly detect UTF32 BE or LE
if no BOM is present.

If your file doesn't have a BOM and 'doesn't appear to be Unicode' (based on
my algorithm*) but contains non-ASCII characters *after* index ByteCountToCheck,
the file will be incorrectly identified as ASCII.  So put a BOM in there, would ya!

For more information and sample encoding files see:
http://danspowershellstuff.blogspot.com/2012/02/get-file-encoding-even-if-no-byte-order.html
And please give me any tips you have about improving the detection algorithm.

*For a full description of the algorithm used to analyze non-BOM files,
see "Determine if Unicode/UTF8 with no BOM algorithm description".
.PARAMETER Path
Path to file
.PARAMETER ByteCountToCheck
Number of bytes to check, by default check first 10000 character.
Depending on the size of your file, this might be the entire content of your file.
.PARAMETER PercentageMatchUnicode
If pecentage of null 0 value characters found is greater than or equal to
PercentageMatchUnicode then this file is identified as Unicode.  Default value .5 (50%)
.EXAMPLE
Get-IHIFileEncoding -Path .\SomeFile.ps1 1000
Attempts to determine encoding using only first 1000 characters
BodyName          : unicodeFFFE
EncodingName      : Unicode (Big-Endian)
HeaderName        : unicodeFFFE
WebName           : unicodeFFFE
WindowsCodePage   : 1200
IsBrowserDisplay  : False
IsBrowserSave     : False
IsMailNewsDisplay : False
IsMailNewsSave    : False
IsSingleByte      : False
EncoderFallback   : System.Text.EncoderReplacementFallback
DecoderFallback   : System.Text.DecoderReplacementFallback
IsReadOnly        : True
CodePage          : 1201
#>
function Get-DTWFileEncoding {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('FullName')]
    [string]$Path,
    [Parameter(Mandatory = $false)]
    [int]$ByteCountToCheck = 10000,
    [Parameter(Mandatory = $false)]
    [decimal]$PercentageMatchUnicode = .5
  )
  #endregion
  process {
    # minimum number of characters to check if no BOM
    [int]$MinCharactersToCheck = 400
    #region Parameter validation
    #region SourcePath must exist; if not, exit
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name) :: Path does not exist: $Path"
      return
    }
    #endregion
    #region ByteCountToCheck should be at least MinCharactersToCheck
    if ($ByteCountToCheck -lt $MinCharactersToCheck) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name) :: ByteCountToCheck should be at least $MinCharactersToCheck : $ByteCountToCheck"
      return
    }
    #endregion
    #endregion

    #region Determine file encoding based on BOM - if exists
    # the code in this section is mostly Lee Holmes' algorithm: http://poshcode.org/2153
    # until we determine the file encoding, assume it is unknown
    $Unknown = 'UNKNOWN'
    $result = $Unknown

    # The hashtable used to store our mapping of encoding bytes to their
    # name. For example, "255-254 = Unicode"
    $encodings = @{}

    # Find all of the encodings understood by the .NET Framework. For each,
    # determine the bytes at the start of the file (the preamble) that the .NET
    # Framework uses to identify that encoding.
    $encodingMembers = [System.Text.Encoding] | Get-Member -Static -MemberType Property
    $encodingMembers | ForEach-Object {
      $encodingBytes = [System.Text.Encoding]::($_.Name).GetPreamble() -join '-'
      $encodings[$encodingBytes] = $_.Name
    }

    # Find out the lengths of all of the preambles.
    $encodingLengths = $encodings.Keys | Where-Object { $_ } | ForEach-Object { ($_ -split '-').Count }

    # Go through each of the possible preamble lengths, read that many
    # bytes from the file, and then see if it matches one of the encodings
    # we know about.
    foreach ($encodingLength in $encodingLengths | Sort-Object -Descending) {
      # as of PS Core beta 9, if you want to read bytes, you need to use -AsByteStream
      # as -Encoding byte no longer exists
      if (((Get-Command Get-Content).Parameters).Keys -contains "AsByteStream") {
        $bytes = (Get-Content -Path $Path -AsByteStream -ReadCount $encodingLength)[0]
      } else {
        $bytes = (Get-Content -Path $Path -Encoding byte -ReadCount $encodingLength)[0]
      }
      $encoding = $encodings[$bytes -join '-']

      # If we found an encoding that had the same preamble bytes,
      # save that output and break.
      if ($encoding) {
        $result = $encoding
        break
      }
    }
    # if encoding determined from BOM, then return it
    if ($result -ne $Unknown) {
      [System.Text.Encoding]::$result
      return
    }
    #endregion

    #region No BOM on file, attempt to determine based on file content
    #region Determine if Unicode/UTF8 with no BOM algorithm description
    <#
       Looking at the content of many code files, most of it is code or
       spaces.  Sure, there are comments/descriptions and there are variable
       names (which could be double-byte characters) or strings but most of
       the content is code - represented as single-byte characters.  If the
       file is Unicode but the content is mostly code, the single byte
       characters will have a null/value 0 byte as either as the first or
       second byte in each group, depending on Endian type.
       My algorithm uses the existence of these 0s:
        - look at the first ByteCountToCheck bytes of the file
        - if any character is greater than 127, note it (if any are found, the
          file is at least UTF8)
        - count the number of 0s found (in every other character)
          - if a certain percentage (compared to total # of characters) are
            null/value 0, then assume it is Unicode
          - if the percentage of 0s is less than we identify as a Unicode
            file (less than PercentageMatchUnicode) BUT a character greater
            than 127 was found, assume it is UTF8.
          - Else assume it's ASCII.
       Yes, technically speaking, the BOM is really only for identifying the
       byte order of the file but c'mon already... if your file isn't ASCII
       and you don't want it's encoding to be confused just put the BOM in
       there for pete's sake.
       Note: if you have a huge amount of text at the beginning of your file which
       is not code and is not single-byte, this algorithm may fail.  Again, put a
       BOM in.
    #>
    #endregion
    $Content = $null
    # as of PS Core beta 9, if you want to read bytes, you need to use -AsByteStream
    # as -Encoding byte no longer exists
    if (((Get-Command Get-Content).Parameters).Keys -contains "AsByteStream") {
      $Content = Get-Content -Path $Path -AsByteStream -ReadCount $ByteCountToCheck -TotalCount $ByteCountToCheck
    } else {
      $Content = Get-Content -Path $Path -Encoding byte -ReadCount $ByteCountToCheck -TotalCount $ByteCountToCheck
    }
    # get actual count of bytes (in case less than $ByteCountToCheck)
    $ByteCount = $Content.Count
    [bool]$NonAsciiFound = $false
    # yes, the big/little endian sections could be combined in one loop
    # sorry, crazy busy right now...

    #region Check if Big Endian
    # check if big endian Unicode first - even-numbered index bytes will be 0)
    $ZeroCount = 0
    for ($i = 0; $i -lt $ByteCount; $i += 2) {
      if ($Content[$i] -eq 0) { $ZeroCount++ }
      if ($Content[$i] -gt 127) { $NonAsciiFound = $true }
    }
    if (($ZeroCount / ($ByteCount / 2)) -ge $PercentageMatchUnicode) {
      # create big-endian Unicode with no BOM
      New-Object -TypeName System.Text.UnicodeEncoding $true,$false
      return
    }
    #endregion

    #region Check if Little Endian
    # check if little endian Unicode next - odd-numbered index bytes will be 0)
    $ZeroCount = 0
    for ($i = 1; $i -lt $ByteCount; $i += 2) {
      if ($Content[$i] -eq 0) { $ZeroCount++ }
      if ($Content[$i] -gt 127) { $NonAsciiFound = $true }
    }
    if (($ZeroCount / ($ByteCount / 2)) -ge $PercentageMatchUnicode) {
      # create little-endian Unicode with no BOM
      New-Object -TypeName System.Text.UnicodeEncoding $false,$false
      return
    }
    #endregion

    #region Doesn't appear to be Unicode; either UTF8 or ASCII
    # OK, at this point, it's not a Unicode based on our percentage rules
    # if not Unicode but non-ASCII character found, call it UTF8 (no BOM, alas)
    if ($NonAsciiFound -eq $true) {
      New-Object -TypeName System.Text.UTF8Encoding $false
      return
    } else {
      # if made it this far, we are calling it ASCII
      New-Object -TypeName System.Text.AsciiEncoding
      return
    }
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Get-DTWFileEncoding
#endregion

#endregion


#region Functions: Get-DTWFileEncodingSystemProviderNameFromTypeName, Get-DTWFileEncodingTypeFromName

#region Function: Get-DTWFileEncodingSystemProviderNameFromTypeName

<#
.SYNOPSIS
Returns file system cmdlet provider encoding name given common encoding name.
.DESCRIPTION
When passed a encoding name, such as the encoding type name or BodyName or WebName,
etc. returns the valid Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding.
In other words, when you need to call Get-Content and pass in a valid Encoding value
but the values you have don't exactly match, use this function to get the right value.
Warning - if you pass in the type itself / type name of a Big Endian UTF 16 or 32
type, the function will return the Little Endian equivalent.  You need to specify a
value that's more specific, say the BodyName, EncodingName, HeaderName or WebName
values off the type itself.
If no match found throws error - all valid names are in parameter set.
Also, sorry for the long function name.
.PARAMETER Name
A name value of encoding type, such as Ascii, US-ASCII, UTF8, utf-8, etc.
.EXAMPLE
Get-DTWFileEncodingSystemProviderNameFromTypeName 'utf-8'
UTF8
.EXAMPLE
Get-DTWFileEncodingSystemProviderNameFromTypeName 'Unicode (UTF-8)'
UTF8
#>
function Get-DTWFileEncodingSystemProviderNameFromTypeName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $false)]
    [ValidateSet('Ascii','ASCIIEncoding','System.Text.ASCIIEncoding','US-ASCII','UTF7','UTF7Encoding','System.Text.UTF7Encoding','utf-7','Unicode (UTF-7)','UTF8','UTF8Encoding','System.Text.UTF8Encoding','utf-8','Unicode (UTF-8)','Unicode','UnicodeEncoding','System.Text.UnicodeEncoding','utf-16','BigEndianUnicode','utf-16BE','Unicode (Big-Endian)','UTF32','UTF32Encoding','System.Text.UTF32Encoding','utf-32','Unicode (UTF-32)')]
    [string]$Name
  )
  #endregion
  process {

    [hashtable]$Lookup = @{
      'Ascii' = 'Ascii';
      'ASCIIEncoding' = 'Ascii';
      'System.Text.ASCIIEncoding' = 'Ascii';
      'US-ASCII' = 'Ascii';

      'UTF7' = 'UTF7';
      'UTF7Encoding' = 'UTF7';
      'System.Text.UTF7Encoding' = 'UTF7';
      'utf-7' = 'UTF7';
      'Unicode (UTF-7)' = 'UTF7';

      'UTF8' = 'UTF8';
      'UTF8Encoding' = 'UTF8';
      'System.Text.UTF8Encoding' = 'UTF8';
      'utf-8' = 'UTF8';
      'Unicode (UTF-8)' = 'UTF8';

      'Unicode' = 'Unicode';
      'UnicodeEncoding' = 'Unicode';
      'System.Text.UnicodeEncoding' = 'Unicode';
      'utf-16' = 'Unicode';

      # note: BE Unicode has the same type as (LE) Unicode but
      # (LE) Unicode is the default, so type names UnicodeEncoding
      # and System.Text.UnicodeEncoding will map to that.  Sorry.
      'BigEndianUnicode' = 'BigEndianUnicode';
      'utf-16BE' = 'BigEndianUnicode';
      'Unicode (Big-Endian)' = 'BigEndianUnicode';

      'UTF32' = 'UTF32';
      'UTF32Encoding' = 'UTF32';
      'System.Text.UTF32Encoding' = 'UTF32';
      'utf-32' = 'UTF32';
      'Unicode (UTF-32)' = 'UTF32';

      # note: BE Unicode 32 has the same type as (LE) Unicode 32 but
      # (LE) Unicode 32 is the default, so type names UTF32Encoding
      # and System.Text.UTF32Encoding will map to that.  Sorry.
      'BigEndianUTF32' = 'BigEndianUTF32';
      'utf-32BE' = 'BigEndianUTF32';
      'Unicode (UTF-32 Big-Endian)' = 'BigEndianUTF32';
    }
    # return match
    $Lookup.$Name
  }
}
Export-ModuleMember -Function Get-DTWFileEncodingSystemProviderNameFromTypeName
#endregion


#region Function: Get-DTWFileEncodingTypeFromName

<#
.SYNOPSIS
Returns System.Text file encoding given name
.DESCRIPTION
Returns System.Text file encoding given name; can specify -NoBom for Byte Order
Marker.
.PARAMETER Name
A name value of encoding type, such as Ascii, US-ASCII, UTF8, utf-8, etc.
.PARAMETER NoBom
If specified, type will not include Byte Order Marker. Ignored if specified for
Ascii file encoding.
.EXAMPLE
Get-DTWFileEncodingTypeFromName 'utf-8'
<returns UTF8 encoding with BOM>
.EXAMPLE
Get-DTWFileEncodingTypeFromName 'UTF8' -NoBOM
UTF8
#>
function Get-DTWFileEncodingTypeFromName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $false)]
    [ValidateSet('Ascii','ASCIIEncoding','System.Text.ASCIIEncoding','US-ASCII','UTF7','UTF7Encoding','System.Text.UTF7Encoding','utf-7','Unicode (UTF-7)','UTF8','UTF8Encoding','System.Text.UTF8Encoding','utf-8','Unicode (UTF-8)','Unicode','UnicodeEncoding','System.Text.UnicodeEncoding','utf-16','BigEndianUnicode','utf-16BE','Unicode (Big-Endian)','UTF32','UTF32Encoding','System.Text.UTF32Encoding','utf-32','Unicode (UTF-32)')]
    [string]$Name,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$NoBom
  )
  #endregion
  process {

    switch ($Name) {
      { $Name -in ('Ascii','ASCIIEncoding','System.Text.ASCIIEncoding','US-ASCII') } { New-Object -TypeName System.Text.AsciiEncoding }

      { $Name -in ('UTF7','UTF7Encoding','System.Text.UTF7Encoding','utf-7','Unicode (UTF-7)') } { New-Object -TypeName System.Text.UTF7Encoding }

      { $Name -in ('UTF8','UTF8Encoding','ASCIIEncoding','System.Text.UTF8Encoding','utf-8','Unicode (UTF-8)') } { New-Object -TypeName System.Text.UTF8Encoding (!$NoBom) }

      { $Name -in ('Unicode','UnicodeEncoding','System.Text.UnicodeEncoding','utf-16') } { New-Object -TypeName System.Text.UnicodeEncoding $false,(!$NoBom) }

      { $Name -in ('BigEndianUnicode','utf-16BE','Unicode (Big-Endian)') } { New-Object -TypeName System.Text.UnicodeEncoding $true,(!$NoBom) }

      { $Name -in ('UTF32','UTF32Encoding','System.Text.UTF32Encoding','utf-32','Unicode (UTF-32)') } { New-Object -TypeName System.Text.UTF32Encoding $false,(!$NoBom) }

      { $Name -in ('BigEndianUTF32','utf-32BE','Unicode (UTF-32 Big-Endian)') } { New-Object -TypeName System.Text.UTF32Encoding $true,(!$NoBom) }
    }
  }
}
Export-ModuleMember -Function Get-DTWFileEncodingTypeFromName
#endregion

#endregion


#region Functions: Compare-DTWFiles, Compare-DTWFilesIncludingBOM, Compare-DTWFilesIgnoringBOM

#region Function: Compare-DTWFiles

<#
.SYNOPSIS
Compares two files, returns $true if same, $false otherwise
.DESCRIPTION
Compares two files, returns $true if same, $false otherwise. If both files have a
BOM, uses Compare-DTWFilesIncludingBOM. If one file has a BOM and the other does
not, uses: Compare-DTWFilesIgnoringBOM.
Line ending differences (Windows-style vs. Unix-style) are ignored during compare.
.PARAMETER Path1
Path to first file
.PARAMETER Path2
Path to second file
.EXAMPLE
Compare-DTWFiles 'c:\temp\file1.ps1' 'c:\temp\file2.ps1'
$true  # files have same contents in this case
#>
function Compare-DTWFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path1,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path2
  )
  #endregion
  process {
    #region Parameter validation
    #region $Path1 must exist
    if ($false -eq (Test-Path -Path $Path1)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path1"
      return
    }
    #endregion
    # make sure we have the full path
    $Path1 = (Resolve-Path -Path $Path1).Path

    #region $Path1 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path1).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path1"
      return
    }
    #endregion

    #region $Path2 must exist
    if ($false -eq (Test-Path -Path $Path2)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path2"
      return
    }
    #endregion
    # make sure we have the full path
    $Path2 = (Resolve-Path -Path $Path2).Path

    #region $Path2 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path2).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path2"
      return
    }
    #endregion
    #endregion

    if (((Get-DTWFileEncoding $Path1).GetPreamble().Length) -ne ((Get-DTWFileEncoding $Path2).GetPreamble().Length)) {
      Compare-DTWFilesIgnoringBOM -Path1 $Path1 -Path2 $Path2
    } else {
      Compare-DTWFilesIncludingBOM -Path1 $Path1 -Path2 $Path2
    }
  }
}
Export-ModuleMember -Function Compare-DTWFiles
#endregion


#region Function: Compare-DTWFilesIncludingBOM

<#
.SYNOPSIS
Compares two files, including BOMs, returning $true if same, $false otherwise
.DESCRIPTION
Compares two files, including BOMs, returning $true if same, $false otherwise.
Line ending differences (Windows-style vs. Unix-style) are ignored during compare.
.PARAMETER Path1
Path to first file
.PARAMETER Path2
Path to second file
.EXAMPLE
Compare-DTWFilesIncludingBOM 'c:\temp\file1.ps1' 'c:\temp\file2.ps1'
$true  # files have same contents in this case
#>
function Compare-DTWFilesIncludingBOM {
  #region Function parameters
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path1,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path2
  )
  #endregion
  process {
    #region Parameter validation
    #region $Path1 must exist
    if ($false -eq (Test-Path -Path $Path1)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path1"
      return
    }
    #endregion
    # make sure we have the full path
    $Path1 = (Resolve-Path -Path $Path1).Path

    #region $Path1 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path1).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path1"
      return
    }
    #endregion

    #region $Path2 must exist
    if ($false -eq (Test-Path -Path $Path2)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path2"
      return
    }
    #endregion
    # make sure we have the full path
    $Path2 = (Resolve-Path -Path $Path2).Path

    #region $Path2 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path2).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path2"
      return
    }
    #endregion
    #endregion

    #region Compare files byte by byte
    # get file content
    [string]$File1SourceString = [System.IO.File]::ReadAllText($Path1)
    [string]$File2SourceString = [System.IO.File]::ReadAllText($Path2)
    # replace any windows line endings with Unix line endings so doesn't affect comparison;
    # depending on a user's git settings, the test files may or may not have windows line
    # endings; because we need to compare the files at a binary level, safest thing to do
    # is to replace windows line endings with Unix
    $File1SourceString = $File1SourceString -replace "`r`n","`n"
    $File2SourceString = $File2SourceString -replace "`r`n","`n"
    # doing binary comparison; if not same length, we know they don't match
    if ($File1SourceString.Length -ne $File2SourceString.Length) {
      $false
    } else {
      [bool]$Equal = $true
      for ($i = 0; $i -lt ((Get-Item -Path $Path1).Length); $i++) {
        # we use case-sensitive not equals (-cne instead of -ne)
        if ($File1SourceString[$i] -cne $File2SourceString[$i]) {
          $Equal = $false
          break
        }
      }
      $Equal
    }
    #endregion
  }
}
Export-ModuleMember -Function Compare-DTWFilesIncludingBOM
#endregion


#region Function: Compare-DTWFilesIgnoringBOM

<#
.SYNOPSIS
Compares two files, ignoring BOMs, returning $true if same, $false otherwise
.DESCRIPTION
Compares two files, ignoring BOMs, returning $true if same, $false otherwise.
Line ending differences (Windows-style vs. Unix-style) are ignored during compare.
.PARAMETER Path1
Path to first file
.PARAMETER Path2
Path to second file
.EXAMPLE
Compare-DTWFilesIgnoringBOM 'c:\temp\file1.ps1' 'c:\temp\file2.ps1'
$true  # files have same contents in this case but one has a BOM and the other does not
#>
function Compare-DTWFilesIgnoringBOM {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path1,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path2
  )
  #endregion
  process {
    #region Parameter validation
    #region $Path1 must exist
    if ($false -eq (Test-Path -Path $Path1)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path1"
      return
    }
    #endregion
    # make sure we have the full path
    $Path1 = (Resolve-Path -Path $Path1).Path

    #region $Path1 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path1).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path1"
      return
    }
    #endregion

    #region $Path2 must exist
    if ($false -eq (Test-Path -Path $Path2)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: file not found: $Path2"
      return
    }
    #endregion
    # make sure we have the full path
    $Path2 = (Resolve-Path -Path $Path2).Path

    #region $Path2 must be a file, not a folder
    if ($true -eq ((Get-Item -Path $Path2).PSIsContainer)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: this is a folder, not a file: $Path2"
      return
    }
    #endregion
    #endregion

    $File1Content = Get-Content -Path $Path1 -Encoding (Get-DTWFileEncodingSystemProviderNameFromTypeName -Name ((Get-DTWFileEncoding $Path1).EncodingName))
    $File2Content = Get-Content -Path $Path2 -Encoding (Get-DTWFileEncodingSystemProviderNameFromTypeName -Name ((Get-DTWFileEncoding $Path2).EncodingName))
    # replace any windows line endings with Unix line endings so doesn't affect comparison;
    # depending on a user's git settings, the test files may or may not have windows line
    # endings; because we need to compare the files at a binary level, safest thing to do
    # is to replace windows line endings with Unix
    $File1Content = $File1Content -replace "`r`n","`n"
    $File2Content = $File2Content -replace "`r`n","`n"
    # if Compare-Object returns nothing, contents are the same
    $null -eq (Compare-Object $File1Content $File2Content -CaseSensitive)
  }
}
Export-ModuleMember -Function Compare-DTWFilesIgnoringBOM
#endregion

#endregion
