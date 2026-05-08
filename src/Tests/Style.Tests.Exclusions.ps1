$exclusions = @{
    FileFormatting      = {
        $_.FullName -notlike '*\.vs*' -and $_.FullName -notlike '*\.git*' -and $_.FullName -notlike '*\.vscode*' -and $_.FullName -notlike '*\Tests\*'
    }
    ValidateScriptFiles = {
        $_.Extension -eq '.ps1'
    }
    ScriptAnalyzer      = {
        ($_.Extension -eq '.ps1' -or $_.Extension -eq '.psm1')
    }
    BadChars            = {
        ($_.Extension -eq '.ps1' -or $_.Extension -eq '.psm1')
    }
}

function Get-ExclusionScriptBlock
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $ExclusionType
    )

    return $exclusions.$ExclusionType
}
