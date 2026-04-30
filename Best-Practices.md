# PowerShell Best Practices Guide

This guide provides practical conventions for writing readable, maintainable, and reliable PowerShell scripts and modules.

## 1) Comments and Documentation

### Comment intent, not the obvious
- Explain why something is done, especially for non-obvious logic.
- Remove stale comments quickly.

Good:
```powershell
# Retry logic: Some systems take 2-3 seconds to replicate the user object
# across all domain controllers before accepting auth attempts.
Start-Sleep -Seconds 3
```

Avoid:
```powershell
# Sleep for 3 seconds
Start-Sleep -Seconds 3
```

### Use comment-based help for reusable scripts/functions
- Reference: [about_Comment_Based_Help (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-7.6)

```powershell
<#
.SYNOPSIS
Gets user records from the local cache.

.DESCRIPTION
Loads and filters user records using the configured cache path.

.PARAMETER Path
Path to the cache file.

.EXAMPLE
Get-CachedUser -Path 'C:\Data\users.json'
#>
function Get-CachedUser
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	# Function body
}
```

### Documentation standards
- Add comment-based help for all exported functions.
- Include at least `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and one `.EXAMPLE`.
- Keep examples executable and realistic.
- Add inline comments only where intent is non-obvious.

### Use #Requires for module dependencies
- Declare module and PowerShell version requirements at the top of scripts and modules.
- Use `#Requires -Modules ModuleName` to enforce dependency modules.
- Use `#Requires -Version` to enforce minimum PowerShell version.
- Use `#Requires -RunAsAdministrator` if elevated privileges are mandatory.
- Place all `#Requires` statements at the very beginning of the file (before comment-based help).

Example:
```powershell
#Requires -Version 7.0
#Requires -Modules ActiveDirectory, Az.Accounts

<#
.SYNOPSIS
Syncs users from AD to Azure.

.DESCRIPTION
Connects to both Active Directory and Azure to synchronize user accounts.
Requires the ActiveDirectory and Az.Accounts modules.
#>

function Sync-UsersToAzure
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$SearchBase
	)

	# Function body
}
```

Benefits:
- Script fails immediately with clear error if dependencies are missing
- Documents module requirements upfront
- Prevents cryptic "cmdlet not found" errors during execution

### Avoid unnecessary comments
- Do not comment code that is self-explanatory.
- Remove commented-out code; use version control instead.
- Avoid restating what the code obviously does.

Good:
```powershell
# Validate that user exists before processing
$user = Get-ADUser -Identity $userName -ErrorAction Stop
```

Avoid:
```powershell
# Get the user
$user = Get-ADUser -Identity $userName -ErrorAction Stop

# Loop through the items
foreach ($item in $items)
{
	# Check if null
	if ($null -eq $item)
	{
		# Skip it
		continue
	}
}

# This code is commented out but might be useful later
# $result = Invoke-OldLogic -Path $filePath
```

### Use regions when appropriate
- Regions are useful for organizing large files with distinct sections.
- Use regions to group related code (classes, helper functions, public functions).
- Avoid regions if they hide code complexity—that's a sign to refactor instead.
- Keep region names clear and high-level.

Good use of regions (large module file):
```powershell
#region Private Functions
function Private-Helper1 { }
function Private-Helper2 { }
function Private-Helper3 { }
#endregion

#region Public Functions
function Get-Data { }
function Set-Data { }
function Remove-Data { }
#endregion

#region Initialization
$script:config = @{}
#endregion
```

Poor use of regions (small file or hiding complexity):
```powershell
#region Get user
$user = Get-ADUser -Identity $userName
#endregion

#region Process user
foreach ($item in $user) { }
#endregion
```

## 2) Function Design

### Use advanced functions for reusable logic
- Include `[CmdletBinding()]` for cmdlet-like behavior.
- Define explicit parameters and types.
- Use `SupportsShouldProcess` for destructive actions.

### Explicitly type all parameters
- Always declare a type for every parameter in the param block.
- Never use untyped parameters (e.g., `param($Name)` without `[string]`).
- Explicit types enable PowerShell to coerce and validate input automatically.
- Explicit types serve as documentation and improve code clarity.

Preferred (strongly typed):
```powershell
function Process-Items
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[int]$Timeout,

		[Parameter()]
		[switch]$Force
	)

	# Types are clear: string, int, boolean (switch)
}
```

Avoid (untyped or implicit types):
```powershell
function Process-Items
{
	param
	(
		$Path,           # Could be anything
		$Timeout,        # Could be anything
		$Force = $false  # Implicit type
	)
}
```

Common parameter types:
- `[string]` - Text
- `[int]`, `[long]`, `[double]` - Numbers
- `[bool]` - Boolean values
- `[switch]` - Boolean flag parameters
- `[array]` or `[object[]]` - Collections
- `[pscredential]` - Credentials
- `[datetime]` - Dates and times
- `[System.IO.FileInfo]` - File objects
- `[System.IO.DirectoryInfo]` - Directory objects
- Custom types - Classes or specific object types

### Prefer FileInfo/DirectoryInfo over string paths
- Use `[System.IO.FileInfo]` for file path parameters instead of `[string]`.
- Use `[System.IO.DirectoryInfo]` for directory path parameters instead of `[string]`.
- FileInfo and DirectoryInfo objects provide metadata and methods without extra parsing.
- PowerShell automatically converts string literals to these types.

Preferred (FileInfo for file paths):
```powershell
function Read-ConfigFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[System.IO.FileInfo]$ConfigPath
	)

	if (-not $ConfigPath.Exists)
	{
		throw "File not found: $($ConfigPath.FullName)"
	}

	$ConfigPath.FullName                # Full path
	$ConfigPath.DirectoryName            # Parent directory
	$ConfigPath.Name                     # File name only
	$ConfigPath.LastWriteTime            # Metadata available
	Get-Content -Path $ConfigPath        # Still works with string-accepting cmdlets
}
```

Less ideal (string path):
```powershell
function Read-ConfigFile
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$ConfigPath   # Just a string; need to check existence and parse manually
	)

	if (-not (Test-Path -Path $ConfigPath))
	{
		throw "File not found: $ConfigPath"
	}

	# Must parse the string to get directory, name, etc.
	[System.IO.Path]::GetDirectoryName($ConfigPath)
	[System.IO.Path]::GetFileName($ConfigPath)
}
```

Benefits:
- **Type safety**: Parameter is validated as a real file/directory object
- **Metadata access**: Properties like `Exists`, `FullName`, `LastWriteTime` available
- **Cleaner code**: No manual string parsing needed
- **Backward compatible**: PowerShell coerces string arguments to FileInfo automatically

### Validate input early
- Use validation attributes:
  - `[ValidateNotNullOrEmpty()]`
  - `[ValidateSet('Dev','Test','Prod')]`
  - `[ValidateRange(1,10)]`
- Reference: [Validating Parameter Input (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/validating-parameter-input?view=powershell-7.6)

Example:
```powershell
function Set-Environment
{
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Dev', 'Test', 'Prod')]
		[string]$Environment,

		[Parameter(Mandatory = $true)]
		[ValidateRange(1, 100)]
		[int]$Timeout,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ConfigPath
	)

	Write-Output "Setting $Environment with timeout $Timeout seconds"
}
```

### Mandatory attribute usage
- Only specify `Mandatory` as `Mandatory = $true`.
- Do not use shorthand forms like `[Parameter(Mandatory)]`.
- Omit `Mandatory` entirely for optional parameters.

Preferred:
```powershell
[Parameter(Mandatory = $true)]
[string]$Name
```

Avoid:
```powershell
[Parameter(Mandatory)]
[string]$Name
```

### Parameter defaults and boolean flags
- Do not add default values to required parameters—keep them mandatory.
- For optional boolean parameters, prefer `[switch]` over `[bool]` with a default.
- If you use `[bool]` parameters, explicitly set default values.
- Avoid implicit defaults like `$Force = $false` without a type.

Preferred (switch parameter):
```powershell
function Remove-Item
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter()]
		[switch]$Force    # No default needed; absent = $false, present = $true
	)

	# Use: Remove-Item -Path C:\temp
	# Or:  Remove-Item -Path C:\temp -Force
}
```

Avoid (boolean with implicit default):
```powershell
param
(
	[string]$Path,
	$Force = $false  # Type is implicit
)
```

Optional parameter with explicit default:
```powershell
[Parameter()]
[int]$Timeout = 30   # Optional, clearly defaults to 30
```

Guidelines:
- **Required parameters**: Always use `Mandatory = $true`, no default
- **Boolean toggles**: Use `[switch]` to keep it simple
- **Optional values**: Provide explicit defaults when parameters are optional
- **Avoid**: Don't default required parameters to make them "optional"

### Use parameter sets for mutually exclusive parameters
- Use parameter sets when a function needs to accept different combinations of parameters.
- Parameter sets enforce that only valid parameter combinations can be used together.
- Use `ParameterSetName` to group related parameters into sets.
- Mark parameters as `Mandatory = $true` within specific parameter sets, not globally.

When to use parameter sets:
```powershell
# Good: Get user by name OR by ID, but not both
function Get-User
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
		[string]$Name,

		[Parameter(Mandatory = $true, ParameterSetName = 'ById')]
		[int]$Id,

		[Parameter()]  # Available in all sets
		[switch]$Detailed
	)

	if ($PSCmdlet.ParameterSetName -eq 'ByName')
	{
		Get-ADUser -Identity $Name
	}
	else
	{
		Get-ADUser -Filter "ObjectGUID -eq '$Id'"
	}
}

# Usage:
# Get-User -Name 'john'
# Get-User -Id 12345
# Get-User -Name 'john' -Detailed
# Get-User -Name 'john' -Id 12345  # ERROR: Cannot use both
```

Avoid (no parameter sets - confusing and error-prone):
```powershell
function Get-User
{
	param
	(
		[string]$Name,
		[int]$Id,
		[switch]$Detailed
	)

	# Caller could pass both $Name and $Id, creating ambiguity
	# Function must check which was provided
	if ($Name -and $Id)
	{
		throw "Cannot specify both Name and Id"  # Runtime error
	}

	# No IDE help about which combinations are valid
}
```

Benefits of parameter sets:
- **Compile-time validation**: PowerShell prevents invalid parameter combinations
- **Better IntelliSense**: IDEs show only valid parameters for each set
- **Cleaner code**: Logic is clear about which parameters go together
- **Self-documenting**: Function signature shows valid usage patterns

### Keep functions focused
- One function should do one clear task.
- Compose larger workflows from smaller functions.

Example—Single responsibility:
```powershell
# Do one thing well
function Get-UserInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$UserName
	)

	Get-ADUser -Identity $UserName -Properties DisplayName, Department, Manager
}

function Export-UserInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$UserName,

		[Parameter(Mandatory = $true)]
		[string]$OutputPath
	)

	$user = Get-UserInfo -UserName $UserName
	$user | Export-Csv -Path $OutputPath -NoTypeInformation
}
```

### Advanced function structure
- Reference: [about_Functions_Advanced_Parameters (Microsoft Learn)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.6)
- Prefer advanced functions with explicit blocks: `param`, `begin`, `process`, `end`.
- Keep the declaration order predictable:
  1. Attributes and `CmdletBinding`
  2. `param` block
  3. `begin`
  4. `process`
  5. `end`
- If pipeline input is supported, put per-item work in `process`.
- Avoid large monolithic functions; split responsibilities into private helper functions.

Recommended skeleton:
```powershell
function Get-Example
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$Name
	)

	begin
	{
		# Initialize expensive resources once.
	}

	process
	{
		# Handle one pipeline item at a time.
	}

	end
	{
		# Finalize or flush buffered work.
	}
}
```

### Avoid unnecessary begin/process/end blocks
- Only use `begin`, `process`, and `end` blocks when they serve a purpose.
- Simple functions without pipeline input or initialization don't need these blocks.
- Extra blocks add cognitive overhead and make code harder to read.

Use simple function body when:
```powershell
# Simple lookup function—no pipeline input, no initialization needed
function Get-UserInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$UserName
	)

	Get-ADUser -Identity $UserName -Properties DisplayName, Department, Manager
}
```

Use begin/process/end only when:
```powershell
# Pipeline-aware function with initialization
function Get-FileSize
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$Path
	)

	begin
	{
		# Initialize once for all pipeline items
		$totalSize = 0
	}

	process
	{
		# Handle each pipeline item
		$file = Get-Item -Path $_ -ErrorAction Stop
		$totalSize += $file.Length
	}

	end
	{
		# Report final result
		Write-Output "Total size: $totalSize bytes"
	}
}
```

## 3) Error Handling and Reliability

### Use terminating errors when appropriate
- Set `-ErrorAction Stop` for operations you want to catch.
- Wrap risky operations in `try/catch/finally` **only when you have recovery logic** in the catch or finally block.
- If you have no catch/finally logic, use `-ErrorAction Stop` alone—it's cleaner and prevents unnecessary nesting.
- Re-throw when the caller should decide how to handle the failure.
- Add context when re-throwing so logs remain actionable.

Only use try/catch if you have recovery logic:
```powershell
try
{
	$content = Get-Content -Path $filePath -ErrorAction Stop
}
catch
{
	Write-Error "Failed to read file '$filePath'. $_"
	return
}
```

Skip try/catch if there's no recovery needed:
```powershell
# Good: Just use -ErrorAction Stop, no try/catch needed
$content = Get-Content -Path $filePath -ErrorAction Stop
$data = $content | ConvertFrom-Json -ErrorAction Stop
```

Avoid (unnecessary try/catch):
```powershell
# Bad: No catch logic, just letting it fail anyway
try
{
	$content = Get-Content -Path $filePath -ErrorAction Stop
}
catch
{
	# Empty catch or just re-throwing
}
```

Preferred rethrow pattern (has recovery logic):
```powershell
try
{
	Invoke-ExternalStep -ErrorAction Stop
}
catch
{
	$err = $_
	throw "Invoke-ExternalStep failed for '$filePath': $($err.Exception.Message)"
}
```

### Avoid wrapping entire scripts in try/catch
- Do not wrap your whole script or function in a single `try/catch` block.
- Only wrap the specific operations that might fail and need recovery.
- Broad try/catch blocks hide errors, make debugging harder, and prevent proper error propagation.
- Let errors bubble up unless you have a specific recovery strategy.

Avoid (blanket try/catch):
```powershell
try
{
	$users = Get-ADUser -Filter * -Properties DisplayName
	$users | ForEach-Object {
		$group = Get-ADGroup -Identity "Group_$($_.Name)"
		Add-ADGroupMember -Identity $group -Members $_
	}
	Write-Output "All users added"
}
catch
{
	Write-Error "Operation failed: $_"
	exit 1
}
```

Preferred (targeted try/catch):
```powershell
$users = @(Get-ADUser -Filter * -Properties DisplayName -ErrorAction Stop)

foreach ($user in $users)
{
	try
	{
		$group = Get-ADGroup -Identity "Group_$($user.Name)" -ErrorAction Stop
		Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
	}
	catch
	{
		Write-Error "Failed to add user '$($user.Name)' to group: $($_.Exception.Message)"
		continue  # Try next user instead of failing everything
	}
}

Write-Output "User group assignment complete"
```

Best approach (let errors propagate):
```powershell
# For critical operations where any error should stop execution, just use -ErrorAction Stop
# Let the error propagate naturally; the caller decides how to handle it

$users = @(Get-ADUser -Filter * -Properties DisplayName -ErrorAction Stop)

foreach ($user in $users)
{
	# If this fails, the error propagates up; the caller's try/catch handles it
	$group = Get-ADGroup -Identity "Group_$($user.Name)" -ErrorAction Stop
	Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
}

Write-Output "User group assignment complete"
```

Then the caller can handle it if needed:
```powershell
try
{
	& .\Add-UsersToGroups.ps1
}
catch
{
	Write-Error "Failed to add users: $($_.Exception.Message)"
	exit 1
}
```

Guidelines:
- Wrap **only the operations that might fail and need recovery**
- Use `continue` or `return` in catch to handle errors gracefully without stopping everything
- If an error should stop the entire script, let it propagate—don't catch it
- Place catch blocks as close as possible to the failing code for clarity
- **Prefer letting errors propagate** when the caller should decide what to do with them

### Output practices
- Use pipeline output for data (not `Write-Host` for data).
- Use `Write-Verbose`, `Write-Warning`, and `Write-Error` for messaging.
- Return objects, not formatted strings.
- Prefer `[pscustomobject]` for structured output.

Example:
```powershell
function Get-ProcessInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$ProcessName
	)

	$proc = Get-Process -Name $ProcessName -ErrorAction Stop
	Write-Verbose "Found process $ProcessName"

	# Return structured object for pipeline
	[pscustomobject]@{
		Name         = $proc.Name
		Id           = $proc.Id
		MemoryMB     = [math]::Round($proc.WorkingSet / 1MB, 2)
		ThreadCount  = $proc.Threads.Count
		StartTime    = $proc.StartTime
	}
}
```

## 4) Pipeline and Performance Practices

### Make pipeline-friendly functions
- Accept pipeline input when it makes sense.
- Support property-by-name binding where useful.

Example:
```powershell
function Get-FileInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$Path
	)

	process
	{
		Get-Item -Path $Path -ErrorAction Stop
	}
}

# Can now be used in pipeline:
Get-ChildItem -Path 'C:\temp' | Get-FileInfo
```

### Filter left, format right
- Filter data as early as possible.
- Use `Format-Table` and `Format-List` only for final display.

Good:
```powershell
# Filter at the source
Get-Process | Where-Object { $_.CPU -gt 10 } | Select-Object Name, CPU
```

Avoid:
```powershell
# Load everything, format it all
Get-Process | Format-Table Name, CPU, Memory | Where-Object { $_.CPU -gt 10 }
```

### Avoid unnecessary loops and calls
- Minimize external command calls in tight loops.
- Cache reusable values when possible.

Good:
```powershell
$users = @(Get-ADUser -Filter * -Properties DisplayName)
foreach ($user in $users)
{
	if ($user.DisplayName -like '*Admin*')
	{
		$user
	}
}
```

Avoid:
```powershell
foreach ($user in 1..1000)
{
	# Calls Get-ADUser 1000 times!
	Get-ADUser -Filter "ID -eq $user"
}
```

### Prefer manual looping for readability
- Use explicit `foreach` loops when it makes the intent clearer.
- Avoid chaining multiple pipeline operators if simpler logic is more readable.
- Pipelines are powerful, but readability matters more than brevity.

Clear loop (easy to follow):
```powershell
$results = @()
foreach ($item in $items)
{
	if ($item.IsActive)
	{
		$status = Invoke-Check -Item $item -ErrorAction Stop
		if ($status.Success)
		{
			$results += [pscustomobject]@{
				Item   = $item.Name
				Status = $status.Code
				Time   = Get-Date
			}
		}
	}
}

$results
```

Compact pipeline (harder to follow):
```powershell
$items | Where-Object IsActive | ForEach-Object { Invoke-Check -Item $_ -ErrorAction Stop } | Where-Object Success | ForEach-Object { [pscustomobject]@{ Item = $_.Name; Status = $_.Code; Time = Get-Date } }
```

Use pipelines when:
- The intent is immediately clear (e.g., `Get-Process | Where-Object CPU -gt 10`)
- Chaining 1-2 operations
- The data flow is linear and simple

Use explicit loops when:
- Multiple conditions or transformations
- Complex error handling needed
- Variable assignments in the middle of logic
- The loop body is more than one line

## 5) Security and Safety

### Handle secrets carefully
- Do not hardcode secrets in scripts.
- Prefer SecretManagement, secure vaults, or environment-backed secure retrieval.

Example using SecretManagement:
```powershell
# Store secret securely (one time)
$cred = Get-Credential
$cred | Export-CliXml -Path "$env:APPDATA\MyApp\cred.xml" -Force

# Later, retrieve it safely
function Connect-Database
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Server
	)

	$cred = Import-CliXml -Path "$env:APPDATA\MyApp\cred.xml"
	$userName = $cred.UserName
	$password = $cred.GetNetworkCredential().Password

	Invoke-Sqlcmd -ServerInstance $Server -Credential $cred
}
```

### Never use plain text passwords
- Never hardcode passwords as plain text strings in function parameters or script variables.
- Never pass passwords as `[string]` parameters.
- Always use `[pscredential]` or `[System.Management.Automation.PSCredential]` for authentication.
- The credential object securely handles password encoding and prevents accidental exposure in logs or transcripts.

Preferred:
```powershell
function Connect-Service
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[pscredential]$Credential
	)

	$userName = $Credential.UserName
	$password = $Credential.GetNetworkCredential().Password
	# Use securely
}
```

Avoid:
```powershell
function Connect-Service
{
	param
	(
		[string]$UserName,
		[string]$Password  # Never do this
	)
}
```

### Least privilege
- Run with minimum required permissions.
- Avoid forcing admin unless truly necessary.

Example:
```powershell
function Invoke-PrivilegedOperation
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Target
	)

	# Only elevate for the operation that truly needs it
	if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
	{
		throw "This operation requires administrator privileges. Please run as administrator."
	}

	# Proceed with minimal assumption of elevated rights
	Write-Verbose "Running privileged operation on $Target"
}
```

### Safe changes
- For destructive commands, implement `-WhatIf` and `-Confirm` support using `SupportsShouldProcess`.

Example:
```powershell
function Remove-OldFile
{
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[int]$DaysOld = 30
	)

	$files = @(Get-ChildItem -Path $Path -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) })

	foreach ($file in $files)
	{
		if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove file'))
		{
			Remove-Item -Path $file.FullName -Force
		}
	}
}
```

## 6) Testing and Quality

### Write tests with Pester
- Reference: [Pester Quick Start](https://pester.dev/docs/quick-start)
- Write unit tests for core logic.
- Add integration tests for environment-dependent behavior.
- Cover `ShouldProcess` behavior for commands that support `-WhatIf` and `-Confirm`.
- Include tests for invalid parameter input and error paths.

Example:
```powershell
Describe 'Get-ProcessInfo' {
	Context 'Valid input' {
		It 'Returns a process object for existing process' {
			$result = Get-ProcessInfo -ProcessName 'powershell'
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'powershell'
			$result | Should -HaveProperty 'MemoryMB'
		}
	}

	Context 'Invalid input' {
		It 'Throws error when process does not exist' {
			{ Get-ProcessInfo -ProcessName 'NonExistentProcess12345' } | Should -Throw
		}

		It 'Throws error when ProcessName is empty' {
			{ Get-ProcessInfo -ProcessName '' } | Should -Throw
		}
	}

	Context 'Error handling' {
		It 'Outputs structured custom object' {
			$result = Get-ProcessInfo -ProcessName 'powershell'
			$result | Should -BeOfType 'System.Management.Automation.PSCustomObject'
		}
	}
}
```
