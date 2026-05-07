Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe 'Get-PesterResult' {
    }

    Describe 'It - Implementation' {
        $testState = New-PesterState -Path $TestDrive

        It 'Throws an error if It is called outside of Describe' {
            $scriptBlock = { ItImpl -Pester $testState 'Tries to enter a test without entering a Describe first' { } }
            $scriptBlock | Should Throw 'The It command may only be used inside a Describe block.'
        }

        $testState.EnterDescribe('Mocked Describe')

        # We call EnterTest() directly here because if we actually nest calls to ItImpl, the outer call will catch the error we're trying to
        # verify with Should Throw.  (Another option would be to nest the ItImpl calls, and look for a failed test result in $testState.)
        $testState.EnterTest('Outer Test')

        It 'Throws an error if you try to enter It from inside another It' {
            $scriptBlock = {
                ItImpl -Pester $testState 'Enters the second It' { }
            }

            $scriptBlock | Should Throw 'You already are in It, you cannot enter It twice'
        }

        $testState.LeaveTest()

        It 'Throws an error if you fail to pass in a test block' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' }
            $scriptBlock | Should Throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
        }

        It 'Does not throw an error if It is called inside a Describe, and adds a successful test result.' {
            $scriptBlock = { ItImpl -Pester $testState 'Enters an It block inside a Describe' { } }
            $scriptBlock | Should Not Throw

            $testState.TestResult[-1].Passed | Should Be $true
            $testState.TestResult[-1].ParameterizedSuiteName | Should BeNullOrEmpty
        }

        It 'Does not throw an error if the -Pending switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Pending }
            $scriptBlock | Should Not Throw
        }

        It 'Does not throw an error if the -Skip switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Skip }
            $scriptBlock | Should Not Throw
        }

        It 'Does not throw an error if the -Ignore switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Ignore }
            $scriptBlock | Should Not Throw
        }

        It 'Creates a pending test for an empty (whitespace and comments only) script block' {
            $scriptBlock = {
                # Single-Line comment
                <#
                    Multi-
                    Line-
                    Comment
                #>
            }

            { ItImpl -Pester $testState 'Some Name' $scriptBlock } | Should Not Throw
            $testState.TestResult[-1].Result | Should Be 'Pending'
        }

        It 'Adds a failed test if the script block throws an exception' {
            $scriptBlock = {
                ItImpl -Pester $testState 'Enters an It block inside a Describe' {
                    throw 'I am a failed test'
                }
            }

            $scriptBlock | Should Not Throw
            $testState.TestResult[-1].Passed | Should Be $false
            $testState.TestResult[-1].ParameterizedSuiteName | Should BeNullOrEmpty
            $testState.TestResult[-1].FailureMessage | Should Be 'I am a failed test'
        }

        $script:counterNameThatIsReallyUnlikelyToConflictWithAnything = 0

        It 'Calls the output script block for each test' {
            $outputBlock = { $script:counterNameThatIsReallyUnlikelyToConflictWithAnything++ }

            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }
            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }
            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }

            $script:counterNameThatIsReallyUnlikelyToConflictWithAnything | Should Be 3
        }

        Remove-Variable -Scope Script -Name counterNameThatIsReallyUnlikelyToConflictWithAnything

        Context 'Parameterized Tests' {
            # be careful about variable naming here; with InModuleScope Pester, we can create the same types of bugs that the v3
            # scope isolation fixed for everyone else.  (Naming this variable $testCases gets hidden later by parameters of the
            # same name in It.)

            $cases = @(
                @{ a = 1; b = 1; expectedResult = 2}
                @{ a = 1; b = 2; expectedResult = 3}
                @{ a = 5; b = 4; expectedResult = 9}
                @{ a = 1; b = 1; expectedResult = 'Intentionally failed' }
            )

            $suiteName = 'Adds <a> and <b> to get <expectedResult>.  <Bogus> is not a parameter.'

            ItImpl -Pester $testState -Name $suiteName -TestCases $cases {
                param ($a, $b, $expectedResult)

                ($a + $b) | Should Be $expectedResult
            }

            It 'Creates test result records with the ParameterizedSuiteName property set' {
                for ($i = -1; $i -ge -4; $i--)
                {
                    $testState.TestResult[$i].ParameterizedSuiteName | Should Be $suiteName
                }
            }

            It 'Expands parameters in parameterized test suite names' {
                for ($i = -1; $i -ge -4; $i--)
                {
                    $expectedName = "Adds $($cases[$i]['a']) and $($cases[$i]['b']) to get $($cases[$i]['expectedResult']).  <Bogus> is not a parameter."
                    $testState.TestResult[$i].Name | Should Be $expectedName
                }
            }

            It 'Logs the proper successes and failures' {
                $testState.TestResult[-1].Passed | Should Be $false
                for ($i = -2; $i -ge -4; $i--)
                {
                    $testState.TestResult[$i].Passed | Should Be $true
                }
            }
        }
    }

    Describe 'Get-OrderedParameterDictionary' {
        $_testScriptBlock = {
            param (
                $1, $c, $0, $z, $a, ${Something.Really/Weird }
            )
        }

        $hashtable = @{
            '1' = 'One'
            '0' = 'Zero'
            z = 'Z'
            a = 'A'
            c = 'C'
            'Something.Really/Weird ' = 'Weird'
        }

        $dictionary = Get-OrderedParameterDictionary -ScriptBlock $_testScriptBlock -Dictionary $hashtable

        It 'Reports keys and values in the same order as the param block' {
            ($dictionary.Keys -join ',') |
            Should Be '1,c,0,z,a,Something.Really/Weird '

            ($dictionary.Values -join ',') |
            Should Be 'One,C,Zero,Z,A,Weird'
        }
    }

    Describe 'Remove-Comments' {
        It 'Removes single line comments' {
            Remove-Comments -Text 'code #comment' | Should Be 'code '
        }
        It 'Removes multi line comments' {
            Remove-Comments -Text 'code <#comment
            comment#> code' | Should Be 'code  code'
        }
    }
}

$thisScriptRegex = [regex]::Escape($MyInvocation.MyCommand.Path)

Describe 'Get-PesterResult' {
    $getPesterResult = InModuleScope Pester { ${function:Get-PesterResult} }

    Context 'failed tests in Tests file' {
        #the $script scriptblock below is used as a position marker to determine
        #on which line the test failed.
        $errorRecord = $null
        try{'something' | should be 'nothing'}catch{ $errorRecord=$_} ; $script={}
        $result = & $getPesterResult 0 $errorRecord
        It 'records the correct stack line number' {
            $result.Stacktrace | should match "at line: $($script.startPosition.StartLine) in $thisScriptRegex"
        }
        It 'records the correct error record' {
            $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should be $true
            $result.ErrorRecord.Exception.Message | Should match 'Expected: {nothing}'
        }
    }
    It 'Does not modify the error message from the original exception' {
        $object = New-Object psobject
        $message = 'I am an error.'
        Add-Member -InputObject $object -MemberType ScriptMethod -Name ThrowSomething -Value { throw $message }

        $errorRecord = $null
        try { $object.ThrowSomething() } catch { $errorRecord = $_ }

        $pesterResult = & $getPesterResult 0 $errorRecord

        $pesterResult.FailureMessage | Should Be $errorRecord.Exception.Message
    }
    Context 'failed tests in another file' {
        $errorRecord = $null

        $testPath = Join-Path $TestDrive test.ps1
        $escapedTestPath = [regex]::Escape($testPath)

        Set-Content -Path $testPath -Value "`r`n'One' | Should Be 'Two'"

        try
        {
            & $testPath
        }
        catch
        {
            $errorRecord = $_
        }

        $result = & $getPesterResult 0 $errorRecord


        It 'records the correct stack line number' {
            $result.Stacktrace | should match "at line: 2 in $escapedTestPath"
        }
        It 'records the correct error record' {
            $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should be $true
            $result.ErrorRecord.Exception.Message | Should match 'Expected: {Two}'
        }
    }
}

# SIG # Begin signature block
# MIInYQYJKoZIhvcNAQcCoIInUjCCJ04CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCT7hodUcKmASqq
# 77kpXQ+Mw6bkME7fkMjDJzx4xtoeSqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GwMwghr/AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# 9wXUMFsilCu0g+QP50pnLsawFhpKncXErtXp7s91m0cwUAYKKwYBBAGCNwoDHDFC
# DEAzQkI0RjdDRjMwRTM0QTI2QjU3RTkwRkMyMkNGNUNCNDJCMTBFQUIwNTdCMzk5
# NkQxQkUzQkQ5RUIxNzZGRkVGMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAlneto0FgEKGqU529ULTy
# aonRn+RL7mUb8URf9PndG6kv9hVipBFo/lAShEQzc0rkxt4Vgn0Hn3vpDuUzGbjg
# n4bYyFBWdbvkBH0Vil+SOQIwA2Z3QS2UXA/YkpxIzcTsVpS2rQYkqpIYU5DUcplN
# 4S8XahD36fDUP/QRt++C3FTsJCCpM7s/e4gQ9xhS6KOyFX6XpemIvCkvAtcgmAAd
# /Hir7ug4vrJMs3O58ow0/MpL4n1z84wX5uA/DSUs2hTrSAMfv500zkPOwfnvinLf
# KYfCj3bC+8Oh8GfgAPU3VKeEKvjxOJGCINie0knFGe5NM4YS7gJHh9YuWxT4QfYx
# U1eDerZJlKXjjoMoDgERcYqSskxz8Pc1K4yOSdptsyZj3sOQ4DjG2EAfpEhpj6+F
# gZ9rhSCWuK5eaxGaOgwOYROuBcLnuUad84K/cotIEZgiq42iVFdNME0O1rHbxUNJ
# Pym4mA6QrdhHFm96strZHTmfZhx3MFccQDMLM8Gs+ajvoYIXsDCCF6wGCisGAQQB
# gjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UCAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILZYbQ1Av4QdCCIX87E/BBiIrR8t4KqmGa0qGCq9
# 7fhcAgZpvGbkL5cYEzIwMjYwNDExMTA1MzE2LjMxMVowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjJBMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMCAQICEzMAAAIQq83kFhjv
# ObAAAQAAAhAwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODEyWhcNMjYxMTEzMTg0ODEyWjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046MkExQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCNxzir
# TntnAiCkq7ilNdYt6O9gR25F/7WYiluIkQwVZaZTbGmKn7MrvEXEoYHUJyVRcFTT
# 9lBnosbwfSAjvK+iyuw8QjUM8H9dxwYK+zApsApySeA64ZMQ8aTsr+8Rlr2HRe3T
# Zvubaf0x0iOQusWXSkOuIrLPRAcal2H3dfr40Cl8TVMvbhWjTGR6gUakvetf2BeE
# g4Xn0QydN3ajjkVb+jEyBj2rTLSMY7QesItMJmvnR7tNlFI1gDLaXIpu8ojYwqU3
# XAvMm9lttz/8vezWrcnoqFLQoLZU0QiZh0WBWQl6PjNmod9JxNvH2GMWAWlWQmXj
# EflUny3Il1cT369TST0BpPZA/VmbdZCZd51KguOMjstbOe4fCegYhcuIkxDM+oqp
# EgUvfDNysOtl5aC0B0E9uKmCVnkJCezoFqPkxvpr8RkL0bd9olgrlBUd4Tp4uhIT
# CnV3Pla6stc0+ynRVamWmX8UlvyOtFP+M6ge7zmpFx1imAHJT1bshY92u2GbJ+p4
# DDSiZVY3knFyiBhsujakA0keWwx1afEik3ljAdsYQ8K6iwEc+TZd334T+lk9BRHq
# /4Pzl4Q3kD9kz/GI+nFrx0lnzsGlO+6Lv/a5+VQwl/Zhz1ks+AR2FBCjQvAwNJMN
# PjzLexXs92j6Dmr4yqcnO03/qq3VyBRN7277KQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFJ7jb4Wul0XZq9tSGWTzoEtIfmR6MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQC+zis7eijxzM6vE+qedISRRWrvXxDOWsiLLv8RbsmZBewmgXEdZQXRTHQ8PIoU
# NFc8lW/b0XuSkmQEkmZxCDkdBXtuVRcgxZDWpfQp20VBcj8xEvvtn6krnHWNf61t
# GQDtrkW3u9a5GgASLTYekUfmb8CSH91+xvHzA6l5wlti+4e7LhobT+0bM5YULEww
# 2EYAgnip1Xzsmdj+4wGaKh2Wb4bPfntdZbm2Dceu01le5DS1ZS/bq53icYomj+gt
# kc/vmnhGm3t0x1gpQX0C5UUHDFhlim+CTXa18r7/I7Crzj9+NdUJ0zzdCdrC1t6d
# uT+Wdtz0qxmib4ae8DiK0AxSlJcVatxGSp1RAs34msbp88GhXz4PxTZDYXheSIJH
# oRT0nNgrBO68vq3ecW7GeQt02NtODb/K/aPdZoO4IrmVI+Cyd0iIfoGS7ZSLcDRp
# SjoP3P2/5cS4Gz2KhUlo6N//P5SuqDsRKfEbT9PV0pyLu8tDZc2BYVg7786UOO0a
# iZrWKNfibXg32qCtdO5YQbCALuGEGCneJ38sA5/0FJNYDmUGuKWwSh7FcGs6f/XA
# zeuMbSEizG8Xn9g4rvyZVEZjpjvNgn65e3g5M4UHBp0+/wySWt5Bks+dA+2LCini
# uUtRho8KIPhhSpE1sunxKDKj2DSIBxljOdO5z7xDxkiuDDCCB3EwggVZoAMCAQIC
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
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIICQQIBATCCAQGhgdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjJBMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQA6zJ/ZvquI8qedeUiA
# gvZ/nc9SwqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7YSNVjAiGA8yMDI2MDQxMTA5MDUyNloYDzIwMjYwNDEy
# MDkwNTI2WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDthI1WAgEAMAoCAQACAgaL
# AgH/MAcCAQACAhLdMAoCBQDthd7WAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBAELk3YykV2HWKbVPjCDQhJow++VAFvIaCLRekM9vPNwJa9v3fKxJ7gCqX1Yl
# Dn11yCAjzXIRPdShXh4miDONIvqQPnnH/35XdmAS/ZXCAvBbvZ0dOhP3nrskZ78q
# AH9R9Ql2VPFO/Ik2SqAM2jDwJS60qBr9IcfGXURIc9R4T+4Tg/vWlPtzpPk1plCJ
# Ky14t6ClNQDOMHoCX32Sx46lKg6eXIH2SUN0txVGF+h73r7oCUCBO8VE+iDDcRAD
# fYx4ulI+HglMvzLIvf5POTEy0ZYO9NdCeqIfIDSawLwoNaQH9j+1p/ZnYKNKpnPk
# SCR3yEbioN70h4iJV/BpvKYwbdExggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhCrzeQWGO85sAABAAACEDANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCApgIGrP5Byq0R9xRL1EXvSydiJvqTIwdwQVW7XKIXkuDCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIMPVIe5+yPNjn1LWIdRBj2GewpKsk+Dlr0xzhica
# Y8fGMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIQ
# q83kFhjvObAAAQAAAhAwIgQgcvivP4C45X3mhcmcwlihtjdZe6dLpwXoSQ9aasK6
# gwEwDQYJKoZIhvcNAQELBQAEggIAMi/OjSYLGl+wls8IMZ/WNMaRPM4Eov/sfpEz
# mB+enHc1134qAXa454xX/ACKEeSQ5D/ANV+dop3ddqWyB7TvyRKw+ll4U1zbJIeZ
# Aj9Y1slIQGMiFX+bngjJgprSL8m/4NepMJvSfC87HJzjRyI99fx6YLsb16D93m7+
# i1EyBzG70bRP7jU3Nhgdb0JH9MSvjxMmm2a3ynC5j9hKGZcsBa7bD5KXByxT/GCo
# wGp+WnrJNLEzfEnkgvGEC/hcki+GEz7dXh783LtWUaFsLlAJo5kwh23HJO88dIFT
# CKJrbQ1BbGFVg3rTKNGGclFu9XZHd26Sy6V1WufG6JecNGP2bKoz+nfR3EL2k7Ee
# 54D0xhDn5vf7/HM6XX3GlDH9al4NZGIYXhQ1EC//gNc7rD3BUykdqA0OHHBT2Hoe
# vYdZ2SeqfdEhXvz6lJnW5dqfQBOmRU/GqD6YSJhr8hPA3KelMW/WYQasuNaLTMpw
# gpnVVdUVqc4OOjIQl9hXNGyeKPKfWV/VbA41tLXA1Ciwcvfhl615fShqxJSWNM8B
# +we0tPLrH8UWXsIgc1RvawE5aUpBG3KAdU5pWtnWbHGwCt3Ipfd3oMaNDBqH74Ma
# xxG+YoMc3p5sCf0tuQpoMfnicjBm3krTg6rmCwbTKORgPl1wp+96G9llh+qJk34c
# UgNQWrc=
# SIG # End signature block
