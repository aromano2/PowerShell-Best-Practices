function Mock {

<#
.SYNOPSIS
Mocks the behavior of an existing command with an alternate
implementation.

.DESCRIPTION
This creates new behavior for any existing command within the scope of a
Describe or Context block. The function allows you to specify a script block
that will become the command's new behavior.

Optionally, you may create a Parameter Filter which will examine the
parameters passed to the mocked command and will invoke the mocked
behavior only if the values of the parameter values pass the filter. If
they do not, the original command implementation will be invoked instead
of a mock.

You may create multiple mocks for the same command, each using a different
ParameterFilter. ParameterFilters will be evaluated in reverse order of
their creation. The last one created will be the first to be evaluated.
The mock of the first filter to pass will be used. The exception to this
rule are Mocks with no filters. They will always be evaluated last since
they will act as a "catch all" mock.

Mocks can be marked Verifiable. If so, the Assert-VerifiableMocks command
can be used to check if all Verifiable mocks were actually called. If any
verifiable mock is not called, Assert-VerifiableMocks will throw an
exception and indicate all mocks not called.

If you wish to mock commands that are called from inside a script module,
you can do so by using the -ModuleName parameter to the Mock command. This
injects the mock into the specified module. If you do not specify a
module name, the mock will be created in the same scope as the test script.
You may mock the same command multiple times, in different scopes, as needed.
Each module's mock maintains a separate call history and verified status.

.PARAMETER CommandName
The name of the command to be mocked.

.PARAMETER MockWith
A ScriptBlock specifying the behvior that will be used to mock CommandName.
The default is an empty ScriptBlock.
NOTE: Do not specify param or dynamicparam blocks in this script block.
These will be injected automatically based on the signature of the command
being mocked, and the MockWith script block can contain references to the
mocked commands parameter variables.

.PARAMETER Verifiable
When this is set, the mock will be checked when Assert-VerifiableMocks is
called.

.PARAMETER ParameterFilter
An optional filter to limit mocking behavior only to usages of
CommandName where the values of the parameters passed to the command
pass the filter.

This ScriptBlock must return a boolean value. See examples for usage.

.PARAMETER ModuleName
Optional string specifying the name of the module where this command
is to be mocked.  This should be a module that _calls_ the mocked
command; it doesn't necessarily have to be the same module which
originally implemented the command.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Using this Mock, all calls to Get-ChildItem will return a hashtable with a
FullName property returning "A_File.TXT"

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter { $Path -eq "some_path" -and $Value -eq "Expected Value" }

When this mock is used, if the Mock is never invoked and Assert-VerifiableMocks is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\1) }
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\2) }
Mock Get-ChildItem { return @{FullName = "C_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\3) }

Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

.EXAMPLE
Mock Get-ChildItem { return @{FullName="B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName="A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the most recent Mock created.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem c:\windows

Here, A_File.TXT will be returned. Since no filter was specified, it will apply to any call to Get-ChildItem that does not pass another filter.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned. Even though the filterless mock was created more recently. This illustrates that filterless Mocks are always evaluated last regardlss of their creation order.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ModuleName MyTestModule

Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
will return a hashtable with a FullName property returning "A_File.TXT"

.EXAMPLE
Get-Module -Name ModuleMockExample | Remove-Module
New-Module -Name ModuleMockExample  -ScriptBlock {
    function Hidden { "Internal Module Function" }
    function Exported { Hidden }

    Export-ModuleMember -Function Exported
} | Import-Module -Force

Describe "ModuleMockExample" {

    It "Hidden function is not directly accessible outside the module" {
        { Hidden } | Should Throw
    }

    It "Original Hidden function is called" {
        Exported | Should Be "Internal Module Function"
    }

    It "Hidden is replaced with our implementation" {
        Mock Hidden { "Mocked" } -ModuleName ModuleMockExample
        Exported | Should Be "Mocked"
    }
}

This example shows how calls to commands made from inside a module can be
mocked by using the -ModuleName parameter.


.LINK
Assert-MockCalled
Assert-VerifiableMocks
Describe
Context
It
about_Should
about_Mocking
#>

    param(
        [string]$CommandName,
        [ScriptBlock]$MockWith={},
        [switch]$Verifiable,
        [ScriptBlock]$ParameterFilter = {$True},
        [string]$ModuleName
    )

    Assert-DescribeInProgress -CommandName Mock

    $contextInfo = Validate-Command $CommandName $ModuleName
    $CommandName = $contextInfo.Command.Name

    if ($contextInfo.Session.Module -and $contextInfo.Session.Module.Name)
    {
        $ModuleName = $contextInfo.Session.Module.Name
    }
    else
    {
        $ModuleName = ''
    }

    if (Test-IsClosure -ScriptBlock $MockWith)
    {
        # If the user went out of their way to call GetNewClosure(), go ahead and leave the block bound to that
        # dynamic module's scope.
        $mockWithCopy = $MockWith
    }
    else
    {
        $mockWithCopy = [scriptblock]::Create($MockWith.ToString())
        Set-ScriptBlockScope -ScriptBlock $mockWithCopy -SessionState $contextInfo.Session
    }

    $block = @{
        Mock       = $mockWithCopy
        Filter     = $ParameterFilter
        Verifiable = $Verifiable
        Scope      = Get-ScopeForMock -PesterState $pester
    }

    $mock = $mockTable["$ModuleName||$CommandName"]

    if (-not $mock)
    {
        $metadata                = $null
        $cmdletBinding           = ''
        $paramBlock              = ''
        $dynamicParamBlock       = ''
        $dynamicParamScriptBlock = $null

        if ($contextInfo.Command.psobject.Properties['ScriptBlock'] -or $contextInfo.Command.CommandType -eq 'Cmdlet')
        {
            $metadata = [System.Management.Automation.CommandMetaData]$contextInfo.Command
            $null = $metadata.Parameters.Remove('Verbose')
            $null = $metadata.Parameters.Remove('Debug')
            $null = $metadata.Parameters.Remove('ErrorAction')
            $null = $metadata.Parameters.Remove('WarningAction')
            $null = $metadata.Parameters.Remove('ErrorVariable')
            $null = $metadata.Parameters.Remove('WarningVariable')
            $null = $metadata.Parameters.Remove('OutVariable')
            $null = $metadata.Parameters.Remove('OutBuffer')

            # Some versions of powershell may include dynamic parameters here
            # We will filter them out and add them at the end to be
            # compatible with both earlier and later versions
            $dynamicParams = $metadata.Parameters.Values | & $SafeCommands['Where-Object'] {$_.IsDynamic}
            if($dynamicParams -ne $null) {
                $dynamicparams | & $SafeCommands['ForEach-Object'] { $null = $metadata.Parameters.Remove($_.name) }
            }

            $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
            if ($global:PSVersionTable.PSVersion.Major -ge 3 -and $contextInfo.Command.CommandType -eq 'Cmdlet') {
                if ($cmdletBinding -ne '[CmdletBinding()]') {
                    $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length-2, ',')
                }
                $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length-2, 'PositionalBinding=$false')
            }

            $paramBlock    = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)

            if ($contextInfo.Command.CommandType -eq 'Cmdlet')
            {
                $dynamicParamBlock = "dynamicparam { Get-MockDynamicParameters -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters }"
            }
            else
            {
                $dynamicParamStatements = Get-DynamicParamBlock -ScriptBlock $contextInfo.Command.ScriptBlock

                if ($dynamicParamStatements -match '\S')
                {
                    $metadataSafeForDynamicParams = [System.Management.Automation.CommandMetaData]$contextInfo.Command
                    foreach ($parameter in $metadataSafeForDynamicParams.Parameters.Values)
                    {
                        $parameter.ParameterSets.Clear()
                    }

                    $paramBlockSafeForDynamicParams = [System.Management.Automation.ProxyCommand]::GetParamBlock($metadataSafeForDynamicParams)
                    $comma = if ($metadataSafeForDynamicParams.Parameters.Count -gt 0) { ',' } else { '' }
                    $dynamicParamBlock = "dynamicparam { Get-MockDynamicParameters -ModuleName '$ModuleName' -FunctionName '$CommandName' -Parameters `$PSBoundParameters -Cmdlet `$PSCmdlet }"

                    $code = @"
                        $cmdletBinding
                        param(
                            [object] `${P S Cmdlet}$comma
                            $paramBlockSafeForDynamicParams
                        )

                        `$PSCmdlet = `${P S Cmdlet}

                        $dynamicParamStatements
"@

                    $dynamicParamScriptBlock = [scriptblock]::Create($code)

                    $sessionStateInternal = Get-ScriptBlockScope -ScriptBlock $contextInfo.Command.ScriptBlock

                    if ($null -ne $sessionStateInternal)
                    {
                        Set-ScriptBlockScope -ScriptBlock $dynamicParamScriptBlock -SessionStateInternal $sessionStateInternal
                    }
                }
            }
        }

        $EscapeSingleQuotedStringContent =
            if ($global:PSVersionTable.PSVersion.Major -ge 5) {
                { [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($args[0]) }
            } else {
                { $args[0] -replace "['‘’‚‛]", '$&$&' }
            }

        $newContent = & $SafeCommands['Get-Content'] function:\MockPrototype
        $newContent = $newContent -replace '#FUNCTIONNAME#', (& $EscapeSingleQuotedStringContent $CommandName)
        $newContent = $newContent -replace '#MODULENAME#', (& $EscapeSingleQuotedStringContent $ModuleName)

        $canCaptureArgs = 'true'
        if ($contextInfo.Command.CommandType -eq 'Cmdlet' -or
            ($contextInfo.Command.CommandType -eq 'Function' -and $contextInfo.Command.CmdletBinding)) {
            $canCaptureArgs = 'false'
        }
        $newContent = $newContent -replace '#CANCAPTUREARGS#', $canCaptureArgs

        $code = @"
            $cmdletBinding
            param ( $paramBlock )
            $dynamicParamBlock
            begin
            {
                `${mock call state} = @{}
                $($newContent -replace '#BLOCK#', 'Begin' -replace '#INPUT#')
            }

            process
            {
                $($newContent -replace '#BLOCK#', 'Process' -replace '#INPUT#', '-InputObject @($input)')
            }

            end
            {
                $($newContent -replace '#BLOCK#', 'End' -replace '#INPUT#')
            }
"@

        $mockScript = [scriptblock]::Create($code)

        $mock = @{
            OriginalCommand         = $contextInfo.Command
            Blocks                  = @()
            CommandName             = $CommandName
            SessionState            = $contextInfo.Session
            Scope                   = $pester.Scope
            Metadata                = $metadata
            CallHistory             = @()
            DynamicParamScriptBlock = $dynamicParamScriptBlock
            FunctionScope           = ''
            Alias                   = $null
        }

        $mockTable["$ModuleName||$CommandName"] = $mock

        if ($contextInfo.Command.CommandType -eq 'Function')
        {
            $mock['FunctionScope'] = $contextInfo.Scope

            $scriptBlock =
            {
                param ( [string] $CommandName )

                if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\$CommandName"))
                {
                    $ExecutionContext.InvokeProvider.Item.Rename("Function:\$CommandName", "script:PesterIsMocking_$CommandName", $true)
                }
            }

            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $CommandName
        }

        $scriptBlock = { $ExecutionContext.InvokeProvider.Item.Set("Function:\script:$($args[0])", $args[1], $true, $true) }
        $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $CommandName, $mockScript

        if ($mock.OriginalCommand.ModuleName)
        {
            $mock.Alias = "$($mock.OriginalCommand.ModuleName)\$($CommandName)"

            $scriptBlock = {
                $setAlias = & (Pester\SafeGetCommand) -Name Set-Alias -CommandType Cmdlet -Module Microsoft.PowerShell.Utility
                & $setAlias -Name $args[0] -Value $args[1] -Scope Script
            }

            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $mock.Alias, $CommandName
        }
    }

    $mock.Blocks = @(
        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -eq '$True' }
        if ($block.Filter.ToString() -eq '$True') { $block }

        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -ne '$True' }
        if ($block.Filter.ToString() -ne '$True') { $block }
    )
}


function Assert-VerifiableMocks {
<#
.SYNOPSIS
Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.

.DESCRIPTION
This can be used in tandem with the -Verifiable switch of the Mock
function. Mock can be used to mock the behavior of an existing command
and optionally take a -Verifiable switch. When Assert-VerifiableMocks
is called, it checks to see if any Mock marked Verifiable has not been
invoked. If any mocks have been found that specified -Verifiable and
have not been invoked, an exception will be thrown.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

{ ...some code that never calls Set-Content some_path -Value "Expected Value"... }

Assert-VerifiableMocks

This will throw an exception and cause the test to fail.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

Set-Content some_path -Value "Expected Value"

Assert-VerifiableMocks

This will not throw an exception because the mock was invoked.

#>
    Assert-DescribeInProgress -CommandName Assert-VerifiableMocks

    $unVerified=@{}
    $mockTable.Keys | & $SafeCommands['ForEach-Object'] {
        $m=$_;

        $mockTable[$m].blocks |
        & $SafeCommands['Where-Object'] { $_.Verifiable } |
        & $SafeCommands['ForEach-Object'] { $unVerified[$m]=$_ }
    }
    if($unVerified.Count -gt 0) {
        foreach($mock in $unVerified.Keys){
            $array = $mock -split '\|\|'
            $function = $array[1]
            $module = $array[0]

            $message = "`r`n Expected $function "
            if ($module) { $message += "in module $module " }
            $message += "to be called with $($unVerified[$mock].Filter)"
        }
        throw $message
    }
}

function Assert-MockCalled {
<#
.SYNOPSIS
Checks if a Mocked command has been called a certain number of times
and throws an exception if it has not.

.DESCRIPTION
This command verifies that a mocked command has been called a certain number
of times.  If the call history of the mocked command does not match the parameters
passed to Assert-MockCalled, Assert-MockCalled will throw an exception.

.PARAMETER CommandName
The mocked command whose call history should be checked.

.PARAMETER ModuleName
The module where the mock being checked was injected.  This is optional,
and must match the ModuleName that was used when setting up the Mock.

.PARAMETER Times
The number of times that the mock must be called to avoid an exception
from throwing.

.PARAMETER Exactly
If this switch is present, the number specified in Times must match
exactly the number of times the mock has been called. Otherwise it
must match "at least" the number of times specified.  If the value
passed to the Times parameter is zero, the Exactly switch is implied.

.PARAMETER ParameterFilter
An optional filter to qualify wich calls should be counted. Only those
calls to the mock whose parameters cause this filter to return true
will be counted.

.PARAMETER ExlusiveFilter
Like ParameterFilter, except when you use ExclusiveFilter, and there
were any calls to the mocked command which do not match the filter,
an exception will be thrown.  This is a convenient way to avoid needing
to have two calls to Assert-MockCalled like this:

Assert-MockCalled SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
Assert-MockCalled SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

.PARAMETER Scope
An optional parameter specifying the Pester scope in which to check for
calls to the mocked command.  By default, Assert-MockCalled will find
all calls to the mocked command in the current Context block (if present),
or the current Describe block (if there is no active Context.)  Valid
values are Describe, Context and It. If you use a scope of Describe or
Context, the command will identify all calls to the mocked command in the
current Describe / Context block, as well as all child scopes of that block.

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content

This will throw an exception and cause the test to fail if Set-Content is not called in Some Code.

.EXAMPLE
C:\PS>Mock Set-Content -parameterFilter {$path.StartsWith("$env:temp\")}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 2 { $path -eq "$env:temp\test.txt" }

This will throw an exception if some code calls Set-Content on $path=$env:temp\test.txt less than 2 times

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 0

This will throw an exception if some code calls Set-Content at all

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content -Exactly 2

This will throw an exception if some code does not call Set-Content Exactly two times.

.EXAMPLE
Describe 'Assert-MockCalled Scope behavior' {
    Mock Set-Content { }

    It 'Calls Set-Content at least once in the It block' {
        {... Some Code ...}

        Assert-MockCalled Set-Content -Exactly 0 -Scope It
    }
}

Checks for calls only within the current It block.

.EXAMPLE
Describe 'Describe' {
    Mock -ModuleName SomeModule Set-Content { }

    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled -ModuleName SomeModule Set-Content
    }
}

Checks for calls to the mock within the SomeModule module.  Note that both the Mock
and Assert-MockCalled commands use the same module name.

.EXAMPLE
Assert-MockCalled Get-ChildItem -ExclusiveFilter { $Path -eq 'C:\' }

Checks to make sure that Get-ChildItem was called at least one time with
the -Path parameter set to 'C:\', and that it was not called at all with
the -Path parameter set to any other value.

.NOTES
The parameter filter passed to Assert-MockCalled does not necessarily have to match the parameter filter
(if any) which was used to create the Mock.  Assert-MockCalled will find any entry in the command history
which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
mocked command are made which did not match any mock's parameter filter (resulting in the original command
being executed instead of a mock), these calls to the original command are not tracked in the call history.
In other words, Assert-MockCalled can only be used to check for calls to the mocked implementation, not
to the original.

#>

[CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$CommandName,

    [Parameter(Position = 1)]
    [int]$Times=1,

    [Parameter(ParameterSetName = 'ParameterFilter', Position = 2)]
    [ScriptBlock]$ParameterFilter = {$True},

    [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
    [scriptblock] $ExclusiveFilter,

    [Parameter(Position = 3)]
    [string] $ModuleName,

    [Parameter(Position = 4)]
    [ValidateSet('Describe','Context','It')]
    [string] $Scope,

    [switch]$Exactly
)

    if ($PSCmdlet.ParameterSetName -eq 'ParameterFilter')
    {
        $filter = $ParameterFilter
        $filterIsExclusive = $false
    }
    else
    {
        $filter = $ExclusiveFilter
        $filterIsExclusive = $true
    }

    Assert-DescribeInProgress -CommandName Assert-MockCalled

    if (-not $PSBoundParameters.ContainsKey('ModuleName') -and $null -ne $pester.SessionState.Module)
    {
        $ModuleName = $pester.SessionState.Module.Name
    }

    $contextInfo = Validate-Command $CommandName $ModuleName
    $CommandName = $contextInfo.Command.Name

    $mock = $script:mockTable["$ModuleName||$CommandName"]

    $moduleMessage = ''
    if ($ModuleName)
    {
        $moduleMessage = " in module $ModuleName"
    }

    if (-not $mock)
    {
        throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    }

    if (-not $Scope)
    {
        if ($pester.CurrentContext)
        {
            $Scope = 'Context'
        }
        else
        {
            $Scope = 'Describe'
        }
    }

    $matchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList
    $nonMatchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList

    foreach ($historyEntry in $mock.CallHistory)
    {
        if (-not (Test-MockCallScope -CallScope $historyEntry.Scope -DesiredScope $Scope)) { continue }

        $params = @{
            ScriptBlock     = $filter
            BoundParameters = $historyEntry.BoundParams
            ArgumentList    = $historyEntry.Args
            Metadata        = $mock.Metadata
        }


        if (Test-ParameterFilter @params)
        {
            $null = $matchingCalls.Add($historyEntry)
        }
        else
        {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }

    $lineText = $MyInvocation.Line.TrimEnd("`n")
    $line = $MyInvocation.ScriptLineNumber

    if($matchingCalls.Count -ne $times -and ($Exactly -or ($times -eq 0)))
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called $times times exactly but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif($matchingCalls.Count -lt $times)
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called at least $times times but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif ($filterIsExclusive -and $nonMatchingCalls.Count -gt 0)
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter, but $($nonMatchingCalls.Count) non-matching calls were made"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
}

function Test-MockCallScope
{
    [CmdletBinding()]
    param (
        [string] $CallScope,
        [string] $DesiredScope
    )

    # It would probably be cleaner to replace all of these scope strings with an enumerated type at some point.
    $scopes = 'Describe', 'Context', 'It'

    return ([array]::IndexOf($scopes, $CallScope) -ge [array]::IndexOf($scopes, $DesiredScope))
}

function Exit-MockScope {
    if ($null -eq $mockTable) { return }

    $currentScope = $pester.Scope
    $parentScope = $pester.ParentScope

    $scriptBlock =
    {
        param (
            [string] $CommandName,
            [string] $Scope,
            [string] $Alias
        )

        $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)
        if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\PesterIsMocking_$CommandName", $true, $true))
        {
            $ExecutionContext.InvokeProvider.Item.Rename("Function:\PesterIsMocking_$CommandName", "$Scope$CommandName", $true)
        }

        if ($Alias -and $ExecutionContext.InvokeProvider.Item.Exists("Alias:$Alias", $true, $true))
        {
            $ExecutionContext.InvokeProvider.Item.Remove("Alias:$Alias", $false, $true, $true)
        }
    }

    $mockKeys = [string[]]$mockTable.Keys

    foreach ($mockKey in $mockKeys)
    {
        $mock = $mockTable[$mockKey]
        $mock.Blocks = @($mock.Blocks | & $SafeCommands['Where-Object'] {$_.Scope -ne $currentScope})

        if ($null -eq $parentScope)
        {
            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $mock.CommandName, $mock.FunctionScope, $mock.Alias
            $mockTable.Remove($mockKey)
        }
        else
        {
            foreach ($historyEntry in $mock.CallHistory)
            {
                if ($historyEntry.Scope -eq $currentScope) { $historyEntry.Scope = $parentScope }
            }
        }
    }
}

function Validate-Command([string]$CommandName, [string]$ModuleName) {
    $module = $null
    $origCommand = $null

    $commandInfo = & $SafeCommands['New-Object'] psobject -Property @{ Command = $null; Scope = '' }

    $scriptBlock = {
        $getContentCommand = & (Pester\SafeGetCommand) Get-Content -Module Microsoft.PowerShell.Management -CommandType Cmdlet
        $newObjectCommand  = & (Pester\SafeGetCommand) New-Object  -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet

        $command = $ExecutionContext.InvokeCommand.GetCommand($args[0], 'All')
        while ($null -ne $command -and $command.CommandType -eq [System.Management.Automation.CommandTypes]::Alias)
        {
            $command = $command.ResolvedCommand
        }

        $properties = @{
            Command = $command
        }

        if ($null -ne $command -and $command.CommandType -eq 'Function')
        {
            if ($ExecutionContext.InvokeProvider.Item.Exists("function:\global:$($command.Name)") -and
                (& $getContentCommand "function:\global:$($command.Name)" -ErrorAction Stop) -eq $command.ScriptBlock)
            {
                $properties['Scope'] = 'global:'
            }
            elseif ($ExecutionContext.InvokeProvider.Item.Exists("function:\script:$($command.Name)") -and
                    (& $getContentCommand "function:\script:$($command.Name)" -ErrorAction Stop) -eq $command.ScriptBlock)
            {
                $properties['Scope'] = 'script:'
            }
            else
            {
                $properties['Scope'] = ''
            }
        }

        return & $newObjectCommand psobject -Property $properties
    }

    if ($ModuleName) {
        $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop
        $commandInfo = & $module $scriptBlock $CommandName
    }

    $session = $pester.SessionState

    if (-not $commandInfo.Command) {
        Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $session
        $commandInfo = & $scriptBlock $commandName
    }

    if (-not $commandInfo.Command) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $commandName")
    }

    if ($module) {
        $session = & $module { $ExecutionContext.SessionState }
    }

    $hash = @{Command = $commandInfo.Command; Session = $session}
    if ($commandInfo.Command.CommandType -eq 'Function')
    {
        $hash['Scope'] = $commandInfo.Scope
    }

    return $hash
}

function MockPrototype {
    if ($PSVersionTable.PSVersion.Major -ge 3)
    {
        [string] ${ignore preference} = 'Ignore'
    }
    else
    {
        [string] ${ignore preference} = 'SilentlyContinue'
    }

    ${get Variable Command} = & (Pester\SafeGetCommand) -Name Get-Variable -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

    [object] ${a r g s} = $null
    if (${#CANCAPTUREARGS#}) {
        ${a r g s} = & ${get Variable Command} -Name args -ValueOnly -Scope Local -ErrorAction ${ignore preference}
    }
    if ($null -eq ${a r g s}) { ${a r g s} = @() }

    ${p s cmdlet} = & ${get Variable Command} -Name PSCmdlet -ValueOnly -Scope Local -ErrorAction ${ignore preference}

    ${session state} = if (${p s cmdlet}) { ${p s cmdlet}.SessionState }

    # @{mock call state} initialization is injected only into the begin block by the code that uses this prototype.
    Invoke-Mock -CommandName '#FUNCTIONNAME#' -ModuleName '#MODULENAME#' -BoundParameters $PSBoundParameters -ArgumentList ${a r g s} -CallerSessionState ${session state} -FromBlock '#BLOCK#' -MockCallState ${mock call state} #INPUT#
}

function Invoke-Mock {
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter(Mandatory = $true)]
        [hashtable] $MockCallState,

        [string]
        $ModuleName,

        [hashtable]
        $BoundParameters = @{},

        [object[]]
        $ArgumentList = @(),

        [object] $CallerSessionState,

        [ValidateSet('Begin', 'Process', 'End')]
        [string] $FromBlock,

        [object] $InputObject
    )

    $detectedModule = $ModuleName
    $mock = FindMock -CommandName $CommandName -ModuleName ([ref]$detectedModule)

    if ($null -eq $mock)
    {
        # If this ever happens, it's a bug in Pester.  The scriptBlock that calls Invoke-Mock should be removed at the same time as the entry in the mock table.
        throw "Internal error detected:  Mock for '$CommandName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    switch ($FromBlock)
    {
        Begin
        {
            $MockCallState['InputObjects'] = & $SafeCommands['New-Object'] System.Collections.ArrayList
            $MockCallState['ShouldExecuteOriginalCommand'] = $false
            $MockCallState['BeginBoundParameters'] = $BoundParameters.Clone()
            $MockCallState['BeginArgumentList'] = $ArgumentList

            return
        }

        Process
        {
            $block = $null
            if ($detectedModule -eq $ModuleName)
            {
                $block = FindMatchingBlock -Mock $mock -BoundParameters $BoundParameters -ArgumentList $ArgumentList
            }

            if ($null -ne $block)
            {
                ExecuteBlock -Block $block `
                             -CommandName $CommandName `
                             -ModuleName $ModuleName `
                             -BoundParameters $BoundParameters `
                             -ArgumentList $ArgumentList `
                             -Mock $mock

                return
            }
            else
            {
                $MockCallState['ShouldExecuteOriginalCommand'] = $true
                if ($null -ne $InputObject)
                {
                    $null = $MockCallState['InputObjects'].AddRange(@($InputObject))
                }

                return
            }
        }

        End
        {
            if ($MockCallState['ShouldExecuteOriginalCommand'])
            {
                if ($MockCallState['InputObjects'].Count -gt 0)
                {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        $InputObjects | & $Command @ArgumentList @BoundParameters
                    }
                }
                else
                {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        & $Command @ArgumentList @BoundParameters
                    }
                }

                $state = if ($CallerSessionState) { $CallerSessionState } else { $mock.SessionState }

                Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $state

                & $scriptBlock -Command $mock.OriginalCommand `
                               -ArgumentList $MockCallState['BeginArgumentList'] `
                               -BoundParameters $MockCallState['BeginBoundParameters'] `
                               -InputObjects $MockCallState['InputObjects']
            }
        }
    }
}

function FindMock
{
    param (
        [string] $CommandName,
        [ref] $ModuleName
    )

    $mock = $mockTable["$($ModuleName.Value)||$CommandName"]

    if ($null -eq $mock)
    {
        $mock = $mockTable["||$CommandName"]
        if ($null -ne $mock)
        {
            $ModuleName.Value = ''
        }
    }

    return $mock
}

function FindMatchingBlock
{
    param (
        [object] $Mock,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    for ($idx = $mock.Blocks.Length; $idx -gt 0; $idx--)
    {
        $block = $mock.Blocks[$idx - 1]

        $params = @{
            ScriptBlock     = $block.Filter
            BoundParameters = $BoundParameters
            ArgumentList    = $ArgumentList
            Metadata        = $mock.Metadata
        }

        if (Test-ParameterFilter @params)
        {
            return $block
        }
    }

    return $null
}

function ExecuteBlock
{
    param (
        [object] $Block,
        [object] $Mock,
        [string] $CommandName,
        [string] $ModuleName,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    $Block.Verifiable = $false
    $Mock.CallHistory += @{CommandName = "$ModuleName||$CommandName"; BoundParams = $BoundParameters; Args = $ArgumentList; Scope = $pester.Scope }

    $scriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            $ScriptBlock,

            [hashtable]
            $BoundParameters = @{},

            [object[]]
            $ArgumentList = @(),

            [System.Management.Automation.CommandMetadata]
            $Metadata,

            [System.Management.Automation.SessionState]
            $SessionState
        )

        # This script block exists to hold variables without polluting the test script's current scope.
        # Dynamic parameters in functions, for some reason, only exist in $PSBoundParameters instead
        # of being assigned a local variable the way static parameters do.  By calling Set-DynamicParameterValues,
        # we create these variables for the caller's use in a Parameter Filter or within the mock itself, and
        # by doing it inside this temporary script block, those variables don't stick around longer than they
        # should.

        # Because Set-DynamicParameterVariables might potentially overwrite our $ScriptBlock, $BoundParameters and/or $ArgumentList variables,
        # we'll stash them in names unlikely to be overwritten.

        $___ScriptBlock___ = $ScriptBlock
        $___BoundParameters___ = $BoundParameters
        $___ArgumentList___ = $ArgumentList

        Set-DynamicParameterVariables -SessionState $SessionState -Parameters $BoundParameters -Metadata $Metadata
        & $___ScriptBlock___ @___BoundParameters___ @___ArgumentList___
    }

    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $mock.SessionState
    & $scriptBlock -ScriptBlock $block.Mock -ArgumentList $ArgumentList -BoundParameters $BoundParameters -Metadata $mock.Metadata -SessionState $mock.SessionState
}

function Invoke-InMockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]
        $ArgumentList = @()
    )

    if ($SessionState.Module)
    {
        $SessionState.Module.Invoke($ScriptBlock, $ArgumentList)
    }
    else
    {
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $SessionState
        & $ScriptBlock @ArgumentList
    }
}

function Test-ParameterFilter
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [System.Collections.IDictionary]
        $BoundParameters,

        [object[]]
        $ArgumentList,

        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    if ($null -eq $BoundParameters)   { $BoundParameters = @{} }
    if ($null -eq $ArgumentList)      { $ArgumentList = @() }

    $paramBlock = Get-ParamBlockFromBoundParameters -BoundParameters $BoundParameters -Metadata $Metadata

    $scriptBlockString = "
        $paramBlock

        Set-StrictMode -Off
        $ScriptBlock
    "

    $cmd = [scriptblock]::Create($scriptBlockString)
    Set-ScriptBlockScope -ScriptBlock $cmd -SessionState $pester.SessionState

    & $cmd @BoundParameters @ArgumentList
}

function Get-ParamBlockFromBoundParameters
{
    param (
        [System.Collections.IDictionary] $BoundParameters,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    $params = foreach ($paramName in $BoundParameters.Keys)
    {
        if (IsCommonParameter -Name $paramName -Metadata $Metadata)
        {
            continue
        }

        "`${$paramName}"
    }

    $params = $params -join ','

    if ($null -ne $Metadata)
    {
        $cmdletBinding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($Metadata)
    }
    else
    {
        $cmdletBinding = ''
    }

    return "$cmdletBinding param ($params)"
}

function IsCommonParameter
{
    param (
        [string] $Name,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    if ($null -ne $Metadata)
    {
        if ([System.Management.Automation.Internal.CommonParameters].GetProperty($Name)) { return $true }
        if ($Metadata.SupportsShouldProcess -and [System.Management.Automation.Internal.ShouldProcessParameters].GetProperty($Name)) { return $true }
        if ($PSVersionTable.PSVersion.Major -ge 3 -and $Metadata.SupportsPaging -and [System.Management.Automation.PagingParameters].GetProperty($Name)) { return $true }
        if ($Metadata.SupportsTransactions -and [System.Management.Automation.Internal.TransactionParameters].GetProperty($Name)) { return $true }
    }

    return $false
}

function Get-ScopeForMock
{
    param ($PesterState)

    $scope = $PesterState.Scope
    if ($scope -eq 'It') { $scope = $PesterState.ParentScope }

    return $scope
}

function Set-DynamicParameterVariables
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [hashtable]
        $Parameters,

        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    if ($null -eq $Parameters) { $Parameters = @{} }

    foreach ($keyValuePair in $Parameters.GetEnumerator())
    {
        $variableName = $keyValuePair.Key

        if (-not (IsCommonParameter -Name $variableName -Metadata $Metadata))
        {
            if ($ExecutionContext.SessionState -eq $SessionState)
            {
                & $SafeCommands['Set-Variable'] -Scope 1 -Name $variableName -Value $keyValuePair.Value -Force -Confirm:$false -WhatIf:$false
            }
            else
            {
                $SessionState.PSVariable.Set($variableName, $keyValuePair.Value)
            }
        }
    }
}

function Get-DynamicParamBlock
{
    param (
        [scriptblock] $ScriptBlock
    )

    if ($PSVersionTable.PSVersion.Major -le 2)
    {
        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $dynamicParams = [scriptblock].GetField('_dynamicParams', $flags).GetValue($ScriptBlock)

        if ($null -ne $dynamicParams)
        {
            return $dynamicParams.ToString()

        }
    }
    else
    {
        if ($null -ne $ScriptBlock.Ast.Body.DynamicParamBlock)
        {
            $statements = $ScriptBlock.Ast.Body.DynamicParamBlock.Statements |
                          & $SafeCommands['Select-Object'] -ExpandProperty Extent |
                          & $SafeCommands['Select-Object'] -ExpandProperty Text

            return $statements -join "`r`n"
        }
    }
}

function Get-MockDynamicParameters
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Cmdlet')]
        [string] $CmdletName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Function')]
        [string] $FunctionName,

        [Parameter(ParameterSetName = 'Function')]
        [string] $ModuleName,

        [hashtable] $Parameters,

        [object] $Cmdlet
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        'Cmdlet'
        {
            Get-DynamicParametersForCmdlet -CmdletName $CmdletName -Parameters $Parameters
        }

        'Function'
        {
            Get-DynamicParametersForMockedFunction -FunctionName $FunctionName -ModuleName $ModuleName -Parameters $Parameters -Cmdlet $Cmdlet
        }
    }
}

function Get-DynamicParametersForCmdlet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $CmdletName,

        [System.Collections.IDictionary] $Parameters
    )

    if ($null -eq $Parameters) { $Parameters = @{} }

    try
    {
        $command = & $SafeCommands['Get-Command'] -Name $CmdletName -CommandType Cmdlet -ErrorAction Stop

        if (@($command).Count -gt 1)
        {
            throw "Name '$CmdletName' resolved to multiple Cmdlets"
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    $cmdlet = & $SafeCommands['New-Object'] $command.ImplementingType.FullName
    if ($cmdlet -isnot [System.Management.Automation.IDynamicParameters])
    {
        return
    }

    $flags = [System.Reflection.BindingFlags]'Instance, Nonpublic'
    $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
    [System.Management.Automation.Cmdlet].GetProperty('Context', $flags).SetValue($cmdlet, $context, $null)

    foreach ($keyValuePair in $Parameters.GetEnumerator())
    {
        $property = $cmdlet.GetType().GetProperty($keyValuePair.Key)
        if ($null -eq $property -or -not $property.CanWrite) { continue }

        $isParameter = [bool]($property.GetCustomAttributes([System.Management.Automation.ParameterAttribute], $true))
        if (-not $isParameter) { continue }

        $property.SetValue($cmdlet, $keyValuePair.Value, $null)
    }

    try
    {
        # This unary comma is important in some cases.  On Windows 7 systems, the ActiveDirectory module cmdlets
        # return objects from this method which implement IEnumerable for some reason, and even cause PowerShell
        # to throw an exception when it tries to cast the object to that interface.

        # We avoid that problem by wrapping the result of GetDynamicParameters() in a one-element array with the
        # unary comma.  PowerShell enumerates that array instead of trying to enumerate the goofy object, and
        # everyone's happy.

        # Love the comma.  Don't delete it.  We don't have a test for this yet, unless we can get the AD module
        # on a Server 2008 R2 build server, or until we write some C# code to reproduce its goofy behavior.

        ,$cmdlet.GetDynamicParameters()
    }
    catch [System.NotImplementedException]
    {
        # Some cmdlets implement IDynamicParameters but then throw a NotImplementedException.  I have no idea why.  Ignore them.
    }
}

function Get-DynamicParametersForMockedFunction
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FunctionName,

        [string]
        $ModuleName,

        [System.Collections.IDictionary]
        $Parameters,

        [object]
        $Cmdlet
    )

    $mock = $mockTable["$ModuleName||$FunctionName"]

    if (-not $mock)
    {
        throw "Internal error detected:  Mock for '$FunctionName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    if ($mock.DynamicParamScriptBlock)
    {
        $splat = @{ 'P S Cmdlet' = $Cmdlet }
        return & $mock.DynamicParamScriptBlock @Parameters @splat
    }
}

function Test-IsClosure
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $sessionStateInternal = Get-ScriptBlockScope -ScriptBlock $ScriptBlock

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $module = $sessionStateInternal.GetType().GetProperty('Module', $flags).GetValue($sessionStateInternal, $null)

    return (
        $null -ne $module -and
        $module.Name -match '^__DynamicModule_([a-f\d-]+)$' -and
        $null -ne ($matches[1] -as [guid])
    )
}

# SIG # Begin signature block
# MIInYQYJKoZIhvcNAQcCoIInUjCCJ04CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDKj5s2LMFiGtKC
# IaBufK6LR1XvlPpTKnoQLrT6m6ns1qCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# gd60jJ+KncpwIndovKia4chj1l6DXqq59Tzts1nI5LUwUAYKKwYBBAGCNwoDHDFC
# DEAxRkM2RDUyOEIwRDFBMEU4MzYxN0YwQTJEQ0RGMEE3RTI1MDE4MEI0RUIyOTE1
# MEIxRDE2RDdBNzgwQ0Q5QTZDMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAQqp+aIb2xIeKNdQ0O6Er
# +GB5ZtXL6hXrLLzZ3zf2p5xnI18eC+wZlLWJHaW40rWuZgT7RTPTgNIyTS3ournr
# XANxuu5jdDgVG4t+2DE6Unj/EjO2oFG8NKKpjRF9uAIz8+hilr43eMEeJcv/GE36
# a3B7nYVz9DWllGGBN4ar5uxXSk/hVUySAJYkuCcWjwf3XYjNIvRdwcUiTnHZ9ge7
# peOHAeXLNCYNdAZ8NIUcOh6xEcrAQlw/VUWOJfPhRKWZPl6Xe9g2RRdcvpfM6D2x
# xhKizYNO0YdJHDzPQ+W30DFJmZ7EdAJQ5fboy92fyeubuhALY7gb6yifaMa/JPA8
# S6FEJjOiszyhh8Pr8W/vQc8zbPzmLpv26DEyj0DmndqX0jKRX0HKa5kpH5QMykqY
# QjunuHDyF90htBoOEk2N29R7PoplmKWr4wyS6tTBFRW6b8Tdxl+E0Lgy6ij3t0Pg
# jOphh/kQnEmsLBRUVIubD+gXhshWdTNjcqvQR6JZiVMAoYIXsDCCF6wGCisGAQQB
# gjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UCAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEINX+KeSY/gtnPAn98k9xFXceZBY0CZTLaXXlvQb+
# 2MSrAgZpvQH088YYEzIwMjYwNDExMTA1MzE2LjE3MVowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMCAQICEzMAAAIcCVUV18NZ
# B9EAAQAAAhwwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODMxWhcNMjYxMTEzMTg0ODMxWjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NkYxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjDTEQ
# BRoUjLIshd4XN4jwgrIE43a7QOvTYhITmn0bkJRd+cW7ZLQTWBYIy8NamilfqVHG
# OaCepovcG2daUFVOjzFQ1Fm7beJ7hgEwAkHtS3qaeqcdXC8MnEY7hMPdKesJ37KD
# fkH1AV6Orejj44HK9ePKdrKlnK6RxBouwpC+jETwSUcfvNw5cQlaZTeudfNpb9Lh
# Ifc4+GhRtNNzLqdSArHmlFaJDbhQQ8tjNzEYmOqOTP4aIJYY8UcMx1bzqVpa+YKy
# Wi5A+w3Z4GTx3ElwRmZbiXqnhO2Ghdx97EQD1h1hozPXRoyFk2l2w1oO0NBQwMQL
# eTUPUzLr0xdI+VSYP3EXIOWReJVrsEISnddxW2pODMcbCvbwkPqgTvMQ9h65k6K4
# IFdNlKj/CTe1sOWwRJsg9XqKdiqvPGIxiqXF8J3MLcKKaH381P8uT39pT4jLJz1v
# c5pPR1nzCAtpUMIYQtEyurIiZ0Ue/Qy51y3Nb+Q+xXclr25+kpa6MSI3cJb/9fyE
# Vr2PkiY15DNwyK3cyhJqgbCduJklfUjKJsimGWpxxcWTihNNI5AGwBTDxTSDA6cz
# lQkPyYFQF3rk2no0GTHZy+IngjfgbJcUJbLLkW3VCwFjJV8Abco6EJ88dB/yVDMm
# 8uvnthbRsP/FWzgCDiBNLopk3IUR9f2MV1GWvQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFFreY4LMHy7vOm8OHwwYpVgsKTtkMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCSVvrD915qJ3cG6NAK1YUF7Sf2mTJHL7LJYSDvSIPCgnm7R7Q77gZ6s3N1lvXN
# M+wcnwQYzKjUrvK0vbX6mZ0UxOXX08Lw4nljan5cpRDLZ0P6GCBEyYmANCyBs4LE
# dh476ODi36+DrXBSui/PMuQffPQ8lde+g24GP0t1r0KI0x3rTjnUq5t730CtJ/pk
# yPe3SnisVuBJrMOz7xMn7woDkZVpiM8eP2uUy4jdaOiERz1qmdDqEyMxyTeOUdkj
# CW5Vh5RATSqOYCl8y1MATNsxR1jywtO6cvUaRsNJ4qf07uWUEac23IzW4z0x2/VX
# JaHTP8iuJAoiOe2qobKgXQe8Mc4VkLJQME8t+XKK7tjXND+w+i6exv3poF9B2reH
# cs6fq36b0Sc3P8bozPNa+kmTpiBMdMip5A38X9emI+9t96Teer89hsvdq76QF9FQ
# eIIVdK+3qWivQcLrbq9SbP1k087HARYu5xyibGzLcnBYfv2+wz/sBGqgbmHp3o1q
# F9o65E/hcj3G10fc9r80IvJCPEpfIvHPBDON12RfYSlMmeXKm6E+YR15rn1TPYTf
# TcvHJdKcoG8awCfJZgB+d6OvdgCIv1is3aXZ2fX3xGkDgMKb1C1liLALSrZ+5S+6
# Lfg988hRkHJ/vAe65a7nSFj1YvHWQ4wjzHKjsAjpNo2ucjCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBaZOIDTW7mbGr+dXGJ
# Eksw6yRUZ6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7YR/ujAiGA8yMDI2MDQxMTA4MDcyMloYDzIwMjYwNDEy
# MDgwNzIyWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDthH+6AgEAMAoCAQACAgQQ
# AgH/MAcCAQACAhL7MAoCBQDthdE6AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBAGtUW9VEydBfRhuJtgoOp2Seqxx23TFnCL7CDahfjLkvdApdaY/7DFrBdIS+
# JUNCfiPSCWrm0+jXHZvuiUURqp9gFe1ArzsD6f0WxkFBDUpyGXfLXms5HXDwH3OZ
# RkLGUOXX/nSZf5P36bkdAEQBxKElUCuy2SslQERNt+/vUM+DdRPxivtkDTjxfNMO
# GWK/IFQE58NTe0L+mFsGV7nKfvOAQp4MCtz0zMlu6GS5uM8XRTuTXbTswn9mrPjy
# XVSNdRC4m1pnDIzzbccvZ022haVNB32THajIk7kFO4qGhRLRyliciLio0D3Dx/Vy
# g8HJV1WaGXdTXfpeiO+/jSs4ZIwxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhwJVRXXw1kH0QABAAACHDANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCAyKP0ohT65g57OQ6Wrlr0r5PvmpMHEwAvAXWApHoAWKDCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIKAgaSY2F2jv4oTt1aEj4TYK3HZEtahi+8mh0Ihy
# IcdoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIc
# CVUV18NZB9EAAQAAAhwwIgQgU2zur2hlshE06aQe09OiVlwz7hoY7SctN///KXOC
# qEYwDQYJKoZIhvcNAQELBQAEggIAkFUZkYky7aY4wcR+gqXQ3Gq7CUhqN5I8NzXS
# L5k0cX8Ps0Mg9dirjP/5G29/+O723/PNiP798S7nuP6bgajDNHHt3c2rRRCMo0VD
# JgK4znC2ZHV+H+T9XpfTPWFGGOEnsz9sCMCm2Dktu0MpUi2QuqOtwpIi9+4kTH+8
# xtyRgzghJZ3D965/z/2DzRa0OtalU7Ti4VfaKQrl7zXOdLhqbxQDo3iBFLhx2SRd
# cHkHgDUh5bnWSt30s9v5RYTiEASdRdE9NHw9Ul7GyKNeCboWmwpS7rXGsHVbpC2w
# EXPAsYtS9ogkQnRIuV8/xQD4FkZJtHeZKL9yFKzyXDm4eZxf9kJmQ+NP31ag1Swx
# MqL1INbRwpA7jOiZH3DkJt3e/o8NiRpdbDSXDLC8OqJ7eZwofU9aMUaf/FY1GihR
# cH0tmIXS0UaerujZwXCDhBG7f4KHnH6dKcLvzQOTQPL0IMQH/K6jpuhs1xvUpkLr
# lUIxD0JAfTydxGZvWyxGSfGcGarT+fSTuI1pBZQA+A0czD4CJvQo/FTK7gO6qSw3
# PiBgXxFl7CzCtIlTSe2eOpMy1kxGRjU4ALWp8pFLnOgWqm3HPQNsPONglN6JVIjy
# CNWbSpgtG+dg9J0+2/Y9KqLTHRZpyQ8oS4F2RfrNJOhLPEZsWs8/8YVPdTgF6Buu
# 7jdS0WY=
# SIG # End signature block
