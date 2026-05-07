$Exclusions = @{
    FileFormatting      = {
        $_.FullName -notlike '*\.vs*'
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

    return $Exclusions.$ExclusionType
}
