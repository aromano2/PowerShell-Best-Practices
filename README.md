# PowerShell Scripting Standards and Best Practices

This repository contains comprehensive guides for writing readable, maintainable, and reliable PowerShell scripts and modules.

## Guides

### [Style-Guide.md](Style-Guide.md)
Covers automated code quality checks and formatting standards that can be enforced through PSScriptAnalyzer and consistent tooling:
- **Naming and Casing Standards** - PascalCase functions, camelCase variables, approved verb patterns
- **Approved Verbs** - How to use and validate PowerShell approved verbs
- **Code Formatting and Style** - Indentation, spacing, braces, line length, splatting
- **File Encoding** - UTF-8 BOM standards and end-of-file rules
- **PSScriptAnalyzer Configuration** - Setting up linting in CI/CD pipelines

### [Best-Practices.md](Best-Practices.md)
Provides practical conventions for writing robust, well-designed PowerShell code:
- **Comments and Documentation** - Documentation standards and comment-based help
- **Function Design** - Advanced functions, parameter validation, focused responsibilities
- **Error Handling and Reliability** - Try/catch patterns, error context, output practices
- **Pipeline and Performance** - Pipeline-friendly functions, filter-left-format-right
- **Security and Safety** - Secret handling, least privilege, `-WhatIf`/`-Confirm` support
- **Testing and Quality** - Pester testing strategies and coverage

## Quick Start

1. Review [Style-Guide.md](Style-Guide.md) to understand code style and formatting standards.
2. Review [Best-Practices.md](Best-Practices.md) for function design and reliability patterns.
3. Refer to the checklists in each guide during code review and development.
4. Integrate PSScriptAnalyzer into your CI pipeline using the configuration in Style-Guide.md.

## Additional Resources

- **Get-Verb** - PowerShell cmdlet to list approved verbs
- **Invoke-ScriptAnalyzer** - PSScriptAnalyzer cmdlet for linting
- **Pester** - PowerShell testing framework

---

## Detailed Guides

Below is the original combined guide. For specific topics, refer to the separate guides above.


### 11.5 Naming Conventions (Expanded)
- Commands/functions: `Verb-Noun` in PascalCase.
- Parameters: PascalCase (`-ComputerName`, `-Credential`).
- Local variables: camelCase.
- Script/global variables: include scope when needed (`$Script:cache`, `$Global:settings`).
- Acronyms in public names should be consistent (`Get-PSDrive`, `Get-ADUser`).

## 12) Best Practices Track (Template-Aligned)

### 12.1 Build Reusable Tools
- Design functions as tools first, scripts second.
- Accept input from pipeline and parameters.
- Output objects that other commands can consume.
- Separate business logic from host interaction.

### 12.2 Parameter Block Practices
- Always define parameter types.
- Use attributes deliberately:
  - `Mandatory`
  - `ValueFromPipeline`
  - `ValueFromPipelineByPropertyName`
  - `ValidateSet`, `ValidatePattern`, `ValidateScript`
- Group mutually exclusive actions using parameter sets.
- Provide sane defaults, but avoid hidden side effects.

Example parameter set design:
```powershell
param(
	[Parameter(Mandatory, ParameterSetName = 'ByName')]
	[string]$Name,

	[Parameter(Mandatory, ParameterSetName = 'ById')]
	[int]$Id
)
```

### 12.3 Output and Formatting
- Never format inside reusable commands (`Format-Table`, `Format-List`) unless the command's purpose is formatting.
- Emit one object "kind" per command whenever possible.
- Use `PSTypeName` and format files for module-level display customization.
- Use output streams correctly:
  - `Write-Output`: data
  - `Write-Verbose`: optional details
  - `Write-Debug`: maintainer diagnostics
  - `Write-Warning`: non-fatal issues
  - `Write-Error`: recoverable failures or surfaced exceptions
  - `Write-Progress`: live progress status

### 12.4 Error Handling Patterns
- Prefer `try/catch/finally` around logical transactions.
- Use `-ErrorAction Stop` on operations that must be trapped.
- Avoid relying on `$?` as your primary error strategy.
- Capture the active error early in catch blocks:
```powershell
catch {
	$err = $_
	Write-Error "Operation failed: $($err.Exception.Message)"
}
```

### 12.5 Performance Guidance
- Measure before optimizing:
```powershell
Measure-Command { Invoke-MyWorkload }
```
- Choose readability first until performance is proven to be an issue.
- Avoid loading huge files fully into memory unless necessary.
- Prefer streaming/pipeline processing for large data sets.
- Reduce repeated calls to remote systems inside loops.

### 12.6 Security Guidance (Expanded)
- Accept credentials as `[PSCredential]` parameters rather than prompting inside reusable functions.
- Never store plain text passwords in script source.
- When persistence is required, prefer secure storage patterns:
  - SecretManagement vaults
  - `Export-Clixml` for user/machine-scoped encrypted credentials
- Validate and sanitize external inputs (file paths, hostnames, user-provided filters).

### 12.7 Language, Interop, and .NET
- Use native PowerShell commands first.
- Use .NET APIs when they provide clear capability or performance benefits.
- Wrap complex .NET interop behind clear PowerShell functions.
- Keep interop boundary code isolated and well-tested.

### 12.8 Metadata, Versioning, and Packaging
- Version modules using semantic versioning where practical.
- Keep module manifests (`.psd1`) accurate:
  - `RootModule`
  - `ModuleVersion`
  - `FunctionsToExport`
  - `PrivateData` tags
- Document breaking changes in a changelog.
- Publish from CI where possible to keep release steps reproducible.

### 12.9 Put Reusable Functions Into a Module

If a function is used by multiple scripts, shared across teams, or expected to evolve over time, move it into a module.

Benefits:
- Centralized maintenance and versioning.
- Better discoverability with `Get-Command -Module <ModuleName>`.
- Clear public API boundaries through exports.
- Easier testing and CI publishing.

Recommended structure:
```text
MyTools\
	MyTools.psd1
	MyTools.psm1
	Public\
		Get-Widget.ps1
		Set-Widget.ps1
	Private\
		Resolve-WidgetPath.ps1
```

Implementation guidance:
- Put user-facing commands in `Public`.
- Put helper functions in `Private`.
- Dot-source files from `Public` and `Private` in `MyTools.psm1`.
- Export only public commands with `Export-ModuleMember`.
- Keep script files thin: orchestrate work by calling module functions.

Example `MyTools.psm1` pattern:
```powershell
Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 | ForEach-Object {
		. $_.FullName
}

Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 | ForEach-Object {
		. $_.FullName
}

Export-ModuleMember -Function @(
		'Get-Widget',
		'Set-Widget'
)
```

Manifest tips:
- Keep `FunctionsToExport` explicit (avoid `'*'` in mature modules).
- Update `ModuleVersion` on every release.
- Add tags in `PrivateData.PSData.Tags` for gallery searchability.
- Keep required module dependencies listed in `RequiredModules`.

When to keep a function in a script instead:
- One-off migration scripts.
- Extremely context-specific logic that is not expected to be reused.
- Throwaway automation where long-term maintenance is not needed.

## 13) Team Enforcement and Tooling

### PSScriptAnalyzer Baseline
Start with a shared settings file and enforce in CI.

Example CI command:
```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

### Formatting
- Use a formatter consistently in editor and CI.
- If using `Invoke-Formatter`, keep style settings committed to source control.
- Add editor settings (or `.editorconfig`) so files are saved with your agreed newline and encoding rules.

Recommended `.editorconfig` defaults for PowerShell files:
```ini
[*.{ps1,psm1,psd1}]
charset = utf-8-bom
end_of_line = crlf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4
```

### Test Strategy with Pester
- Unit tests for function logic and parameter validation.
- Integration tests for file system, remoting, and external system interactions.
- Tag slow tests so CI can split fast and full suites.

## 14) Pull Request Checklist

- Function names use approved verbs and clear nouns.
- No aliases in committed script logic.
- No positional parameters where named parameters improve clarity.
- No hardcoded credentials or secrets.
- Errors are intentionally handled and surfaced.
- Output is object-based and pipeline-friendly.
- Tests added or updated.
- ScriptAnalyzer warnings reviewed.
- Help and examples updated for behavior changes.
- Files end with a final newline.
- Script file encoding matches team standard (default: UTF-8 without BOM).

## 15) Copy/Paste Starters

### Advanced function starter
```powershell
function Invoke-TemplateAction {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	[OutputType([pscustomobject])]
	param(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential
	)

	begin {
		Set-StrictMode -Version Latest
	}

	process {
		if ($PSCmdlet.ShouldProcess($Name, 'Invoke template action')) {
			try {
				[pscustomobject]@{
					Name      = $Name
					Succeeded = $true
					Timestamp = Get-Date
				}
			}
			catch {
				$err = $_
				Write-Error "Invoke-TemplateAction failed for '$Name': $($err.Exception.Message)"
			}
		}
	}
}
```

### Script preamble starter
```powershell
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

## 16) Notes on Source Inspiration

This guide is inspired by the community structure used in PoshCode's PowerShell Practice and Style project and adapted into original wording for team use.

## 17) Repository Defaults (Recommended)

If your team has not chosen standards yet, start here:
- Encoding: UTF-8 without BOM
- Line endings: CRLF for Windows-focused repositories
- Final newline: required in all script/module/manifest files
- Indentation: 4 spaces
- Formatting enforcement: PSScriptAnalyzer plus editor configuration

