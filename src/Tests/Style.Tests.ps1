Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1') -Force

. $PsScriptRoot\Style.Tests.Exclusions.ps1
$rootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$dependenciesPath = Join-Path -Path $rootPath -ChildPath 'Dependencies'
Add-PsModulePath -Path $dependenciesPath
$srcRoot = Join-Path -Path $rootPath -ChildPath 'src'
$dscResourcePath = Join-Path -Path $dependenciesPath -ChildPath 'DSCResource.Tests'
Import-Module -Name (Join-Path -Path $dscResourcePath -ChildPath 'TestHelper.psm1') -Force

$fileList = Get-TextFilesList $srcRoot

$fileFormattingFilterScript = Get-ExclusionScriptBlock -ExclusionType FileFormatting
$validateScriptFilesFilterScript = Get-ExclusionScriptBlock -ExclusionType ValidateScriptFiles
$scriptAnalyzerFilterScript = Get-ExclusionScriptBlock -ExclusionType ScriptAnalyzer
$badCharsFilterScript = Get-ExclusionScriptBlock -ExclusionType BadChars

$textFiles = $fileList | Where-Object -FilterScript $fileFormattingFilterScript

$pssaRuleSetPath = Join-Path -Path $PSScriptRoot -ChildPath 'Style.PssaRuleSets.psd1'
$pssaRuleSets = Import-PowerShellDataFile -Path $pssaRuleSetPath
$requiredPssaRuleNames = @($pssaRuleSets.RequiredPssaRuleNames)
$flaggedPssaRuleNames = @($pssaRuleSets.FlaggedPssaRuleNames)
$ignorePssaRuleNames = @($pssaRuleSets.IgnorePssaRuleNames)
$knownPssaRuleNames = $requiredPssaRuleNames + $flaggedPssaRuleNames + $ignorePssaRuleNames

$customDscResourceAnalyzerRulesPath = Join-Path -Path $dscResourcePath -ChildPath 'DscResource.AnalyzerRules'
$customAnalyzerRulesPath = Join-Path -Path $srcRoot -ChildPath 'CustomAnalyzerRules'
$customDscPssaRuleNames = Get-ScriptAnalyzerRule -CustomRulePath $customDscResourceAnalyzerRulesPath | Select-Object -ExpandProperty RuleName
$customPssaRuleNames = Get-ScriptAnalyzerRule -CustomRulePath $customAnalyzerRulesPath | Select-Object -ExpandProperty RuleName

Describe 'Style Tests By File' {
    foreach ($textFile in $textFiles)
    {
        $filePath = $textFile.FullName
        $relativeFilePath = if ($filePath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase))
        {
            $filePath.Substring($rootPath.Length).TrimStart('\\')
        }
        else
        {
            $filePath
        }
        $isValidateScriptFile = $null -ne ($textFile | Where-Object -FilterScript $validateScriptFilesFilterScript)
        $isScriptAnalyzerFile = $null -ne ($textFile | Where-Object -FilterScript $scriptAnalyzerFilterScript)
        $isBadCharsFile = $null -ne ($textFile | Where-Object -FilterScript $badCharsFilterScript)

        Context "File $relativeFilePath" {
            $fileTestCase = @{
                FilePath         = $filePath
                RelativeFilePath = $relativeFilePath
            }

            It 'Should not contain any tab characters' -ForEach @($fileTestCase) {
                $fileContent = Get-Content -Path $_.FilePath -Raw
                $tabCharacterMatches = $fileContent | Select-String "`t"
                $containsFileWithTab = $null -ne $tabCharacterMatches
                $tabLineNumbers = @($tabCharacterMatches | Select-Object -ExpandProperty LineNumber)
                $because = if ($containsFileWithTab)
                {
                    "$($_.RelativeFilePath): tab character(s) found at line(s): $($tabLineNumbers -join ', ')" 
                }
                else
                {
                    "$($_.RelativeFilePath): no tab characters were found" 
                }

                $containsFileWithTab | Should -Be $false -Because $because
            }

            It 'Should not be an empty file' -ForEach @($fileTestCase) {
                $fileContent = Get-Content -Path $_.FilePath -Raw
                $containsEmptyFile = [String]::IsNullOrWhiteSpace($fileContent)
                $because = "file $($_.RelativeFilePath) is empty"

                $containsEmptyFile | Should -Be $false -Because $because
            }

            It 'Should end with a newline' -ForEach @($fileTestCase) {
                $fileContent = Get-Content -Path $_.FilePath -Raw
                $containsFileWithoutNewLine = -not [String]::IsNullOrWhiteSpace($fileContent) -and $fileContent[-1] -ne "`n"
                $because = "$($_.RelativeFilePath) does not end with a newline. Use fixer function 'Add-NewLine'"

                $containsFileWithoutNewLine | Should -Be $false -Because $because
            }

            It 'Should not contain trailing whitespace' -ForEach @($fileTestCase) {
                $fileContent = Get-Content -Path $_.FilePath
                $whitespace = $false
                $lineNumber = 1
                $trailingWhitespaceLineNumbers = @()
                foreach ($line in $fileContent)
                {
                    if ($line -match '[ \t]+(\r?$)')
                    {
                        $whitespace = $true
                        $trailingWhitespaceLineNumbers += $lineNumber
                    }

                    $lineNumber++
                }

                $because = if ($whitespace)
                {
                    "$($_.RelativeFilePath): trailing whitespace found at line(s): $($trailingWhitespaceLineNumbers -join ', ')" 
                }
                else
                {
                    "$($_.RelativeFilePath): no trailing whitespace was found" 
                }
                $whitespace | Should -Be $false -Because $because
            }

            if ($isValidateScriptFile)
            {
                It 'Should not have Byte Order Mark (BOM)' -Tag 'Script' -ForEach @($fileTestCase) {
                    $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $_.FilePath
                    $because = "$($_.RelativeFilePath) contains Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'"

                    $scriptFileHasBom | Should -Be $false -Because $because
                }
            }

            if ($isScriptAnalyzerFile)
            {
                It 'Should pass all error-level PS Script Analyzer rules' -Tag 'Script' -ForEach @($fileTestCase) {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $errorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'
                    $because = if ($null -eq $errorPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $ruleLineSummary = $errorPssaRulesOutput |
                            Group-Object -Property RuleName |
                            ForEach-Object -Process {
                                $lineNumbers = @($_.Group | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                                $shortReason = ($_.Group | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                                "$($_.Name): $shortReason (Lines: $($lineNumbers -join ', '))"
                            }

                        @(
                            "File: $($_.RelativeFilePath)"
                            'Rules with violations (line numbers):'
                            ($ruleLineSummary -join "`n")
                        ) -join "`n"
                    }

                    $errorPssaViolationCount = @($errorPssaRulesOutput).Count
                    if ($errorPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }

                $requiredPssaRuleTestCases =
                foreach ($requiredPssaRuleName in $requiredPssaRuleNames)
                {
                    @{
                        FilePath         = $filePath
                        RelativeFilePath = $relativeFilePath
                        RuleName         = $requiredPssaRuleName
                    }
                }

                It 'Should pass required PS Script Analyzer rule <RuleName>' -Tag 'Script' -ForEach $requiredPssaRuleTestCases {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $requiredPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $_.RuleName
                    $because = if ($null -eq $requiredPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $lineSummary = @($requiredPssaRulesOutput | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                        $shortReason = ($requiredPssaRulesOutput | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                        @(
                            "File: $($_.RelativeFilePath)"
                            "Rule: $($_.RuleName)"
                            "Why: $shortReason"
                            "Lines: $($lineSummary -join ', ')"
                        ) -join "`n"
                    }

                    $requiredPssaViolationCount = @($requiredPssaRulesOutput).Count
                    if ($requiredPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }

                $flaggedPssaRuleTestCases =
                foreach ($flaggedPssaRuleName in $flaggedPssaRuleNames)
                {
                    @{
                        FilePath         = $filePath
                        RelativeFilePath = $relativeFilePath
                        RuleName         = $flaggedPssaRuleName
                    }
                }

                It 'Should pass flagged PS Script Analyzer rule <RuleName>' -Tag 'Script' -ForEach $flaggedPssaRuleTestCases {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $flaggedPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $_.RuleName
                    $because = if ($null -eq $flaggedPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $lineSummary = @($flaggedPssaRulesOutput | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                        $shortReason = ($flaggedPssaRulesOutput | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                        @(
                            "File: $($_.RelativeFilePath)"
                            "Rule: $($_.RuleName)"
                            "Why: $shortReason"
                            "Lines: $($lineSummary -join ', ')"
                        ) -join "`n"
                    }

                    $flaggedPssaViolationCount = @($flaggedPssaRulesOutput).Count
                    if ($flaggedPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }

                It 'Should pass any recently-added, error-level PS Script Analyzer rules' -Tag 'Script' -ForEach @($fileTestCase) {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $excludeRuleNames = @($knownPssaRuleNames) | Where-Object -FilterScript { -not [string]::IsNullOrWhiteSpace($_) }

                    if ($excludeRuleNames.Count -gt 0)
                    {
                        $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -ExcludeRule $excludeRuleNames -Severity 'Error'
                    }
                    else
                    {
                        $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'
                    }

                    $because = if ($null -eq $newErrorPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $ruleLineSummary = $newErrorPssaRulesOutput |
                            Group-Object -Property RuleName |
                            ForEach-Object -Process {
                                $lineNumbers = @($_.Group | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                                $shortReason = ($_.Group | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                                "$($_.Name): $shortReason (Lines: $($lineNumbers -join ', '))"
                            }

                        @(
                            "File: $($_.RelativeFilePath)"
                            'Rules with violations (line numbers):'
                            ($ruleLineSummary -join "`n")
                        ) -join "`n"
                    }

                    $newErrorPssaViolationCount = @($newErrorPssaRulesOutput).Count
                    if ($newErrorPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }

                It 'Should not suppress any required PS Script Analyzer rules' -Tag 'Script' -ForEach @($fileTestCase) {
                    $requiredRuleIsSuppressed = $false
                    $suppressedRuleNames = Get-SuppressedPSSARuleNameList -FilePath $_.FilePath
                    $suppressedRequiredRules = @()
                    foreach ($suppressedRuleName in $suppressedRuleNames)
                    {
                        $suppressedRuleNameNoQuotes = $suppressedRuleName.Replace("'", '')
                        if ($requiredPssaRuleNames -icontains $suppressedRuleNameNoQuotes)
                        {
                            $requiredRuleIsSuppressed = $true
                            $suppressedRequiredRules += $suppressedRuleNameNoQuotes
                        }
                    }

                    $because = if ($requiredRuleIsSuppressed)
                    {
                        "$($_.RelativeFilePath): required rule suppression(s) found: $($suppressedRequiredRules -join ', ')" 
                    }
                    else
                    {
                        "$($_.RelativeFilePath): no required PS Script Analyzer rules were suppressed" 
                    }
                    $requiredRuleIsSuppressed | Should -Be $false -Because $because
                }

                $customDscPssaRuleTestCases =
                foreach ($customDscPssaRuleName in $customDscPssaRuleNames)
                {
                    @{
                        FilePath         = $filePath
                        RelativeFilePath = $relativeFilePath
                        RuleName         = $customDscPssaRuleName
                        CustomRulePath   = $customDscResourceAnalyzerRulesPath
                    }
                }

                It 'Should pass custom DSC Resource Kit PSSA rule <RuleName>' -Tag 'Script' -ForEach $customDscPssaRuleTestCases {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -CustomRulePath $_.CustomRulePath -IncludeRule $_.RuleName -Severity 'Warning'
                    $because = if ($null -eq $customPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $lineSummary = @($customPssaRulesOutput | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                        $shortReason = ($customPssaRulesOutput | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                        @(
                            "File: $($_.RelativeFilePath)"
                            "Rule: $($_.RuleName)"
                            "Why: $shortReason"
                            "Lines: $($lineSummary -join ', ')"
                        ) -join "`n"
                    }

                    $customDscPssaViolationCount = @($customPssaRulesOutput).Count
                    if ($customDscPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }

                $customPssaRuleTestCases =
                foreach ($customPssaRuleName in $customPssaRuleNames)
                {
                    @{
                        FilePath         = $filePath
                        RelativeFilePath = $relativeFilePath
                        RuleName         = $customPssaRuleName
                        CustomRulePath   = $customAnalyzerRulesPath
                    }
                }

                It 'Should pass custom PSSA rule <RuleName>' -Tag 'Script' -ForEach $customPssaRuleTestCases {
                    $invokeScriptAnalyzerParameters = @{
                        Path        = $_.FilePath
                        ErrorAction = 'SilentlyContinue'
                        Recurse     = $true
                    }

                    $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -CustomRulePath $_.CustomRulePath -IncludeRule $_.RuleName -Severity 'Warning'
                    $because = if ($null -eq $customPssaRulesOutput)
                    {
                        "File: $($_.RelativeFilePath)`nNo analyzer violations were found"
                    }
                    else
                    {
                        $lineSummary = @($customPssaRulesOutput | Select-Object -ExpandProperty Line | Sort-Object -Unique)
                        $shortReason = ($customPssaRulesOutput | Select-Object -First 1 -ExpandProperty Message) -replace '\s+See\s+https?://\S+$', ''
                        @(
                            "File: $($_.RelativeFilePath)"
                            "Rule: $($_.RuleName)"
                            "Why: $shortReason"
                            "Lines: $($lineSummary -join ', ')"
                        ) -join "`n"
                    }

                    $customPssaViolationCount = @($customPssaRulesOutput).Count
                    if ($customPssaViolationCount -ne 0)
                    {
                        throw $because
                    }
                }
            }

            if ($isBadCharsFile)
            {
                It 'Should not have bad chars' -ForEach @($fileTestCase) {
                    $containsBadChars = $false
                    $badChars = -join (226, 8364, 8220 | ForEach-Object -Process { [char]$_ })

                    $fileContent = Get-Content -Path $_.FilePath
                    $badCharsMatch = $fileContent | Select-String -Pattern $badChars
                    $badCharLineNumbers = @($badCharsMatch | Select-Object -ExpandProperty LineNumber)

                    if ( $null -ne $badCharsMatch )
                    {
                        $containsBadChars = $true
                    }

                    $because = if ($containsBadChars)
                    {
                        "$($_.RelativeFilePath): bad character(s) found at line(s): $($badCharLineNumbers -join ', ')" 
                    }
                    else
                    {
                        "$($_.RelativeFilePath): no bad characters were found" 
                    }
                    $containsBadChars | Should -Be $false -Because $because
                }
            }
        }
    }
}
