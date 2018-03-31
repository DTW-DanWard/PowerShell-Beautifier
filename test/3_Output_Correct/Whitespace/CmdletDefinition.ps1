
<#
.SYNOPSIS
This is the synopsis
.DESCRIPTION
And this is the description
#>
function Test-FunctionHere1 {
  "Testing"
}


function Test-FunctionHere2 {
<#
.SYNOPSIS
This is the synopsis
.DESCRIPTION
And this is the description
#>
  "Testing"
}

function Test-ReturnsArray {
  $Arr = @()
  return ,$Arr
}
