Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Parse-ShouldArgs" {
        It "sanitizes assertions functions" {
            $parsedArgs = Parse-ShouldArgs TestFunction
            $parsedArgs.AssertionMethod | Should Be PesterTestFunction
        }

        It "works with strict mode when using 'switch' style tests" {
            Set-StrictMode -Version Latest
            { throw 'Test' } | Should Throw
        }

        Context "for positive assertions" {

            $parsedArgs = Parse-ShouldArgs testMethod, 1

            It "gets the expected value from the 2nd argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a positive assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $true
            }
        }

        Context "for negative assertions" {

            $parsedArgs = Parse-ShouldArgs Not, testMethod, 1

            It "gets the expected value from the third argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a negative assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $false
            }
        }

        Context "for the throw assertion" {

            $parsedArgs = Parse-ShouldArgs Throw

            It "translates the Throw assertion to PesterThrow" {
                $ParsedArgs.AssertionMethod | Should Be PesterThrow
            }

        }
    }

    Describe "Get-TestResult" {
        Context "for positive assertions" {
            function PesterTest { return $true }
            $shouldArgs = Parse-ShouldArgs Test

            It "returns false if the test returns true" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }

        Context "for negative assertions" {
            function PesterTest { return $false }
            $shouldArgs = Parse-ShouldArgs Not, Test

            It "returns false if the test returns false" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }
    }

    Describe "Get-FailureMessage" {
        Context "for positive assertions" {
            function PesterTestFailureMessage($v, $e) { return "slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Test, 1

            It "should return the postive assertion failure message" {
                Get-FailureMessage $shouldArgs 2 | Should Be "slime 1 2"
            }
        }

        Context "for negative assertions" {
            function NotPesterTestFailureMessage($v, $e) { return "not slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Not, Test, 1

            It "should return the negative assertion failure message" {
              Get-FailureMessage $shouldArgs 2 | Should Be "not slime 1 2"
            }
        }

    }

    Describe -Tag "Acceptance" "Should" {
        It "can use the Be assertion" {
            1 | Should Be 1
        }

        It "can use the Not Be assertion" {
            1 | Should Not Be 2
        }

        It "can use the BeNullOrEmpty assertion" {
            $null | Should BeNullOrEmpty
            @()   | Should BeNullOrEmpty
            ""    | Should BeNullOrEmpty
        }

        It "can use the Not BeNullOrEmpty assertion" {
            @("foo") | Should Not BeNullOrEmpty
            "foo"    | Should Not BeNullOrEmpty
            "   "    | Should Not BeNullOrEmpty
            @(1,2,3) | Should Not BeNullOrEmpty
            12345    | Should Not BeNullOrEmpty
            $item1 = New-Object PSObject -Property @{Id=1; Name="foo"}
            $item2 = New-Object PSObject -Property @{Id=2; Name="bar"}
            @($item1, $item2) | Should Not BeNullOrEmpty
        }

        It "can handle exception thrown assertions" {
            { foo } | Should Throw
        }

        It "can handle exception should not be thrown assertions" {
            { $foo = 1 } | Should Not Throw
        }

        It "can handle Exist assertion" {
            $TestDrive | Should Exist
        }

        It "can handle the Match assertion" {
            "abcd1234" | Should Match "d1"
        }

        It "can test for file contents" {
            Setup -File "test.foo" "expected text"
            "$TestDrive\test.foo" | Should Contain "expected text"
        }

        It "ensures all assertion functions provide failure messages" {
            $assertionFunctions = @("PesterBe", "PesterThrow", "PesterBeNullOrEmpty", "PesterExist",
                "PesterMatch", "PesterContain")
            $assertionFunctions | % {
                "function:$($_)FailureMessage" | Should Exist
                "function:Not$($_)FailureMessage" | Should Exist
            }
        }

        # TODO understand the purpose of this test, perhaps some better wording
        It "can process functions with empty output as input" {
            function ReturnNothing {}

            # TODO figure out why this is the case
            if ($PSVersionTable.PSVersion -eq "2.0") {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Not Throw
            } else {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Throw
            }
        }

    }
}

# SIG # Begin signature block
# MIInVAYJKoZIhvcNAQcCoIInRTCCJ0ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDeyEEHvAd2qbXv
# 0sMhs9VQZslkyLMVmq7f0pfYSsyQi6CCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
# KBkLiTVYAAAAAAE/MA0GCSqGSIb3DQEBCwUAMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMjAeFw0yNTExMTMxOTU5NDJaFw0y
# NjExMTAxOTU5NDJaMIGEMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyAzcmQgcGFydHkgQ29tcG9u
# ZW50MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA2Zy0BnZmL5lF9IDS
# IFBJ81NqCWCPLo2bRGJObUnrlezQw+FWEDU9+poMEyRjgbgafifNKY4TJ3e9Od4p
# q56xMXBcGYVIe546gz4p68MQG4iXqqSBB4kk5jwk5U7igTCfZIga6PFElV6Wm7kv
# Bdw14NVgdJZZDdmIc9TdaWbxrxAda9IMjZNQYfJZ/WVinf0mPnYM2hQwj4Gl4DGC
# 0/KO6U+ayXHAtcS9qj2UJYB7rCyteNydGWHaMa5B8fzOpSNS3ioJfYcBwSjfcBRD
# pemnEb5BcIF10FVuNA4foeMz5emIZaGGl8XxVC9K79Xwkc571Sv899qEdYP8ZFW9
# yVXY8l1ptvk4nD52nq9ld4HjWA+FHmhbhKggbjEVymQee7fOgEWKE3Uc73YnTMGf
# TXzDwH9jYip5fwls08LWs0HCINu/iA/OG/vm1jrJdK5wcBgX2B0fZPdwgLTEgs0R
# rSIyv9WucI0S6XffXJuUH+lziAX7RmCPhy5kZR1R3LB0GnBlAgMBAAGjggG3MIIB
# szATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUt3RSDxhJIhKufhwaOyWL
# 3nMDoeUwVAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5k
# IE9wZXJhdGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwODA5KzUwNjIzOTAfBgNV
# HSMEGDAWgBRhcaeHr/9p1SF2T1KTKAC+eRKrhDB0BgNVHR8EbTBrMGmgZ6BlhmNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBX
# aW5kb3dzJTIwVGhpcmQlMjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5j
# cmwwgYEGCCsGAQUFBwEBBHUwczBxBggrBgEFBQcwAoZlaHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhp
# cmQlMjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAk+iGdVNjQ2VMiNXhflILGybQmTUMM+qd
# BZ3KErdJ9wkVTN/fMukvmp9y1iF8Sz1NUqDNqiKLofcL0XukOu5W3zAofFlAs2tR
# vf0ArWKgRP5gjpqXeo3xWRM/1LBYTDhwDmylfh36AnfErB+aHyoIr9an+2KqeIqj
# 5VvFPgwJ1n6ZTXZMhjvYnIol/P+vwVroo2XKwbOL1/c79xRj7X8Lqw+7sVoIA9/P
# ytqdSDV1ClBjltkRpdgwvbSDPzycfvN8V5pPFfkrqrcIHjaL2pe76nqRsEIPqiVQ
# SmqiaJV6iprCSDGJYC4/4EMLIDZ4uf+m0XHW3Qzlr7RLlMdsJKny7jCCBeEwggPJ
# oAMCAQICCmELqsEAAAAAAAkwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEyMDQxODIzNDgzOFoXDTI3
# MDQxODIzNTgzOFowgY4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xODA2BgNVBAMTL01pY3Jvc29mdCBXaW5kb3dzIFRoaXJkIFBhcnR5IENvbXBv
# bmVudCBDQSAyMDEyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo5ww
# hAmnYy7PCkfw6iT5ozAgD15XMSaBmjEHslDUzmcJCGUKWqVLrtXtEC7npZm1n2gv
# mItYAqwgtCnEcb0oHKX9PJtk5MXr32ElvPDuaL/Rp8t+KgKBTmRcDFOGeVcZN2G3
# mPkMoE4iWZv5Gy1nPCc8VpBm4/1/ZX0Phr01R+iKzPTajulqTqunVeyiiR7VM0VT
# y/med73NLPkFuH90AR3o+xjhQ9EN6arcN2+9/rgP7R1NAUZOCqz8gujsVoMTjjoB
# 7RRkdOpksmYQtmhtyHAAfVBILj1D7uAklcbNjsf9uOSVz91++5VeoQHNQ7EH16Qw
# 7puGGipuwQtZonRviwIDAQABo4IBQzCCAT8wEAYJKwYBBAGCNxUBBAMCAQAwHQYD
# VR0OBBYEFGFxp4ev/2nVIXZPUpMoAL55EquEMBkGCSsGAQQBgjcUAgQMHgoAUwB1
# AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9j
# cmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8y
# MDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAt
# MDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQBaimfazNX9DSZBd78KRni0s94S
# aSt3I8JlLwFf0gP0YbpQnS6MOXLzbD5qsR52bey384LczLvFaXAoc2YXP1Tr7gEW
# SMRG2RuAroE6jQ95bWiwnuotPznTyjh+vV58CG4Z3MbC9DgzaGHiUkeD4QABVtK6
# y4eCBTEKQYtO539fX+1f0zktReuiE7/9HsKYQXFhFl/ICnAlfFlpMSTkcecKuwQX
# 959yHsnSuxq+PQL+CQyyQ7RZGplTk5YhX+DWtyYBQpU2rCf9vvSFd2g9GL30vpiI
# IhGGUhbzRewDlxBwh6NwQ3E828mGAxcM9XNbxn3hXGTt18VI1+0y4tGq08+n9ldO
# Yfl362fyiLPeANoDj9CKNDc+HdhiuNKx8+Evi3I7gZZ8b/zsZnZyYBsk8qCJbVtt
# AC7vKN2GhwXCtLnlvmTCKvJKFVyY4sQnhf9S42J+D7ICC9dmxwqy0z0gBBRQMlmD
# Cn2b7Vo4EgFSui9eIHKOSvH953ECjDvhB77Jc/TdR9i077SkszC5iT52yrkAmFZ+
# q+qKuKXQOKtpdxMLFC/pqkEf97q9Ois0iu4Kq2PmY/eIJI4gDSs7nePCSVKsnx8O
# OTtd1G5QauZ9UjqqfDMVKQ0mXgFYp06pPXqEb3Q/YJ/kMk82AK9tcdM+pkZlX4F0
# 8f7BcdpMoEFagt3xHzGCGucwghrjAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQg5vFDuRO/uxsktBYaiwPhW2RNIcyyYD5Fffe7IQS60UMw
# UAYKKwYBBAGCNwoDHDFCDEBDQjIxMzBFN0FFQzQ4N0RGOTVDN0U4N0NBNDVEMjA2
# M0U1QTFCQ0ZFRDlDMEE5Rjk0QjlGNjc5M0M3RjQyQjY4MFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# dE94FSc7AE1DX6rkXthBhZ+3bFGeYgvW+eAXSEaJtYsoUnbcjmogz6pjskUMW7EL
# m7xrRrAyEYfhkZIudVU4RFLkSkW048XeFKYy6DEHBpsCL47VrSEcafK8yZosnvWJ
# 9OGwh/VmpYuXFUly0lo2pAGmc9aj0E7j0MGCjkgD6unN2hGrd12UxQFm1ZP482uS
# nXoXSfcN2Gkw+K5bc9mLVJ+r2O+VKoV+uNKGHz9fbi1yVDbUuzxHA3FhhubuXwiL
# Vd7WriYb1iyaSytN+k45mCs1Z0yZ9irm1H+N/OkESmK6y5kifuq+Cr+k5sPq5Uix
# nvKFMHr+44llO44+/3j5igt7s1kgji0WxSBO9tNtM79+xgG792q8XT3cWk7HrYQ4
# VUcGj9AZSWjNse/YHBA0ZfAzbFsxTmiMs75VJxbsV4fuNmsfppkth8CgpdXZNd7B
# gBLb10kMo0e2bu6NIFwxMyTZBYwvV7kvJFDY0YPuzKzeYsAghwzBga3OBs43K8hF
# oYIXlDCCF5AGCisGAQQBgjcDAwExgheAMIIXfAYJKoZIhvcNAQcCoIIXbTCCF2kC
# AQMxDzANBglghkgBZQMEAgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEINjhweFuVLjCDa+YLeo2
# zlnu/91MVQaYtHJJKTfERYSjAgZp17FELj4YEzIwMjYwNDExMTA1MzE1LjY4Mlow
# BIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjpBOTM1LTAzRTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAAC
# J9XAg8OxLlctAAEAAAInMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5NDAwNFoXDTI3MDUxNzE5NDAwNFowgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpBOTM1LTAzRTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOLFbLV8
# M5IviqPcDWlp3L56UgMvCcXdS4vMkg5bAYdwSCvHHC2fK+JQgOabHKVNSXW77asE
# +nbNPgHDBCG8ZomkTGq88uUMWVt+ZJ+Uojzp4Wqh+JnuPw1NE7iXvAaD02Ob6a41
# q5NwVbap18iMoT3nQ6Sub0ycw4ZjL5+Js1h3FM9E+rVPgwtkreze90zIwQ6V1w5C
# RIqnEPr/UaTqA6YK7YqAjx/R7Hq9jGcoOX1bQ4tIRr/rLzaghuyb7VAGJ85DjvFY
# pMbUKa+0avzkvMDvn8wBxSZHDn+h/+oRPRQVXVa6UxwmsjoMBICw0I0H7pYuui24
# FkCP5UyWpuflExnpDghjsnBoCIheHtWPGufBQ5hkbxYQaF+sD3x2L7ssSf0Cq+8Q
# 7Ib5RByNWEIJswZeKAldICl7J5a6kKwPSOBAw0LF8HkEsENbGB1jd0kEQ+DF+SBM
# NAsGCC1W/Z3kJjEcqAgi0Hhsjl5JvmOQgbZai2cV61PSV6CnD8SjPB/f1qjq0Q1j
# bV5VYjNHD8aya/CNhAXq9WvE4PSkZWx+oYXyzdU95juEjZPEcUyo0DQgH9rY0tjs
# lPFgAoA//XUQlm3vFuoMsyAPVgN0YTMalCKObecA8IvYJ5s/+Oa73RpsnZbjbnKC
# UYdMj+cIGvBKl9EKDDOt8V6UloIozr7floV/AgMBAAGjggFJMIIBRTAdBgNVHQ4E
# FgQU0tbnw3gwZIbq53uNaqBP3ait9F4wHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIB
# ACqdy53g9ILW15vYfqdG7LuwOIorXcVcmKtUHhN/CN2jYxv5AviPvBn+Tgb0/QIA
# 0dkWsNBwrRUUNPKyti7xnQCFrXhpwNk+zIig+8AZFGFocS5/s1yRGOR9r/KWjUrI
# gjyNsv032wkCoE8vxXgU0GOWO/7UYcM7DXbutnPllJM+gA9vZIDS/nIOBylQx/GC
# U/Knpyc8+hClO0P04bHwPCbY/6jVM/EEjLojRP1Fq66WiBUK8rB+V94tNwoC+dIb
# WsKN6tJeZTUM1c6wAP9uytKOBtfmYBsPtdNEwX+9rABYRIVyf8GOOLPF5ZlvTRph
# KWQkDatW0WUwzjzVpVZd0Btc8/lHNSJZOWDId/8buULEdhYYhm4HXdPdojpjyYSC
# f+i7jRqIUmjyvT6LQ/kZ02d5a3GJHQIwpR+Sj7mz/vdzB7VZ+nwEpdrbvRyJxVBq
# wV/mxFXukWb5Xt81FfAK7tqdM6aBrvrM7v/a37M6WJu+mFP5Dpl34HapixKfjEFp
# j5jMemfJwtbly8nKE/EEJxvWhFh+FHMIANva60jYS0YKNzY/aKLgvJHhAxv+fxw7
# B4v0ipVMorPNWT7NknFXe+ungvK5BfDQ7fSVroFwd00AAAH1QLzfOzcb134CUh9k
# sz3u0xQ0paNsGkiKsXHotMMVdW1lB3uGrMtgHKNuMfS6MIIHcTCCBVmgAwIBAgIT
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
# je6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHLMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046QTkzNS0wM0UwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVACMfOq2E/A7QYNyQMwDrHniUiIwqoIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEL
# BQACBQDthCm6MCIYDzIwMjYwNDExMDIwMDI2WhgPMjAyNjA0MTIwMjAwMjZaMHQw
# OgYKKwYBBAGEWQoEATEsMCowCgIFAO2EKboCAQAwBwIBAAICFKAwBwIBAAICEw0w
# CgIFAO2FezoCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgC
# AQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEABM5EESlPxq8O
# lKamwp3MhfDOhJG5oNGPxu0AYdTIJlCJNQVkXo/CXbUjvN356dYkJKZ6jGLnGL/W
# ggv87e/etTtYxcayH9O3pQYw439GcjsGja0juinrnqp7gfoYRqjnj9Btwxvw6wTf
# BQKrYRplUsShCrMqP0HJoqsdECxU2/jR9ouFFKYJUMqugoRtHI0nJ1syGVlhIjCZ
# CPmwBLUOY/Z6GVIDfYxOD7cAbagCGXUQd0lfvxkMOSVBBlxuh2Z541JQD3AiamNf
# gmWhx7N1GM9Vk04QKxPKa7HapLDNo2VYH7ytppX4br0Z8YXYaD9p2+jbYpmq8q6i
# kP+1MMtrljGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwAhMzAAACJ9XAg8OxLlctAAEAAAInMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEICjxwNhVBRBa
# cQuwbgT5g3FUCvgTB9X0DIOs5w2fIV09MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB
# 5DCBvQQg5ecBGjWhUhw4skoOqUTRp2r+Nn1Nd2WddZFxcZOEEXIwgZgwgYCkfjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAifVwIPDsS5XLQABAAAC
# JzAiBCAWPv83ovVhwUCn6SYyp1N76VHOH9+Q43bOrnkdQChT+TANBgkqhkiG9w0B
# AQsFAASCAgCQmhtY2cOtjwfK0+OQan3nZhxMf3tOQjD1lBtAZjMPTkyxva/XFe9O
# Ete2L3wobTk5dc9dMIrz0qksZnS1NShGq5xFcT3U+aZIb2r+Hf36ZjHHHjFOHGBW
# TTMgPBojktIZZMTra2kHkAySx3Ag/V+LpBRcICsGIqcTaBaXoJN29atSURrHayxn
# 2LE2572vXs6ujKWAnMy5zed23J3HhS9oGLewbN31xV2T0SheIO7Lg21dwv8VVt/g
# pwA4XdI+hUpWOp2HPD2o13XHqw2XHrJtO9J6xrl3kqNnBylAqVDGi7gWPLfgFl++
# qEdKE8yZrTUruPdHqLK6g8swI4LPwrNwTnjpgnXHqIc2UIbxCYRKkazlBmkw+c+3
# xFFmaXK4rVKb6bSNSYOdunDbK+WZ4tWqwC6h85piX1NFX9QKL9HraLSp20vowAdb
# fIasekdV5wzrfP5rp9eVhdjrOTt+h0a9XffNPQdzQQOQWpq+uiSD3qZn09Wwa7z4
# rVZpRXPCgrLLxa/O/MeeipbKq+lPCH3DeovlPdjeIi85msdM5z04ia/iEvTeLYVa
# 7Dz332XseeETBMY07JkUHbN5/D9fBHn/C+GD/kZ9P5s7yO4jBq/vBbmERC+b8JZ5
# oCzl9+o8HDTEgC5hLHYDmdb2PEU8WofPy+GIMOHHwQyWHyCvzJhvTQ==
# SIG # End signature block
