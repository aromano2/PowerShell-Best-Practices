function Copy-DscResourceTestsRepo
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.IO.DirectoryInfo]
        $Destination = (Join-Path -Path $PSScriptRoot -ChildPath 'DSCResource.Tests')

    )

    if ( (-not (Test-Path -Path $Destination)) -or `
        (-not (Test-Path -Path (Join-Path -Path $Destination -ChildPath 'TestHelper.psm1'))) )
    {
        & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', $Destination, '-q')
    }
}

<#
    .SYNOPSIS
        Write a warning message for PsScriptAnalyzer rules that fail

    .PARAMETER PssaRuleOutput
        Output object from Invoke-ScriptAnalyzer

    .PARAMETER RuleType
        Name of the rule type that is being processed
#>
function Write-PsScriptAnalyzerWarning
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [object[]]
        $PssaRuleOutput,

        [Parameter(Mandatory = $true)]
        [string]
        $RuleType
    )

    Write-Warning -Message "$RuleType PSSA rule(s) did not pass."
    $ruleCollection = $PssaRuleOutput | Group-Object -Property RuleName

    foreach ($ruleNameGroup in $ruleCollection)
    {
        Write-Warning -Message "The following PSScriptAnalyzer rule '$($ruleNameGroup.Name)' errors need to be fixed:"
        foreach ($rule in $ruleNameGroup.Group)
        {
            Write-Warning -Message "$($rule.ScriptName) (Line $($rule.Line)): $($rule.Message)"
        }
    }

    Write-Warning -Message 'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
}

<#
    .SYNOPSIS
        Adds folder(s) to the $env:PsModulePath

    .PARAMETER Path
        Folder(s) to be added to $env:PsModulePath

    .PARAMETER Machine
        If set the PSModulePath will be changed machine wide. If not set, only
        the current session will be changed.

#>
function Add-PsModulePath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Path,

        [Parameter()]
        [Switch]
        $Machine
    )

    if ($null -ne $env:PSModulePath)
    {
        $psModulePathSplit = $env:PSModulePath -split ';'
        # Remove the existing module path from the new PSModulePath
        $newPSModulePathSplit = ( $psModulePathSplit | Where-Object { $_ -notin $Path } ) -join ';'
        $psModulePath = $newPSModulePathSplit -join ';'
    }
    else
    {
        $psModulePath = $null
    }

    $addPath = $Path -join ';'
    $newPSModulePath = "$addPath;$psModulePath"

    if ($Machine.IsPresent)
    {
        Set-PsModulePath -Path $newPSModulePath -Machine
    }
    else
    {
        Set-PsModulePath -Path $newPSModulePath
    }
}