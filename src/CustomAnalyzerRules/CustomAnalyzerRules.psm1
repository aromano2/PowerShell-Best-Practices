#Requires -Version 4.0

# Import Localized Data
Import-LocalizedData -BindingVariable localizedData

Import-PSScriptAnalyzer

$script:diagnosticRecordType = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
$script:diagnosticRecord = @{
    Message  = ''
    Extent   = $null
    RuleName = $PSCmdlet.MyInvocation.InvocationName
    Severity = 'Information'
}

<#
    .SYNOPSIS
        Returns a list of the automatic and preference variables (and the Node variable for DSC coverage)
        that are PascalCase and should be filtered out of the tests to check against camelCase variables

    .EXAMPLE
        $psVariableList = Get-PsVariableList

    .OUTPUTS
        [array]

    .NOTES
        Used in the CustomAnalyzerRules module and tests file to filter out
        automatic and preference variables from camelCase variable test
#>
function Get-PsVariableList
{
    [CmdletBinding()]
    [OutputType([array])]
    param ()

    return [array]@(
        '$', '?', '^', '_', 'Allnodes', 'Args', 'ConfirmPreference', 'ConsoleFileName', 'DebugPreference',
        'Error', 'ErrorActionPreference', 'ErrorView', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext',
        'FALSE', 'ForEach', 'FormatEnumerationLimit', 'Home', 'Host', 'Input', 'LastExitCode', 'LogCommandHealthEvent',
        'LogCommandLifecycleEvent', 'LogEngineHealthEvent', 'LogEngineLifecycleEvent', 'LogProviderHealthEvent',
        'LogProviderLifecycleEvent', 'Matches', 'MaximumAliasCount', 'MaximumDriveCount', 'MaximumErrorCount',
        'MaximumFunctionCount', 'MaximumHistoryCount', 'MaximumVariableCount', 'MyInvocation', 'NestedPromptLevel',
        'NULL', 'OFS', 'OFS', 'OutputEncoding', 'PID', 'Profile', 'ProgressPreference', 'PSBoundParameters',
        'PsCmdlet', 'PSCommandPath', 'PsCulture', 'PSDebugContext', 'PSEmailServer', 'PsHome', 'PSitem',
        'PSModuleAutoloading', 'PSScriptRoot', 'PSSenderInfo', 'PSSessionApplicationName', 'PSSessionConfigurationName',
        'PSSessionOption', 'PsUICulture', 'PsVersionTable', 'Pwd', 'Sender', 'ShellID', 'SourceArgs', 'SourceEventArgs',
        'StackTrace', 'This', 'TRUE', 'VerbosePreference', 'WarningPreference', 'WhatIfPreference', 'Node'
    )
}

<#
.SYNOPSIS
    Validates the [CmdletBinding()] attribute for each parameter.

.DESCRIPTION
    All parameters must contain a [CmdletBinding()] attribute.

.PARAMETER ParamBlockAst
    The AST representing the param statement in a script block.

.EXAMPLE
    Measure-CmdletBindingAttribute -ParamBlockAst $ParamBlockAst.

.INPUTS
    [System.Management.Automation.Language.ParamBlockAst]

.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    None
#>

function Measure-CmdletBindingAttribute
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ParamBlockAst]
        $ParamBlockAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $ParamBlockAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName
        [System.Boolean] $inAClass = Test-IsInClass -Ast $ParamBlockAst

        <#
            If we are in a class the parameter attributes are not valid in Classes
            the ParameterValidation attributes are however
        #>

        if (-not $inAClass)
        {
            if ($ParamBlockAst.Attributes.TypeName.FullName -notcontains 'CmdletBinding')
            {
                $script:diagnosticRecord['Message'] = $localizedData.CmdletBindingAttributeMissing
                $script:diagnosticRecord -as $script:diagnosticRecordType
            }

            elseif ($ParamBlockAst.Attributes.TypeName.FullName -contains 'CmdletBinding')
            {
                $collection = $ParamBlockAst.Attributes.TypeName.FullName

                foreach ($item in $collection)
                {
                    if (($item -contains 'CmdletBinding') -and ($item -cne 'CmdletBinding'))
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.CmdletBindingAttributeLowerCase
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }
            }
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
.SYNOPSIS
    Check Parameters in PowerShell to make sure they are following expected Style Guidelines.

.DESCRIPTION
    Parameter names should use a consistent capitalization style, i.e. : PascalCase for Parameters.

.PARAMETER ScriptBlockAST
    An abstract base class for all PowerShell abstract syntax tree (AST) nodes and is a collection of statements from the scanned script.

.EXAMPLE
    Measure-ParameterCase -ScriptBlockAst $ScriptBlockAst

.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]

.OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    https://msdn.microsoft.com/en-us/library/dd878270(v=vs.85).aspx
    https://msdn.microsoft.com/en-us/library/ms229043(v=vs.110).aspx
#>

function Measure-ParameterCase
{
    #Predicates are being used and are not fully a function so no need for cmdletbinding
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process
    {
        try
        {
            $script:parameterArray = @()
            $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

            #Check for PascalCase on the defined parameters.
            [ScriptBlock] $checkParameterBlock =
            {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )
                [bool] $returnValue = $false

                if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst])
                {
                    if ($Ast.Parent.Attributes.TypeName.FullName -eq 'Parameter')
                    {
                        $script:parameterArray += $Ast.Extent.Text
                        if ($Ast.Extent.Text -cnotmatch '^[$|@][A-Z]')
                        {
                            $returnValue = $true
                        }
                    }
                }
                return $returnValue
            }

            #Check for PascalCase on parameters used in body of script.
            [ScriptBlock] $checkParametersMainScript =
            {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )
                [bool] $returnValue = $false

                if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst])
                {
                    if ($script:parameterArray -contains $Ast.Extent.Text)
                    {
                        if ($Ast.Parent.Attributes.TypeName.FullName -notcontains 'Parameter')
                        {
                            if ($Ast.Extent.Text -cnotmatch '^[$|@][A-Z]')
                            {
                                $returnValue = $true
                            }
                        }
                    }
                }
                return $returnValue
            }

            #Check the ast to verify it is the root node and if so find matches to the predicates.
            if ($null -ne $ScriptBlockAst.ParamBlock -or $ScriptBlockAst.EndBlock -notcontains 'param' -and (-not($ScriptBlockAst.Parent)))
            {
                [System.Management.Automation.Language.Ast[]]$parameterBlockViolations = $ScriptBlockAst.FindAll($checkParameterBlock, $true)
                [System.Management.Automation.Language.Ast[]]$parameterScriptViolations = $ScriptBlockAst.FindAll($checkParametersMainScript, $true)

                if ($parameterBlockViolations.Count -ne 0)
                {
                    foreach ($parameterBlockViolation in $parameterBlockViolations)
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.ParameterNotPascalCase
                        $script:diagnosticRecord['Extent'] = $parameterBlockViolation.Extent
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }

                if ($parameterScriptViolations.Count -ne 0)
                {
                    foreach ($parameterScriptViolation in $parameterScriptViolations)
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.ParameterNotPascalCase
                        $script:diagnosticRecord['Extent'] = $parameterScriptViolation.Extent
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

<#
.SYNOPSIS
    Check Variables in PowerShell to make sure they are following expected Style Guidelines.

.DESCRIPTION
    Variable names should use a consistent capitalization style, i.e. : camelCase for Variables.

.PARAMETER ScriptBlockAST
    An abstract base class for all PowerShell abstract syntax tree (AST) nodes and is a collection of statements from the scanned script.

.EXAMPLE
    Measure-VariableCase -ScriptBlockAst $ScriptBlockAst

.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]

.OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    https://msdn.microsoft.com/en-us/library/dd878270(v=vs.85).aspx
    https://msdn.microsoft.com/en-us/library/ms229043(v=vs.110).aspx
#>

function Measure-VariableCase
{
    #Predicates are being used and are not fully a function so no need for cmdletbinding
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process
    {
        try
        {
            $script:parameterArray = @()
            $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

            #Check for camelCase on variables.
            [ScriptBlock] $checkVariable =
            {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )
                [bool] $returnValue = $false

                # List of automatic and preference variables (with Node added in for DSC coverage) to ignore in camelCase rule
                $psVariableList = Get-PsVariableList

                if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst])
                {
                    if ($Ast.Parent.Attributes.TypeName.FullName -eq 'Parameter')
                    {
                        $script:parameterArray += $Ast.Extent.Text
                    }
                    if ($script:parameterArray -notcontains $Ast.Extent.Text)
                    {
                        if ($psVariableList -notcontains $Ast.Extent.Text.Substring(1))
                        {
                            if ($Ast.Extent.Text -cnotmatch '^[$|@][a-z]')
                            {
                                $returnValue = $true
                            }
                        }
                    }
                }
                return $returnValue
            }

            #Check the ast to verify it is the root node and if so find matches to the predicates.
            if ($null -ne $ScriptBlockAst.ParamBlock -or $ScriptBlockAst.EndBlock -notcontains 'param' -and (-not($ScriptBlockAst.Parent)))
            {
                [System.Management.Automation.Language.Ast[]]$variableViolations = $ScriptBlockAst.FindAll($checkVariable, $true)

                if ($variableViolations.Count -ne 0)
                {
                    foreach ($variableViolation in $variableViolations)
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.VariableNotCamelCase
                        $script:diagnosticRecord['Extent'] = $variableViolation.Extent
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

<#
.SYNOPSIS
    Check Parameter Attributes in PowerShell to make sure they are following expected Style Guidelines.

.DESCRIPTION
    Parameter Attributes should use a consistent capitalization style, i.e. : PascalCase.

.PARAMETER ScriptBlockAST
    An abstract base class for all PowerShell abstract syntax tree (AST) nodes and is a collection of statements from the scanned script.

.EXAMPLE
    Measure-ParameterAttribute -ScriptBlockAst $ScriptBlockAst

.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]

.OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    https://msdn.microsoft.com/en-us/library/dd878270(v=vs.85).aspx
    https://msdn.microsoft.com/en-us/library/ms229043(v=vs.110).aspx
#>

function Measure-ParameterAttribute
{
    #Predicates are being used and are not fully a function so no need for cmdletbinding
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process
    {
        try
        {
            $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

            #region Define predicates to find ASTs.
            [ScriptBlock]$checkParameterAttributesNamed = {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )
                [bool]$returnValue = $false

                if ($Ast -is [System.Management.Automation.Language.ParameterAst])
                {
                    if ($Ast.Attributes.NamedArguments.ArgumentName -cnotmatch '^[A-Z]')
                    {
                        $returnValue = $true
                    }
                }
                return $returnValue
            }

            [ScriptBlock]$checkParameterAttributesTypeName = {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )
                [bool]$returnValue = $false

                if ($Ast -is [System.Management.Automation.Language.ParameterAst])
                {
                    if ($Ast.Attributes.TypeName.Name -cnotmatch '^[A-Z]')
                    {
                        $returnValue = $true
                    }
                }
                return $returnValue
            }

            #endregion
            #region Finds ASTs that match the predicates.
            if ($null -ne $ScriptBlockAst.ParamBlock -or $ScriptBlockAst.EndBlock -notcontains 'param' -and (-not($ScriptBlockAst.Parent)))
            {
                [System.Management.Automation.Language.Ast[]]$parameterAttributesNamedViolations = $ScriptBlockAst.FindAll($checkParameterAttributesNamed, $true)
                [System.Management.Automation.Language.Ast[]]$parameterAttributesTypeNameViolations = $ScriptBlockAst.FindAll($checkParameterAttributesTypeName, $true)

                if ($parameterAttributesNamedViolations.Count -ne 0)
                {
                    foreach ($parameterAttributesNamedViolation in $parameterAttributesNamedViolations)
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.ParameterAttributeNotPascalCase
                        $script:diagnosticRecord['Extent'] = $parameterAttributesNamedViolation.Extent
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }

                if ($parameterAttributesTypeNameViolations.Count -ne 0)
                {
                    foreach ($parameterAttributesTypeNameViolation in $parameterAttributesTypeNameViolations)
                    {
                        $script:diagnosticRecord['Message'] = $localizedData.ParameterAttributeNotPascalCase
                        $script:diagnosticRecord['Extent'] = $parameterAttributesTypeNameViolation.Extent
                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }
            }
        } #endregion

        catch
        {
            $psCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
