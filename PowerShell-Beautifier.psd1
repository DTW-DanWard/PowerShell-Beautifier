@{ ModuleVersion         = '1.2.5'
   Author                = 'Dan Ward'
   CompanyName           = 'DTWConsulting.com'
   Copyright             = 'Copyright 2012-2017 Dan Ward. All rights reserved.'
   Description           = 'PowerShell beautifier / code cleaner / pretty printer.  For more info see: https://github.com/DTW-DanWard/PowerShell-Beautifier'
   GUID                  = '{222A4EF8-9A04-4240-AE0C-18A0CDED5248}'
   NestedModules         = 'src/DTW.PS.FileSystem.Encoding.psm1',
                           'src/DTW.PS.Beautifier.PopulateValidNames.psm1',
                           'src/DTW.PS.Beautifier.Main.psm1'
   PrivateData           = @{
                              ValidCommandNames = $null;
                              ValidCommandParameterNames = $null;
                              ValidAttributeNames = $null;
                              ValidMemberNames = $null;
                              ValidVariableNames = $null;
                              PSData = @{
                                Tags = @('Beautifier','WhiteSpace','PrettyPrinter','Tabs','Spaces','Format','Core')
                                LicenseUri = 'https://github.com/DTW-DanWard/PowerShell-Beautifier/blob/master/LICENSE'
                                ProjectUri = 'https://github.com/DTW-DanWard/PowerShell-Beautifier'
                              }
                           }
}
