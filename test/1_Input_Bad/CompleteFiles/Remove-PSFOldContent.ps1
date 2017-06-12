
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


function Move-PSFPSItemsToRecycleBin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$RootPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [int]$CutOffDateDays,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ref]$RefTotalItemsRemoved,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ref]$RefTotalSizeKB
  )
  process {

    $Now = get-DATE
    # get rid of content greater than 3 months ago; make sure we have a negative number
    $CutOffDate = (Get-Date).AddDays(-1 * ([math]::abs($CutOffDateDays)))

    [int]$TotalItemsRemovedThisPath = 0
    [long]$TotalSizeKBThisPath = 0

    $master = [Sitecore.Configuration.Factory]::GetDatabase("master")
    $linkDB = [Sitecore.Globals]::LinkDatabase
    $ItemOutputFormat = "{0}`t{1}`t{2}`t{3}`t{4}"

    Write-Host ' '
    Write-Host "Processing path: $RootPath"
    Write-Host ' '
    Write-Host $($ItemOutputFormat -f @('Recycle ID','Item ID','Last Updated','Name','Path'))
    Write-Host ' '

    # need to ignore folders defined under these locations
      # master:\sitecore\templates\Common\Folder
      # master:\sitecore\templates\User Defined\Common\Folders
      # master:\templates\System
    $FolderTemplateIds = "{A87A00B1-E6DB-45AB-8B54-636FEC3B5523}","{f91ce530-a2b4-418a-a745-5186ace102d4}","{df11389e-693f-4763-8b3e-290b397c4be8}","{acc046e6-f445-449e-9598-8256d3b565fe}","{6891f329-2db1-4285-8e9b-a86b974f343d}","{783aad9f-8895-4bd0-a617-000516230ae2}","{ffd26c02-8930-4853-8871-e0049dc2a71c}","{c2117591-c9dc-4d23-8311-f63e4f0ac916}","{821f7d95-8268-4e48-be80-830ddb3a4a70}","{f3748040-1efe-4a90-b07b-2d1ec0d0e1cd}","{b3a9ca32-0468-4e28-9150-021f88f5b5b9}","{27168cfe-d1e8-4197-b452-d9848d6d3f36}","{a6565fbf-3026-4285-ba63-123e9962dad9}","{64b1a9b6-15ee-495a-b3e0-bffddbd204e5}","{48036443-b4b7-4ee9-85be-f890a1a24def}","{12533bc9-b3f7-4e57-b7ed-2a40a0a8ec52}","{03e873d9-c6f2-42d1-8774-9c8103606cfe}","{d8b24c4d-4120-448a-b021-f2ef350aa2d1}","{74618881-bc72-476e-98da-57aec0acb87f}","{3ab40d7c-900c-4b7a-9fdd-a98f323dc54b}","{1ff971fe-a42f-45f2-9ec3-02855c7b4625}","{d6cd2315-3b77-428f-9d07-7df24c3ba5f3}","{b8b3a872-f97c-4a06-b758-c4cbebb79105}","{26c6fc3e-c189-410f-8181-0cc170a074ba}","{468646cc-fc4f-4e17-a481-536db8ae5418}","{d7356522-2ce4-43e2-8ce1-b1d576e23405}","{9567ff24-7157-4915-b6a3-4dd1c7cb2c6c}","{264ca577-c2cb-4243-8518-45e98b907cbb}","{85ADBF5B-E836-4932-A333-FE0F9FA1ED1E}","{267D9AC7-5D85-4E9D-AF89-99AB296CC218}","{93227C5D-4FEF-474D-94C0-F252EC8E8219}","{C3B037A0-46E5-4B67-AC7A-A144B962A56F}","{814C7598-3537-448E-8685-C2654053FBEC}","{7EE0975B-0698-493E-B3A2-0B2EF33D0522}","{3BAA73E5-6BA9-4462-BF72-C106F8801B11}","{FE5DD826-48C6-436D-B87A-7C4210C7413B}","{54DAE7CD-BFD8-4E69-9679-75F2AE9F9034}","{DDA66314-03F3-4C89-84A9-39DFFB235B06}","{8EA2CF67-4250-47A2-AECA-4F70FD200DC7}","{96C8E5DD-63C3-496B-A97C-A3E37E1DACBA}","{AAD4C04A-EAA6-4824-87D2-E01F2325D422}","{0437FEE2-44C9-46A6-ABE9-28858D9FEE8C}","{E1FD9E57-A27F-481A-95CA-AA8627414A36}"

    # do not delete the items with these IDs
    $IdsToSkip = "{5BC268D7-8A9D-4BA5-A3CD-69AB8E973DC0}","{830A947A-6DB9-43A1-9874-7DC1CFD2DA3F}","{A53EABA0-DF38-4D92-A7CA-34E9727171C9}","{DD3CBA06-316A-4EA7-9D8D-4ACBD7FC2CA5}","{797818F4-D797-42BD-8588-4276A8CDDED5}","{38D3850C-7FDC-4171-BD21-DA6F01363633}","{D14D2812-46AE-46DD-B51B-A85697AB1A8F}","{25B68829-46B6-469A-956A-81A5EC9F2ABB}","{30D16FD5-C7A4-4613-9007-5A3C6FB023E9}","{AF98329B-9FCB-4873-9737-756AD64B7EE8}"

    # Main process:
    # get all content under path then 
    #   ignore items with children
    #   ignore folder items (which might be currently empty but we don't want to delete
    #   ignore items that are being linked to
    #   ignore items modified within CutOffDate
    dir -path $RootPath -Recurse | ? { ($_.HasChildren -eq $false) -and ($FolderTemplateIds -notcontains $_.TemplateId) -and ($IdsToSkip -notcontains $_.ID.ToString()) -and ($linkDB.GetReferrers($_).Count -eq 0) } | ForEach-Object {
      $Item = $_
      [datetime]$ItemUpdatedDate = Get-PSFSCItemUpdatedDate $Item
      # only process if last updated is less than cutoff date
      if ($ItemUpdatedDate -lt $CutOffDate) {
        $TotalItemsRemovedThisPath += 1
        $TotalSizeKBThisPath += [math]::floor($Item.Size / 1KB)

        # Recycle item
        # grab item path before recycling; value is 'orphan' afterwards
        [string]$ItemPath = $Item.Paths[0].FullPath
        $RecycleId = $Item.Recycle()
        Write-Host $($ItemOutputFormat -f ($RecycleId.Guid.ToString().ToUpper(), $Item.Id.Guid.ToString().ToUpper(), $ItemUpdatedDate.ToShortDateString(), $Item.Name, $ItemPath))
        # FYI, restore items programmatically (easier than using Recycle app), do this:
        # $Archive = ([Sitecore.Configuration.Factory]::GetDatabase("master")).Archives["recyclebin"]
        # $Archive.RestoreItem("<guid from first column above>")
      }
    }

    Write-Host ' '
    Write-Host "Items removed this path: $TotalItemsRemovedThisPath"
    Write-Host "Content size removed this path: $($TotalSizeKBThisPath/1KB) MB"

    $RefTotalItemsRemoved.Value += $TotalItemsRemovedThisPath
    $RefTotalSizeKB.Value += $TotalSizeKBThisPath
  }
}

[int]$TotalItemsRemoved = 0
[long]$TotalSizeKB = 0


#region Set content paths to process

# set content paths
[string[]]$ContentPaths = "master:\content\widgets"
Get-ChildItem -Path "master:\content\Sites" | WHERE { @("newcorporate","locations") -notcontains $_.Name  } | ForEach-Object {
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\about-us\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\careers\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\case-studies\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\news\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\sectors\_subcontent"
    $ContentPaths += "master:\content\Sites\" + $_.Name + "\home\services\_subcontent"
}

# set media library paths - don't do any report paths (differnet logic, handled by separte script)
[string[]]$MediaLibraryPaths = "master:\media library\banners","master:\media library\inline-content","master:\media library\key-properties","master:\media library\new-home-page","master:\media library\people","master:\media library\widgets"

# combine all paths
$Paths=$ContentPaths      + $MediaLibraryPaths
                      
#endregion

#region Loop through each path, move old items to recycle bin then publish path
$Paths | % {
  Move-PSFPSItemsToRecycleBin -RootPath $_ -CutOffDateDays 90 -RefTotalItemsRemoved ([ref]$TotalItemsRemoved) -RefTotalSizeKB ([ref]$TotalSizeKB)
  # now publish the root folder
  Write-Host ' '
  Write-Host "Publishing path: $($_)"
    Publish-Item -Path $_ -Recurse -Target web -PublishMode Smart
  Write-Host ' '
  Write-Host ' '
}
#endregion
                                
#region Output Totals
Write-Host ' '
Write-Host "Total items removed: $TotalItemsRemoved"
Write-Host "Total content size removed: $($TotalSizeKB/1KB) MB"
Write-Host ' '
#endregion

#region Disable logging
Disable-PSFLogFile
#endregion
