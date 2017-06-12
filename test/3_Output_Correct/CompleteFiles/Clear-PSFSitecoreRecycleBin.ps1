#region Make sure running in a Sitecore shell
if ($Host.Name -notmatch 'Sitecore') {
  Write-Host "`nThis script can only be run in a Sitecore PowerShell console`n" -ForegroundColor Cyan
  exit
}
#endregion

#region Enable logging 
# enable logging in default Sitecore log path location
# log file name is the name of script name plus timestamp
# important note: if your Sitecore PowerShell script produces too much text
# the Sitecore shell will crash.  in this case, you can suppress all output
# from the script by specifying -Silent as a parameter to Enable-PSFLogFile
Enable-PSFLogFile -Silent
# make sure this location is writable
if ($false -eq (Test-PSFFolderWritable -Path (Split-Path -Path (Get-PSFLogFilePath) -Parent))) {
  Write-Host "Log file location is not writable - grant write access to: $(Get-PSFLogFilePath)" -ForegroundColor Cyan
}
#endregion


function Remove-PSFSCOldItemsFromRecycleBin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$Databasename,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [int]$CutOffDateDays
  )
  process {

    # get rid of content greater than 3 months ago; make sure we have a negative number
    $CutOffDate = (Get-Date).AddDays(-1 * ([math]::abs($CutOffDateDays)))

    $Archive = ([Sitecore.Configuration.Factory]::GetDatabase($DatabaseName)).Archives["recyclebin"]

    #region Output info before processing
    Write-Host " "
    Write-Host "Cut off date: $CutOffDate"
    Write-Host ("Total items in $DatabaseName Recycle Bin: " + $Archive.GetEntryCount())
    Write-Host " "
    #endregion

    [int]$TotalDeleted = 0

    # note: there is no easy way to get items in recycling bin in order oldest first, so instead 
    # we have to get a largish group items, loop through these looking for items older than $CutOffDate
    # and keep looping until no items get deleted that round

    # $CutOffDate make sure this number is a large size - at least a few hundred
    $ReviewGroupSize = 10000
    Write-Host "ArchiveDate : ItemId : ArchivedBy : OriginalLocation"

    do
    {
      [int]$DeletedThisRound = 0

      # only process items older than CutOffDate
      $Archive.GetEntries(0,$ReviewGroupSize) | Where-Object { $_.ArchiveDate -lt $CutOffDate } | ForEach-Object {
        $Item = $_
        $TotalDeleted += 1
        $DeletedThisRound += 1
        Write-Host ("" + $Item.ArchiveDate + " : " + $Item.ItemId + " : " + $Item.ArchivedBy + " : " + $Item.OriginalLocation)
        # RemoveEntries takes ArchivalId, not ItemId
        $Archive.RemoveEntries($Item.ArchivalId)
      }

    } while ($DeletedThisRound -ne 0)

    Write-Host "Total items deleted: $TotalDeleted"
    Write-Host " "

  }
}

# cut-off date in days
$CutOffDateDays = 90

Write-Host " "
Remove-PSFSCOldItemsFromRecycleBin -DatabaseName "web" -CutOffDateDays $CutOffDateDays

Write-Host " "
Remove-PSFSCOldItemsFromRecycleBin -DatabaseName "master" -CutOffDateDays $CutOffDateDays

#region Disable logging
Disable-PSFLogFile
#endregion
