
function Test-Function {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Server,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
    [string]$BackgroundColor,
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")]
    [string[]]$SqlFilePath,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [System.Collections.Hashtable]$FileParameters,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$FileExtensions = (".udf",".viw",".prc",".trg")
  )
  #endregion
  process {
    # nothing to do
  }
}
