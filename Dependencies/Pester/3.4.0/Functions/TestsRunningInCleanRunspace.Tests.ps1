function Invoke-PesterInJob ($ScriptBlock, [switch] $GenerateNUnitReport)
{
    $PesterPath = Get-Module Pester | Select-Object -First 1 -ExpandProperty Path

    $job = Start-Job {
        param ($PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport)
        Import-Module $PesterPath -Force | Out-Null
        $ScriptBlock | Set-Content $TestDrive\Temp.Tests.ps1 | Out-Null

        $params = @{
            PassThru = $true
            Path = $TestDrive
        }

        if ($GenerateNUnitReport)
        {
            $params['OutputFile'] = "$TestDrive\Temp.Tests.xml"
            $params['OutputFormat'] = 'NUnitXml'
        }

        Invoke-Pester @params

    } -ArgumentList  $PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport
    $job | Wait-Job | Out-Null

    #not using Recieve-Job to ignore any output to Host
    #TODO: how should this handle errors?
    #$job.Error | foreach { throw $_.Exception  }
    $job.Output
    $job.ChildJobs| foreach {
        $childJob = $_
        #$childJob.Error | foreach { throw $_.Exception }
        $childJob.Output
    }
    $job | Remove-Job
}

Describe "Tests running in clean runspace" {
    It "It - Skip and Pending tests" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It - Skip and Pending tests' {

                It "Skip without ScriptBlock" -skip
                It "Skip with empty ScriptBlock" -skip {}
                It "Skip with not empty ScriptBlock" -Skip {"something"}

                It "Implicit pending" {}
                It "Pending without ScriptBlock" -Pending
                It "Pending with empty ScriptBlock" -Pending {}
                It "Pending with not empty ScriptBlock" -Pending {"something"}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.SkippedCount | Should Be 3
        $result.PendingCount | Should Be 4
        $result.TotalCount | Should Be 7
    }

    It "It - It without ScriptBlock fails" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It without ScriptBlock fails' {
               It "Fails whole describe"
               It "is not run" { "but it would pass if it was run" }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should Be 0
        $result.FailedCount | Should Be 1

        $result.TotalCount | Should Be 1
    }

    It "Invoke-Pester - PassThru output" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'PassThru output' {
               it "Passes" { "pass" }
               it "fails" { throw }
               it "Skipped" -Skip {}
               it "Pending" -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should Be 1
        $result.FailedCount | Should Be 1
        $result.SkippedCount | Should Be 1
        $result.PendingCount | Should Be 1

        $result.TotalCount | Should Be 4
    }

    It 'Produces valid NUnit output when syntax errors occur in test scripts' {
        $invalidScript = '
            Describe "Something" {
                It "Works" {
                    $true | Should Be $true
                }
            # Deliberately missing closing brace to trigger syntax error
        '

        $result = Invoke-PesterInJob -ScriptBlock $invalidScript -GenerateNUnitReport

        $result.FailedCount | Should Be 1
        $result.TotalCount | Should Be 1
        'TestDrive:\Temp.Tests.xml' | Should Exist

        $xml = [xml](Get-Content TestDrive:\Temp.Tests.xml)

        $xml.'test-results'.'test-suite'.results.'test-suite'.name | Should Not BeNullOrEmpty
    }
}

Describe 'Guarantee It fail on setup or teardown fail (running in clean runspace)' {
    #these tests are kinda tricky. We need to ensure few things:
    #1) failing BeforeEach will fail the test. This is easy, just put the BeforeEach in the same try catch as the invocation
    #   of It code.
    #2) failing AfterEach will fail the test. To do that we might put the AfterEach to the same try as the It code, BUT we also
    #   want to guarantee that the AfterEach will run even if the test in It will fail. For this reason the AfterEach must be triggered in
    #   a finally block. And there we are not protected by the catch clause. So we need another try in the the finally to catch teardown block
    #   error. If we fail to do that the state won't be correctly cleaned up and we can get strange errors like: "You are still in It block", when
    #   running next test. For the same reason I am putting the "ensure all tests run" tests here. otherwise you get false positives because you cannot determine
    #   if the suite failed because of the whole suite failed or just a single test failed.

    It 'It fails if BeforeEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                BeforeEach {
                    throw [System.InvalidOperationException] 'test exception'
                }

                It 'It fails if BeforeEach fails' {
                    $true
                }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }

    It 'It fails if AfterEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                It 'It fails if AfterEach fails' {
                    $true
                }

                 AfterEach {
                    throw [System.InvalidOperationException] 'test exception'
                }
            }

            Describe 'Make sure all the tests in the suite run' {
                #when the previous test fails in after each and
                It 'It is pending' -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        if ($result.PendingCount -ne 1)
        {
            throw "The test suite in separate runspace did not run to completion, it was likely terminated by an uncaught exception thrown in AfterEach."
        }

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDMXLR+Va7Sa4M8
# P5trYXi9LZnt+EF1eUV4EH3pEK60iqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# 8lI1aVvrGg9VlCVa7YFdaJoLCGcQzFAi7Ma44/Sqsy8wUAYKKwYBBAGCNwoDHDFC
# DEA4RTdGNTc0MUE0MjZGNkNBRjYwOTk0NTU0QURCRUI2QzRENTMxMUI2NEVEOEU3
# RUEwMDc1MkMwMUZDMTczOEIzMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAV4nvS6K7gRq0vSkcP6Ar
# 3SYi1xNHSbjCSl4HXVrfqoHHLhfFnHPnEm+K0HBnPaB/U28I4sGUWkUVCrRVPYCk
# 8WDr3NY9xrUcNVJEInIuDAwsA7RGGkmtkcyzr7xwTzXBkg5m0Wrj2vp25ibWVRWp
# jb6QBTtcLJ4p7zzLG2xhQBwMqO69HcfX65ryTIwDTiFNFA9k4t1Ci+NY7j2XG1HI
# 37puTqxb9VFVq8eslizFVAKPd44M5z7L7RT+1rIMOSYlri8XX8Q7aDn+fDmYZJgv
# wKvLyIYbxrDoGosbQVzaDm8p7oVBfwCvk20y15ptK2BSV9aD4F5W55bqGkNmwAf6
# nRwTKuguprb/evDvynR90jmna322j1bZpNUhFaL73koQ3CEes7bDRw/to8uj2tiY
# LK0uQ+xdla7E9xlutfKVzHp9NpbIM+9qdhQaTgnJTHtGhxv0IrT8bvtGa3MRFz+C
# WDNpSi43XHaBp9v3A2fDk5AIBmreIvXwc2SJ4aJTC7fQoYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIF1wLmp7toy2y4nyZoJ8fjRc9xrG25aV/TDrkJGj
# cdvbAgZpvNZheHQYEzIwMjYwNDExMTA1MzE2LjEzNVowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjU1MUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIb0LK4Amf3
# cs8AAQAAAhswDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODMwWhcNMjYxMTEzMTg0ODMwWjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NTUxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCOxZ3n
# ZlmTMHld7mD+XYaw6MDPfSyDqNXF8UlX7DjEgNXJojcs7xsimbNi6XcBkeDnRQhD
# w+tJFkalCoWRE276jdgoniDa4ZgFGSwecdhHS5VIJCDnxOGRjJ6mUZfegC8ZFW48
# ilC0CJOxHvoD+B2hTscPARtvvdsnBPKtsoeFH5ZozL0NAcjiTlCjj5tkOzSSPvpu
# +Em90ZT5LzPFAGntQCGMmcWorEi6xIhMTvMIJHjbYQuGSFVU4WorbDqHUwC8gt7v
# qHFEhw+PRIEvavw723HmeNTj62DasB1TXnembKGprN2lRxxgET3ANEVR3970KhbH
# tN2dSJwH4xqLtFPqqx7t7loapfUHtueP9ke+ut8X4EkQiVL2INcBSB6S9dn4VmaO
# 8vA/5037T9yuH76vh7wWScXsRfogl+eY14M3/rxnn2RtonV/4/macph/J0J5mbGs
# alLS1paQOTfoPeM9Vl+W/Gtz7WuEIiUzm/1qAsQUjXZCIFN+k4E4GvcAYI+T54fT
# 6Vq2NBqO6D7b8EPXapvzbnTQtDK1RZPai1r8didGBK/WO9nT92aXUWzFZjM6cKuN
# 90H/s3qk3JK3i+f48Y3p0UuKbuTGiz4H1Z9A97MmLd+4rLIMAH3NIc+PVm7ydl95
# xkn26bjOPsMWC8ldMNOcbmqUbhl1sVFr+ut/OQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFLa+n3f+XEumk0rw6Rq4nYC82YhQMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQBmRTVfFAPg5MzcZOG3fZNdKEh88Ggx9KwWwFCoU5mosk7HIk6WUgEWmam860Y0
# +QLlnyV0bxoKm+AU2j+MNZ5PkWJbnd0CP0qdnGmxDc9/l9HNIYdFzEQw51chXMMn
# BxlRfRyN/GdrvJ02/x5cH9eTobpLKtHY4fpLUscxbXWbdS8oX54uMg+XjmvGKa4M
# KgR35p3SU4BcDn+9k4o3mf949h4/QtFyFlfRDofyf9mZI8yVuWLcw7znVDT1GZP9
# kYdr78V3L5YsOvBxjKRX2ZTL/hNvArDoW11Hpk8fEx0iLWmTxjaYL8bMKrQsKwfS
# 5MV5DpDs1zcxGYRH/eYtZSFtpYeBfUVthyG9HbZv4G6n5g9HlD/QGFpoA3oAgF9w
# az67+cmggHLJkoDxxPIKadQj/i9boPi/LCDdcEV/h/YPAUfL96+wL7nwoyX6TbBr
# TlfaQrRP9sI8uFqi/1lfKhtrB804tgaJq4pPYVa9vBnMcgUJPGMHDDo+3m5G8IT+
# OdRx//GGU4YyfqIo71e3j29lMTZJ8gGT/fiItNEEnoftoY9NNCfNrc59a7X91HJw
# LpaXmiezc+OcZdNIpLFeWUk+aDpH+6Uaic/9QJignqY34ReN/IMs9cuqyv3X5VMb
# WtjNEKM/AEUAe/gQjBoTRqMKt/vl5QYjf6hdTRQ/quWhnzCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjU1MUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCGhXqvj0zgYF3jUrVF
# gHVnR/jO4KCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7YRUIzAiGA8yMDI2MDQxMTA1MDEyM1oYDzIwMjYwNDEy
# MDUwMTIzWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDthFQjAgEAMAcCAQACAiBg
# MAcCAQACAhKvMAoCBQDthaWjAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# AE9TGLQYYAPg4puHyVFn38aF5YBJBjikq+g6/8+5+U3xrrfwMy4sw38u6UT0TPQp
# I8elQ20GAYzOFMigM5CFm8dN1YuqgrZy/H55MSthcbM67VTYGfccpnGhIBtbevXD
# ha1ZQ31d7EJRbVuXjs3UCLZm66eKrczjiXlTLO8ViwzAc/ilfD/P5BsmyL9wnH7K
# NakLsm5s2EHwlnQ9z3QaUFTz1LHlu2gFgyWou2bjcTDIl0ecdlduT7aUMotpKYTb
# 5WSn7xqcNp1W9aF6Inote+EK1miG27WTYVs7O6Dk8sbQEQhYyWKzRYGg7hKMbaCd
# wybdl6aTZ9l72lQoiBUCNkExggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAhvQsrgCZ/dyzwABAAACGzANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCD/mOGbh/pqK4DPpKrxfN3HEzYxSvXAF4si9CwMziJfQTCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIDAlFJW4PaOYxxAIVd0u4kDAOlRU1nptzp18lTzdDYuA
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIb0LK4
# Amf3cs8AAQAAAhswIgQgeVZ7M3gQpYeayifzaGz2+BeNDyUQESI1r1CWW8tdPVgw
# DQYJKoZIhvcNAQELBQAEggIAJILDo9s2H6RUBaCD0ewG3H9z4idLR3Ey7d4zrt2v
# tCsLnDoXS50j3VWtDFVj/f4/kQen5ug3alLXnuHrIvX5g4vZY/5OfUwqszPIsGqw
# 0HDMq3R4jdmaz1bST9J62MGJScU60/2DLzNWJSdlewf6cTvfXf2E7cmMYI++xxTO
# kKII5MUTTuceUB8GJl5HFp2Hfr9aIz0Zlp4QGd/2SwcJqAPo7z2YkTA29jZp4cnW
# OeLBjEPJtF5raeAMr6aejMugs40iUa5wyIEr5dWoWqA6C8gkEVkCX3j2prGPOHmB
# +Y+KBYvUyE09j7W43VeJHXpL4+coL7UXTBzhpftN+QVRGh2/Jh8SiCsbrNXuO4ZL
# KvlC1TOhsyi2+HMq60t4TgvyJY8/0ncbwDBhD+rpcNrPKfjqyL9qfgIooZnR9+dD
# ZhoSg6y2HQ6duFJNtOPATTL7gCPjL3i+i2XaqXPkWyvy3Rw6xZsw9m2cwqGCK5nv
# SBKbR+A7Teo48kcXCVSvrN7AhkuPWDT8f/5c+YB0sElWMkigU/7QtxhyUTWY6eqZ
# h6KidbyMpfysuQ7ztquD7d6FKCX3pasorwlPcfoTrS44BdYAl0zMx4AKQ7n4n+xk
# 9CUVm/9ojIQhPoJWpXQZ+JDdbLpgVfAtnIL7n0lnSupSrJFpRUtc/a0rXT6R2vbr
# nMY=
# SIG # End signature block
