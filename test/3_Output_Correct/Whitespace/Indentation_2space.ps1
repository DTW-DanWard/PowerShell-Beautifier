# indentation test file to be used with 
# 2 space, 4 space and tab indentation tests

Get-ChildItem | ForEach-Object {
  $_.FullName
  $_.FullName
  $AA = @{
    One = 1;
    Two = 2;
    Three = 3333;
    Four = @{
      AA = 11;
      BB = 22;
      CCC = 99999;
    }
  }
}
