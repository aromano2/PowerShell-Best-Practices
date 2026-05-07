Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write nunit test results (Legacy)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]::FromSeconds(2.5)
            $TestResults.AddTestResult("Failed testcase","Failed",$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'

            $description = $null
            if ($xmlTestResult.PSObject.Properties['description'])
            {
                $description = $xmlTestResult.description
            }

            $xmlTestResult.type    | Should Be "Powershell"
            $xmlTestResult.name    | Should Be "Mocked Describe"
            $description           | Should BeNullOrEmpty
            $xmlTestResult.result  | Should Be "Success"
            $xmlTestResult.success | Should Be "True"
            $xmlTestResult.time    | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]

            $description = $null
            if ($xmlTestSuite1.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite1.description
            }

            $xmlTestSuite1.name    | Should Be "Describe #1"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite1.result  | Should Be "Success"
            $xmlTestSuite1.success | Should Be "True"
            $xmlTestSuite1.time    | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $description = $null
            if ($xmlTestSuite2.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite2.description
            }

            $xmlTestSuite2.name    | Should Be "Describe #2"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite2.result  | Should Be "Failure"
            $xmlTestSuite2.success | Should Be "False"
            $xmlTestSuite2.time    | Should Be 2.0
        }

        it "should write parent results in tree correctly" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Failed')
            $TestResults.AddTestResult("Failed","Failed")
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Skipped')
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Pending')
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Passed')
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name     | Should Be "Failed"
            $xmlTestSuite1.result   | Should Be "Failure"
            $xmlTestSuite1.success  | Should Be "False"

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name     | Should Be "Skipped"
            $xmlTestSuite2.result   | Should Be "Ignored"
            $xmlTestSuite2.success  | Should Be "True"

            $xmlTestSuite3 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[2]
            $xmlTestSuite3.name     | Should Be "Pending"
            $xmlTestSuite3.result   | Should Be "Inconclusive"
            $xmlTestSuite3.success  | Should Be "True"

            $xmlTestSuite4 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[3]
            $xmlTestSuite4.name     | Should Be "Passed"
            $xmlTestSuite4.result   | Should Be "Success"
            $xmlTestSuite4.success  | Should Be "True"

        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (New Legacy)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{ Parameter = 'One' }
            )

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                @{ Parameter = 'Two' }

            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $description = $null
                if ($xmlTestSuite.PSObject.Properties['description'])
                {
                    $description = $xmlTestSuite.description
                }

                $xmlTestSuite.name    | Should Be 'Parameterized Testcase <A>'
                $description          | Should BeNullOrEmpty
                $xmlTestSuite.type    | Should Be 'ParameterizedTest'
                $xmlTestSuite.result  | Should Be 'Failure'
                $xmlTestSuite.success | Should Be 'False'
                $xmlTestSuite.time    | Should Be '2'

                foreach ($testCase in $xmlTestSuite.results.'test-case')
                {
                    $testCase.Name | Should Match '^Parameterized Testcase (One|<A>)$'
                    $testCase.time | Should Be 1
                }
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Write nunit test results (Newer format)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Mocked Describe.Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]25000000 #2.5 seconds
            $TestResults.AddTestResult("Failed testcase",'Failed',$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Mocked Describe.Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type            | Should Be "TestFixture"
            $xmlTestResult.name            | Should Be "Mocked Describe"
            $xmlTestResult.description     | Should Be "Mocked Describe"
            $xmlTestResult.result          | Should Be "Success"
            $xmlTestResult.success         | Should Be "True"
            $xmlTestResult.time            | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name        | Should Be "Describe #1"
            $xmlTestSuite1.description | Should Be "Describe #1"
            $xmlTestSuite1.result      | Should Be "Success"
            $xmlTestSuite1.success     | Should Be "True"
            $xmlTestSuite1.time        | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name        | Should Be "Describe #2"
            $xmlTestSuite2.description | Should Be "Describe #2"
            $xmlTestSuite2.result      | Should Be "Failure"
            $xmlTestSuite2.success     | Should Be "False"
            $xmlTestSuite2.time        | Should Be 2.0
        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (Newer format)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{Parameter = 'One'}
            )

            $parameters = New-Object System.Collections.Specialized.OrderedDictionary
            $parameters.Add('StringParameter', 'Two')
            $parameters.Add('NullParameter', $null)
            $parameters.Add('NumberParameter', -42.67)

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                $parameters
            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $xmlTestSuite.name        | Should Be 'Mocked Describe.Parameterized Testcase <A>'
                $xmlTestSuite.description | Should Be 'Parameterized Testcase <A>'
                $xmlTestSuite.type        | Should Be 'ParameterizedTest'
                $xmlTestSuite.result      | Should Be 'Failure'
                $xmlTestSuite.success     | Should Be 'False'
                $xmlTestSuite.time        | Should Be '2'

                $testCase1 = $xmlTestSuite.results.'test-case'[0]
                $testCase2 = $xmlTestSuite.results.'test-case'[1]

                $testCase1.Name | Should Be 'Mocked Describe.Parameterized Testcase One'
                $testCase1.Time | Should Be 1

                $testCase2.Name | Should Be 'Mocked Describe.Parameterized Testcase <A>("Two",null,-42.67)'
                $testCase2.Time | Should Be 1
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Get-TestTime" {
        function Using-Culture {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [ScriptBlock]$ScriptBlock,
                [System.Globalization.CultureInfo]$Culture='en-US'
            )

            $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
            }
        }

        It "output is culture agnostic" {
            #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
            #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

            #using the string formatter here to know how the string will be output to screen
            $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
            $Result | Should Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should Be 0.1235
        }
    }

    Describe "GetFullPath" {
        It "Resolves non existing path correctly" {
            pushd TestDrive:\
            $p = GetFullPath notexistingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            pushd TestDrive:\
            New-Item -ItemType File -Name existingfile.txt
            $p = GetFullPath existingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive existingfile.txt)
        }

        It "Resolves full path correctly" {
            GetFullPath C:\Windows\System32\notepad.exe | Should Be C:\Windows\System32\notepad.exe
        }
    }
}

# SIG # Begin signature block
# MIInRQYJKoZIhvcNAQcCoIInNjCCJzICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKD7WI8pBtccjL
# Ep1BJK+QbNkIDGYkDdkUBOY1i/oaFaCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# C0Ks46ZT58jpdBsRRqtdYH41Ska1tmmHIJ/c2UqMR8AwUAYKKwYBBAGCNwoDHDFC
# DEA4MDM4NjJEM0Y0NUYxRUQ0RDRDMTY1QkE2MDE3RTdEQkQwMEUxRkVDQTBFNTE1
# MkM5QTQ0RDk0RDY5RjU3RTNCMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAgipGB/iSAN2lqCW7LVrr
# 9RvLJw3MQY3pGChoo3t5BNWxkljuSPaVV1Oq7/9y7uoMAdM7LSLPMr79hxMO8cZy
# xr3hnlhRYWQhyoC5kAATKuR38Z/Qr9MUQZKANDKmbY1Yiy5uOCsbrgpbomSTZGof
# re8DxGtr2ChzEUXsThB1ggOudrNHIFlcY5uRvwBeUNm+1ROuEcP5GQQma1ZwyUMT
# 9pqmiAjSy+ldk150GK34T8sqTYjyCisAuBx+CppXQdESygG0laEQe4nbicxWlq8A
# VTLtdUYged+ntMzW7LtLUCvhAuv8aQJYTwUaCisgv8y/fk3AM/T9F9XjyisxUWwl
# 7ID8wdcV6pCqaUOyuMYHAw/1OhWVJhM7t0h9jbi5Sd+hV0pzn2N7j8oYKfCdmEsa
# TxI6aI7lusBB+lmX+9b8c0YMt94PHq4FhfSSX8zpgwv2Pv8b/N30B/Tuw/x8Hd9y
# cuIthumjfroT9dFltJLF0UVj8XvcHoUsYxMA+LLqO2oooYIXlDCCF5AGCisGAQQB
# gjcDAwExgheAMIIXfAYJKoZIhvcNAQcCoIIXbTCCF2kCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEeFPR9i9K3RQjeLpRA1PLNfhuz+I/xjrZ5IhqQ9
# BVgyAgZp1/KCTC0YEzIwMjYwNDExMTA1MzE2LjYwNVowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo4NjAzLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAACJYDHN8bNqndJAAEAAAIl
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5NDAwMVoXDTI3MDUxNzE5NDAwMVowgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo4NjAzLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKbxEg/R4sDjpVwI+i++aqwiU3qq
# SbPkiwdaZRTSd5Sqny4bFp16j5LBYELBDlqVkj8M12ld/KJktlHpdiClE8XN6kiX
# s4INvg20SyQkIhkORAw3Csf1jBTK7vUYaKCwsjF6V4e0De62hVN4eNLVvxSfA5FG
# 2ScqTKtQCtPpmkHauh0hyZwty/fHfDCBiU6zQUSDkSxWtlvss1z+d3RtcOn4dM5Z
# a6Lx6hNXAl4vFxU/zr2gXyWLlJTzVpra0Ynr8mx6OLP0kxbxIlcoFPYMJcw5SQKw
# aOic9lGp++gxIhBmC1o5PIAmWu+zLRNnvxesaqjKC1CKZCds4Avgo0tIK5blNkRA
# ZMcs5AkaCCBvePmAoLvvz5Eg8kD6f+GYcn/HipP8dNM+hV4wJy4EpatBdHX7+lhq
# 7cXB7S1YjIb4tbORGv9k08+6lwDZhyLeqfwdH1HC9CimpI0nCfZGLpqbwBDJ9VXL
# 8EHDS3qOmhE+PAq+5SN8LOlp7p247FC1DVcM308DbKX2wOSj/4BdX9I57x5rxChB
# y/ezcSuQb4unqGe/Do4w+JqfiCA2RG2C0HuujU6Kik5Rcmf1jkQ7clQBc1y4z2b7
# kzLVUS68bK2AAfe7GayVOdbdhut9rNrJIJJKdaSFo5nfeGBu5RB8fufY0UQBRz9w
# XN+YJBSKRaKycljLAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUsTjSqhdO4wdfcB9l
# S7WfyfHaH3cwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAAed9zbJTKgdlu+/JUoW
# 5eHkfHEci8hpH0lakh8hMmVz8qLTeO5H69yTOre2nl8Ufksvt4gVdEi6h7Ayy9Z4
# Wta5+utbgeGaELCSoCt8DULTGT4dpizY7jxhLExf2WBLWRNMhvdix+gV0Wkq6s9/
# adzZh3jAuD4WDCaTGR7ITcxQpWdrxJl5WkSOdLm5wVyTiys/ArY5EB/vQjbcYbI+
# GqAgpmmE1eFKxxMBCzIioHkbAMx1FXksrfs19ThibG8JiHdMVgT8aHTVDrIm9/0f
# GIRmnBb6hSTSCu4ehuDeyAhHmt+BSjyXfS9SdoNgxw8AKVoUwL9BsdlJpSFZdkbU
# 45wynSD29hA0sMSoVfaOWq6/NVJLC0e2bUpOV0KNEQP6R0LJtw/Fs9qXAmKBdzUG
# wj0KK2dN/SWPBv02Rn8lUjz8PratdfOHPgXe7SJUbPCdwZrFHEcb9e/idOumQ556
# mhhs0FsxZLYbWo/dePulV/T7ipHIConSy2NCOhU4kiZU9ZGPPk9HcOfpp1BUwEkM
# zqAOuPWtlMVWAK1OKOoZlIbO9ekaQXe9izITpkOZr+QZ2JR7mxp4jqUfro+JZZeC
# rG3uzLYTO/TIiNJW/54w5PZAxSJnpYJzuBW0CZel94i6z42aAW8z4hzVfnx7gj0Q
# vhlICJ1KlZbQZlMs0LTaavIuMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
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
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVAFNv5so48CMIF+WHPDkRcG5JbF4OoIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDthGsCMCIYDzIw
# MjYwNDExMDYzODU4WhgPMjAyNjA0MTIwNjM4NThaMHQwOgYKKwYBBAGEWQoEATEs
# MCowCgIFAO2EawICAQAwBwIBAAICHCAwBwIBAAICEuwwCgIFAO2FvIICAQAwNgYK
# KwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQAC
# AwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAVI82RrPPTuyIC2PAt/ne4278P9Kf7RIY
# y6kkkoXLhZjvbQqKNKqAOGBOVK+mC5scs2rGT6HaPwfzuYytFtNcyA6clB0XA4KI
# zHBsZ1s1pwsl2s4B0G+s/QUp8cPzjtJ10HThhhvt5cRtKmW+xnz84SXCh2Ugwg0g
# 5iE2eDfeJcadteQ9YfYLD9GieGN66mxwT1Drf/w4Qwm8c/KPct9gb/Kz4mwzT7nR
# 4AVKJsyEOHj7Kq+A/V3BhgHxil8gkKtntNbNgjjR1kt0les0clM0zlRPMpbckfTW
# 9ILGOb7F2SxdBK5wDqK/tWLMUuWtCGkkeQpc0GwfechyAUtDcVGXuDGCBA0wggQJ
# AgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACJYDHN8bN
# qndJAAEAAAIlMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIILAjz6HlafP8T2eSIxL4i1qVBrr/gzs
# wa8vxvBZRWXKMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVg3uiHo43fL3
# YKYCX+UXQJjCuNZZA/p0JTFqM9IcoRAwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAiWAxzfGzap3SQABAAACJTAiBCDib6EVr5h9ekKd
# MaUFp2jARhlDeqyDZPxd1kMl8kNjAzANBgkqhkiG9w0BAQsFAASCAgBYT6uaF4FT
# nMTSz3/RUO5c7X3b2y4Im71o7kFeo9tiPzPP49bZl3hHyIlab9qdPPlhMeIt9Ki5
# Na2us6w+DUZDEyK5ofOT4ay5jeNcplvyi0M6smbeeMdfOTd3e/+vKElgVOCieXzP
# HX5aEsIFWV0TkbxLRtm2YgqI4ymlDPBS680dsaOf93940GX26Edw1B50EMx9JHVD
# 4eluTGQvwVOrvTQPVohIlm9ge8bf5pLz98sbDIYkkyRTr1JnAbtQKw2CGCxGCMuu
# yIvKba+EIzz2vAzNZbCnjP1fzw0BJ4U2mJit0pk0LMMWPfvrH/gAPcEoFQ2qK2Q1
# oG9DzSd3SuGjfMcunBpdXcQxtpCUiUiE/pYC9Tba4Bvr7JgpaMjJ110/OFLhvwwj
# LpHgJ7DLyBITUJ9Iz8Gz67Nu0ZvN0IoiWlBhbJ7ZPSy9lniBUqwOSe6xBPrKc/u2
# TS01wEGDcqoOPWWVl/yAzr/g6oZspbZCPl+TPjt3hWD3RCY+yu2pyxFuhwKmnEzf
# z0ekKBsxh+J2jKEYDLlDHHj2OepE9Sr7MIldIDMFT9DqWODfL0qyEMIMJcljPhTK
# VgtzZuEB0Pe1mrpetVm4qPLyKAAhgXwr44FmVRbAhjv2F3tJktPSFZiwWqKFsJzy
# nZEPrH/a/7Puk7mM+INKO6SZ4NhttWda5w==
# SIG # End signature block
