Set-StrictMode -Version Latest

function FunctionUnderTest
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $param1
    )

    return "I am a real world test"
}

function FunctionUnderTestWithoutParams([string]$param1) {
    return "I am a real world test with no params"
}

filter FilterUnderTest { $_ }

function CommonParamFunction (
    [string] ${Uncommon},
    [switch]
    ${Verbose},
    [switch]
    ${Debug},
    [System.Management.Automation.ActionPreference]
    ${ErrorAction},
    [System.Management.Automation.ActionPreference]
    ${WarningAction},
    [System.String]
    ${ErrorVariable},
    [System.String]
    ${WarningVariable},
    [System.String]
    ${OutVariable},
    [System.Int32]
    ${OutBuffer} ){
    return "Please strip me of my common parameters. They are far too common."
}

function PipelineInputFunction {
    param(
        [Parameter(ValueFromPipeline=$True)]
        [int]$PipeInt1,
        [Parameter(ValueFromPipeline=$True)]
        [int[]]$PipeInt2,
        [Parameter(ValueFromPipeline=$True)]
        [string]$PipeStr,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [int]$PipeIntProp,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [int[]]$PipeArrayProp,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$PipeStringProp
    )
    begin{
        $p = 0
    }
    process {
        foreach($i in $input)
        {
            $p += 1
            write-output @{
                index=$p;
                val=$i;
                PipeInt1=$PipeInt1;
                PipeInt2=$PipeInt2;
                PipeStr=$PipeStr;
                PipeIntProp=$PipeIntProp;
                PipeArrayProp=$PipeArrayProp;
                PipeStringProp=$PipeStringProp;
            }
        }
    }
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest { return "I am the mock test that was passed $param1"}

    $result = FunctionUnderTest "boundArg"

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed | Should Be $true
    }

    It "Should Invoke the mocked script" {
        $result | Should Be "I am the mock test that was passed boundArg"
    }
}

Describe "When the caller mocks a command Pester uses internally" {
    Mock Write-Host { }

    Context "Context run when Write-Host is mocked" {
        It "does not make extra calls to the mocked command" {
            Write-Host 'Some String'
            Assert-MockCalled 'Write-Host' -Exactly 1
        }

        It "retains the correct mock count after the first test completes" {
            Assert-MockCalled 'Write-Host' -Exactly 1
        }
    }
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Get-Process"
    }

    It 'Should not resolve $args to the parent scope' {
        { $args = 'From', 'Parent', 'Scope'; Get-Process SomeName } | Should Not Throw
    }
}

Describe 'When calling Mock on an alias' {
    $originalPath = $env:path

    try
    {
        # Our TeamCity server has a dir.exe on the system path, and PowerShell v2 apparently finds that instead of the PowerShell alias first.
        # This annoying bit of code makes sure our test works as intended even when this is the case.

        $dirExe = Get-Command dir -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $dirExe)
        {
            foreach ($app in $dirExe)
            {
                $parent = (Split-Path $app.Path -Parent).TrimEnd('\')
                $pattern = "^$([regex]::Escape($parent))\\?"

                $env:path = $env:path -split ';' -notmatch $pattern -join ';'
            }
        }

        Mock dir {return 'I am not dir'}

        $result = dir

        It 'Should Invoke the mocked script' {
            $result | Should Be 'I am not dir'
        }
    }
    finally
    {
        $env:path = $originalPath
    }
}

Describe 'When calling Mock on an alias that refers to a function Pester can''t see' {
    It 'Mocks the aliased command successfully' {
        # This function is defined in a non-global scope; code inside the Pester module can't see it directly.
        function orig {'orig'}
        New-Alias 'ali' orig

        ali | Should Be 'orig'

        { mock ali {'mck'} } | Should Not Throw

        ali | Should Be 'mck'
    }
}

Describe 'When calling Mock on a filter' {
    Mock FilterUnderTest {return 'I am not FilterUnderTest'}

    $result = 'Yes I am' | FilterUnderTest

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not FilterUnderTest'
    }
}

Describe 'When calling Mock on an external script' {
    $ps1File = New-Item 'TestDrive:\tempExternalScript.ps1' -ItemType File -Force
    $ps1File | Set-Content -Value "'I am tempExternalScript.ps1'"

    Mock 'TestDrive:\tempExternalScript.ps1' {return 'I am not tempExternalScript.ps1'}

    <#
        # Invoking the script using its absolute path is not supported

        $result = TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using the command-invocation operator (&)' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }
    #>

    Push-Location TestDrive:\

    try
    {
        $result = tempExternalScript.ps1
        It 'Should Invoke the mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & tempExternalScript.ps1
        It 'Should Invoke the mocked script using the command-invocation operator' {
            #the command invocation operator is (&). Moved this to comment because it breaks the contionuous builds.
            #there is issue for this on GH

            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . tempExternalScript.ps1
        It 'Should Invoke the mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        <#
            # Invoking the script using only its relative path is not supported

            $result = .\tempExternalScript.ps1
            It 'Should Invoke the relative-path-qualified mocked script' {
                $result | Should Be 'I am not tempExternalScript.ps1'
            }
        #>

    }
    finally
    {
        Pop-Location
    }

    Remove-Item $ps1File -Force -ErrorAction SilentlyContinue
}

Describe 'When calling Mock on an application command' {
    Mock schtasks.exe {return 'I am not schtasks.exe'}

    $result = schtasks.exe

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not schtasks.exe'
    }
}

Describe "When calling Mock in the Describe block" {
    Mock Out-File {return "I am not Out-File"}

    It "Should mock Out-File successfully" {
        $outfile = "test" | Out-File "TestDrive:\testfile.txt"
        $outfile | Should Be "I am not Out-File"
    }
}

Describe "When calling Mock on existing cmdlet to handle pipelined input" {
    Mock Get-ChildItem {
        if($_ -eq 'a'){
            return "AA"
        }
        if($_ -eq 'b'){
            return "BB"
        }
    }

    $result = ''
    "a", "b" | Get-ChildItem | % { $result += $_ }

    It "Should process the pipeline in the mocked script" {
        $result | Should Be "AABB"
    }
}

Describe "When calling Mock on existing cmdlet with Common params" {
    Mock CommonParamFunction

    $result=[string](Get-Content function:\CommonParamFunction)

    It "Should strip verbose" {
        $result.contains("`${Verbose}") | Should Be $false
    }
    It "Should strip Debug" {
        $result.contains("`${Debug}") | Should Be $false
    }
    It "Should strip ErrorAction" {
        $result.contains("`${ErrorAction}") | Should Be $false
    }
    It "Should strip WarningAction" {
        $result.contains("`${WarningAction}") | Should Be $false
    }
    It "Should strip ErrorVariable" {
        $result.contains("`${ErrorVariable}") | Should Be $false
    }
    It "Should strip WarningVariable" {
        $result.contains("`${WarningVariable}") | Should Be $false
    }
    It "Should strip OutVariable" {
        $result.contains("`${OutVariable}") | Should Be $false
    }
    It "Should strip OutBuffer" {
        $result.contains("`${OutBuffer}") | Should Be $false
    }
    It "Should not strip an Uncommon param" {
        $result.contains("`${Uncommon}") | Should Be $true
    }
}

Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message | Should Be "Could not find command NotFunctionUnderTest"
    }
}

Describe 'When calling Mock, StrictMode is enabled, and variables are used in the ParameterFilter' {
    Set-StrictMode -Version Latest

    $result = $null
    $testValue = 'test'

    try
    {
        Mock FunctionUnderTest { 'I am the mock' } -ParameterFilter { $param1 -eq $testValue }
    }
    catch
    {
        $result = $_
    }

    It 'Does not throw an error when testing the parameter filter' {
        $result | Should Be $null
    }

    It 'Calls the mock properly' {
        FunctionUnderTest $testValue | Should Be 'I am the mock'
    }

    It 'Properly asserts the mock was called when there is a variable in the parameter filter' {
        Assert-MockCalled FunctionUnderTest -Exactly 1 -ParameterFilter { $param1 -eq $testValue }
    }
}

Describe "When calling Mock on existing function without matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test"
    }
}

Describe "When calling Mock on existing function with matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe "When calling Mock on existing function without matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "test" -and $args[0] -eq 'notArg0'}

    $result=FunctionUnderTestWithoutParams -param1 "test" "arg0"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test with no params"
    }
}

Describe "When calling Mock on existing function with matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "badTest" -and $args[0] -eq 'arg0'}

    $result=FunctionUnderTestWithoutParams "badTest" "arg0"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe 'When calling Mock on a function that has no parameters' {
    function Test-Function { }
    Mock Test-Function { return $args.Count }

    It 'Sends the $args variable properly with 2+ elements' {
        Test-Function 1 2 3 4 5 | Should Be 5
    }

    It 'Sends the $args variable properly with 1 element' {
        Test-Function 1 | Should Be 1
    }

    It 'Sends the $args variable properly with 0 elements' {
        Test-Function | Should Be 0
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Set-Item {return "I am not Set-Item"}
    Mock Set-Item {return "I am not Set-Item"}

    $result = Set-Item "mypath" -value "value"

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Set-Item"
    }
}

Describe "When calling Mock on More than one command" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    Mock FunctionUnderTest {return "I am the mock test"}

    $result = Invoke-Command {return "yes I am"}
    $result2 = FunctionUnderTest

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am not Invoke-Command"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the mock test"
    }
}

Describe 'When calling Mock on a module-internal function.' {
    New-Module -Name TestModule {
        function InternalFunction { 'I am the internal function' }
        function PublicFunction   { InternalFunction }
        function PublicFunctionThatCallsExternalCommand { Start-Sleep 0 }

        function FuncThatOverwritesExecutionContext {
            param ($ExecutionContext)

            InternalFunction
        }

        Export-ModuleMember -Function PublicFunction, PublicFunctionThatCallsExternalCommand, FuncThatOverwritesExecutionContext
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function InternalFunction { 'I am the second module internal function' }
        function InternalFunction2 { 'I am the second module, second function' }
        function PublicFunction   { InternalFunction }
        function PublicFunction2 { InternalFunction2 }

        function FuncThatOverwritesExecutionContext {
            param ($ExecutionContext)

            InternalFunction
        }

        function ScopeTest {
            return Get-CallerModuleName
        }

        function Get-CallerModuleName {
            [CmdletBinding()]
            param ( )

            return $PSCmdlet.SessionState.Module.Name
        }

        Export-ModuleMember -Function PublicFunction, PublicFunction2, FuncThatOverwritesExecutionContext, ScopeTest
    } | Import-Module -Force

    It 'Should fail to call the internal module function' {
        { TestModule\InternalFunction } | Should Throw
    }

    It 'Should call the actual internal module function from the public function' {
        TestModule\PublicFunction | Should Be 'I am the internal function'
    }

    Context 'Using Mock -ModuleName "ModuleName" "CommandName" syntax' {
        Mock -ModuleName TestModule InternalFunction { 'I am the mock test' }

        It 'Should call the mocked function' {
            TestModule\PublicFunction | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule Start-Sleep { }

        It 'Should mock calls to external functions from inside the module' {
            PublicFunctionThatCallsExternalCommand

            Assert-MockCalled -ModuleName TestModule Start-Sleep -Exactly 1
        }

        Mock -ModuleName TestModule2 InternalFunction -ParameterFilter { $args[0] -eq 'Test' } {
            "I'm the mock who's been passed parameter Test"
        }

        It 'Should only call mocks within the same module' {
            TestModule2\PublicFunction | Should Be 'I am the second module internal function'
        }

        Mock -ModuleName TestModule2 InternalFunction2 {
            InternalFunction 'Test'
        }

        It 'Should call mocks from inside another mock' {
            TestModule2\PublicFunction2 | Should Be "I'm the mock who's been passed parameter Test"
        }

        It 'Should work even if the function is weird and steps on the automatic $ExecutionContext variable.' {
            TestModule2\FuncThatOverwritesExecutionContext | Should Be 'I am the second module internal function'
            TestModule\FuncThatOverwritesExecutionContext | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }

        It 'Should call the original command from the proper scope if no parameter filters match' {
            TestModule2\ScopeTest | Should Be 'TestModule2'
        }

        Mock -ModuleName TestModule2 Get-Content { }

        It 'Does not trigger the mocked Get-Content from Pester internals' {
            Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }
            Assert-MockCalled -ModuleName TestModule2 Get-Content -Times 0 -Scope It
        }
    }

    AfterAll {
        Remove-Module TestModule -Force
        Remove-Module TestModule2 -Force
    }
}

Describe "When Applying multiple Mocks on a single command" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "two"

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am the first mock test"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1.Length -gt 0 }
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -gt 1 }

    $result = FunctionUnderTest "one"

    It "The last Mock should win" {
        $result | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "three"

    It "The parameterless mock is evaluated last" {
        $result | Should Be "I am the first mock test"
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2 | Should Be "I am the paramless mock test"
    }
}

Describe "When Creating a Verifiable Mock that is not called" {
    Context "In the test script's scope" {
        Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        FunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected FunctionUnderTest to be called with `$param1 -eq `"one`""
        }
    }

    Context "In a module's scope" {
        New-Module -Name TestModule -ScriptBlock {
            function ModuleFunctionUnderTest { return 'I am the function under test in a module' }
        } | Import-Module -Force

        Mock -ModuleName TestModule ModuleFunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        TestModule\ModuleFunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected ModuleFunctionUnderTest in module TestModule to be called with `$param1 -eq `"one`""
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }
}

Describe "When Creating a Verifiable Mock that is called" {
    Mock FunctionUnderTest -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    It "Assert-VerifiableMocks Should not throw" {
        { Assert-VerifiableMocks } | Should Not Throw
    }
}

Describe "When Calling Assert-MockCalled 0 without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest 0
    } Catch {
        $result=$_
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 0 times exactly but was called 1 times"
    }

    It "Should not throw if mock was not called" {
        Assert-MockCalled FunctionUnderTest 0 { $param1 -eq "stupid" }
    }
}

Describe "When Calling Assert-MockCalled with exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest -exactly 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 3 times exactly but was called 2 times"
    }

    It "Should not throw if mock was called the number of times specified" {
        Assert-MockCalled FunctionUnderTest -exactly 2 { $param1 -eq "one" }
    }
}

Describe "When Calling Assert-MockCalled without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"
    FunctionUnderTest "two"

    It "Should throw if mock was not called atleast the number of times specified" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest 4 }
        $scriptBlock | Should Throw "Expected FunctionUnderTest to be called at least 4 times but was called 3 times"
    }

    It "Should not throw if mock was called at least the number of times specified" {
        Assert-MockCalled FunctionUnderTest
    }

    It "Should not throw if mock was called at exactly the number of times specified" {
        Assert-MockCalled FunctionUnderTest 2 { $param1 -eq "one" }
    }

    It "Should throw an error if any non-matching calls to the mock are made, and the -ExclusiveFilter parameter is used" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } }
        $scriptBlock | Should Throw '1 non-matching calls were made'
    }
}

Describe "Using Pester Scopes (Describe,Context,It)" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}

    Context "When in the first context" {
        It "should mock Describe scoped paramles mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When in the second context" {
        It "should mock Describe scoped paramles mock again" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock again" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When using mocks in both scopes" {
        Mock FunctionUnderTestWithoutParams {return "I am the other function"}

        It "should mock Describe scoped mock." {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Context scoped mock." {
            FunctionUnderTestWithoutParams | should be "I am the other function"
        }
    }

    Context "When context hides a describe mock" {
        Mock FunctionUnderTest {return "I am the context mock"}
        Mock FunctionUnderTest {return "I am the parameterized context mock"} -parameterFilter {$param1 -eq "one"}

        It "should use the context paramles mock" {
            FunctionUnderTest | should be "I am the context mock"
        }
        It "should use the context parameterized mock" {
            FunctionUnderTest "one" | should be "I am the parameterized context mock"
        }
    }

    Context "When context no longer hides a describe mock" {
        It "should use the describe mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }

        It "should use the describe parameterized mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context 'When someone calls Mock from inside an It block' {
        Mock FunctionUnderTest { return 'I am the context mock' }

        It 'Sets the mock' {
            Mock FunctionUnderTest { return 'I am the It mock' }
        }

        It 'Leaves the mock active in the parent scope' {
            FunctionUnderTest | Should Be 'I am the It mock'
        }
    }
}

Describe 'Testing mock history behavior from each scope' {
    function MockHistoryChecker { }
    Mock MockHistoryChecker { 'I am the describe mock.' }

    Context 'Without overriding the mock in lower scopes' {
        It "Reports that zero calls have been made to in the describe scope" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope Describe
        }

        It 'Calls the describe mock' {
            MockHistoryChecker | Should Be 'I am the describe mock.'
        }

        It "Reports that zero calls have been made in an It block, after a context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope It
        }

        It "Reports one Context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It "Reports one Describe-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'After exiting the previous context' {
        It 'Reports zero context-scoped calls in the new context.' {
            Assert-MockCalled MockHistoryChecker -Exactly 0
        }

        It 'Reports one describe-scoped call from the previous context' {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'While overriding mocks in lower scopes' {
        Mock MockHistoryChecker { 'I am the context mock.' }

        It 'Calls the context mock' {
            MockHistoryChecker | Should Be 'I am the context mock.'
        }

        It 'Reports one context-scoped call' {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It 'Reports two describe-scoped calls, even when one is an override mock in a lower scope' {
            Assert-MockCalled MockHistoryChecker -Exactly 2 -Scope Describe
        }

        It 'Calls an It-scoped mock' {
            Mock MockHistoryChecker { 'I am the It mock.' }
            MockHistoryChecker | Should Be 'I am the It mock.'
        }

        It 'Reports 2 context-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 2
        }

        It 'Reports 3 describe-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 3 -Scope Describe
        }
    }

    It 'Reports 3 describe-scoped calls using the default scope in a Describe block' {
        Assert-MockCalled MockHistoryChecker -Exactly 3
    }
}

Describe "Using a single no param Describe" {
    Mock FunctionUnderTest {return "I am the describe mock test"}

    Context "With a context mocking the same function with no params"{
        Mock FunctionUnderTest {return "I am the context mock test"}
        It "Should use the context mock" {
            FunctionUnderTest | should be "I am the context mock test"
        }
    }
}

Describe 'Dot Source Test' {
    # This test is only meaningful if this test file is dot-sourced in the global scope.  If it's executed without
    # dot-sourcing or run by Invoke-Pester, there's no problem.

    function TestFunction { Test-Path -Path 'Test' }
    Mock Test-Path { }

    $null = TestFunction

    It "Calls the mock with parameter 'Test'" {
        Assert-MockCalled Test-Path -Exactly 1 -ParameterFilter { $Path -eq 'Test' }
    }

    It "Doesn't call the mock with any other parameters" {
        InModuleScope Pester {
            $global:calls = $mockTable['||Test-Path'].CallHistory
        }
        Assert-MockCalled Test-Path -Exactly 0 -ParameterFilter { $Path -ne 'Test' }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters' {
    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { Get-ChildItem -Path Cert:\ -CodeSigningCert } | Should Not Throw
        Assert-MockCalled Get-ChildItem
    }
}

Describe 'Mocking functions with dynamic parameters' {
    Context 'Dynamicparam block that uses the variables of static parameters in its logic' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting {
            [CmdletBinding()]
            param (
                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting
        }

        $Capitalize = $false

        It 'Sets the dynamic parameter variable properly' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting -Scope It
        }
    }

    Context 'When the mocked command is in a module' {
        New-Module -Name TestModule {
            function PublicFunction { Get-Greeting -Name lowercase -Capitalize }

            $script:DoDynamicParam = $true

            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function script:Get-Greeting {
                [CmdletBinding()]
                param (
                    [string] $Name
                )

                DynamicParam {
                    # This check is here to make sure the mocked version can still work if the
                    # original function's dynamicparam block relied on script-scope variables.
                    if (-not $script:DoDynamicParam) { return }

                    if ($Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end
                {
                    if($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }
        } | Import-Module -Force

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { TestModule\PublicFunction } | Should Not Throw
            Assert-MockCalled Get-Greeting -ModuleName TestModule
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }

    Context 'When the mocked command has mandatory parameters that are passed in via the pipeline' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting2 {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string] $MandatoryParam,

                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting2 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = 'Mandatory' | Get-Greeting2 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command has parameter sets that are ambiguous at the time the dynamic param block is executed' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting3 {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'One')]
                [string] $One,

                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Two')]
                [string] $Two,

                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting3 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = New-Object psobject -Property @{ One = 'One' } | Get-Greeting3 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSBoundParameters' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting4 {
            [CmdletBinding()]
            param (
                [string] $Name
            )

            DynamicParam {
                if ($PSBoundParameters['Name'] -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting4 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Get-Greeting4 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSCmdlet.ParameterSetName' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting5 {
            [CmdletBinding(DefaultParameterSetName = 'One')]
            param (
                [string] $Name,

                [Parameter(ParameterSetName = 'Two')]
                [string] $Two
            )

            DynamicParam {
                if ($PSCmdlet.ParameterSetName -eq 'Two' -and $Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting5 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Get-Greeting5 -Two 'Two' -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters in a module' {
    New-Module -Name TestModule {
        function PublicFunction   { Get-ChildItem -Path Cert:\ -CodeSigningCert }
    } | Import-Module -Force

    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should Not Throw
        Assert-MockCalled Get-ChildItem -ModuleName TestModule
    }

    AfterAll {
        Remove-Module TestModule -Force
    }
}

Describe 'DynamicParam blocks in other scopes' {
    New-Module -Name TestModule1 {
        $script:DoDynamicParam = $true

        function DynamicParamFunction {
            [CmdletBinding()]
            param ( )

            DynamicParam {
                if ($script:DoDynamicParam)
                {
                    Get-MockDynamicParameters -CmdletName Get-ChildItem -Parameters @{ Path = [string[]]'Cert:\' }
                }
            }

            end
            {
                'I am the original function'
            }
        }
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function CallingFunction
        {
            DynamicParamFunction -CodeSigningCert
        }

        function CallingFunction2 {
            [CmdletBinding()]
            param (
                [ValidateScript({ [bool](DynamicParamFunction -CodeSigningCert) })]
                [string]
                $Whatever
            )
        }
    } | Import-Module -Force

    Mock DynamicParamFunction { if ($CodeSigningCert) { 'I am the mocked function' } } -ModuleName TestModule2

    It 'Properly evaluates dynamic parameters when called from another scope' {
        CallingFunction | Should Be 'I am the mocked function'
    }

    It 'Properly evaluates dynamic parameters when called from another scope when the call is from a ValidateScript block' {
        CallingFunction2 -Whatever 'Whatever'
    }

    AfterAll {
        Remove-Module TestModule1 -Force
        Remove-Module TestModule2 -Force
    }
}

Describe 'Parameter Filters and Common Parameters' {
    function Test-Function { [CmdletBinding()] param ( ) }

    Mock Test-Function { } -ParameterFilter { $VerbosePreference -eq 'Continue' }

    It 'Applies common parameters correctly when testing the parameter filter' {
        { Test-Function -Verbose } | Should Not Throw
        Assert-MockCalled Test-Function
        Assert-MockCalled Test-Function -ParameterFilter { $VerbosePreference -eq 'Continue' }
    }
}

Describe "Mocking Get-ItemProperty" {
    Mock Get-ItemProperty { New-Object -typename psobject -property @{ Name = "fakeName" } }
    It "Does not fail with NotImplementedException" {
        Get-ItemProperty -Path "HKLM:\Software\Key\" -Name "Property" | Select -ExpandProperty Name | Should Be fakeName
    }
}

Describe 'When mocking a command with parameters that match internal variable names' {
    function Test-Function
    {
        [CmdletBinding()]
        param (
            [string] $ArgumentList,
            [int] $FunctionName,
            [double] $ModuleName
        )
    }

    Mock Test-Function { return 'Mocked!' }

    It 'Should execute the mocked command successfully' {
        { Test-Function } | Should Not Throw
        Test-Function | Should Be 'Mocked!'
    }
}

Describe 'Mocking commands with potentially ambigious parameter sets' {
    function SomeFunction
    {
        [CmdletBinding()]
        param
        (
            [parameter(ParameterSetName                = 'ps1',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p1,

            [parameter(ParameterSetName                = 'ps2',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p2
        )
        process
        {
            return $true
        }
    }

    Mock SomeFunction { }

    It 'Should call the function successfully, even with delayed parameter binding' {
        $object = New-Object psobject -Property @{ p1 = 'Whatever' }
        { $object | SomeFunction } | Should Not Throw
        Assert-MockCalled SomeFunction -ParameterFilter { $p1 -eq 'Whatever' }
    }
}

Describe 'When mocking a command that has an ArgumentList parameter with validation' {
    Mock Start-Process { return 'mocked' }

    It 'Calls the mock properly' {
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Start-Process -FilePath cmd.exe -ArgumentList '/c dir c:\' }

        $scriptBlock | Should Not Throw
        $hash.Result | Should Be 'mocked'
    }
}

# These assertions won't actually "fail"; we had an infinite recursion bug in Get-DynamicParametersForCmdlet
# if the caller mocked New-Object.  It should be fixed by making that call to New-Object module-qualified,
# and this test will make sure it's working properly.  If this test fails, it'll take a really long time
# to execute, and then will throw a stack overflow error.

Describe 'Mocking New-Object' {
    It 'Works properly' {
        Mock New-Object

        $result = New-Object -TypeName Object
        $result | Should Be $null
        Assert-MockCalled New-Object
    }
}

Describe 'Mocking a function taking input from pipeline' {
    $psobj = New-Object -TypeName psobject -Property @{'PipeIntProp'='1';'PipeArrayProp'=1;'PipeStringProp'=1}
    $psArrayobj = New-Object -TypeName psobject -Property @{'PipeArrayProp'=@(1)}
    $noMockArrayResult = @(1,2) | PipelineInputFunction
    $noMockIntResult = 1 | PipelineInputFunction
    $noMockStringResult = '1' | PipelineInputFunction
    $noMockResultByProperty = $psobj | PipelineInputFunction -PipeStr 'val'
    $noMockArrayResultByProperty = $psArrayobj | PipelineInputFunction -PipeStr 'val'

    Mock PipelineInputFunction { write-output 'mocked' } -ParameterFilter { $PipeStr -eq 'blah' }

    context 'when calling original function with an array' {
        $result = @(1,2) | PipelineInputFunction
        it 'Returns actual implementation' {
            $result[0].keys | % {
                $result[0][$_] | Should Be $noMockArrayResult[0][$_]
                $result[1][$_] | Should Be $noMockArrayResult[1][$_]
            }
        }
    }

    context 'when calling original function with an int' {
        $result = 1 | PipelineInputFunction
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockIntResult[$_]
            }
        }
    }

    context 'when calling original function with a string' {
        $result = '1' | PipelineInputFunction
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockStringResult[$_]
            }
        }
    }

    context 'when calling original function and pipeline is bound by property name' {
        $result = $psobj | PipelineInputFunction -PipeStr 'val'
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockResultByProperty[$_]
            }
        }
    }

    context 'when calling original function and forcing a parameter binding exception' {
        Mock PipelineInputFunction {
            if($MyInvocation.ExpectingInput) {
                throw New-Object -TypeName System.Management.Automation.ParameterBindingException
            }
            write-output $MyInvocation.ExpectingInput
        }
        $result = $psobj | PipelineInputFunction

        it 'falls back to no pipeline input' {
            $result | Should Be $false
        }
    }

    context 'when calling original function and pipeline is bound by property name with array values' {
        $result = $psArrayobj | PipelineInputFunction -PipeStr 'val'
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockArrayResultByProperty[$_]
            }
        }
    }

    context 'when calling the mocked function' {
        $result = 'blah' | PipelineInputFunction
        it 'Returns mocked implementation' {
            $result | Should Be 'mocked'
        }
    }
}

Describe 'Mocking module-qualified calls' {
    It 'Mock alias should not exist before the mock is defined' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Be $null
    }

    $mockFile = 'TestDrive:\TestFile'
    $mockResult = 'Mocked'

    Mock Get-Content { return $mockResult } -ParameterFilter { $Path -eq $mockFile }
    Setup -File TestFile -Content 'The actual file'

    It 'Creates the alias while the mock is in effect' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Not Be $null
    }

    It 'Calls the mock properly even if the call is module-qualified' {
        $result = Microsoft.PowerShell.Management\Get-Content -Path $mockFile
        $result | Should Be $mockResult
    }
}

Describe 'After a mock goes out of scope' {
    It 'Removes the alias after the mock goes out of scope' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Be $null
    }
}

Describe 'Assert-MockCalled with Aliases' {
    AfterEach {
        if (Test-Path alias:PesterTF) { Remove-Item Alias:PesterTF }
    }

    It 'Allows calls to Assert-MockCalled to use both aliases and the original command name' {
        function TestFunction { }
        Set-Alias -Name PesterTF -Value TestFunction
        Mock PesterTF
        $null = PesterTF

        { Assert-MockCalled PesterTF } | Should Not Throw
        { Assert-MockCalled TestFunction } | Should Not Throw
    }
}

Describe 'Mocking Get-Command' {
    # This was reported as a bug in 3.3.12; we were relying on Get-Command to safely invoke other commands.
    # Mocking Get-Command, though, would result in infinite recursion.

    It 'Does not break when Get-Command is mocked' {
        { Mock Get-Command } | Should Not Throw
    }
}

Describe 'Mocks with closures' {
    $closureVariable = 'from closure'
    $scriptBlock = { "Variable resolved $closureVariable" }
    $closure = $scriptBlock.GetNewClosure()
    $closureVariable = 'from script'

    function TestClosure([switch] $Closure) { 'Not mocked' }

    Mock TestClosure $closure -ParameterFilter { $Closure }
    Mock TestClosure $scriptBlock

    It 'Resolves variables in the closure rather than Pester''s current scope' {
        TestClosure | Should Be 'Variable resolved from script'
        TestClosure -Closure | Should Be 'Variable resolved from closure'
    }
}

Describe '$args handling' {

    function AdvancedFunction {
        [CmdletBinding()]
        param()
        'orig'
    }
    function SimpleFunction {
        . AdvancedFunction
    }
    function AdvancedFunctionWithArgs {
        [CmdletBinding()]
        param($Args)
        'orig'
    }
    Add-Type -TypeDefinition '
        using System.Management.Automation;
        [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithArgs")]
        public class InvokeCmdletWithArgs : Cmdlet {
            public InvokeCmdletWithArgs() { }
            [Parameter]
            public object Args {
                set { }
            }
            protected override void EndProcessing() {
                WriteObject("orig");
            }
        }
    ' -PassThru | Select-Object -ExpandProperty Assembly | Import-Module

    Mock AdvancedFunction { 'mock' }
    Mock AdvancedFunctionWithArgs { 'mock' }
    Mock Invoke-CmdletWithArgs { 'mock' }

    It 'Advanced function mock should be callable with dot operator' {
        SimpleFunction garbage | Should Be mock
    }
    It 'Advanced function with Args parameter should be mockable' {
        AdvancedFunctionWithArgs -Args garbage | Should Be mock
    }
    It 'Cmdlet with Args parameter should be mockable' {
        Invoke-CmdletWithArgs -Args garbage | Should Be mock
    }

}

Describe 'Single quote in command/module name' {
    BeforeAll {
        $module = New-Module "Module '‘’‚‛" {
            Function NormalCommandName { 'orig' }
            New-Item "Function::Command '‘’‚‛" -Value { 'orig' }
        } | Import-Module -PassThru
    }

    AfterAll {
        if ($module) { Remove-Module $module; $module = $null }
    }

    It 'Command with single quote in module name should be mockable' {
        Mock NormalCommandName { 'mock' }
        NormalCommandName | Should Be mock
    }
    It 'Command with single quote in name should be mockable' {
        Mock "Command '‘’‚‛" { 'mock' }
        & "Command '‘’‚‛" | Should Be mock
    }

}

if ($global:PSVersionTable.PSVersion.Major -ge 3) {
    Describe 'Mocking cmdlet without positional parameters' {

        Add-Type -TypeDefinition '
            using System.Management.Automation;
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithoutPositionalParameters")]
            public class InvokeCmdletWithoutPositionalParameters : Cmdlet {
                public InvokeCmdletWithoutPositionalParameters() { }
                [Parameter]
                public object Parameter {
                    set { }
                }
            }
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithValueFromRemainingArguments")]
            public class InvokeCmdletWithValueFromRemainingArguments : Cmdlet {
                private string parameter;
                private string[] remainings;
                public InvokeCmdletWithValueFromRemainingArguments() { }
                [Parameter]
                public string Parameter {
                    set {
                        parameter=value;
                    }
                }
                [Parameter(ValueFromRemainingArguments=true)]
                public string[] Remainings {
                    set {
                        remainings=value;
                    }
                }
                protected override void EndProcessing() {
                    WriteObject(string.Concat(parameter, "; ", string.Join(", ", remainings)));
                }
            }
        ' -PassThru | Select-Object -First 1 -ExpandProperty Assembly | Import-Module

        It 'Original cmdlet does not have positional parameters' {
            { Invoke-CmdletWithoutPositionalParameters garbage } | Should Throw
        }
        Mock Invoke-CmdletWithoutPositionalParameters
        It 'Mock of cmdlet should not make parameters to be positional' {
            { Invoke-CmdletWithoutPositionalParameters garbage } | Should Throw
        }

        It 'Original cmdlet bind all to Remainings' {
            Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should Be '; asd, fgh, jkl'
        }
        Mock Invoke-CmdletWithValueFromRemainingArguments { -join ($Parameter, '; ', ($Remainings -join ', ')) }
        It 'Mock of cmdlet should bind all to Remainings' {
            Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should Be '; asd, fgh, jkl'
        }

    }
}

Describe 'Nested Mock calls' {
    $testDate = New-Object DateTime(2012,6,13)

    Mock Get-Date -ParameterFilter { $null -eq $Date } {
        Get-Date -Date $testDate -Format o
    }

    It 'Properly handles nested mocks' {
        $result = @(Get-Date)
        $result.Count | Should Be 1
        $result[0] | Should Be '2012-06-13T00:00:00.0000000'
    }
}

# SIG # Begin signature block
# MIInSAYJKoZIhvcNAQcCoIInOTCCJzUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAkpc/exW5Mgzst
# vtrs/3BxZAzjbOAHK7Tw8WBQzKoGh6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# knjmSivrcMyLv8AWmBmpW480WR9T0ThSbYWP5nSGaKowUAYKKwYBBAGCNwoDHDFC
# DEA1MDZBRkE2NzQxM0I3RUE2MTI2NTQzM0JBNTEzNzBDRTkyRTM1QjIzRjVFQjdG
# OUE1RUVEQUJGODNBREJCQTQ1MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAjzj1c3LTKowotaxvoUkS
# 5T17o/EfsiuI976zlAAuhdWAi11K6GGwjjyB1I5FksTP+sIXa+Hu+amvjLBcrOLj
# /F7/pE8MULe1CDHs4fpnwF7qtB9OsLEu3dIveQnkLGJVtmxiG2vfj2S9r8qGYzbR
# gGtSStgBCCk0JU/3feSas5Y7FxuKcB8I5hxSSNt1NQLUdAXGWO+u4+A/9QTBPo/I
# 06yW/2wAc2x2iNTUSgBFu3vyMlUGlVtsmrO22cILaAgIVsXHmovhEwogK8MRpzGw
# nUapF2l3dMGK871atPYkTXGs/aClraPHF0jb14qJBZwSbHNw+enqk9TiMdPJ5czf
# nvx7Ijt/MPIn7CUuvSpIoGDqHJPmMZFOpex4Zu2OEh58BYQciJOuAeb1dJavJZut
# naG0D2LXy4UT5wcsN+Jz9eKOmlbIyQNUFMMovHCq62JZkCW/MlJHlxDG+Hkaw5vI
# CJtPR84w8Pm/FD8leVMv6UibDeWeZUtpapdReqWtDzhSoYIXlzCCF5MGCisGAQQB
# gjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEICJozmh88kTELimSyfR/thne2+gCUrOjnzBQQM8e
# 8pUvAgZp2BiXgZIYEzIwMjYwNDExMTA1MzE2LjI0OFowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo3RjAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAACHqOspG45b3xJAAEAAAIe
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5Mzk0OVoXDTI3MDUxNzE5Mzk0OVowgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RjAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKXROO1sPCxHsV7xpzqiXmzXOG1O
# p3YBalyFCEun0bmaZIzbc3l/JAYJDUPTqs4Dc+BcoX7vq9e84KzZWwu/WjCPiYcT
# ISqKrwYnnIL79A1hGlk8Dx7s6B6TMM7pL/i/L+NMxhuneuG4WIooLNNY5C10VwX4
# PSTfr0jumb8TTtLI0waS413mWPlIn3VSoW5l+MwHpxDbCHvua2JFRV2PnfKN02qP
# 4ZCX5hrPb0GOvOftTWWf4mkuWdvTF0aZmgg8plvAFVxa3Ivi7KEwvtJJOaI59ZdT
# 6D7I2XQJ2gsYvwu1YcSLwWy5M95J1KqZ4yu8toSaJtNVNLi9BBjw0+dvq4jnLqI1
# X28EVybwtT+UNOMZOo9rtQFPiB1/kmbfBit8IVng/+PkyipPQk41xrnSO3hMYj3R
# KKFdoMRiqTbdLQglndSRSm6QNFOMrvXcEjKR9/HIGox5Cp87TO9Z9THsGuZSm6BB
# zD334PEuXaB/65ASlGaeVutUn129b12zh+oQ83aMbRDAXU8FKCU1xXVKmpkqK1CA
# EZLC7/zYArO2gIfBhEdE3DPBNV7/Uo1O+aoB3hSB6zjLA4fTaFpqBPzBhjw51Z2M
# qfeTTnbD6SZzRQLQX6JVdMZkgzG+j2IFlChd6HNG1Yn9U60q8LJLdywrM3utK1Yn
# CNJbPp205/SX7K0tAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU5goWmuoEHQlmYlwU
# Lhw8+Z4XgmQwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAKShkHk2clUVvnAp6NGi
# eTnXxrZME1ikpwEy18voFLQBFoAE4wZguU826EjUfCZ6U/2FfeirdNoSb9wOSTM1
# ADMN50+ChEjZHv7ymg1Ja8dcQCztJk4Ob3HsqqUGQ1kz17HhdjXI2ZU4CZYONGvu
# MqNqJBue1/sQLgY2KTEYZpVY6N9i3dD1fSv8qzwoGVvMNH3OMD9MJy1HhyjValTV
# lEsWsH1uXx1HGxufJPapDjUTt1PXZHfR4gZTOISzkY37bpX+i9c6LbR0mIzXeFha
# /LU00kCGQo6UsHU426d3p9+E91Rwday7xX6VHRpqQxXrgeoNsu6ZmsI3BSh9XHfE
# yTwXi0Jgm1DEtPLBzfSxkAPVLawLX3n3HoqLED6njUUtSXyDrigfLdt9icfnF3gk
# 4GBChqqd0aNxy3Gv7wSSeOErKuADOtNwosltR7OCjJ7xusIsn7Lo8CgSOldGRJgB
# TzB9DdhZFyToAvChXtSKfz6ukZBJteEXpzV1MVqReYKEKW53ggANj+3olGQn7ToX
# Mv6MN3wotXxCPvsl+K5OI8gbkb/GWcahkVxf7LIG0O/NkTjx35j4dhR39y+EfUUq
# XsAf7kDKi2olIWa8z8G5hHHYHbRqxVeKVXaTYls07csYLPdD52kSXPCx8muRrU3+
# B62Zrt9amjCw2+ghoRC+Np3xMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
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
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVAIP9A2QoMhbhUgXuPeiLaputHRr/oIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDthJEdMCIYDzIw
# MjYwNDExMDkyMTMzWhgPMjAyNjA0MTIwOTIxMzNaMHcwPQYKKwYBBAGEWQoEATEv
# MC0wCgIFAO2EkR0CAQAwCgIBAAICRpECAf8wBwIBAAICE/4wCgIFAO2F4p0CAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAgRVlK4aUfSHQUldAesRJozsdqsEO
# jWXgwzTromA6m1dybplCzcSrrC1WNJZXbdjR/s2Mk8CeJDPQbN2SZyhWVXmAUDyy
# DRawEN2t6/iXqNxScnesroToi6UaS21KcDY0OYR02TOVQCLB11pk8HWo7PmYcgOR
# EvOY+vmjY0rPBDmgAwEP5TH5rRqh5f3MDbVkEe8o//p/mKSr8W9BhOdiiwo6OGdI
# vbD4bN+uSrvOoWbgQiAUCOIW4QvdwD2rvJyeSXch3A8kMt9fqHo7lboKFwFmQlBL
# bPIRiBKRMQTiTqK5CAx8SFfJGtkHYzXExHuMhoMAQsiFr5XgwT8Zh5tYtzGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACHqOs
# pG45b3xJAAEAAAIeMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIDFs9c14oL08nUuA/hhrFxIg5oHZ
# 0mHqgINKYZIqTSXDMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgL4FdavP2
# B4yAzwG+fxurEeOEdcnb0QGLMhMjDQH284IwgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAh6jrKRuOW98SQABAAACHjAiBCBE5tzr6vrr
# GzZ08GbtlvhoZSP3Flbgx8zPsjgfsXvSQzANBgkqhkiG9w0BAQsFAASCAgBN4FH7
# 8SuBOTO+Sy937+m/aElHhB8gn7uAuAq1m8ct8mMH+LGimLV46rV4HDPiHlXeBpGY
# ASN8z6rwYUbsEbRfXNJj20lr5MoR5/NIXTeV/KsP2+eLZcwvEDEZH/3eCvsgXXze
# vDgu9CmhchxdZeEmtBrht3iseRpI84ED1AQ/zOeix2UaJQCBlHltB9wD8NduYzsP
# jgOvXY00DUNoZZNOFTl2/RQM4ra8cJtKzmvoVwZxAQZEHnHmecgM9cl+Dhx8cYR5
# xlaHCLyUS0qBEPzzWitkJRf/mxQbmIEupDv5qJ/KFHD1ADnJvqlPC5ZsJcHnj+RK
# f2n7fc//YjRs1LnFaC1tD97LDS9ZxUlJ3wni7VyQdwazyYeV21fby7/sgUSfGZNf
# 2SsFCHtWAATWuXUT2bsKOXy68JwCpjHDPfHKn2I2wj5URKHOtP8qiZV422yIxH1k
# NoMOpx4muinuY3TGE/kkYZ5C0CTQbqA73JpqkkdHl6TYJbCidCQhKS6AQw9OGNec
# sqCpGRmDnmZoy0gJNrZfZy1NrVQv+9ikt6JHhhtlwvDsnehtHCiQBssRZ1C3joN8
# ZCfIhPFeiRXexqmPqI2bqYmv2fzvZqgUmLgah2adN4ByqkUME7y9V087YAAiAYBr
# CxOjscc0t/2HiNYOCcDd8HekHipCqRwBXqhkDQ==
# SIG # End signature block
