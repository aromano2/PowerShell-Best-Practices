$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$manifestPath   = "$here\Pester.psd1"
$changeLogPath = "$here\CHANGELOG.md"

# DO NOT CHANGE THIS TAG NAME; IT AFFECTS THE CI BUILD.

Describe -Tags 'VersionChecks' "Pester manifest and changelog" {
    $script:manifest = $null
    It "has a valid manifest" {
        {
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
        } | Should Not Throw
    }

    It "has a valid name in the manifest" {
        $script:manifest.Name | Should Be Pester
    }

    It "has a valid guid in the manifest" {
        $script:manifest.Guid | Should Be 'a699dea5-2c73-4616-a270-1f7abb777e71'
    }

    It "has a valid version in the manifest" {
        $script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
    }

    $script:changelogVersion = $null
    It "has a valid version in the changelog" {

        foreach ($line in (Get-Content $changeLogPath))
        {
            if ($line -match "^\D*(?<Version>(\d+\.){1,3}\d+)")
            {
                $script:changelogVersion = $matches.Version
                break
            }
        }
        $script:changelogVersion                | Should Not BeNullOrEmpty
        $script:changelogVersion -as [Version]  | Should Not BeNullOrEmpty
    }

    It "changelog and manifest versions are the same" {
        $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
    }

    if (Get-Command git.exe -ErrorAction SilentlyContinue) {
        $script:tagVersion = $null
        It "is tagged with a valid version" {
            $thisCommit = git.exe log --decorate --oneline HEAD~1..HEAD

            if ($thisCommit -match 'tag:\s*(\d+(?:\.\d+)*)')
            {
                $script:tagVersion = $matches[1]
            }

            $script:tagVersion                  | Should Not BeNullOrEmpty
            $script:tagVersion -as [Version]    | Should Not BeNullOrEmpty
        }

        It "all versions are the same" {
            $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
            $script:manifest.Version -as [Version] | Should be ( $script:tagVersion -as [Version] )
        }

    }
}

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $error.Clear()
    Describe 'Clean treatment of the $error variable' {
        Context 'A Context' {
            It 'Performs a successful test' {
                $true | Should Be $true
            }
        }

        It 'Did not add anything to the $error variable' {
            $error.Count | Should Be 0
        }
    }

    InModuleScope Pester {
        Describe 'SafeCommands table' {
            $path = $ExecutionContext.SessionState.Module.ModuleBase
            $filesToCheck = Get-ChildItem -Path $path -Recurse -Include *.ps1,*.psm1 -Exclude *.Tests.ps1
            $callsToSafeCommands = @(
                foreach ($file in $files)
                {
                    $tokens = $parseErrors = $null
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $parseErrors)
                    $filter = {
                        $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                        $args[0].InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and
                        $args[0].CommandElements[0] -is [System.Management.Automation.Language.IndexExpressionAst] -and
                        $args[0].CommandElements[0].Target -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $args[0].CommandElements[0].Target.VariablePath.UserPath -match '^(?:script:)?SafeCommands$'
                    }

                    $ast.FindAll($filter, $true)
                }
            )

            $uniqueSafeCommands = $callsToSafeCommands | ForEach-Object { $_.CommandElements[0].Index.Value } | Select-Object -Unique

            $missingSafeCommands = $uniqueSafeCommands | Where-Object { -not $script:SafeCommands.ContainsKey($_) }

            It 'The SafeCommands table contains all commands that are called from the module' {
                $missingSafeCommands | Should Be $null
            }
        }
    }
}

Describe 'Style rules' {
    $pesterRoot = (Get-Module Pester).ModuleBase

    $files = @(
        Get-ChildItem $pesterRoot -Include *.ps1,*.psm1
        Get-ChildItem $pesterRoot\Functions -Include *.ps1,*.psm1 -Recurse
    )

    It 'Pester source files contain no trailing whitespace' {
        $badLines = @(
            foreach ($file in $files)
            {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ($lines[$i] -match '\s+$')
                    {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    It 'Pester Source Files all end with a newline' {
        $badFiles = @(
            foreach ($file in $files)
            {
                $string = [System.IO.File]::ReadAllText($file.FullName)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n")
                {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }
}

InModuleScope Pester {
    Describe 'ResolveTestScripts' {
        Setup -File SomeFile.ps1
        Setup -File SomeFile.Tests.ps1
        Setup -File SomeOtherFile.ps1
        Setup -File SomeOtherFile.Tests.ps1

        It 'Resolves non-wildcarded file paths regardless of whether the file ends with Tests.ps1' {
            $result = @(ResolveTestScripts $TestDrive\SomeOtherFile.ps1)
            $result.Count | Should Be 1
            $result[0].Path | Should Be "$TestDrive\SomeOtherFile.ps1"
        }

        It 'Finds only *.Tests.ps1 files when the path contains wildcards' {
            $result = @(ResolveTestScripts $TestDrive\*.ps1)
            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains "$TestDrive\SomeFile.Tests.ps1") | Should Be $true
            ($paths -contains "$TestDrive\SomeOtherFile.Tests.ps1") | Should Be $true
        }

        It 'Finds only *.Tests.ps1 files when the path refers to a directory and does not contain wildcards' {
            $result = @(ResolveTestScripts $TestDrive)

            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains "$TestDrive\SomeFile.Tests.ps1") | Should Be $true
            ($paths -contains "$TestDrive\SomeOtherFile.Tests.ps1") | Should Be $true
        }

        It 'Assigns empty array and hashtable to the Arguments and Parameters properties when none are specified by the caller' {
            $result = @(ResolveTestScripts "$TestDrive\SomeFile.ps1")

            $result.Count | Should Be 1
            $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

            ,$result[0].Arguments | Should Not Be $null
            ,$result[0].Parameters | Should Not Be $null

            $result[0].Arguments.GetType() | Should Be ([object[]])
            $result[0].Arguments.Count | Should Be 0

            $result[0].Parameters.GetType() | Should Be ([hashtable])
            $result[0].Parameters.PSBase.Count | Should Be 0
        }

        Context 'Passing in Dictionaries instead of Strings' {
            It 'Allows the use of a "P" key instead of "Path"' {
                $result = @(ResolveTestScripts @{ P = "$TestDrive\SomeFile.ps1" })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"
            }

            $testArgs = @('I am a string')
            It 'Allows the use of an "Arguments" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Arguments = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "Args" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Args = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "A" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; A = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            $testParams = @{ MyKey = 'MyValue' }
            It 'Allows the use of a "Parameters" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Parameters = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Allows the use of a "Params" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Params = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Throws an error if no Path is specified' {
                { ResolveTestScripts @{} } | Should Throw
            }

            It 'Throws an error if a Parameters key is used, but does not contain an IDictionary object' {
                { ResolveTestScripts @{ P='P'; Params = 'A string' } } | Should Throw
            }
        }
    }
}

# SIG # Begin signature block
# MIInYAYJKoZIhvcNAQcCoIInUTCCJ00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBfE/e7u3jI6yz7
# QBumibsiH2jWUPju+4aTP+s3pHx6C6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GwIwghr+AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# 94xukSE+y4BA4FzFksXXaGjRyjPUpkDE4RMJYruwNLIwUAYKKwYBBAGCNwoDHDFC
# DEA1REYzOEJFQ0NENkYzMjk3NTlCQTEwNDMwNzc2RTQ1NUJCQzczRTJCNTQ5MDYy
# MzY1RTBERDIyMkVDQzFGQzEyMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAR3PGSl9Eb0IOd2fM/+yT
# u4mJD7GgOxESlMbOc8BowawC+UioX2QdV1egyrvn1lBRj5rEB8PvDeGARPAJwOCf
# XmJI/Zc3rZXoda2KIse1VrBuD/sHeufla8IjoaYai3fiLvI8VTsdOSb6Z86E3ofi
# WvAdZO2QGupirBuJYECyH10b4ZEnbKHzkEzgvIwTvMJAApEfXSYthAftofmjZJQt
# w9zK6vccieJiUoiND0rylBy4sUvGQjHXXY8tI/GAVbnm5HAw6VmBQ7N+dVUM0O+A
# HBjH5ZYGA00dpsjPotO+tI3P1vgJKVZ40GnzWIPNkh8wG3p0ulz6X29Ig6i38kc2
# UPYT0B/+5HbV83BmASNa11GiZj3Z8kMhf3Rpgc8PyG+d7tvfjDKM/Uo1pINBXnDN
# 4BRWd8cikM/bNNLCq9PtMRm77n5rs8N1FqDz/XroECbIhI4NdCY/CMsXAWyx7W6N
# hm3Z4z7apRUN16xgg9UmNezUB5NIb8V6hDAogVg6rZmLoYIXrzCCF6sGCisGAQQB
# gjcDAwExghebMIIXlwYJKoZIhvcNAQcCoIIXiDCCF4QCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIAS1ES7LujgLc0K16zeyWJqqAn07PTe+kwF09iql
# hKJHAgZpvIp2j1wYEjIwMjYwNDExMTA1MzE3LjA4WjAEgAIB9KCB2aSB1jCB0zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWlj
# cm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046NEMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghH+MIIHKDCCBRCgAwIBAgITMwAAAhgl2ZIF4ufl
# 5AABAAACGDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yNTA4MTQxODQ4MjVaFw0yNjExMTMxODQ4MjVaMIHTMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo0QzFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALHc6Orr
# kCagH8S57xAXyL4+pJyvqem5zFxBWf0IzzhcsJXIw38yPA4NZ8w5cZu/6am741oc
# r2syphcjuqmz8ApX0ZyOe4eTgosYKTjghiSUCGUk4jILotwfAz4hbST3H80bdxbJ
# 8Yy18ASIxoJ4xn5kJe83owNVqGC/6gZkIcPxQxU1nm8X6OJtEQgjsX9qsI99Wjo3
# NmmFHj7SzFx7FyjxR9LaeUiiBf/bScUUoNDWBL0KlYpY3vGkJD3d6swLsdjHORzE
# iuDTE7VVQmAFg1GeKfuogyPbeQTQgSLH+aKBTVFrcQqp6RWIi2JB3xX8YVVAWfCx
# hsWLAN+rJw+ubNh3+LfOpNHvFnpR/7rH4WKjjN89smiPK4NPOt9SJMKlM8kKBD6j
# LB4AXptcaZjhkiFJ1b07AL/pZhAi9kaq3DmZWWsfCtGooo/IelJFgTdiAP4pGnJE
# 0hlUQUJllmbixVlf0+Mbjc7HAtF+8aOH3rYKbKmhANI2P0Hr5E7y7+DpTTfXji/C
# zYe1ZtEeuT+6GmzkA6rVBQMAoI4DydIlf40AmjAHDt0mKRucEgGIiZJOFy4zUpTc
# VNiHY7NbDkYZe7OywuoTm+21QB1cDje+BsXxTYhCAOgX7nQDY6UCdJ1HP6aRF6U+
# KYAwR7GLVfDsikoyrCMTnRUe3yCSIw3PA71JAgMBAAGjggFJMIIBRTAdBgNVHQ4E
# FgQUJC6hxFw6G2O3R7qEAgWuLF+2i9EwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIB
# AJ5I0YY8D4HaCKb7eGIqE/49C1rgcRdwEQSlwxDYIK2irwtKET8G4wJrF5zxJrbq
# OTA/LifV8PXmK8aqpCuAxfbJ2TKxzH6KMQmvvtYqy8/GKKMwuLXIvmuDd+0m5Hta
# bdcbPambb5D4GRlp+QXMFX5gMEmSx4tgrmdOmNP1/renzQZ62zFaLzWg1+Fj3ciP
# RhM8XyIIA7HJNiKaOFVy/wK3M+6dhe2xGRkbssY4DAvsKApAyWh/8pP8HGaQLIsX
# uDznTdA1umW9+Ttw4N/muqawDTHN1iHb3yg5e+T9GqnEG0AEe29H+IB+DTJFHLdF
# puBjeSobBNWCu1f8AKgypiuI8d8y892vB7MWvRwdxsorZZgubA4TpeEExjeZEYuq
# AqFeISvpCBYJ5Fox4UkTaJs9+kJ2wkhvwRyxJthkVPbt/yOM1HfRNQAveyCRBn8G
# /tDVm90BHK5MqXRnVsJdCxDm4a0EfQdVe/nnXMjZrF9KdgV9KxaXdT5FyUm8X/CH
# BIsP25DYGoGRPlZQ7cV3q7i3aOZN5Rjr+6z2LjhGqGWMQ72baRz/T9+sJluCDY0e
# jSJ59lDPpKz/8Xi50WwwZJvUbJZ6A4Va2pYigx+tgcYXIC/bYkYDh5XCNMKr1Vi3
# b/MlvK8ZGsDpYQkak9xChAlvJLVAD8DWwVC5E/qFnLwXMIIHcTCCBVmgAwIBAgIT
# MwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcN
# MzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT
# /e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYj
# DLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/Y
# JlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d
# 9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVU
# j9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFK
# u75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231f
# gLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C
# 89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC
# +hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2
# XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54W
# cmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMG
# CSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cV
# XQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/
# BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2Nz
# L1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcU
# AgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8G
# A1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9n
# ATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP
# +2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27Y
# P0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8Z
# thISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNh
# cy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7G
# dP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4J
# vbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjo
# iV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TO
# PqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ
# 1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NN
# je6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA1kwggJBAgEBMIIBAaGB2aSB1jCB0zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWlj
# cm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046NEMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAJ1rRq11orjRPEKyn5uA
# rRq+e8/poIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQELBQACBQDthAgwMCIYDzIwMjYwNDEwMjMzNzIwWhgPMjAyNjA0MTEy
# MzM3MjBaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAO2ECDACAQAwCgIBAAICGgQC
# Af8wBwIBAAICEqIwCgIFAO2FWbACAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOC
# AQEATsjc0MiLtLrHYX2OvEQrEIH2slia2PTGD8JLfp291aEyzHZY0E6VUW4s0YLB
# PNlpoHgIffgJR97v2AUShtr/PeNlk1VwQEVwxh49x5rmtmPdv9ay4WtHSh90KcZ9
# mjl06mXZOVxeDPoPJnHegW/S5EBFsaB0IfpVXAxo+Uv04u35Am0VljlLnCy/ncrU
# mFRKlw3Ms10Kw58fTzOz3BVOvigZKNTA2ePXGTJ45Q8cbK1DC9OOzExAUbKKVwaT
# rkD+MkDn5P1s+dmce4xvFaNJvRNrDyiA0yBOfx7SfhCqr/drIvVAMwJm71vYdwb9
# GfIchVbBR9cRuu/8Q/s6TaFviDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAACGCXZkgXi5+XkAAEAAAIYMA0GCWCGSAFlAwQC
# AQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkE
# MSIEIDfstI767cTZewPrClKpB/oUVNN2Y1HWc2WVyA8XljliMIH6BgsqhkiG9w0B
# CRACLzGB6jCB5zCB5DCBvQQgmRPcibjkyLSMFmhEupcxiitV3EqM9cp0c2jlc8fX
# hWowgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhgl
# 2ZIF4ufl5AABAAACGDAiBCBzZ0JiOmdFYrReMCwSuof6oEs531OrPEqRDI3JSfXI
# MzANBgkqhkiG9w0BAQsFAASCAgAoGA+7ey726LyTjb82gAcW9Ly7ddq9cDImUTh+
# FTwQ+3Zgm1GzN/YpiwhKTLvwxobJKqExZAoSWl5FKkVf5pURZf/csIZWWf8URdvQ
# pLidxHa984p7UxWbxHRoKyk0vVuB5dD32KJMPypyS5iGi89c8xRiUcQ968wqvdNg
# xVowRwxwapvDmCaC6gEhwbX5PhFNh/xoHualtDntSn5eMm18JYuVK3DEQdJyJdEs
# hvaKySMRyI7XucYDvvLCe//SQNK4S9UEN6alOtgjocuCk0mUaDn0t0IsQLDsnFfx
# tMtTaxGzR2wVxaLj9QyRuQ7TyTrBnLCKKAmqBZh01QVfg95ne29425tAfd+HMIzl
# tmPrEHG92NntYURBjUrWtVdO6+O9ZQ2Fy5481sp9ns9TDDKhOas47fY0miH8gBck
# K9dnyPh4MccjAzVcf9laPqow5xw4XbljKB8MIZkjX2Xx6g/YyOeIkAmhkir98ssR
# mDgLvExJs0khuACbVk4Mk3fknof5L0fzEEDCc3SSV8RuEMS3AVJp9zRS5r8Bsuwm
# edUA6EEoTQoCoI5dOpZQndS1sVOBTTA/vDNp7oNlKodcyACGXLSWrejb7xxnm2e2
# ZUC127wFTTwbNoQJDGHZA4V4CYEUGetT2uOYlprHoHijAs5C0FC0kNbI58prxkOD
# saNQUg==
# SIG # End signature block
