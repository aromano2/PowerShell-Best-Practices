function BeforeEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeEach
}

function AfterEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterEach
}

function BeforeAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of the current Context
    or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeAll
}

function AfterAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterAll
}

function Clear-SetupAndTeardown
{
    $pester.BeforeEach = @( $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.AfterEach  = @( $pester.AfterEach  | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.BeforeAll  = @( $pester.BeforeAll  | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.AfterAll   = @( $pester.AfterAll   | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
}

function Invoke-TestCaseSetupBlocks
{
    $orderedSetupBlocks = @(
        $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Describe' } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
        $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Context'  } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedSetupBlocks
}

function Invoke-TestCaseTeardownBlocks
{
    $orderedTeardownBlocks = @(
        $pester.AfterEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Context'  } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
        $pester.AfterEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Describe' } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedTeardownBlocks
}

function Invoke-TestGroupSetupBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.BeforeAll |
                    & $SafeCommands['Where-Object'] { $_.Scope -eq $Scope } |
                    & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-TestGroupTeardownBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.AfterAll |
                    & $SafeCommands['Where-Object'] { $_.Scope -eq $Scope } |
                    & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-Blocks
{
    param ([scriptblock[]] $ScriptBlock)

    foreach ($block in $ScriptBlock)
    {
        if ($null -eq $block) { continue }
        $null = . $block
    }
}

function Add-SetupAndTeardown
{
    param (
        [scriptblock] $ScriptBlock
    )

    if ($PSVersionTable.PSVersion.Major -le 2)
    {
        Add-SetupAndTeardownV2 -ScriptBlock $ScriptBlock
    }
    else
    {
        Add-SetupAndTeardownV3 -ScriptBlock $ScriptBlock
    }
}

function Add-SetupAndTeardownV3
{
    param (
        [scriptblock] $ScriptBlock
    )

    $pattern = '^(?:Before|After)(?:Each|All)$'
    $predicate = {
        param ([System.Management.Automation.Language.Ast] $Ast)

        $Ast -is [System.Management.Automation.Language.CommandAst] -and
        $Ast.CommandElements.Count -eq 2 -and
        $Ast.CommandElements[0].ToString() -match $pattern -and
        $Ast.CommandElements[1] -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
    }

    $searchNestedBlocks = $false

    $calls = $ScriptBlock.Ast.FindAll($predicate, $searchNestedBlocks)

    foreach ($call in $calls)
    {
        # For some reason, calling ScriptBlockAst.GetScriptBlock() sometimes blows up due to failing semantics
        # checks, even though the code is perfectly valid.  So we'll poke around with reflection again to skip
        # that part and just call the internal ScriptBlock constructor that we need

        $iPmdProviderType = [scriptblock].Assembly.GetType('System.Management.Automation.Language.IParameterMetadataProvider')

        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $constructor = [scriptblock].GetConstructor($flags, $null, [Type[]]@($iPmdProviderType, [bool]), $null)

        $block = $constructor.Invoke(@($call.CommandElements[1].ScriptBlock, $false))

        Set-ScriptBlockScope -ScriptBlock $block -SessionState $pester.SessionState
        $commandName = $call.CommandElements[0].ToString()
        Add-SetupOrTeardownScriptBlock -CommandName $commandName -ScriptBlock $block
    }
}

function Add-SetupAndTeardownV2
{
    param (
        [scriptblock] $ScriptBlock
    )

    $codeText = $ScriptBlock.ToString()
    $tokens = @(ParseCodeIntoTokens -CodeText $codeText)

    for ($i = 0; $i -lt $tokens.Count; $i++)
    {
        $token = $tokens[$i]
        $type = $token.Type
        if ($type -eq [System.Management.Automation.PSTokenType]::Command -and
            (IsSetupOrTeardownCommand -CommandName $token.Content))
        {
            $openBraceIndex, $closeBraceIndex = Get-BraceIndecesForCommand -Tokens $tokens -CommandIndex $i

            $block = Get-ScriptBlockFromTokens -Tokens $Tokens -OpenBraceIndex $openBraceIndex -CloseBraceIndex $closeBraceIndex -CodeText $codeText
            Add-SetupOrTeardownScriptBlock -CommandName $token.Content -ScriptBlock $block

            $i = $closeBraceIndex
        }
        elseif ($type -eq [System.Management.Automation.PSTokenType]::GroupStart)
        {
            # We don't want to parse Setup or Teardown commands in child scopes here, so anything
            # bounded by a GroupStart / GroupEnd token pair which is not immediately preceded by
            # a setup / teardown command name is ignored.
            $i = Get-GroupCloseTokenIndex -Tokens $tokens -GroupStartTokenIndex $i
        }
    }
}

function ParseCodeIntoTokens
{
    param ([string] $CodeText)

    $parseErrors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($CodeText, [ref] $parseErrors)

    if ($parseErrors.Count -gt 0)
    {
        $currentScope = $pester.Scope
        throw "The current $currentScope block contains syntax errors."
    }

    return $tokens
}

function IsSetupOrTeardownCommand
{
    param ([string] $CommandName)
    return (IsSetupCommand -CommandName $CommandName) -or (IsTeardownCommand -CommandName $CommandName)
}

function IsSetupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeEach' -or $CommandName -eq 'BeforeAll'
}

function IsTeardownCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'AfterEach' -or $CommandName -eq 'AfterAll'
}

function IsTestGroupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeAll' -or $CommandName -eq 'AfterAll'
}

function Get-BraceIndecesForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    $openingGroupTokenIndex = Get-GroupStartTokenForCommand -Tokens $Tokens -CommandIndex $CommandIndex
    $closingGroupTokenIndex = Get-GroupCloseTokenIndex -Tokens $Tokens -GroupStartTokenIndex $openingGroupTokenIndex

    return $openingGroupTokenIndex, $closingGroupTokenIndex
}

function Get-GroupStartTokenForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    # We may want to allow newlines, other parameters, etc at some point.  For now it's good enough to
    # just verify that the next token after our BeforeEach or AfterEach command is an opening curly brace.

    $commandName = $Tokens[$CommandIndex].Content

    if ($CommandIndex + 1 -ge $tokens.Count -or
        $tokens[$CommandIndex + 1].Type -ne [System.Management.Automation.PSTokenType]::GroupStart -or
        $tokens[$CommandIndex + 1].Content -ne '{')
    {
        throw "The $commandName command must be immediately followed by the opening brace of a script block."
    }

    return $CommandIndex + 1
}

& $SafeCommands['Add-Type'] -TypeDefinition @'
    namespace Pester
    {
        using System;
        using System.Management.Automation;

        public static class ClosingBraceFinder
        {
            public static int GetClosingBraceIndex(PSToken[] tokens, int startIndex)
            {
                int groupLevel = 1;
                int len = tokens.Length;

                for (int i = startIndex + 1; i < len; i++)
                {
                    PSTokenType type = tokens[i].Type;
                    if (type == PSTokenType.GroupStart)
                    {
                        groupLevel++;
                    }
                    else if (type == PSTokenType.GroupEnd)
                    {
                        groupLevel--;

                        if (groupLevel <= 0) { return i; }
                    }
                }

                return -1;
            }
        }
    }
'@

function Get-GroupCloseTokenIndex
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $GroupStartTokenIndex
    )

    $closeIndex = [Pester.ClosingBraceFinder]::GetClosingBraceIndex($Tokens, $GroupStartTokenIndex)

    if ($closeIndex -lt 0)
    {
        throw 'No corresponding GroupEnd token was found.'
    }

    return $closeIndex
}

function Get-ScriptBlockFromTokens
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $OpenBraceIndex,
        [int] $CloseBraceIndex,
        [string] $CodeText
    )

    $blockStart = $Tokens[$OpenBraceIndex + 1].Start
    $blockLength = $Tokens[$CloseBraceIndex].Start - $blockStart
    $setupOrTeardownCodeText = $codeText.Substring($blockStart, $blockLength)

    $scriptBlock = [scriptblock]::Create($setupOrTeardownCodeText)
    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $pester.SessionState

    return $scriptBlock
}

function Add-SetupOrTeardownScriptBlock
{
    param (
        [string] $CommandName,
        [scriptblock] $ScriptBlock
    )

    $isSetupCommand = IsSetupCommand -CommandName $CommandName
    $isGroupCommand = IsTestGroupCommand -CommandName $CommandName

    if ($isSetupCommand)
    {
        if ($isGroupCommand)
        {
            Add-BeforeAll -ScriptBlock $ScriptBlock
        }
        else
        {
            Add-BeforeEach -ScriptBlock $ScriptBlock
        }
    }
    else
    {
        if ($isGroupCommand)
        {
            Add-AfterAll -ScriptBlock $ScriptBlock
        }
        else
        {
            Add-AfterEach -ScriptBlock $ScriptBlock
        }
    }
}

function Add-BeforeEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.BeforeEach += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-AfterEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.AfterEach += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-BeforeAll
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.BeforeAll += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-AfterAll
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.AfterAll += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCXY4Q7g3V96Vnk
# uJlLiTyJAgqODpDvSo9oFPM3kG+TBKCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GwAwghr8AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# V2Tt+dsyg2aUJSPh0fJYAL8QrcswJBZNFmQ/uD4lbVwwUAYKKwYBBAGCNwoDHDFC
# DEA3Q0E2MUIwQzUyQzFFRENENzE4MUQxQjhGNjdGQjdDMkVERTc3MzY1MTMyRTMw
# OEMxNjNEQzIzRjkyNDUzNzEyMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGALb3NLnyD1MGK/BfvzzQ4
# X6wgNoSeQ1TyJWizfkfiLtTRKaOhzOfn72KP5FJdOMdGC3M67kj5QEsLBY+MUGoe
# K0Qj0vfjkqhFoEfueyDUxEjm32PMAnEAv0Wr6t6eZ/VSFo4G7+T1R4bxBaB/6Akm
# MX98sdHPNwDC4xfR5EDVvhl7xdjMTzbpKjOq+I1AeaLoFGak6XroWHRQphh6/8X4
# 4alya56CZ7M5WVNNC9raJObpFqfIzAEG5ASyu3vENrn9cLGF6hWWZWPZaNJs4qw2
# hzOJMblODe3EdVC0SENEnVTz7EzFWzNg8K0+8l8+fhiNCSwH/IVSg6yoMKCcg0uo
# qreLarucSPr8lJFTRyA1reFDa/cg+2XQ0Dik2Gz/yOh4DTfvYduouGfTJ44gKsDO
# ub54PgSWPdBTiEhhKoHfjSLGBLZtt6Yp6XeucJtzydu/W8RV/P06e/8WN1/LGPuU
# KU0/UXLIVus/AReN0D+1Fda4BqmAHFEKtDiaPg5PUHT8oYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIFvEMnYTdbwA5F3ZkEKx/9SmwhCVdyRfigH2p//T
# iOYNAgZpvC4kvZoYEzIwMjYwNDExMTA1MzE3LjEyNlowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAITsEM1Zs+v
# legAAQAAAhMwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODE3WhcNMjYxMTEzMTg0ODE3WjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046MzYwNS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQD0mXrg
# uhnEMg1IWDP70pLk7O/mbnjx49XNz1FdZ7hPj8ymV+Brh6rXZEZ2nlxW+eN17m/F
# +rZrH+Oe7u9Rbitk3iY5Sbm+H6RxixCVhDncXCAgHecSNxAeiasbeZl7+jOMVICv
# oluCUq0h4DJI/MBwXPIB6vmUs1QcES9AwzwE6MzJqkK+HTGyDjEoVxUQlAsoR8IY
# F98xkj9qa60cVvcJRNntpWkbYocQVQ2VnW/Awq/FdM9EOdvA8bPLKoknOd+ws0dD
# i9e3a21LU94KgYjSE3U96rzIawhcz2ihzALToMY1Iz/gsDHa4q/CZSfo3AtzT62a
# +fLrDbytkt6OyRF+dVah8S/WZZjSMdScevBIYFLyBU/2BwGzo/mDQ6kk8x/F1SQd
# dGRww89bSEg/w1tbxblK6nwe7CdIpuOnICUYFR0z9XmtlvSxmaSfvXivpQsYr5ws
# sA3pHcWFfo3SePrgXbstMrYFtLSkllpeOjR4M3PVBzF4gUtSAX5EGwtgOfwTxwKR
# 7Erw2W3caL3Ml/nnDpR9Nn6TBMzEyoXGHv5N/Hv5oE5tn6fH3rUC2KoDLvNVXr2j
# 8tZF0o9l29mf0RLIZtOc9+OQERG/bamtKUROVHDM/puYRU4pYtZXDG7CHttRZS5R
# vVyP3fO+21BgZBq3kT0Assk2aW8soKyQHutouwIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFBOeEErH4WvKmFBYxGKkfj2wwUA6MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCCbFomsapDYPpQmFnpCXZJkU5o24ZtbcvMH4RL6XYEHUwm0FFIV2L+FVjfc2nG
# wlCFDlMtWnQNdg6Qig9BzXusf4hWF6Y7yMK35TojVMjDpxHtz60Sj8mOnoSoRTVz
# j+atoyOAeFD6toL85QCb3wDWvhsg8e2wGYtE4aZ4TlcsgVoEhlYe+HYI5chMo5td
# V3nAa0nV1ll3BocAJcXnTqO1r66hR3LMB642VM8tOtnyfKHEbCT1WHp6INDsJAxZ
# JJrwMlL09ReN6iL29N1Ltkxeq762/pDPfG2gEXn5gUri4T6aIaz3QXGbRUraVauY
# WGORGXnPKgc53Abuyk1iQOiYI81Yi51RCZBgqm38eyyl9xv7GmdYgNB0zOATymPW
# +nAuBYScfsu1Ph1kJ6gOj08rjRHEEPyQonvr2eCQTB/AIPYRf8xCTv14i86GmcfX
# Ya5UHK9opmTldm+q08403Cvyr+oDfzvsi5bBaCdp5f6munDR1n9Au1sYZWuA/5NF
# CO37Z1xkDk/dfgvAA2GI+zLQ6XhcJ2Ps7EEsW87OwI8M9pWeSn518MUb404GKvtq
# pMnrzrbanKaDVX7qBz/VG/EL/CC9jIbTfd5wmq/Q6fRlE1iv6L86TCADcc/VosPR
# oesSnDqW3TbreJGQK+tx1w5bzDeMLxMm5oZbILZL2MSPODCCB3EwggVZoAMCAQIC
# EzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoX
# DTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC
# 0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VG
# Iwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP
# 2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/P
# XfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361
# VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwB
# Sru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9
# X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269e
# wvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDw
# wvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr
# 9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+e
# FnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAj
# BgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+n
# FV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0Nl
# ckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4Swf
# ZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTC
# j/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu
# 2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/
# GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3D
# YXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbO
# xnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqO
# Cb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I
# 6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0
# zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaM
# mdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNT
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNWMIICPgIBATCCAQGhgdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCYETxIKPGCNpybLz9U
# R2Ts3GlHpqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7YRUjjAiGA8yMDI2MDQxMTA1MDMxMFoYDzIwMjYwNDEy
# MDUwMzEwWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDthFSOAgEAMAcCAQACAim2
# MAcCAQACAhLaMAoCBQDthaYOAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# ANZsRKDlC1SsBbNnBICUsxYhvhaEWqRmFN3D3gyLeFrOhjtixypjpIBETl0EpqsE
# k2nYPU1epsdaiq63WVsrpkauATxoRJjWofXNylVc0yYOkM3FbeAsq56ZkzOjqnJT
# A5zKC39zc9HjZwcsbUcXRHkaA8pcPMxg1GA1U62pw1m5pLWbX6hIeBX+UUaRxcHI
# Gf6VnTq1vv89T6uDHQBcyiuztBpIZNeDRYio605u11ypQROQGZm6Z7gDiSd+2v3O
# WAN6KvvR/Pjrh9XZ+wZEpPH28p+5ERJ/gwizlMqNgcEZKbvmoZuCk6G/ELcdn/8d
# zvEZchzG9wGp3mUXsn6bej0xggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAhOwQzVmz6+V6AABAAACEzANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCColXwxstv4KWKykIKFC2lZgJhyKQV1BsDKDNzXhZWZ8zCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIMzhCW0UhTPwngOMDM/idWh1m9DFgaV5Qh+nzo5rnFho
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAITsEM1
# Zs+vlegAAQAAAhMwIgQgfUKmePmHso8dt2rp6KfmE/lI8i0eF8vhB9xMF9Dz08ww
# DQYJKoZIhvcNAQELBQAEggIAQKrJNrPW9/Uk7FOAdgx44hBaXM3btZ1RhbyxfXWw
# SDlHzxmpWuLBSJLIirroLQwDPQqbgeZpMNWuYooUoq9mn44MlgK5E92fhA3aAGgw
# HiKdzQQrXHbR5SeLB92yWkyV4aCPJrP0bK36GtEBXLNDJRDKvnOlZZvlGB+W8dNC
# XyiIlYF+r15zjbWX9i0HOTZkbxSoJGxFNVXQnXoLs0ljFDBRQqA1HTUv1sOS4BGg
# pmsgo6URyadrXXK9HbqiY7eJNdWC/so0mwSwReXuO2ryqqJHsONvipliAne2NL7Q
# XbLpQVWahuw49FASe3P/HTJptSuw5oFDkn8e1BClggYa55th+zO5/uhLJkYC5VE7
# MsWAqdnOqmS2FMX+ZrFHFNdfUc38iKwFgyV0T/yiS3vIwwu+3Tt+ZzeAQNKvzOuO
# Hk3Q0OXY+aescfdkfKApa+xbqB1W4kP0ILs+29o1E8cRFvVNMiH8QVUIQcMb9zZp
# VgHKr0AbXKU4jkMqztvzOvmAnFuCYUG8TSNbI8KsJd0iO4TcfqqmC9UdSDOtwCJK
# yoJvVIuCiGDzDBMfjTNBdj0ykc3gv96pPeFusGhjdVV10/Y6TP7/2Oh+tTUNw2l5
# oL61Mcm+EfDRHDk9JB0abQfyb3aELOz9Ni4KbaKh9kbz2npKFxjvfDh3SSy5/BJL
# KOA=
# SIG # End signature block
