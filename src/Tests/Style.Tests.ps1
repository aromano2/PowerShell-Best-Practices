Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1') -Force

. $PsScriptRoot\Style.Tests.Exclusions.ps1
$rootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$dependenciesPath = Join-Path -Path $rootPath -ChildPath 'Dependencies'
Add-PsModulePath -Path $dependenciesPath
$srcRoot = Join-Path -Path $rootPath -ChildPath 'src'
$dscResourcePath = Join-Path -Path $dependenciesPath -ChildPath 'DSCResource.Tests'
Import-Module -Name (Join-Path -Path $dscResourcePath -ChildPath 'TestHelper.psm1') -Force

$fileList = Get-TextFilesList $srcRoot
Describe 'Common Tests - File Formatting' {
    $scriptFilesFilterScript = Get-ExclusionScriptBlock -ExclusionType FileFormatting
    $textFiles = $fileList | Where-Object -FilterScript $scriptFilesFilterScript
    It 'Should not contain any files with tab characters in <_.FullName>' -ForEach $textFiles {
        $fileName = $_.FullName
        $fileContent = Get-Content -Path $fileName -Raw
        $containsFileWithTab = $false
        $tabCharacterMatches = $fileContent | Select-String "`t"

        if ($null -ne $tabCharacterMatches)
        {
            Write-Warning -Message "Found tab character(s) in $fileName."
            $containsFileWithTab = $true
        }

        $containsFileWithTab | Should -Be $false
    }

    It 'Should not contain empty files in <_.FullName>' -ForEach $textFiles {
        $fileName = $_.FullName
        $fileContent = Get-Content -Path $fileName -Raw
        $containsEmptyFile = $false
        if ([String]::IsNullOrWhiteSpace($fileContent))
        {
            Write-Warning -Message "File $fileName is empty. Please remove this file."
            $containsEmptyFile = $true
        }

        $containsEmptyFile | Should -Be $false
    }

    It 'Should not contain files without a newline at the end in <_.FullName>' -ForEach $textFiles {
        $fileName = $_.FullName
        $fileContent = Get-Content -Path $fileName -Raw
        $containsFileWithoutNewLine = $false
        if (-not [String]::IsNullOrWhiteSpace($fileContent) -and $fileContent[-1] -ne "`n")
        {
            if (-not $containsFileWithoutNewLine)
            {
                Write-Warning -Message 'Each file must end with a new line.'
            }

            Write-Warning -Message "$fileName does not end with a new line. Use fixer function 'Add-NewLine'"

            $containsFileWithoutNewLine = $true
        }

        $containsFileWithoutNewLine | Should -Be $false
    }

    It 'Should not contain trailing whitespace in <_.FullName>' -ForEach $textFiles {
        $fileName = $_.FullName
        $fileContent = Get-Content -Path $fileName
        $whitespace = $false
        $lineNumber = 1
        foreach ($line in $fileContent)
        {
            if ($line -match '[ \t]+(\r?$)')
            {
                Write-Warning -Message "Found trailing whitespace in $fileName on Line $lineNumber"
                $whitespace = $true
            }

            $lineNumber++
        }

        $whitespace | Should -Be $false
    }
}

Describe 'Common Tests - Validate Script Files' -Tag 'Script' {
    $scriptFilesFilterScript = Get-ExclusionScriptBlock -ExclusionType ValidateScriptFiles
    $scriptFiles = $fileList | Where-Object -FilterScript $scriptFilesFilterScript
    It 'Script file <_.FullName> should not have Byte Order Mark (BOM)' -ForEach $scriptFiles {
        $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $_.FullName
        if ($scriptFileHasBom)
        {
            Write-Warning -Message "$($_.FullName) contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
        }

        $scriptFileHasBom | Should -Be $false
    }
}

Describe 'PS Script Analyzer on PowerShell Files' {
    $scriptFilesFilterScript = Get-ExclusionScriptBlock -ExclusionType ScriptAnalyzer
    $scriptFiles = $fileList | Where-Object -FilterScript $scriptFilesFilterScript

    BeforeAll {
        $requiredPssaRuleNames = @(
            'PSAvoidDefaultValueForMandatoryParameter',
            'PSAvoidDefaultValueSwitchParameter',
            'PSAvoidInvokingEmptyMembers',
            'PSAvoidNullOrEmptyHelpMessageAttribute',
            'PSAvoidUsingComputerNameHardcoded',
            'PSAvoidUsingDeprecatedManifestFields',
            'PSAvoidUsingEmptyCatchBlock',
            'PSAvoidUsingPositionalParameters',
            'PSAvoidShouldContinueWithoutForce',
            'PSAvoidUsingWriteHost',
            'PSDSCReturnCorrectTypesForDSCFunctions',
            'PSDSCStandardDSCFunctionsInResource',
            'PSDSCUseIdenticalMandatoryParametersForDSC',
            'PSDSCUseIdenticalParametersForDSC',
            'PSMissingModuleManifestField',
            'PSPossibleIncorrectComparisonWithNull',
            'PSProvideCommentHelp',
            'PSReservedCmdletChar',
            'PSUseApprovedVerbs',
            'PSReservedParams',
            'PSUseSingularNouns',
            'PSAvoidUsingCmdletAliases',
            'PSUseBOMForUnicodeEncodedFile',
            'Measure-ParameterCase',
            'Measure-VariableCase',
            'Measure-CmdletBindingAttribute'
            'Measure-ParameterAttribute',
            'Measure-Keyword',
            'Measure-Hashtable',
            'PSDSCDscExamplesPresent',
            'PSDSCDscTestsPresent',
            'PSUseShouldProcessForStateChangingFunctions',
            'PSUseToExportFieldsInManifest',
            'PSUseUTF8EncodingForHelpFile',
            'Measure-RestoreEnvironment',
            'ParameterAttributeArgumentNeedsToBeConstantOrScriptBlock'
        )

        $flaggedPssaRuleNames = @(
            'PSUseCmdletCorrectly',
            'PSAvoidUsingInvokeExpression',
            'PSAvoidUsingWMICmdlet',
            'PSUseOutputTypeCorrectly',
            'PSAvoidGlobalVars',
            'PSAvoidUsingConvertToSecureStringWithPlainText',
            'PSAvoidUsingPlainTextForPassword',
            'PSAvoidUsingUsernameAndPasswordParams',
            'PSDSCUseVerboseMessageInDSCResource',
            'PSShouldProcess',
            'PSUseDeclaredVarsMoreThanAssigments',
            'PSUsePSCredentialType'
        )

        $ignorePssaRuleNames = @()

        $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $dependenciesPath = Join-Path -Path $repoRoot -ChildPath 'Dependencies'
        $srcRootPath = Join-Path -Path $repoRoot -ChildPath 'src'
        $dscResourcePath = Join-Path -Path $dependenciesPath -ChildPath 'DSCResource.Tests'
        $customDscResourceAnalyzerRulesPath = Join-Path -Path $dscResourcePath -ChildPath 'DscResource.AnalyzerRules'
        $customAnalyzerRulesPath = Join-Path -Path $srcRootPath -ChildPath 'CustomAnalyzerRules'
    }

    It 'Should pass all error-level PS Script Analyzer rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $errorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'
        if ($null -ne $errorPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $errorPssaRulesOutput -RuleType 'Error-Level'
        }

        $errorPssaRulesOutput | Should -Be $null
    }

    It 'Should pass all required PS Script Analyzer rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $requiredPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $requiredPssaRuleNames
        if ($null -ne $requiredPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $requiredPssaRulesOutput -RuleType 'Required'
        }

        $requiredPssaRulesOutput | Should -Be $null
    }

    It 'Should pass all flagged PS Script Analyzer rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $flaggedPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $flaggedPssaRuleNames
        if ($null -ne $flaggedPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $flaggedPssaRulesOutput -RuleType 'Flagged'
        }

        $flaggedPssaRulesOutput | Should -Be $null
    }

    It 'Should pass any recently-added, error-level PS Script Analyzer rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $knownPssaRuleNames = $requiredPssaRuleNames + $flaggedPssaRuleNames + $ignorePssaRuleNames
        $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -ExcludeRule $knownPssaRuleNames -Severity 'Error'
        if ($null -ne $newErrorPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $newErrorPssaRulesOutput -RuleType 'Recently-added'
        }

        $newErrorPssaRulesOutput | Should -Be $null
    }

    It 'Should not suppress any required PS Script Analyzer rules for <_.FullName>' -ForEach $scriptFiles {
        $requiredRuleIsSuppressed = $false
        $suppressedRuleNames = Get-SuppressedPSSARuleNameList -FilePath $_.FullName
        foreach ($suppressedRuleName in $suppressedRuleNames)
        {
            $suppressedRuleNameNoQuotes = $suppressedRuleName.Replace("'", '')
            if ($requiredPssaRuleNames -icontains $suppressedRuleNameNoQuotes)
            {
                Write-Warning -Message "The file $($_.Name) contains a suppression of the required PS Script Analyser rule $suppressedRuleNameNoQuotes. Please remove the rule suppression."
                $requiredRuleIsSuppressed = $true
            }
        }

        $requiredRuleIsSuppressed | Should -Be $false
    }

    It 'Should pass all custom DSC Resource Kit PSSA rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -CustomRulePath $customDscResourceAnalyzerRulesPath -ExcludeRule $ignorePssaRuleNames -Severity 'Warning'
        if ($null -ne $customPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $customPssaRulesOutput -RuleType 'Custom DSC Resource Kit'
        }

        $customPssaRulesOutput | Should -Be $null
    }

    It 'Should pass all custom PSSA rules for <_.FullName>' -ForEach $scriptFiles {
        $invokeScriptAnalyzerParameters = @{
            Path        = $_.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -CustomRulePath $customAnalyzerRulesPath -ExcludeRule $ignorePssaRuleNames -Severity 'Warning'

        if ($null -ne $customPssaRulesOutput)
        {
            Write-PsScriptAnalyzerWarning -PssaRuleOutput $customPssaRulesOutput -RuleType 'Custom Analyzer Rules'
        }

        $customPssaRulesOutput | Should -Be $null
    }
}

Describe 'Common Tests - Invalid Characters' {

    $scriptFilesFilterScript = Get-ExclusionScriptBlock -ExclusionType BadChars
    $scriptFiles = $fileList | Where-Object -FilterScript $scriptFilesFilterScript

    BeforeAll {
        $badChars = -join (226, 8364, 8220 | ForEach-Object -Process { [char]$_ })
    }

    It 'Should not have bad chars in <_.FullName>' -ForEach $scriptFiles {
        $containsBadChars = $false

        $fileContent = Get-Content -Path $_.FullName
        $badCharsMatch = $fileContent | Select-String -Pattern $badChars

        if ( $null -ne $badCharsMatch )
        {
            Write-Warning -Message "Found bad chars line number $($badCharsMatch[0].LineNumber)"
            Write-Warning -Message "Bad chars: $($badCharsMatch[0].Line)"
            $containsBadChars = $true
        }

        $containsBadChars | Should -Be $false
    }
}
