# Pester
# Version: $version$
# Changeset: $sha$

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $script:IgnoreErrorPreference = 'Ignore'
    $outNullModule = 'Microsoft.PowerShell.Core'
}
else
{
    $script:IgnoreErrorPreference = 'SilentlyContinue'
    $outNullModule = 'Microsoft.PowerShell.Utility'
}

# Tried using $ExecutionState.InvokeCommand.GetCmdlet() here, but it does not trigger module auto-loading the way
# Get-Command does.  Since this is at import time, before any mocks have been defined, that's probably acceptable.
# If someone monkeys with Get-Command before they import Pester, they may break something.

$script:SafeCommands = @{
    'Add-Member'          = Get-Command -Name Add-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Add-Type'            = Get-Command -Name Add-Type            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Compare-Object'      = Get-Command -Name Compare-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Export-ModuleMember' = Get-Command -Name Export-ModuleMember -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'ForEach-Object'      = Get-Command -Name ForEach-Object      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Format-Table'        = Get-Command -Name Format-Table        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-ChildItem'       = Get-Command -Name Get-ChildItem       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Command'         = Get-Command -Name Get-Command         -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-Content'         = Get-Command -Name Get-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Date'            = Get-Command -Name Get-Date            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Item'            = Get-Command -Name Get-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Location'        = Get-Command -Name Get-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Member'          = Get-Command -Name Get-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Module'          = Get-Command -Name Get-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-PSDrive'         = Get-Command -Name Get-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Variable'        = Get-Command -Name Get-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Group-Object'        = Get-Command -Name Group-Object        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Join-Path'           = Get-Command -Name Join-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Measure-Object'      = Get-Command -Name Measure-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-Item'            = Get-Command -Name New-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Module'          = Get-Command -Name New-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'New-Object'          = Get-Command -Name New-Object          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-PSDrive'         = Get-Command -Name New-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Variable'        = Get-Command -Name New-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Out-Null'            = Get-Command -Name Out-Null            -Module $outNullModule                  -CommandType Cmdlet -ErrorAction Stop
    'Out-String'          = Get-Command -Name Out-String          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Pop-Location'        = Get-Command -Name Pop-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Push-Location'       = Get-Command -Name Push-Location       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Item'         = Get-Command -Name Remove-Item         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSBreakpoint' = Get-Command -Name Remove-PSBreakpoint -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSDrive'      = Get-Command -Name Remove-PSDrive      -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Variable'     = Get-Command -Name Remove-Variable     -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Resolve-Path'        = Get-Command -Name Resolve-Path        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Select-Object'       = Get-Command -Name Select-Object       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-Content'         = Get-Command -Name Set-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Set-PSBreakpoint'    = Get-Command -Name Set-PSBreakpoint    -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-StrictMode'      = Get-Command -Name Set-StrictMode      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Set-Variable'        = Get-Command -Name Set-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Sort-Object'         = Get-Command -Name Sort-Object         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Split-Path'          = Get-Command -Name Split-Path          -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Start-Sleep'         = Get-Command -Name Start-Sleep         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Test-Path'           = Get-Command -Name Test-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Where-Object'        = Get-Command -Name Where-Object        -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Write-Error'         = Get-Command -Name Write-Error         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Progress'      = Get-Command -Name Write-Progress      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Verbose'       = Get-Command -Name Write-Verbose       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Warning'       = Get-Command -Name Write-Warning       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
}

 
# Not all platforms have Get-WmiObject (Nano) 
# Get-CimInstance is prefered, but we can use Get-WmiObject if it exists 
# Moreover, it shouldn't really be fatal if neither of those cmdlets 
# exist
if ( Get-Command -ea SilentlyContinue Get-CimInstance ) 
{ 
    $script:SafeCommands['Get-CimInstance'] = Get-Command -Name Get-CimInstance -Module CimCmdlets -CommandType Cmdlet -ErrorAction Stop 
} 
elseif ( Get-command -ea SilentlyContinue Get-WmiObject ) 
{ 
    $script:SafeCommands['Get-WmiObject']   = Get-Command -Name Get-WmiObject   -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop 
} 
else 
{ 
    Write-Warning "OS Information retrieval is not possible, reports will contain only partial system data" 
} 


# little sanity check to make sure we don't blow up a system with a typo up there
# (not that I've EVER done that by, for example, mapping New-Item to Remove-Item...)

foreach ($keyValuePair in $script:SafeCommands.GetEnumerator())
{
    if ($keyValuePair.Key -ne $keyValuePair.Value.Name)
    {
        throw "SafeCommands entry for $($keyValuePair.Key) does not hold a reference to the proper command."
    }
}

$moduleRoot = & $script:SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path

"$moduleRoot\Functions\*.ps1", "$moduleRoot\Functions\Assertions\*.ps1" |
& $script:SafeCommands['Resolve-Path'] |
& $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
& $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }

function Invoke-Pester {
<#
.SYNOPSIS
Invokes Pester to run all tests (files containing *.Tests.ps1) recursively under the Path

.DESCRIPTION
Upon calling Invoke-Pester, all files that have a name containing
"*.Tests.ps1" will have the tests defined in their Describe blocks
executed. Invoke-Pester begins at the location of Path and
runs recursively through each sub directory looking for
"*.Tests.ps1" files containing tests. If a TestName is provided,
Invoke-Pester will only run tests that have a describe block with a
matching name. By default, Invoke-Pester will end the test run with a
simple report of the number of tests passed and failed output to the
console. One may want pester to "fail a build" in the event that any
tests fail. To accomodate this, Invoke-Pester will return an exit
code equal to the number of failed tests if the EnableExit switch is
set. Invoke-Pester will also write a NUnit style log of test results
if the OutputXml parameter is provided. In these cases, Invoke-Pester
will write the result log to the path provided in the OutputXml
parameter.

Optionally, Pester can generate a report of how much code is covered
by the tests, and information about any commands which were not
executed.

.PARAMETER Script
This parameter indicates which test scripts should be run.
This parameter may be passed simple strings (wildcards are allowed), or hashtables containing Path, Arguments and Parameters keys.
If hashtables are used, the Parameters key must refer to a hashtable, and the Arguments key must refer to an array; these will be splatted to the test script(s) indicated in the Path key.

Note:  If the path contains any wildcards, or if it refers to a directory, then Pester will search for and execute all test scripts named *.Tests.ps1 in the target path; the search is recursive.  If the path contains no wildcards and refers to a file, Pester will just try to execute that file regardless of its name.

Aliased to 'Path' and 'relative_path' for backwards compatibility.

.PARAMETER TestName
Informs Invoke-Pester to only run Describe blocks that match this name.

.PARAMETER EnableExit
Will cause Invoke-Pester to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.

.PARAMETER OutputXml
The path where Invoke-Pester will save a NUnit formatted test results log file. If this path is not provided, no log will be generated.

.PARAMETER Tag
Informs Invoke-Pester to only run Describe blocks tagged with the tags specified. Aliased 'Tags' for backwards compatibility.

.PARAMETER ExcludeTag
Informs Invoke-Pester to not run blocks tagged with the tags specified.

.PARAMETER PassThru
Returns a Pester result object containing the information about the whole test run, and each test.

.PARAMETER CodeCoverage
Instructs Pester to generate a code coverage report in addition to running tests.  You may pass either hashtables or strings to this parameter.
If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.
By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"), and EndLine ("E") keys to narrow down the commands to be analyzed.
If Function is specified, StartLine and EndLine are ignored.
If only StartLine is defined, the entire script file starting with StartLine is analyzed.
If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.
Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.

.PARAMETER Strict
Makes Pending and Skipped tests to Failed tests. Useful for continuous integration where you need to make sure all tests passed.

.PARAMETER Quiet
Disables the output Pester writes to screen. No other output is generated unless you specify PassThru, or one of the Output parameters.

.PARAMETER PesterOption
Sets advanced options for the test execution. Enter a PesterOption object, such as one that you create by using the New-PesterOption cmdlet, or a hash table in which the keys are option names and the values are option values.
For more information on the options available, see the help for New-PesterOption.

.Example
Invoke-Pester

This will find all *.Tests.ps1 files and run their tests. No exit code will be returned and no log file will be saved.

.Example
Invoke-Pester -Script ./tests/Utils*

This will run all tests in files under ./Tests that begin with Utils and alsocontains .Tests.

.Example
Invoke-Pester -Script @{ Path = './tests/Utils*'; Parameters = @{ NamedParameter = 'Passed By Name' }; Arguments = @('Passed by position') }

Executes the same tests as in Example 1, but will run them with the equivalent of the following command line:  & $testScriptPath -NamedParameter 'Passed By Name' 'Passed by position'

.Example
Invoke-Pester -TestName "Add Numbers"

This will only run the Describe block named "Add Numbers"

.Example
Invoke-Pester -EnableExit -OutputXml "./artifacts/TestResults.xml"

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

.Example
Invoke-Pester -EnableExit -OutputFile "./artifacts/TestResults.xml" -OutputFormat NUnitxml

This runs all tests from the current directory downwards and writes the results to an output file and NUnitxml output format

.EXAMPLE
Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1'

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

.LINK
Describe
about_pester
New-PesterOption

#>
    [CmdletBinding(DefaultParameterSetName = 'LegacyOutputXml')]
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('Path', 'relative_path')]
        [object[]]$Script = '.',

        [Parameter(Position=1,Mandatory=0)]
        [Alias("Name")]
        [string[]]$TestName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0, ParameterSetName = 'LegacyOutputXml')]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [switch]$PassThru,

        [object[]] $CodeCoverage = @(),

        [Switch]$Strict,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [string] $OutputFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat,

        [Switch]$Quiet,

        [object]$PesterOption
    )

    if ($PSBoundParameters.ContainsKey('OutputXml'))
    {
        & $script:SafeCommands['Write-Warning'] 'The -OutputXml parameter has been deprecated; please use the new -OutputFile and -OutputFormat parameters instead.  To get the same type of export that the -OutputXml parameter currently provides, use an -OutputFormat of "LegacyNUnitXml".'

        & $script:SafeCommands['Start-Sleep'] -Seconds 2

        $OutputFile = $OutputXml
        $OutputFormat = 'LegacyNUnitXml'
    }

    $script:mockTable = @{}

    $pester = New-PesterState -TestNameFilter $TestName -TagFilter ($Tag -split "\s") -ExcludeTagFilter ($ExcludeTag -split "\s") -SessionState $PSCmdlet.SessionState -Strict:$Strict -Quiet:$Quiet -PesterOption $PesterOption
    Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

    Write-Screen "`r`n`r`n`r`n`r`n"

    $invokeTestScript = {
        param (
            [Parameter(Position = 0)]
            [string] $Path,

            [object[]] $Arguments = @(),
            [System.Collections.IDictionary] $Parameters = @{}
        )

        & $Path @Parameters @Arguments
    }

    Set-ScriptBlockScope -ScriptBlock $invokeTestScript -SessionState $PSCmdlet.SessionState

    $testScripts = @(ResolveTestScripts $Script)

    foreach ($testScript in $testScripts)
    {
        try
        {
            do
            {
                & $invokeTestScript -Path $testScript.Path -Arguments $testScript.Arguments -Parameters $testScript.Parameters
            } until ($true)
        }
        catch
        {
            $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $script:SafeCommands['Select-Object'] -First 1
            $pester.AddTestResult("Error occurred in test script '$($testScript.Path)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

            # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
            # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
            # planned for v4.0
            $pester.TestResult[-1].Describe = "Error in $($testScript.Path)"

            $pester.TestResult[-1] | Write-PesterResult
        }
    }

    $pester | Write-PesterReport
    $coverageReport = Get-CoverageReport -PesterState $pester
    Show-CoverageReport -CoverageReport $coverageReport
    Exit-CoverageAnalysis -PesterState $pester

    if(& $script:SafeCommands['Get-Variable'] -Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
        Export-PesterResults -PesterState $pester -Path $OutputFile -Format $OutputFormat
    }

    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $properties = @(
            "TagFilter","ExcludeTagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","SkippedCount","PendingCount","Time","TestResult"

            if ($CodeCoverage)
            {
                @{ Name = 'CodeCoverage'; Expression = { $coverageReport } }
            }
        )

        $pester | & $script:SafeCommands['Select-Object'] -Property $properties
    }

    if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
}

function New-PesterOption
{
<#
.SYNOPSIS
   Creates an object that contains advanced options for Invoke-Pester
.PARAMETER IncludeVSCodeMarker
   When this switch is set, an extra line of output will be written to the console for test failures, making it easier
   for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.
.INPUTS
   None
   You cannot pipe input to this command.
.OUTPUTS
   System.Management.Automation.PSObject
.LINK
   Invoke-Pester
#>

    [CmdletBinding()]
    param (
        [switch] $IncludeVSCodeMarker
    )

    return & $script:SafeCommands['New-Object'] psobject -Property @{
        IncludeVSCodeMarker = [bool]$IncludeVSCodeMarker
    }
}

function ResolveTestScripts
{
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path)
        {
            if ($object -is [System.Collections.IDictionary])
            {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $arguments      = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters     = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S')
                {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary])
                {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else
            {
                $unresolvedPath = [string] $object
                $arguments      = @()
                $parameters     = @{}
            }

            if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                (& $script:SafeCommands['Test-Path'] -LiteralPath $unresolvedPath -PathType Leaf) -and
                (& $script:SafeCommands['Get-Item'] -LiteralPath $unresolvedPath) -is [System.IO.FileInfo])
            {
                $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                if ($extension -ne '.ps1')
                {
                    & $script:SafeCommands['Write-Error'] "Script path '$unresolvedPath' is not a ps1 file."
                }
                else
                {
                    & $script:SafeCommands['New-Object'] psobject -Property @{
                        Path       = $unresolvedPath
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
            else
            {
                # World's longest pipeline?

                & $script:SafeCommands['Resolve-Path'] -Path $unresolvedPath |
                & $script:SafeCommands['Where-Object'] { $_.Provider.Name -eq 'FileSystem' } |
                & $script:SafeCommands['Select-Object'] -ExpandProperty ProviderPath |
                & $script:SafeCommands['Get-ChildItem'] -Include *.Tests.ps1 -Recurse |
                & $script:SafeCommands['Where-Object'] { -not $_.PSIsContainer } |
                & $script:SafeCommands['Select-Object'] -ExpandProperty FullName -Unique |
                & $script:SafeCommands['ForEach-Object'] {
                    & $script:SafeCommands['New-Object'] psobject -Property @{
                        Path       = $_
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
        }
    )

    # Here, we have the option of trying to weed out duplicate file paths that also contain identical
    # Parameters / Arguments.  However, we already make sure that each object in $Path didn't produce
    # any duplicate file paths, and if the caller happens to pass in a set of parameters that produce
    # dupes, maybe that's not our problem.  For now, just return what we found.

    $resolvedScriptInfo
}

function Get-DictionaryValueFromFirstKeyFound
{
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key)
    {
        if ($Dictionary.Contains($keyToTry)) { return $Dictionary[$keyToTry] }
    }
}

function Set-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionState')]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionStateInternal')]
        $SessionStateInternal
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    if ($PSCmdlet.ParameterSetName -eq 'FromSessionState')
    {
        $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    }

    [scriptblock].GetProperty('SessionStateInternal', $flags).SetValue($ScriptBlock, $SessionStateInternal, $null)
}

function Get-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    [scriptblock].GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)
}

function SafeGetCommand
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    return $script:SafeCommands['Get-Command']
}

$snippetsDirectoryPath = "$PSScriptRoot\Snippets"
if ((& $script:SafeCommands['Test-Path'] -Path Variable:\psise) -and
    ($null -ne $psISE) -and
    ($PSVersionTable.PSVersion.Major -ge 3) -and
    (& $script:SafeCommands['Test-Path'] $snippetsDirectoryPath))
{
    Import-IseSnippet -Path $snippetsDirectoryPath
}

& $script:SafeCommands['Export-ModuleMember'] Describe, Context, It, In, Mock, Assert-VerifiableMocks, Assert-MockCalled, Set-TestInconclusive
& $script:SafeCommands['Export-ModuleMember'] New-Fixture, Get-TestDriveItem, Should, Invoke-Pester, Setup, InModuleScope, Invoke-Mock
& $script:SafeCommands['Export-ModuleMember'] BeforeEach, AfterEach, BeforeAll, AfterAll
& $script:SafeCommands['Export-ModuleMember'] Get-MockDynamicParameters, Set-DynamicParameterVariables
& $script:SafeCommands['Export-ModuleMember'] SafeGetCommand, New-PesterOption

# SIG # Begin signature block
# MIInRQYJKoZIhvcNAQcCoIInNjCCJzICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAa1zF00SgCc6Hf
# nndjPuCIoihFDJJWHbmJ8PgIyYhOKqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
# mGsxCLhyAAAAAAFAMA0GCSqGSIb3DQEBCwUAMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMjAeFw0yNTExMTMxOTU5NDNaFw0y
# NjExMTAxOTU5NDNaMIGEMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyAzcmQgcGFydHkgQ29tcG9u
# ZW50MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEArGt4Hrjs3D7+IIab
# GkPGtg4XeWQFi8nKsdeF+N6nkYF9wsmw0qPk4OovEiJnCSRiEtLfYy3Icn4iOp7L
# 24oCa0zlgYCND3OnNfYOuVpMsq3CSkXYg3H+VMiB11hOLcctTu4RWy4ZRKsL5NVI
# AduJFgd/1Qs2mQpUuOyFfLKhu/+Z+T2c9YALxsfnPvqn8Tn8Tt8wdZuFwz7kK3jl
# e2T3YBofybAR2aH678TnOxhLe2/hEpTdKaVfcqyrIX0Mw/LwqEJnj4G8amBbQ7OG
# RnKm1VNd4nMpRt1SflNlVo1Q3Qqnj9K6mSPw99YGMCTaVr6jKPylsWyW4nsvu8m0
# MbBJJiLOi0sOTHtwQEVcBH6WM7xbODqwPaklS1wDbED1wfzImIUR8WsXJVjDm7Fg
# x4JDo8oLIjKFrEvzBfrYWsvlDg8p9XgR7EB/IJwXGuJbFzo/S+r3D5DkUZXX/72k
# XA4FeRJAgLePAuGChPvyQiLtKJeJm9ftJeukrIcs7JpJVHObAgMBAAGjggGoMIIB
# pDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUB9FDBUZ0W11vsv6qqb9t
# vKspCIowRQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEWMBQGA1UEBRMNMjMwODA5KzUwNjIyOTAfBgNVHSMEGDAWgBRhcaeHr/9p
# 1SF2T1KTKAC+eRKrhDB0BgNVHR8EbTBrMGmgZ6BlhmNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhpcmQl
# MjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5jcmwwgYEGCCsGAQUFBwEB
# BHUwczBxBggrBgEFBQcwAoZlaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhpcmQlMjBQYXJ0eSUyMENv
# bXBvbmVudCUyMENBJTIwMjAxMi5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0B
# AQsFAAOCAQEAmFzJPKhkAXPOcfy9S4q1nP3XCvmABVGv/VRzFZ1e+oVtVzOFkbZ6
# osY1OpZqa9CEvtgcrtciv1y9mV1SpxAMwfEqq+Nhw2GdZ3IWqFzWFsEe2S9U196s
# XRIRIxglZMBWyzdy8rQ+P7L2+LciW4qcaw2wtv6YoI0q1isgk0t1OF5kEL0t9hhx
# UrBavTdoqZ3b5JtwDqzmIsxuLtGbE9Pqbz2gx/me+7yduYpIcYlmEmPQkg3gmWkZ
# lnSRePu7/5RXS2TGW1O5JP8aqVcMn0ZkHEhtT368pE/CxQVAkAYHNz6+enP9n+HC
# 2udu395c0fVlRHy/d53f32RukfbjakH8uzCCBeEwggPJoAMCAQICCmELqsEAAAAA
# AAkwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1
# dGhvcml0eSAyMDEwMB4XDTEyMDQxODIzNDgzOFoXDTI3MDQxODIzNTgzOFowgY4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xODA2BgNVBAMTL01p
# Y3Jvc29mdCBXaW5kb3dzIFRoaXJkIFBhcnR5IENvbXBvbmVudCBDQSAyMDEyMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo5wwhAmnYy7PCkfw6iT5ozAg
# D15XMSaBmjEHslDUzmcJCGUKWqVLrtXtEC7npZm1n2gvmItYAqwgtCnEcb0oHKX9
# PJtk5MXr32ElvPDuaL/Rp8t+KgKBTmRcDFOGeVcZN2G3mPkMoE4iWZv5Gy1nPCc8
# VpBm4/1/ZX0Phr01R+iKzPTajulqTqunVeyiiR7VM0VTy/med73NLPkFuH90AR3o
# +xjhQ9EN6arcN2+9/rgP7R1NAUZOCqz8gujsVoMTjjoB7RRkdOpksmYQtmhtyHAA
# fVBILj1D7uAklcbNjsf9uOSVz91++5VeoQHNQ7EH16Qw7puGGipuwQtZonRviwID
# AQABo4IBQzCCAT8wEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFGFxp4ev/2nV
# IXZPUpMoAL55EquEMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQ
# W9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNv
# bS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBa
# BggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqG
# SIb3DQEBCwUAA4ICAQBaimfazNX9DSZBd78KRni0s94SaSt3I8JlLwFf0gP0YbpQ
# nS6MOXLzbD5qsR52bey384LczLvFaXAoc2YXP1Tr7gEWSMRG2RuAroE6jQ95bWiw
# nuotPznTyjh+vV58CG4Z3MbC9DgzaGHiUkeD4QABVtK6y4eCBTEKQYtO539fX+1f
# 0zktReuiE7/9HsKYQXFhFl/ICnAlfFlpMSTkcecKuwQX959yHsnSuxq+PQL+CQyy
# Q7RZGplTk5YhX+DWtyYBQpU2rCf9vvSFd2g9GL30vpiIIhGGUhbzRewDlxBwh6Nw
# Q3E828mGAxcM9XNbxn3hXGTt18VI1+0y4tGq08+n9ldOYfl362fyiLPeANoDj9CK
# NDc+HdhiuNKx8+Evi3I7gZZ8b/zsZnZyYBsk8qCJbVttAC7vKN2GhwXCtLnlvmTC
# KvJKFVyY4sQnhf9S42J+D7ICC9dmxwqy0z0gBBRQMlmDCn2b7Vo4EgFSui9eIHKO
# SvH953ECjDvhB77Jc/TdR9i077SkszC5iT52yrkAmFZ+q+qKuKXQOKtpdxMLFC/p
# qkEf97q9Ois0iu4Kq2PmY/eIJI4gDSs7nePCSVKsnx8OOTtd1G5QauZ9UjqqfDMV
# KQ0mXgFYp06pPXqEb3Q/YJ/kMk82AK9tcdM+pkZlX4F08f7BcdpMoEFagt3xHzGC
# GucwghrjAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# t5Yg6AkohrHBTzz9oUDIXfbyDRSAV28/S8NzmfKEs4swUAYKKwYBBAGCNwoDHDFC
# DEAwOTRDRkY4QTY3OUJCOThBREJDNkNEN0IzRUQzOUU0OTQ5QUMyRjVDRDlCNkNG
# OUYyMDM0MzQxQ0RGQzk3MzIwMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAE0pRM2Fdj3FLiBEKRl/4
# 3B1i7/wQpcsA9aZX5Te307OssafGXlvE4le2WDuvsXuLLVyYB0PV3gI60xtLqO5R
# fnWH7V4Gycce0JwCo5/904Lbv8MNPnwC3ko+qm9qja+xWvic8CafoCCxNA7jLGTJ
# wh1G1NkDJUAeTgx/ReJihF+VGxXWrYV6JPYWgQaRa9ihTbkc/6e29RM/Pod/9wif
# ovjEzbJdvGXkSmYLDMRAC7WA3QJOSPJ4L8YfjGBNw5EfGT7VWh1udEF1mTRboXXC
# kRfCkS8yXkMGzVW5hHnAXqod1vGIK1G/B74xNf3c1fEzWOUsENxYSHUasqGFKoH1
# 6zqVJhGfz5pgDRnxnX++UIAZnBFPPgDs1+wNwSrpjbVIi/W90Kt7EeM+vcl41D98
# izZHc6TbANWKetRBACsj87Wtl6/z4TmAJprB364z12VlsHDWFtrPLgUNzFJBDPC9
# jVTIlmZvBp/CDh3IZdwk0UhO15oMzhhzcN48fzJUzynxoYIXlDCCF5AGCisGAQQB
# gjcDAwExgheAMIIXfAYJKoZIhvcNAQcCoIIXbTCCF2kCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIErLc5HJJJLAugeTr8ll1bsMW5uv+xZ5O5iV7ecv
# C1DkAgZp18E6m+sYEzIwMjYwNDExMTA1MzE2LjM1NlowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo5MjAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAACI0/ZYCRTz/4rAAEAAAIj
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5Mzk1N1oXDTI3MDUxNzE5Mzk1N1owgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5MjAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIrpDaeTlZR0rNIJJp+n5SNQBGxb
# EcpLresmEUL/NJpsW6ZMG5onRA2uap6+5vkNvt9KPmq3DAqeMg73b4dcXrvX3Z+6
# MvsMWi3lYSP8C0Rn9evMUeKYqU3WHqARDA/kjrvCLNo9blnNIE2losGDmge8BI85
# m3B01Shn4NAoXeEmXUpm6giVUr6qLtwuOBqTqzmg5lxEIysqe4LdqhVrrBENti8p
# S6PuuQXH0o7Q+wcn+T4udkyCBGF6HgBV1rDKH6g7Mo+OVAZQ19J5ZSDKbZT0Itry
# 23SZBfgPEPPr6tqbnSCPWgB/JDpNDuv3o8AMU4oGBpTv5ykedpkbz11N6BDrJ0FE
# YjJw7DV1FfZ4oNFHPOIrdyfRZoib/s54azJAqMjMRC5RMO/QmP/3NDu2u4s46kkP
# 3wElU4ruN7zhLPaFvce9RJPuPWPY3yl4PqiWSkUdH/VnwnPgX6aStQXsyY8CKtgd
# HO6dsiDcesMw3AVg3vIGQMDj9Uyj0JjTL2gZSirbKNsLBOJvP1ViX3ecHdBCJMJP
# 2dbcz5M5YH48ytmkTGrUFIeYo/Mip6EqqtQOgzfc8r50QrClgsRPq5erge5BExdZ
# P/+w+5tSdABppQx9CEBlLLbce3HC03d4r35PjAJq/bBAW3nt5Q7BRbn8MLMwX225
# rkd7WE2+BwBdqIbXAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU1sCHz2/b2c9j1vBB
# vVBgLPFWB5cwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAIdDB7vPm2ng1nAB/VwH
# 7hz0niy/Dc/paoYEzG2rOdLoN3NTNK1ccJo9mEzjWDWIoc2eZycuPAu6M4Ro2OFK
# dQOIBmpCNbllqk4HGBzsSCCGH2T6vvypYB7esnhCiEFuFIZ1m0qK9NFp5GqaeHLz
# 5OGsqHMJ4TBpqtcmKZnBKl1BBQNuF5Yd7IDEBKq6W13ko7Sb9QW87Te196moZcDi
# 0KD9YYQLAqo6MnOlEB88gHrLUfJWuT6+YvmukRtPDAs61ftbEUYbz5xguT0eNoOT
# GtoD8diUpBHHWx3Nr7D+C6UvCA6cHJEkoXauvwzsU0iXCiLrLAWlo1zwDsd7BoaO
# DD+19wTbrQjVd6QaW4A0j0ec405haUjsEoFBtYTa16jq+xDVWDwHytNlJ49V2Zcv
# U8+qqzcpV0UozmRihw8IMz7pUvfYhX3qwRJ/ZPsOPFqekKDYPZRiPhnWLtzLxTUs
# sMaDnkpazhp/ZFEGMfYy6UeACZbmhsrGJkINCNFqugnZcSVdSGKAT0HO+EIVtP8c
# Nja+lWmXkedKlwJLGYvmLmUhP/FsBAwjsu6Hvleub4iyV8VY4Y4YyUKn7bioQkSC
# VcQ/vHCyiU10E2d1eKGHIh59UaUjUNHvEYQuImuTyJ9VZij1cRsRe/+Vu+noXZHZ
# SyfB5ZyS+rTLUdacscOofp0+MIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
# AAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2
# AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpS
# g0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2r
# rPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k
# 45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSu
# eik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09
# /SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR
# 6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxC
# aC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaD
# IV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMUR
# HXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMB
# AAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQq
# p1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ
# 6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBB
# MAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP
# 6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWlj
# cm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMu
# Y3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2
# Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03d
# mLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1Tk
# eFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kp
# icO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKp
# W99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrY
# UP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QB
# jloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkB
# RH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0V
# iY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq
# 0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1V
# M1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVADhFYWz6ROJmehmICPUG1iPzMI1qoIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDthDmzMCIYDzIw
# MjYwNDExMDMwODM1WhgPMjAyNjA0MTIwMzA4MzVaMHQwOgYKKwYBBAGEWQoEATEs
# MCowCgIFAO2EObMCAQAwBwIBAAICFXMwBwIBAAICEzUwCgIFAO2FizMCAQAwNgYK
# KwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQAC
# AwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAJFjdErzAkVCXBAnpNKT6mhNMCmhEMwKW
# sC1fD2BjezTW2l2nbfWzG0gYMrRyJv+sVHG0Gs5Ju0jQjJsuNq5JPuJEltt5rYDc
# OwFXulHVVxm+aSPYo+ZqPNxRBBNWjIEtbUWllwKaNxXnQDud6e/azwEjRE1xzt/Y
# uJL/thFUmbf7mxIDNFv8LpIH5DuTR53WKZlINs5eLynPTEVPSJrtHF1LKGOxdU3g
# 2NOjreds6vJbdtyaUWxua8PrbV3hOQ1jZBTdLHd10cRHKZDFaDS6PgDMBq+OGl9U
# lJ3UpVSbZO+7/EUxJ9rDaE1tf/JLfH6b50UCzg0TGI7P7FxeO+F44DGCBA0wggQJ
# AgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACI0/ZYCRT
# z/4rAAEAAAIjMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIC3H3H3I2xelO7go/2BOwW5/hFUfz7ub
# K9q+2dL87YoAMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQglvAzLBFu9waL
# KeOfCMCpxoPjvJi95splEC+0QBHm7rMwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAiNP2WAkU8/+KwABAAACIzAiBCClAIVAP0u/FMRx
# kdhp5k7LF9SinqYeycxpfFoPmU2MfjANBgkqhkiG9w0BAQsFAASCAgB3TQqlIPy0
# w+KmCIE0BFSOF8HD4Tetm1k+RhCTCxkMmfrc/s17IXLFEc2m4rWcTCvo3hGGvUjC
# daXT3dYnn3J1jHjiN6OQ8ij7eh+wZbE2C+q5fI1z/IN5AH1/MfIFLdmqVampLwEb
# WZ5rlNf3AIK409u5F3sVZIrLyGIpd4CHyiNK8KaxPOjL9C0p6vsKqicTH5+9inrV
# rTnYaZCjRvQF/Q8Pbc0YYk0bQvQXi5KcWvDINxLEww5+mVvzOOiZQX9H1GcTd9J6
# atRIkKm37JG18npQlO3zhRwY+Jq5D/w+Req24MTURK0z0RK0WS04tX4ZpnDcF9Xr
# f31k86TbtJT6sVNwWfmHDB0A8X0PSNDUGLS2imlETJeAQ7TbFIRSus8+zg8z3smV
# f6+YkDozJf+p0SWdCiEijJ1zJMF4q/kjvz4vFDhBsAktqx5bffoh+7JHg0XAvEOV
# PFBfXtlIrfggVJfGEk49EDb7s/n/2Il76AdSx6ALGt/FpAczf9+THkNHgmeHEQGD
# GZ88c93ImRCEnQ6H80c3JwSteS2iyYLr0KP+aQ9WNMwTc3Kf0U4Dw9ce7lHwz52A
# w+WilPbuybvymh/GC48cQfaroMtq6nqaMAlQxDW8LlnkCZF6/ZUxTqi0hta8cZSn
# 2dpnVaQQP16rUFRiZL/8V+nmDV6bHbIhWA==
# SIG # End signature block
