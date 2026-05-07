Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "New-PesterState" {
        Context "TestNameFilter parameter is set" {
            $p = new-pesterstate -TestNameFilter "filter"

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should be "filter"
            }

        }
        Context "TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }
        }

        Context "ExcludeTagFilter parameter is set" {
            $p = new-pesterstate -ExcludeTagFilter "tag3", "tag"

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3", "tag")
            }
        }

        Context "TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -ExcludeTagFilter "tag3"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3")
            }
        }
        Context "TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -testnamefilter "filter"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

        }
    }

    Describe "Pester state object" {
        $p = New-PesterState

        Context "entering describe" {
            It "enters describe" {
                $p.EnterDescribe("describe")
                $p.CurrentDescribe | should be "Describe"
            }
            It "can enter describe only once" {
                { $p.EnterDescribe("describe") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "describe"
            }
        }
        Context "leaving describe" {
            It "leaves describe" {
                $p.LeaveDescribe()
                $p.CurrentDescribe | should benullOrEmpty
            }
            It "Reports scope correctly" {
                $p.Scope | should benullOrEmpty
            }
        }

        context "Entering It from Describe" {
            $p.EnterDescribe('Describe')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }

            It "Cannot enter Context from inside It" {
                { $p.EnterContext("Context") } | Should Throw
            }
        }

        context "Leaving It from Describe" {
            It "Leaves It to Describe" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Describe'
            }

            $p.LeaveDescribe()
        }

        Context "entering Context" {
            it "Cannot enter Context before Describe" {
                { $p.EnterContext("context") } | should throw
            }

            it "enters context from describe" {
                $p.EnterDescribe("Describe")
                $p.EnterContext("Context")
                $p.CurrentContext | should be "Context"
            }
            It "can enter context only once" {
                { $p.EnterContext("Context") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "Context"
            }
        }

        Context "leaving context" {
            it "cannot leave describe before leaving context" {
                { $p.LeaveDescribe() } | should throw
            }
            it "leaves context" {
                $p.LeaveContext()
                $p.CurrentContext | should BeNullOrEmpty
            }
            It "Returns from context to describe" {
                $p.Scope | should be "Describe"
            }

            $p.LeaveDescribe()
        }

        context "Entering It from Context" {
            $p.EnterDescribe('Describe')
            $p.EnterContext('Context')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }
        }

        context "Leaving It from Context" {
            It "Leaves It to Context" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Context'
            }

            $p.LeaveContext()
            $p.LeaveDescribe()
        }

        context "adding test result" {
            $p.EnterDescribe('Describe')

            it "adds passed test" {
                $p.AddTestResult("result","Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Passed"
                $result.time.ticks | should be 100
            }
            it "adds failed test" {
                try { throw 'message' } catch { $e = $_ }
                $p.AddTestResult("result","Failed", 100, "fail", "stack","suite name",@{param='eters'},$e)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $false
                $result.Result | Should be "Failed"
                $result.time.ticks | should be 100
                $result.FailureMessage | should be "fail"
                $result.StackTrace | should be "stack"
                $result.ParameterizedSuiteName | should be "suite name"
                $result.Parameters['param'] | should be 'eters'
                $result.ErrorRecord.Exception.Message | should be 'message'
            }

            it "adds skipped test" {
                $p.AddTestResult("result","Skipped", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Skipped"
                $result.time.ticks | should be 100
            }

            it "adds Pending test" {
                $p.AddTestResult("result","Pending", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Pending"
                $result.time.ticks | should be 100
            }

            it "can add test result before entering describe" {
                if ($p.CurrentContext) { $p.LeaveContext()}
                if ($p.CurrentDescribe) { $p.LeaveDescribe() }
                { $p.addTestResult(1,"Passed",1) } | should not throw
            }

            $p.LeaveContext()
            $p.LeaveDescribe()

        }

        Context "Path and TestNameFilter parameter is set" {
            $strict = New-PesterState -Strict

            It "Keeps Passed state" {
                $strict.AddTestResult("test","Passed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $true
                $result.Result | Should be "Passed"
            }

            It "Keeps Failed state" {
                $strict.AddTestResult("test","Failed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Pending state to Failed" {
                $strict.AddTestResult("test","Pending")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Skipped state to Failed" {
                $strict.AddTestResult("test","Skipped")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }
        }
    }
    Describe ConvertTo-FailureLines {
        $testPath = Join-Path $TestDrive test.ps1
        $escapedTestPath = [regex]::Escape($testPath)
        It 'produces correct message lines.' {
            try { throw 'message' } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should be 'RuntimeException: message'
            $r.Message.Count | Should be 1
        }
        It 'failed should produces correct message lines.' {
            try { 'One' | Should be 'Two' } catch { $e = $_ }
            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
            $r.Message[1] | Should be 'Expected: {Two}'
            $r.Message[2] | Should be 'But was:  {One}'
            $r.Message[3] | Should be '-----------^'
            $r.Message[4] | Should match "'One' | Should be 'Two'"
            $r.Message.Count | Should be 5
        }
        Context 'should fails in file' {
            Set-Content -Path $testPath -Value @'
                $script:IgnoreErrorPreference = 'SilentlyContinue'
                'One' | Should be 'Two'
'@

            try { & $testPath } catch { $e = $_ }
            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {


                $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
                $r.Message[1] | Should be 'Expected: {Two}'
                $r.Message[2] | Should be 'But was:  {One}'
                $r.Message[3] | Should be '-----------^'
                $r.Message[4] | Should be "2:                 'One' | Should be 'Two'"                $r.Message.Count | Should be 5
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 2"
                    $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                        Should be $true
                    $r.Trace.Count | Should be 2
                }
            }
            else
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at line: 2 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
        Context 'exception thrown in nested functions in file' {
            Set-Content -Path $testPath -Value @'
                function f1 {
                    throw 'f1 message'
                }
                function f2 {
                    f1
                }
                f2
'@

            try { & $testPath } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {
                $r.Message[0] | Should be 'RuntimeException: f1 message'
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at f1, $testPath`: line 2"
                    $r.Trace[1] | Should be "at f2, $testPath`: line 5"
                    $r.Trace[2] | Should be "at <ScriptBlock>, $testPath`: line 7"
                    $r.Trace[3] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                        Should be $true
                    $r.Trace.Count | Should be 4
                }
            }
            else
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at line: 2 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
        Context 'nested exceptions thrown in file' {
            Set-Content -Path $testPath -Value @'
                try
                {
                    throw New-Object System.ArgumentException(
                        'inner message',
                        'param_name'
                    )
                }
                catch
                {
                    throw New-Object System.FormatException(
                        'outer message',
                        $_.Exception
                    )
                }
'@

            try { & $testPath } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {
                $r.Message[0] | Should be 'ArgumentException: inner message'
                $r.Message[1] | Should be 'Parameter name: param_name'
                $r.Message[2] | Should be 'FormatException: outer message'
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace line.' {
                    $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 10"
                    $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$'
                    $r.Trace.Count | Should be 2
                }
            }
            else
            {
                It 'produces correct trace line.' {
                    $r.Trace[0] | Should be "at line: 10 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIInRAYJKoZIhvcNAQcCoIInNTCCJzECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCzVis637nmKLfu
# tBlmMuPbVllEbkewuwHWaKM6oNYSS6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GuYwghriAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# InRqHKo44foeQeopz1shBwFDUlKjffYxokul9o552kIwUAYKKwYBBAGCNwoDHDFC
# DEA5MUMzOEYzQjRCNUIyNDM1RDE5RjY0RUY3MjhDN0IwNUYzRjBFMzA4RTBERUE3
# ODY4MDI4NDgzODQ3OUNENEM0MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAhQ0RHHjwlzZJqZRcR4V5
# KS5+Y+nhK9tpzr8A8UxNsZOeTQeIiwFNIJMrXTlNJ9wtkM4W5K0tM2FwUQh6Kvc+
# 3g0aTOYo5smFXqO1o4H15O3YC2IgwlyBnUd3tToe3/cm8z4cqr15K5uPgaRUfFgk
# FppUiBUH543XAooa1MtwJ9NzZXobYkK4/LqgutUY+//Uc9gpYEqGDOWM2qQV3v/6
# RtfO/SNl96jifeOOb7ATw2rh0+V10Grc+3yjZ2FR+LdsyKKBfiMsaXTa3d77fiRa
# 1P4DhNdPCqVC013Zd8pfSg7R0J5SACgEmdbh6qvZWUKD0fqSOaq5+WSnKFsfqDgM
# whHQG9pGhq65C9IEqbXFYtrfr4jW7EDL/WrhnZD5TxPsAJI7k67F/ZLjMaqFFqRM
# 4b3EjCz80xcmKdsL0Okf0TaI9qhMAUvRQU8TzkiltIbMk2qhIbiBTDC+JQqZEeuE
# NMELbc36nG6sRn8oFbM5SXNHiBsTUmhkUVN3L3LkQrM9oYIXkzCCF48GCisGAQQB
# gjcDAwExghd/MIIXewYJKoZIhvcNAQcCoIIXbDCCF2gCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMCTbI4L3O65TtLT09XbE6cpSd+3eI0hZz/BRpfb
# ez+xAgZp1/KCTDcYEjIwMjYwNDExMTA1MzE3LjE0WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjg2MDMtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR6jCCByAwggUIoAMCAQICEzMAAAIlgMc3xs2qd0kAAQAAAiUw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTk0MDAxWhcNMjcwNTE3MTk0MDAxWjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjg2MDMtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApvESD9HiwOOlXAj6L75qrCJTeqpJ
# s+SLB1plFNJ3lKqfLhsWnXqPksFgQsEOWpWSPwzXaV38omS2Uel2IKUTxc3qSJez
# gg2+DbRLJCQiGQ5EDDcKx/WMFMru9RhooLCyMXpXh7QN7raFU3h40tW/FJ8DkUbZ
# JypMq1AK0+maQdq6HSHJnC3L98d8MIGJTrNBRIORLFa2W+yzXP53dG1w6fh0zllr
# ovHqE1cCXi8XFT/OvaBfJYuUlPNWmtrRievybHo4s/STFvEiVygU9gwlzDlJArBo
# 6Jz2Uan76DEiEGYLWjk8gCZa77MtE2e/F6xqqMoLUIpkJ2zgC+CjS0grluU2REBk
# xyzkCRoIIG94+YCgu+/PkSDyQPp/4Zhyf8eKk/x00z6FXjAnLgSlq0F0dfv6WGrt
# xcHtLViMhvi1s5Ea/2TTz7qXANmHIt6p/B0fUcL0KKakjScJ9kYumpvAEMn1Vcvw
# QcNLeo6aET48Cr7lI3ws6WnunbjsULUNVwzfTwNspfbA5KP/gF1f0jnvHmvEKEHL
# 97NxK5Bvi6eoZ78OjjD4mp+IIDZEbYLQe66NToqKTlFyZ/WORDtyVAFzXLjPZvuT
# MtVRLrxsrYAB97sZrJU51t2G632s2skgkkp1pIWjmd94YG7lEHx+59jRRAFHP3Bc
# 35gkFIpForJyWMsCAwEAAaOCAUkwggFFMB0GA1UdDgQWBBSxONKqF07jB19wH2VL
# tZ/J8dofdzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAB533NslMqB2W778lShbl
# 4eR8cRyLyGkfSVqSHyEyZXPyotN47kfr3JM6t7aeXxR+Sy+3iBV0SLqHsDLL1nha
# 1rn661uB4ZoQsJKgK3wNQtMZPh2mLNjuPGEsTF/ZYEtZE0yG92LH6BXRaSrqz39p
# 3NmHeMC4PhYMJpMZHshNzFClZ2vEmXlaRI50ubnBXJOLKz8CtjkQH+9CNtxhsj4a
# oCCmaYTV4UrHEwELMiKgeRsAzHUVeSyt+zX1OGJsbwmId0xWBPxodNUOsib3/R8Y
# hGacFvqFJNIK7h6G4N7ICEea34FKPJd9L1J2g2DHDwApWhTAv0Gx2UmlIVl2RtTj
# nDKdIPb2EDSwxKhV9o5arr81UksLR7ZtSk5XQo0RA/pHQsm3D8Wz2pcCYoF3NQbC
# PQorZ039JY8G/TZGfyVSPPw+tq1184c+Bd7tIlRs8J3BmsUcRxv17+J066ZDnnqa
# GGzQWzFkthtaj914+6VX9PuKkcgKidLLY0I6FTiSJlT1kY8+T0dw5+mnUFTASQzO
# oA649a2UxVYArU4o6hmUhs716RpBd72LMhOmQ5mv5BnYlHubGniOpR+uj4lll4Ks
# be7MthM79MiI0lb/njDk9kDFImelgnO4FbQJl6X3iLrPjZoBbzPiHNV+fHuCPRC+
# GUgInUqVltBmUyzQtNpq8i4wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
# AAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBB
# dXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YB
# f2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKD
# RLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus
# 9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTj
# kY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56
# KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39
# IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHo
# vwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJo
# LhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMh
# XV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREd
# cu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEA
# AaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqn
# Uv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnp
# cjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/o
# olxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNy
# b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+
# TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2Y
# urYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4
# U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJ
# w7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb
# 30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ
# /gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGO
# WhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFE
# fnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJ
# jXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rR
# nj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUz
# WLOhcGbyoYIDTTCCAjUCAQEwgfmhgdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo4NjAzLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAU2/myjjwIwgX5Yc8ORFwbklsXg6ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO2EawIwIhgPMjAy
# NjA0MTEwNjM4NThaGA8yMDI2MDQxMjA2Mzg1OFowdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA7YRrAgIBADAHAgEAAgIcIDAHAgEAAgIS7DAKAgUA7YW8ggIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBCwUAA4IBAQBUjzZGs89O7IgLY8C3+d7jbvw/0p/tEhjL
# qSSShcuFmO9tCoo0qoA4YE5Ur6YLmxyzasZPodo/B/O5jK0W01zIDpyUHRcDgojM
# cGxnWzWnCyXazgHQb6z9BSnxw/OO0nXQdOGGG+3lxG0qZb7GfPzhJcKHZSDCDSDm
# ITZ4N94lxp215D1h9gsP0aJ4Y3rqbHBPUOt//DhDCbxz8o9y32Bv8rPibDNPudHg
# BUomzIQ4ePsqr4D9XcGGAfGKXyCQq2e01s2CONHWS3SV6zRyUzTOVE8yltyR9Nb0
# gsY5vsXZLF0ErnAOor+1YsxS5a0IaSR5ClzQbB95yHIBS0NxUZe4MYIEDTCCBAkC
# AQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIlgMc3xs2q
# d0kAAQAAAiUwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG
# 9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgESBLjYa2Fl8AXSDNq7/Jj826YhIVExaK
# rWMW03Kf660wgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBWDe6Iejjd8vdg
# pgJf5RdAmMK41lkD+nQlMWoz0hyhEDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAACJYDHN8bNqndJAAEAAAIlMCIEIOJvoRWvmH16Qp0x
# pQWnaMBGGUN6rINk/F3WQyXyQ2MDMA0GCSqGSIb3DQEBCwUABIICAKMmJN2uHRQP
# H+8WTofnr6AY46Vm1Lb0jRSkUhFCgXVFRyFYDcNwA6gCF6DCVGePHeXOw6Dsyy8s
# 2LFSf1kYA5kZ08R6g81zpvSm0Z015PaE4ngqdDBK6MH1rGgxTag0lZH57FSRaZq4
# Tl0U1w1lZVEB3lRNAOuhpKBfwYY1/BX515eA59BbQOnWnJdvVriGNSkFQ5iDJl8a
# RIUamMOdnDj+Q7H7GsXniORob2rpoIdSgrFVYUnEOpfPHg6SKQX0MU1q1SWyAElJ
# h+WHQB3XiTA5OE5NQMjrP78i4UN3V7ezz5WwYPRc7eH3pcgAZwdUhwsjMRJjie/T
# kycW8bdJdZ3cTI1vC/459y1urmanEXlhWpp5HYqFj/WtWokwMxjomKikhD9x/Qsz
# gUBE+343qRtTpG4ZMsc9mx9dWnNp9zO1kQ0KP5xYP636n2mPcyccos0i8QrE5F5U
# C8mVdmomJCTWfjT67rAAGg/H2ZiOsM5/3+jCEQNa7P8CwVfRnuJJSHf8HUpdf/rX
# pQzntTkVerQ8raV9E21+jnGEC4T3GfqvZMquRgBIuxrbxcWPchB6a9r82OFKIo0C
# Hw+DIoNXAWb94iDJoiRm3VFMrpGNqkazJ/7nEL/yXmKPhqoAs4gmsrgUghvpaddQ
# tw22DP+OkOnu7pl39bQcxN4G5/Ed399Z
# SIG # End signature block
