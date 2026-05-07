function Get-HumanTime($Seconds) {
    if($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = 's'
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = 'ms'
    }
    return "$time$unit"
}

function GetFullPath ([string]$Path) {
    if (-not [System.IO.Path]::IsPathRooted($Path))
    {
        $Path = & $SafeCommands['Join-Path'] $ExecutionContext.SessionState.Path.CurrentFileSystemLocation $Path
    }

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Export-PesterResults
{
    param (
        $PesterState,
        [string] $Path,
        [string] $Format
    )

    switch ($Format)
    {
        'LegacyNUnitXml' { Export-NUnitReport -PesterState $PesterState -Path $Path -LegacyFormat }
        'NUnitXml'       { Export-NUnitReport -PesterState $PesterState -Path $Path }

        default
        {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}
function Export-NUnitReport {
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        $PesterState,

        [parameter(Mandatory=$true)]
        [String]$Path,

        [switch] $LegacyFormat
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path

    $Path = GetFullPath -Path $Path

    $settings = & $SafeCommands['New-Object'] -TypeName Xml.XmlWriterSettings -Property @{
        Indent = $true
        NewLineOnAttributes = $false
    }

    $xmlFile = $null
    $xmlWriter = $null
    try {
        $xmlFile = [IO.File]::Create($Path)
        $xmlWriter = [Xml.XmlWriter]::Create($xmlFile, $settings)

        Write-NUnitReport -XmlWriter $xmlWriter -PesterState $PesterState -LegacyFormat:$LegacyFormat

        $xmlWriter.Flush()
        $xmlFile.Flush()
    }
    finally
    {
        if ($null -ne $xmlWriter) {
            try { $xmlWriter.Close() } catch {}
        }
        if ($null -ne $xmlFile) {
            try { $xmlFile.Close() } catch {}
        }
    }
}

function Write-NUnitReport($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    Write-NUnitTestResultAttributes @PSBoundParameters
    Write-NUnitTestResultChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestResultAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('xmlns','xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi','noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    $XmlWriter.WriteAttributeString('name','Pester')
    $XmlWriter.WriteAttributeString('total', ($PesterState.TotalCount - $PesterState.SkippedCount))
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $PesterState.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', '0')
    $XmlWriter.WriteAttributeString('inconclusive', $PesterState.PendingCount + $PesterState.InconclusiveCount)
    $XmlWriter.WriteAttributeString('ignored', $PesterState.SkippedCount)
    $XmlWriter.WriteAttributeString('skipped', '0')
    $XmlWriter.WriteAttributeString('invalid', '0')
    $date = & $SafeCommands['Get-Date']
    $XmlWriter.WriteAttributeString('date', (& $SafeCommands['Get-Date'] -Date $date -Format 'yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', (& $SafeCommands['Get-Date'] -Date $date -Format 'HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    Write-NUnitEnvironmentInformation @PSBoundParameters
    Write-NUnitCultureInformation @PSBoundParameters

    $XmlWriter.WriteStartElement('test-suite')
    Write-NUnitGlobalTestSuiteAttributes @PSBoundParameters

    $XmlWriter.WriteStartElement('results')

    Write-NUnitDescribeElements @PSBoundParameters

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnitCultureInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitGlobalTestSuiteAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', 'Powershell')

    # TODO: This used to be writing $PesterState.Path, back when that was a single string (and existed.)
    #       Better would be to produce a test suite for each resolved file, rather than for the value
    #       of the path that was passed to Invoke-Pester.

    $XmlWriter.WriteAttributeString('name', 'Pester')
    $XmlWriter.WriteAttributeString('executed', 'True')

    $isSuccess = $PesterState.FailedCount -eq 0
    $result = Get-ParentResult $PesterState
    $XmlWriter.WriteAttributeString('result', $result)
    $XmlWriter.WriteAttributeString('success',[string]$isSuccess)
    $XmlWriter.WriteAttributeString('time',(Convert-TimeSpan $PesterState.Time))
    $XmlWriter.WriteAttributeString('asserts','0')
}

function Write-NUnitDescribeElements($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $Describes = $PesterState.TestResult | & $SafeCommands['Group-Object'] -Property Describe
    if ($null -ne $Describes)
    {
        foreach ($currentDescribe in $Describes)
        {
            $DescribeInfo = Get-TestSuiteInfo $currentDescribe

            #Write test suites
            $XmlWriter.WriteStartElement('test-suite')

            if ($LegacyFormat) { $suiteType = 'PowerShell' } else { $suiteType = 'TestFixture' }

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $DescribeInfo -TestSuiteType $suiteType -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

            $XmlWriter.WriteStartElement('results')

            Write-NUnitDescribeChildElements -TestResults $currentDescribe.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeInfo.Name

            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }
}

function Get-TestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo]$TestSuiteGroup)
{
    $suite = @{
        resultMessage = 'Failure'
        success = 'False'
        totalTime = '0.0'
        name = $TestSuiteGroup.Name
        description = $TestSuiteGroup.Name
    }

    #calculate the time first, I am converting the time into string in the TestCases
    $suite.totalTime = (Get-TestTime $TestSuiteGroup.Group)
    $suite.success = (Get-TestSuccess $TestSuiteGroup.Group)
    $suite.resultMessage = Get-GroupResult $TestSuiteGroup.Group
    $suite
}

function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests)
    {
        foreach ($test in $tests)
        {
            $totalTime += $test.time
        }
    }

    Convert-TimeSpan -TimeSpan $totalTime
}
function Convert-TimeSpan {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $TimeSpan
    )
    process {
        if ($TimeSpan) {
            [string][math]::round(([TimeSpan]$TimeSpan).totalseconds,4)
        }
        else
        {
            '0'
        }
    }
}
function Get-TestSuccess($tests) {
    $result = $true
    if ($tests)
    {
        foreach ($test in $tests) {
            if (-not $test.Passed) {
                $result = $false
                break
            }
        }
    }
    [String]$result
}
function Write-NUnitTestSuiteAttributes($TestSuiteInfo, [System.Xml.XmlWriter] $XmlWriter, [string] $TestSuiteType, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('result', $TestSuiteInfo.resultMessage)
    $XmlWriter.WriteAttributeString('success', $TestSuiteInfo.success)
    $XmlWriter.WriteAttributeString('time',$TestSuiteInfo.totalTime)
    $XmlWriter.WriteAttributeString('asserts','0')

    if (-not $LegacyFormat)
    {
        $XmlWriter.WriteAttributeString('description', $TestSuiteInfo.Description)
    }
}

function Write-NUnitDescribeChildElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName)
{
    $suites = $TestResults | & $SafeCommands['Group-Object'] -Property ParameterizedSuiteName

    foreach ($suite in $suites)
    {
        if ($suite.Name)
        {
            $suiteInfo = Get-TestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            if (-not $LegacyFormat)
            {
                $suiteInfo.Name = "$DescribeName.$($suiteInfo.Name)"
            }

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -TestSuiteType 'ParameterizedTest' -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

            $XmlWriter.WriteStartElement('results')
        }

        Write-NUnitTestCaseElements -TestResults $suite.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $suite.Name

        if ($suite.Name)
        {
            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }
}

function Write-NUnitTestCaseElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    foreach ($testResult in $TestResults)
    {
        $XmlWriter.WriteStartElement('test-case')

        Write-NUnitTestCaseAttributes -TestResult $testResult -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $ParameterizedSuiteName

        $XmlWriter.WriteEndElement()
    }
}

function Write-NUnitTestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    $testName = $TestResult.Name

    if (-not $LegacyFormat)
    {
        if ($testName -eq $ParameterizedSuiteName)
        {
            $paramString = ''
            if ($null -ne $TestResult.Parameters)
            {
                $params = @(
                    foreach ($value in $TestResult.Parameters.Values)
                    {
                        if ($null -eq $value)
                        {
                            'null'
                        }
                        elseif ($value -is [string])
                        {
                            '"{0}"' -f $value
                        }
                        else
                        {
                            #do not use .ToString() it uses the current culture settings
                            #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
                            [string]$value
                        }
                    }
                )

                $paramString = $params -join ','
            }

            $testName = "$testName($paramString)"
        }

        $testName = "$DescribeName.$testName"

        $XmlWriter.WriteAttributeString('description', $TestResult.Name)
    }

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

    switch ($TestResult.Result)
    {
        Passed
        {
            $XmlWriter.WriteAttributeString('result', 'Success')
            $XmlWriter.WriteAttributeString('executed', 'True')
            break
        }
        Skipped
        {
            $XmlWriter.WriteAttributeString('result', 'Ignored')
            $XmlWriter.WriteAttributeString('executed', 'False')
            break
        }

        Pending
        {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')
            break
        }
        Inconclusive
        {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')

            if ($TestResult.FailureMessage)
            {
                $XmlWriter.WriteStartElement('reason')
                $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
                $XmlWriter.WriteEndElement() # Close reason tag
            }

            break
        }
        Failed
        {
            $XmlWriter.WriteAttributeString('result', 'Failure')
            $XmlWriter.WriteAttributeString('executed', 'True')
            $XmlWriter.WriteStartElement('failure')
            $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
            $XmlWriter.WriteElementString('stack-trace', $TestResult.StackTrace)
            $XmlWriter.WriteEndElement() # Close failure tag
            break
        }
    }
}
function Get-RunTimeEnvironment() {
    # based on what we found during startup, use the appropriate cmdlet
    if ( $SafeCommands['Get-CimInstance'] -ne $null )
    {
        $osSystemInformation = (& $SafeCommands['Get-CimInstance'] Win32_OperatingSystem)
    }
    elseif ( $SafeCommands['Get-WmiObject'] -ne $null )
    {
        $osSystemInformation = (& $SafeCommands['Get-WmiObject'] Win32_OperatingSystem)
    }
    else
    {
        $osSystemInformation = @{
            Name = "Unknown"
            Version = "0.0.0.0"
            }
    }
    @{
        'nunit-version' = '2.5.8.0'
        'os-version' = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        cwd = (& $SafeCommands['Get-Location']).Path #run path
        'machine-name' = $env:ComputerName
        user = $env:Username
        'user-domain' = $env:userDomain
        'clr-version' = [string]$PSVersionTable.ClrVersion
    }
}

function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

function Get-ParentResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($inputObject.FailedCount  -gt 0) { return 'Failure' }
    if ($InputObject.SkippedCount -gt 0) { return 'Ignored' }
    if ($InputObject.PendingCount -gt 0) { return 'Inconclusive' }
    return 'Success'
}

function Get-GroupResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($InputObject | & $SafeCommands['Where-Object'] {$_.Result -eq 'Failed'}) { return 'Failure' }
    if ($InputObject | & $SafeCommands['Where-Object'] {$_.Result -eq 'Skipped'}) { return 'Ignored' }
    if ($InputObject | & $SafeCommands['Where-Object'] {$_.Result -eq 'Pending' -or $_.Result -eq 'Inconclusive'}) { return 'Inconclusive' }
    return 'Success'
}

# SIG # Begin signature block
# MIInRAYJKoZIhvcNAQcCoIInNTCCJzECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAuHDKWsUEKLtTX
# JcChkzSHEWRBgB95P6ikKjBN9SHVLKCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# 2c2EkjPE+faxA1/TPgA2uTT+GiIAxJhkJgVEWkOZ4VUwUAYKKwYBBAGCNwoDHDFC
# DEBFRTA4RkI3NkY4RDhCNkZBNUQ4OTFEMzk3Nzg0OTY3ODg2RDRCOUQ1NjhFRDE1
# Q0Y4QjQwRDc3QjM0NjVENjdEMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAefrs5VhHw+cEx3MWF4yt
# HS5s50i+PDdIxIPH+TTrDITsLzY4xHW3mxtLy5QFq75vFS/tTLbTfuH6gFXCT12W
# 3NuV+HV4EDa6yyoeGQL2c8NEFsU6IVj4OJvsDKj8i6IczK88i4Shv4Lrt/T3i+sb
# vlqAM/KMEvUV/zC0eJzmfEU5kM6RbC5eyV1wACzT86G/cBax0Fcy2mbapVZdqcyW
# Sf4f+arsrstu+6yoBROLMXYi/aWc9Zw9pHUNSbFuCdh2wJA4V4lHXe1xnblNvOWa
# UVl6v49D5tpTo2SMcJC8QDDE4MHKONi0VkSvMespUdq72TCVMbW9MB9nEl57PhOq
# NynqbkbCJ/CSjMnREaU0znmDtY/TEG20BxZRynEZh/QyGgiMXCm3RLXtNxkYMYd+
# ZRb1JecyV09GTBRieb6FGhs1f49Xhx39jjRnr7TV6b/GaIQCYhcvP8A9IKZWDQA+
# WyOWhkHk8KMIDTYQ9/al3rggBtp7HN309U7NthtC06u+oYIXkzCCF48GCisGAQQB
# gjcDAwExghd/MIIXewYJKoZIhvcNAQcCoIIXbDCCF2gCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIJJp+DNdz9zlH0ScJDLGeHp85AoWucrpPK0mPMq4
# 8QJ6AgZp19Duq3cYEjIwMjYwNDExMTA1MzE2LjYxWjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkEwMDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR6jCCByAwggUIoAMCAQICEzMAAAIruwBQ/007mqEAAQAAAisw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTk0MDExWhcNMjcwNTE3MTk0MDExWjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAl95oujg97MlKkJuEKoJKyj23LCv0
# Md32HLS/PlTNbjmN26KIuRscGrk4EH+iRRyE06MUu4I6ipSvDhS8y+lE5dI8RCub
# eg7jnICV3b7rYpqE5TktAt5MiE1wQF6I/4KeoUUfc+lkYqdSrZIpW93SVwo0Kk/T
# 9grro6/lc/K/mfow5dPY4v4nP+Bt+K95lcI7P/xp8fT7t9VfK1xYnDYgM8abm2sK
# W3fKan85Vk9r5xt5BfZejIkRG7yd1xy1MB0LIdLf060hcf7P8gqqSVmCeqApRu9L
# b7BR9GkT/MAeHD/whWtiC75NuotznCQZfqaiox00gcvZr8EzxA5Z83KNDbfEeqUj
# 012YAbLHB4aCnwtFkJjs2NpHl2wJkU3GTMl8+b/wCW5qCNMtOwWs77eTZF3XRvUx
# K0FsLbBciCqxJQ4Fnx3gqE7tcLtnIg93Su9s93GtoM6BA8U9o/QVyFCmok803UD0
# bADGjt3VNM2hsDDJcLUicg4deGBIGaFLub0vDLoDKnazY6Yci+ucioY6QFm4WJCB
# zv9LmY7vebT/M2TalyEYeLXX1hyTwE5/a/nMZMrodsdFS3X8dZZivV9zYx9DbYAL
# OSQf8DpZMrrncZhU31lckay9+4rKTmfGjwBYL8kenDU5BqZBaN+SUY3IjZmYlOKk
# /VLcvleYLnRZNY8CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBQ+Fo7kE1CW7W3d45r2
# ZLtBWdnlNjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAzvwirHIhDPJK9X6h+E5X
# 0+uhDaE48V8PNdKchKtD3a4C8H4E98ftYM+wkB7VHXr6jEOah8gy4ZuqU/ddQmJB
# jfuoPjFO3zGE6+nd0sYnicASKFpH0eIO0orRszClOOuShGHo33XaFIKLwv8XEaWg
# Czuad/wNuPAcoSYjLbQUDQ7bE/x2ghcERQlEW8v3/HNZJMvBfMZAlxc/vzLWeXdZ
# VhY8DiNoHmR1qvV4oQzoHnuZ0tpKKOVep/FxtttFE3r1X/qYJqSB+9Vyg1SGExhm
# SbOsj5Xydml6sNTBODUeqJDbGNz9TN9R+gzGEXyRjQTXqefeZFxod2MwN3AosoPo
# 5iefIf307454CKblBXzg6Q4xcdInNWKCwDcYQhd0YUvamDOyuNDRISrIWLmgJCBt
# lwSmIoN6/9P29LI74wcLOeQGKJzJtwPKnF/+pPVX3NJr/XbaJx7lhnwNm/qhNqqQ
# p4cxm3Qx6u4jkmRMNNZzbqQDH9XONZPSKE0Ns94sOsOGWaCzsoOEyjG6dZK6U+La
# 4qf8t9Ar+ZIcqggzaml0KQZDmDjfC4LaEN2plTl+4seY3a58f71MU1EooF761nS+
# 1JPJKZktM7aNk6Mu2k+aAcwk734/YifwTfxNb4RQZISQr2ez1b7DEp005pMdhWpd
# pVZM7bgCOOHw/7siyXWjEEswggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
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
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBMDAwLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUACaw/dMpB6aP9ABm+5ZsL7ArakTmggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO2ESWowIhgPMjAy
# NjA0MTEwNDE1MzhaGA8yMDI2MDQxMjA0MTUzOFowdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA7YRJagIBADAHAgEAAgJCODAHAgEAAgITJTAKAgUA7YWa6gIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBCwUAA4IBAQBpYuBSmAQmmmzkUF6yadJikHGABeQtiTjg
# NxJvugqEGLydskARQyZ+i4Ipq0hV3wnxMjAk3cxLC0nDbX5VdU8kDFp5YPqrVX8F
# b5zf5+BRH6Wk/u0m0XQBcZXDPTEmO5DQZnCJSQkK86xRX5pdeAkkGIkmKcohmSMm
# UdW8t3pJqjPjnxW0oDKl/BE8jyc6dISjDzW01JkHMiooB0U0oqsHq6O32fdok+3u
# 2S+KFFoJsxI2DyqJDpPrwerixQUFFff+SVKr47/R/4votSnMYd6MwwvFzWYQJvqG
# 5QSampSFuwLYz1gYHT7MQNLnCUn5Z8iIFunyeWXqnDoR5rcZgxSyMYIEDTCCBAkC
# AQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIruwBQ/007
# mqEAAQAAAiswDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG
# 9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQg/q1i/KwOeWd7Sn7CypyiJxZfvYTCmU8c
# NNmwqRGySdYwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCByDiP0P5BX7WAP
# jNjmPtQcd2owQ+v1gwLT09rxZL9uUjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAACK7sAUP9NO5qhAAEAAAIrMCIEIOT5VesKH2D1vlvN
# ruqHB5R6vydpWuz8m+XZU/gF3fCKMA0GCSqGSIb3DQEBCwUABIICADknNevTXF0z
# eek8rNkMtU3gN59Z+q264JOUh7+r5fsgckEbazjbwu2bjms6rMZuYOIbpbahfFPa
# nTWGqSBNCid3CRWT4OOyxQ25KFIGnR4x1Vg84IkiRkAC0TdG5+9FLTkbdXDayJ15
# POO7X7dP2b2NH89wPmAlroUEeKCpXeFZnPjLuCfkgGEsfHNa3Kmgz3NXWt2J1Ndh
# s3mUo4kBx+hvTBBUkbqYCRgX4+YrGSIZp0m70sWHBmOQFsHflfu2PjV1q3Mmvzl8
# P6zAAe+lFZFUuU8w7tbhrX8O+ZC/8lpMg96p+L0E3H5XKIxWjZ4PgVI185s3SQvD
# QMFaUeIqLSaA+ZN0jd5kRAJPQdtwk8Yjt8nTCF9M8NVZwPQgUu6G1gq/ELDlYjK6
# HNcwV8ZSinY1aRIDw8Ms9ccSgY8KlR/6zmLQqhZdJtT/WnYOYrkDVmrjPqj/3e1t
# /JQKo1j1EoMYuQkg34urI9IPRp630qN851tZdjoN59r/bPgYfJ6tPytDhWgb9H49
# 0mx3uxP+ZGxfbYXn20cSEdy7NUfM5OEs+vNnjbHRkmX3HV2C6MTC2V+SppnrRY++
# GaZAw51qVsXgmudR8tD3VDXeDc+kRwKPhm0XQq6SZG+D/4HY3AfZpFPQaySWgUzd
# h6aX+rJFeRo+PLOrzEMl4TJCsgecH0qx
# SIG # End signature block
