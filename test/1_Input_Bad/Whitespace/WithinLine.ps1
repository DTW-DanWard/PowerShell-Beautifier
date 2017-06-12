             function   myfun     {
process {
 [hashtable]$ht=@{
   First  =  1     ;
  Second =2;
                    Third    =              3          ;
}
 # here
    [System.IO.StreamWriter]      $SW = $null
Get-ChildItem  -Path       c:\temp                 |    ForEach-Object       {
  Write-Host $_.FullName      
}
                          }
          }

$HT2=@{A=1;B=2;C=3;D=@{AA=11;BB=22;CC=33}}

$HT3    =@{
A  =1     ;
      B=2;
  C=3;
        D=@{
         AA=11;
  BB=22;
             CC=33
  }
}

$Array23 = @(2,
      5     ,      78,
23,
       89      )

if (     $false   -eq     $true    )       {
      # some stuff here
$Date     =  Get-Date    "01 01 2017"         # extra space after date
                    $NoNo=$false
     }

$Array     =     1    ..50
$A1 = $Array[3     .. 6]     

# last group - subexpressions
$BBB = $(
 1    +  `
      2     +      `
   3                 )          
