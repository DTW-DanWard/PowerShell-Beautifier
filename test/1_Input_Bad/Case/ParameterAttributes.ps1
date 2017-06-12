
function Test-Function {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNOTNULLOrEmpty()]
    [string]$Server,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [VALIDATESet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
    [string]$BackgroundColor,
    [Parameter(MANDATORY = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ALIAS("FullName")]
    [string[]]$SqlFilePath,
    [Parameter(Mandatory = $false,ValueFROMPIPELINE = $false)]
    [System.Collections.Hashtable]$FileParameters,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = (".udf",".viw",".prc",".trg")
  )
  #endregion
  process {
    # nothing to do
  }
}
