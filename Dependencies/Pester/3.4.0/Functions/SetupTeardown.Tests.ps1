Describe 'Describe-Scoped Test Case setup' {
    BeforeEach {
        $testVariable = 'From BeforeEach'
    }

    $testVariable = 'Set in Describe'

    It 'Assigns the correct value in first test' {
        $testVariable | Should Be 'From BeforeEach'
        $testVariable = 'Set in It'
    }

    It 'Assigns the correct value in subsequent tests' {
        $testVariable | Should Be 'From BeforeEach'
    }
}

Describe 'Context-scoped Test Case setup' {
    $testVariable = 'Set in Describe'

    Context 'The context' {
        BeforeEach {
            $testVariable = 'From BeforeEach'
        }

        It 'Assigns the correct value inside the context' {
            $testVariable | Should Be 'From BeforeEach'
        }
    }

    It 'Reports the original value after the Context' {
        $testVariable | Should Be 'Set in Describe'
    }
}

Describe 'Multiple Test Case setup blocks' {
    $testVariable = 'Set in Describe'

    BeforeEach {
        $testVariable = 'Set in Describe BeforeEach'
    }

    Context 'The context' {
        It 'Executes Describe setup blocks first, then Context blocks in the order they were defined (even if they are defined after the It block.)' {
            $testVariable | Should Be 'Set in the second Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the first Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the second Context BeforeEach'
        }
    }

    It 'Continues to execute Describe setup blocks after the Context' {
        $testVariable | Should Be 'Set in Describe BeforeEach'
    }
}

Describe 'Describe-scoped Test Case teardown' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in AfterEach'
    }

    It 'Does not modify the variable before the first test' {
        $testVariable | Should Be 'Set in Describe'
    }

    It 'Modifies the variable after the first test' {
        $testVariable | Should Be 'Set in AfterEach'
    }
}

Describe 'Multiple Test Case teardown blocks' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in Describe AfterEach'
    }

    Context 'The context' {
        AfterEach {
            $testVariable = 'Set in the first Context AfterEach'
        }

        It 'Performs a test in Context' { "some output to prevent the It being marked as Pending and failing because of Strict mode"}

        It 'Executes Describe teardown blocks after Context teardown blocks' {
            $testVariable | Should Be 'Set in the second Describe AfterEach'
        }
    }

    AfterEach {
        $testVariable = 'Set in the second Describe AfterEach'
    }
}

$script:DescribeBeforeAllCounter = 0
$script:DescribeAfterAllCounter  = 0
$script:ContextBeforeAllCounter  = 0
$script:ContextAfterAllCounter   = 0

Describe 'Test Group Setup and Teardown' {
    It 'Executed the Describe BeforeAll regardless of definition order' {
        $script:DescribeBeforeAllCounter | Should Be 1
    }

    It 'Did not execute any other block yet' {
        $script:DescribeAfterAllCounter | Should Be 0
        $script:ContextBeforeAllCounter | Should Be 0
        $script:ContextAfterAllCounter  | Should Be 0
    }

    BeforeAll {
        $script:DescribeBeforeAllCounter++
    }

    AfterAll {
        $script:DescribeAfterAllCounter++
    }

    Context 'Context scoped setup and teardown' {
        BeforeAll {
            $script:ContextBeforeAllCounter++
        }

        AfterAll {
            $script:ContextAfterAllCounter++
        }

        It 'Executed the Context BeforeAll block' {
            $script:ContextBeforeAllCounter | Should Be 1
        }

        It 'Has not executed any other blocks yet' {
            $script:DescribeBeforeAllCounter | Should Be 1
            $script:DescribeAfterAllCounter  | Should Be 0
            $script:ContextAfterAllCounter   | Should Be 0
        }
    }

    It 'Executed the Context AfterAll block' {
        $script:ContextAfterAllCounter | Should Be 1
    }
}

Describe 'Finishing TestGroup Setup and Teardown tests' {
    It 'Executed each Describe and Context group block once' {
        $script:DescribeBeforeAllCounter | Should Be 1
        $script:DescribeAfterAllCounter  | Should Be 1
        $script:ContextBeforeAllCounter  | Should Be 1
        $script:ContextAfterAllCounter   | Should Be 1
    }
}


if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $thisTestScriptFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PSCommandPath)

    Describe 'Script Blocks and file association (testing automatic variables)' {
        BeforeEach {
            $commandPath = $PSCommandPath
        }

        $beforeEachBlock = InModuleScope Pester {
            $pester.BeforeEach[0].ScriptBlock
        }

        It 'Creates script block objects associated with the proper file' {
            $scriptBlockFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($beforeEachBlock.File)

            $scriptBlockFilePath | Should Be $thisTestScriptFilePath
        }

        It 'Has the correct automatic variable values inside the BeforeEach block' {
            $commandPath | Should Be $PSCommandPath
        }
    }
}

#Testing if failing setup or teardown will fail 'It' is done in the TestsRunningInCleanRunspace.Tests.ps1 file

# SIG # Begin signature block
# MIInSAYJKoZIhvcNAQcCoIInOTCCJzUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAuMr2lGMekvHLf
# +pJ03VWUau1QIy87P40nhLpns6ETnKCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GuowghrmAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# t/ThmHMA36xthBAcvt1/04eG3bCXqC+or9whkYtTR58wUAYKKwYBBAGCNwoDHDFC
# DEA0MjdCQkJCMEUzQkQzNUYwMjgxNjRFRjdDNEI0REY3NUJBNzM1REU4M0NGQzg2
# Mzg2MEU4NkRBRDk1RDI0ODA4MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAdlt5tnX3dRurtIrL0nxm
# DG9zn7E6MrSZjRGhlvZ6YOmTeLHTKQzj/fW5/k5KGOQhkDhzM3mexm+PNR/ALT9V
# lzTcUGqhE2Uru6x0FRXkf5UomYINRYK9/DFhAeJRagqMEZbroR00ThA4yYyZINSi
# KuF5gW7jVLbw67LonF/UV8cRjL1IekBFbP6QUqk/utlwHNjBHbLEfBx1VaqVZExi
# IIqWwtfmvrfVdplnpHuoeHDbBGLlrw5qHspyQc/AJqpk8khLzXUHoTULLXNROQwa
# rGoaXl7HouSYSZkS0pekopdBLEgyqzfIxCAsAmCHVmOtTGv7nfNBiwY/ZW3JcVCG
# Pjiaxs5jyazIGP1ByOZetoD6InHY2kEdNXLzLg5m/7fFdXcsS2ik+OezScbEggE+
# hVAY5xNR//QYtcmeV02R8ySq9StZjcktR9mJ86/WBC7tujjqB/y+Ws6thnThGTNu
# enVBsMw/WgpNuGM/+VT3yaZZvLZtGK/JPmIn6+/aVdLFoYIXlzCCF5MGCisGAQQB
# gjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIH8WISckT7HIIUb4vX5Nm1q5B7JSoYfz6EBg5MlA
# ANA2AgZp2GVPzK0YEzIwMjYwNDExMTA1MzE2LjI3OVowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpGMDAyLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAACICTh5uAXubSOAAEAAAIg
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5Mzk1MloXDTI3MDUxNzE5Mzk1MlowgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpGMDAyLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANFhjvKvuKNboJHXvy4q94gy5+61
# Y6JzGAnAo5x7/YY5Bx66zplZ9fXiLeM2Dck4/swYkyQ4C5zBYHCIDxRGn5liQaOl
# WhWQZmxXbtaOovCl/YDCoGwn9POrATskUVrG6nct3GPwaN0nKYMVGt1U3+lgegEW
# uMPUiQgO7xvUJafy2CiaIpFJj5JO8mr32ZWR2mEwEhQY56BCfLypF3bhUwTTGLw6
# iaSz1mr0SMN4ocam8BtdQRDqbdxE6gQ+FMT+aLB5Af1Oom3cg6yo+/cvy6uiMHvj
# tcELbLQIMgeUotwuXdkbwPslcqdZMV6feaww8mly+tDfNQFUmsf+YjdHEeYKH2mk
# M/S4bX48nCTof/H6x+gb2FbrjGheSnHoMR81k19xd0ptcXbxcRd0s2fOjdIs1XKZ
# 5AmE2o5IqGdTzhCcqauMSTnjUmK6uUMKQJY72VQFQxv3HSfJ9dRs1E9UuA/49MxF
# 1c6jAl1gLMJB83ZmovSzhgjbwXUNufsGDDYTg/UT26ey8zMke3OFLZOHdOkJ8Fs4
# ZqUiUX3H8Mln+yyb/LLNP1i0gV6qZ83EE9MTdo66HofGZMgLN9gABO9Y2EFujX1D
# CyM94D0m+GpMsLYpQ2CteugbLh4NmjSfuMViNmRSKHVPL7wTqoS9XY1rpnmBTIPl
# r60cYOarr0KZSId/AgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU28ic4IiHEYDyZjuX
# WDTtQe/I2DMwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAK0oYG2jUFK+bhYUj4nQ
# 1LJWFTUscvsXd9uNnZ3sXkqf8UJMFlenOsNWXrcUtE1wgWmcnLj+eWDjevtPmwk9
# 2jgyzwANIdAQmcdK7fH1SmMLNEQE+L36ceG8OBHH/VaYEPqBBRkks6Fw3ZPFbgon
# KGKcy2IEW2Q1Fna+ZnUwB01dObl3QvCTfDOP79/tUIJNYJclKio1rdVT/qwAIcj3
# sS9ufODxt3eHGt/PoJwJW5/vt6C9EeKe2Em7BJF48/tpWZx69vWdZQgAgJ0F5sdA
# 6vM0h5YEhDC9wVpLdIVz7j2uqvBA4wUNHgVgHNLtvRB4FXEW4svaJW7goAcw1SEs
# tIPiIosMUE1M61PNOWEa8yAbvsDVyN5CsMwdrqhF4wN5QOodSvG/yDshF0iH6HSA
# MuTM3TEi7OWLQG/sm3JsYltXonFoMXgLNIIgxGkrn2cjqIqjguCdtAFklbv7pqRi
# wob+lc+V/E2/YiekPXS1IKQK/D2SvpbX41E34S5lzNGADBaVwr1clne67+/+jEe0
# 7v+SZUiznUX2pXpjZA1d3q1Tjpg+sr3ybZAPKz6W8s2KYrR7XFntnUZrAqiEoa+U
# sAtYOVlCqAd8nfUIHQuUgMjuIvJhOl3aLIqOqyRtCLIy0gIf5GYf+gKDsk4rRkDd
# cgxtr1pJaAEXdBnqkbcQZ5CqMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
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
# M1izoXBm8qGCA1AwggI4AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RjAwMi0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVAJMYD2+mwnqCWoIuYjSuCAbHhgQSoIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDthDUiMCIYDzIw
# MjYwNDExMDI0OTA2WhgPMjAyNjA0MTIwMjQ5MDZaMHcwPQYKKwYBBAGEWQoEATEv
# MC0wCgIFAO2ENSICAQAwCgIBAAICNPECAf8wBwIBAAICExQwCgIFAO2FhqICAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAU+4HUtcAxxm6H4anVJWt/TvEIxR2
# fISw+sfdFKT7LrqwTLNJtVnBcxdKg8mqQfhK/tCnFoj66tekKA3bI2c2hMxPrJYg
# VIz59XxdGaBPTjFnP/A5BO0LqjUMgn0BFL/Ai9Be0xdP3qEPQFoqaabnCHo3Mw9l
# NnjWIUpo/v/4Ww/qRpVBWsfPY9T+Es2pFngttjtb0NwyetH+PgroZyUxoVDOL1le
# e1KuP66xlrARZ/rmlafOQ1+YvC5zh4wuE/8o4tbDEm3WUzyhzYWY1U9LZN3jb8qE
# NGL7ICslTllyLjsPmdCo+WqrpGoVVfQ/zm95vmhAYesxF3Ir4DfzEblQxjGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACICTh
# 5uAXubSOAAEAAAIgMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIIaxQodP86NjD7xMxWPLOaYxpp54
# YUSKbm1Y7Ei9jslmMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg43u/I6U8
# DVWqUSnRAhUaU13xLlhYGcqP3su5NYdI7a8wgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiAk4ebgF7m0jgABAAACIDAiBCCFniG0iwPl
# nuJcYJK44UDarAkJRnBB9nghOcB/He5U1zANBgkqhkiG9w0BAQsFAASCAgCDi1ZL
# w1GzCEvEAH6jvmRWl1T134U3Aq6pFJkV4P2f3vJTgR+vRDL5BWNt0mAdURZUEIoT
# 1vgXN7i0OiZZhEWCGOvGpGnEgfbhAwDk7CInCiqtscGufpd2yhfE966loY8PXZrH
# QqLOtSf/0fpj517JD2M8vURAbck9A0pBnL12MDpqKGggupNbM3jyt21gg/zHYbj+
# 8welkR7SKj2MfoV5sVd8e6x7RHcCxoyG5ee5/mh4UWmMqpONoE1MJgEEr8y8+M6X
# QurvpfHZZh9QYycyyib4lu/LYp9l9MvJo4fC1QKYksRtOcQUw8wTj0U4ExYZ2elH
# vprs6V0XWpG0WTYyx6jdqq6GqdatOLhKC5CGrhjozboE4DXNdAeTO5qC+SxrzLJD
# dOI5Cmg2OjwsNOhxPe1mZs0yXPNwokVR1gTj/qrBM2DDSOm1frU6VEpIEHrc+jWA
# DydzZpi22zeK6IutCNPGtheR3rN3kbkeWoaUcYIb88Vrp6gZX2ohyutvU6tR5wO9
# aOIaAauRcjnWXjLqMUzpe2tXpshP03+ry5Cl2DJh20sCq0kMvKseWyIxvGvjrzoU
# 0IL3eH77SRwUBMTTtVfyJ2GnVdZMBCgixyBX2AU9eUXdx62iUg/v2SVAuOHKz8Nq
# W8+PKQeu8D3fztCJvkWQKmebOopM6sy/+/5ytw==
# SIG # End signature block
