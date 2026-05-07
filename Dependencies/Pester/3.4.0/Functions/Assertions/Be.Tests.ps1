Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBe" {
        It "returns true if the 2 arguments are equal" {
            Test-PositiveAssertion (PesterBe 1 1)
        }
        It "returns true if the 2 arguments are equal and have different case" {
            Test-PositiveAssertion (PesterBe "A" "a")
        }

        It "returns false if the 2 arguments are not equal" {
            Test-NegativeAssertion (PesterBe 1 2)
        }
    }
    Describe "PesterBeFailureMessage" {
        #the correctness of difference index value and the arrow pointing to the correct place
        #are not tested here thoroughly, but the behaviour was visually checked and is
        #implicitly tested by using the whole output in the following tests


        It "Returns nothing for two identical strings" {
            #this situation should actually never happen, as the code is called
            #only when the objects are not equal

            $string = "string"
            PesterBeFailureMessage $string $string | Should BeNullOrEmpty
        }

        It "Outputs less verbose message for two different objects that are not strings" {
            PesterBeFailureMessage 2 1 | Should Be "Expected: {1}`nBut was:  {2}"
        }

        It "Outputs verbose message for two strings of different length" {
            PesterBeFailureMessage "actual" "expected" | Should Be "Expected string length 8 but was 6. Strings differ at index 0.`nExpected: {expected}`nBut was:  {actual}`n-----------^"
        }

        It "Outputs verbose message for two different strings of the same length" {
            PesterBeFailureMessage "x" "y" | Should Be "String lengths are both 1. Strings differ at index 0.`nExpected: {y}`nBut was:  {x}`n-----------^"
        }

        It "Replaces non-printable characters correctly" {
            PesterBeFailureMessage "`n`r`b`0`tx" "`n`r`b`0`ty" | Should Be "String lengths are both 6. Strings differ at index 5.`nExpected: {\n\r\b\0\ty}`nBut was:  {\n\r\b\0\tx}`n---------------------^"
        }

        It "The arrow points to the correct position when non-printable characters are replaced before the difference" {
            PesterBeFailureMessage "123`n456" "123`n789" | Should Be "String lengths are both 7. Strings differ at index 4.`nExpected: {123\n789}`nBut was:  {123\n456}`n----------------^"
        }

        It "The arrow points to the correct position when non-printable characters are replaced after the difference" {
            PesterBeFailureMessage "abcd`n123" "abc!`n123" | Should Be "String lengths are both 8. Strings differ at index 3.`nExpected: {abc!\n123}`nBut was:  {abcd\n123}`n--------------^"
        }
    }
}

InModuleScope Pester {
    Describe "BeExactly" {
        It "passes if letter case matches" {
            'a' | Should BeExactly 'a'
        }
        It "fails if letter case doesn't match" {
            'A' | Should Not BeExactly 'a'
        }
        It "passes for numbers" {
            1 | Should BeExactly 1
            2.15 | Should BeExactly 2.15
        }
    }

    Describe "PesterBeExactlyFailureMessage" {
        It "Writes verbose message for strings that differ by case" {
            PesterBeExactlyFailureMessage "a" "A" | Should Be "String lengths are both 1. Strings differ at index 0.`nExpected: {A}`nBut was:  {a}`n-----------^"
        }
    }
}


# SIG # Begin signature block
# MIInRQYJKoZIhvcNAQcCoIInNjCCJzICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAvxCss/+v0RPK+
# 1EmO5jVPSukuiJBHtKPVwTMnSqHFf6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GucwghrjAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# LcnGg9KPrFNotSJlf9GB0cw8vsdJvFj/bnf0Fkt6DmgwUAYKKwYBBAGCNwoDHDFC
# DEBFMEIzMjBEOTFCMUY1MkJGQzZCQzdFQjNGQ0YwQTlDNUE4NUYzNEFBRUNCNjU0
# RDg1NDFCRTcxNzJEMkQ4Q0I3MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAYHNMl6DyfS5cgdAeNCHb
# Gxu8LJ19BU/qpako+dD+/APgsUmFyRAa2pMzp6NR/VfTNn7IkxQbkCyBZKkotJQD
# 9bhVZQw0dmGHZL7LmgI0SaOjyAWogcIA7hB2CBKwWsrxP0aoDInkBNlQCQaOToKq
# d01nOVYSkaVP42itM5pm3PXYtq6dejZdogOVbChSZaOnbX7gH2AISPxjTfckFQDf
# udcdT69f88y3mfAmyEicEC8vTlXrcVfZjucQPeKvJJ4exmrSg3nxN3IpyKNyq4iQ
# Wrj7JAoicUq1BDLhhP2J1yo6OjTHLwxAxb5atHjIMYhlyBbSK9Cymm2s5ai6yj9n
# 1CKXPM3VscvqTkkiAslbhJNLa6hZf4eoaVVx+YD0gcAO+XkDbHc9JLSuHUDV4cMc
# yTTAMWfF7MuKYV913xdX57C3sxWi6tUfbZv4SHQIZVoab9UwdurR/rdEhou+/2UL
# CC+iSrKbvGUkq4dN27UIg/XMfHFD65UAREoLYXBje9U8oYIXlDCCF5AGCisGAQQB
# gjcDAwExgheAMIIXfAYJKoZIhvcNAQcCoIIXbTCCF2kCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIGzJsMuTYCBe+u6kFdujbIEHPKBT+XkmgpINeLPj
# aPAwAgZp19Duq4YYEzIwMjYwNDExMTA1MzE3LjYwMVowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpBMDAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAACK7sAUP9NO5qhAAEAAAIr
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5NDAxMVoXDTI3MDUxNzE5NDAxMVowgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBMDAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJfeaLo4PezJSpCbhCqCSso9tywr
# 9DHd9hy0vz5UzW45jduiiLkbHBq5OBB/okUchNOjFLuCOoqUrw4UvMvpROXSPEQr
# m3oO45yAld2+62KahOU5LQLeTIhNcEBeiP+CnqFFH3PpZGKnUq2SKVvd0lcKNCpP
# 0/YK66Ov5XPyv5n6MOXT2OL+Jz/gbfiveZXCOz/8afH0+7fVXytcWJw2IDPGm5tr
# Clt3ymp/OVZPa+cbeQX2XoyJERu8ndcctTAdCyHS39OtIXH+z/IKqklZgnqgKUbv
# S2+wUfRpE/zAHhw/8IVrYgu+TbqLc5wkGX6moqMdNIHL2a/BM8QOWfNyjQ23xHql
# I9NdmAGyxweGgp8LRZCY7NjaR5dsCZFNxkzJfPm/8AluagjTLTsFrO+3k2Rd10b1
# MStBbC2wXIgqsSUOBZ8d4KhO7XC7ZyIPd0rvbPdxraDOgQPFPaP0FchQpqJPNN1A
# 9GwAxo7d1TTNobAwyXC1InIOHXhgSBmhS7m9Lwy6Ayp2s2OmHIvrnIqGOkBZuFiQ
# gc7/S5mO73m0/zNk2pchGHi119Yck8BOf2v5zGTK6HbHRUt1/HWWYr1fc2MfQ22A
# CzkkH/A6WTK653GYVN9ZXJGsvfuKyk5nxo8AWC/JHpw1OQamQWjfklGNyI2ZmJTi
# pP1S3L5XmC50WTWPAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUPhaO5BNQlu1t3eOa
# 9mS7QVnZ5TYwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAM78IqxyIQzySvV+ofhO
# V9ProQ2hOPFfDzXSnISrQ92uAvB+BPfH7WDPsJAe1R16+oxDmofIMuGbqlP3XUJi
# QY37qD4xTt8xhOvp3dLGJ4nAEihaR9HiDtKK0bMwpTjrkoRh6N912hSCi8L/FxGl
# oAs7mnf8DbjwHKEmIy20FA0O2xP8doIXBEUJRFvL9/xzWSTLwXzGQJcXP78y1nl3
# WVYWPA4jaB5kdar1eKEM6B57mdLaSijlXqfxcbbbRRN69V/6mCakgfvVcoNUhhMY
# ZkmzrI+V8nZperDUwTg1HqiQ2xjc/UzfUfoMxhF8kY0E16nn3mRcaHdjMDdwKLKD
# 6OYnnyH99O+OeAim5QV84OkOMXHSJzVigsA3GEIXdGFL2pgzsrjQ0SEqyFi5oCQg
# bZcEpiKDev/T9vSyO+MHCznkBiicybcDypxf/qT1V9zSa/122ice5YZ8DZv6oTaq
# kKeHMZt0MeruI5JkTDTWc26kAx/VzjWT0ihNDbPeLDrDhlmgs7KDhMoxunWSulPi
# 2uKn/LfQK/mSHKoIM2ppdCkGQ5g43wuC2hDdqZU5fuLHmN2ufH+9TFNRKKBe+tZ0
# vtSTySmZLTO2jZOjLtpPmgHMJO9+P2In8E38TW+EUGSEkK9ns9W+wxKdNOaTHYVq
# XaVWTO24Ajjh8P+7Isl1oxBLMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
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
# M1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVAAmsP3TKQemj/QAZvuWbC+wK2pE5oIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDthElqMCIYDzIw
# MjYwNDExMDQxNTM4WhgPMjAyNjA0MTIwNDE1MzhaMHQwOgYKKwYBBAGEWQoEATEs
# MCowCgIFAO2ESWoCAQAwBwIBAAICQjgwBwIBAAICEyUwCgIFAO2FmuoCAQAwNgYK
# KwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQAC
# AwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAaWLgUpgEJpps5FBesmnSYpBxgAXkLYk4
# 4DcSb7oKhBi8nbJAEUMmfouCKatIVd8J8TIwJN3MSwtJw21+VXVPJAxaeWD6q1V/
# BW+c3+fgUR+lpP7tJtF0AXGVwz0xJjuQ0GZwiUkJCvOsUV+aXXgJJBiJJinKIZkj
# JlHVvLd6Saoz458VtKAypfwRPI8nOnSEow81tNSZBzIqKAdFNKKrB6ujt9n3aJPt
# 7tkvihRaCbMSNg8qiQ6T68Hq4sUFBRX3/klSq+O/0f+L6LUpzGHejMMLxc1mECb6
# huUEmpqUhbsC2M9YGB0+zEDS5wlJ+WfIiBbp8nll6pw6Eea3GYMUsjGCBA0wggQJ
# AgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACK7sAUP9N
# O5qhAAEAAAIrMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIDavjTZEBO4v/Io01f+V21nTyEQbPXqJ
# goXtirxBZY5XMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgcg4j9D+QV+1g
# D4zY5j7UHHdqMEPr9YMC09Pa8WS/blIwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAiu7AFD/TTuaoQABAAACKzAiBCDk+VXrCh9g9b5b
# za7qhweUer8naVrs/Jvl2VP4Bd3wijANBgkqhkiG9w0BAQsFAASCAgByy7fKPSFJ
# b66uq1tbVygCv214MZmrmuT1V61KbOCkrWYd3SUHJgAP9f9jfLMcvmvte0yoF+D1
# O2jOABruPQEGDBvoiBmVbP0bs7z0/Jks1r+3bmlbJmb1e6pkllN+ydGOJgxtPe50
# e/R21wiFk09k09H+7KAneadpmS9/uz7LGhyZkUzKruaCX7yu6alBTMcywb0u9RAH
# hMFVHfJGSiPsQyagRPdtcXlLTLV6zLp/ibY7qctEyBACuHY0eqwyZr9yVf0Q7yqo
# nXNPF3eg5pufnRQ0WsO/xqFC2/Saba6fldwqimoRCfiWs5TVeTnMjzJuUe3hxMa6
# CBRgWYvGDcHXEqRyseLv77lZm4/2zERnoKJ0+r7ihN6woRZUrhn/hYsf0RU/VD6l
# cLnwe/gS51qRy8xQ68ja68Nx7Djn5B0BZ5GKpFw+GOX8yiGOpcTdQ2aGt/fJuRS0
# iCvDHP6t923auTTuS7JJsVXsttAlK49Egnm8v9VYxMiFvgVxXl0ffqhSFQfg7/vI
# kKE2u//NqrbpqptntfD5JlE0Flu8tXvihmwrJhbUe/GLeJ7SIB2YK4aiyRjCvkF3
# Y/WwGsQHdtLivqtSH2zlzLLhIeGZfzmqXapvxgzp6xf7j32xatg1jtSezcmIjBtL
# dYFP9ckOl3DyNNYUI9iURTw6TmMk8iX+5A==
# SIG # End signature block
