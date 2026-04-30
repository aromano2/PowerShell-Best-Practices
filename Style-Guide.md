# PowerShell Linting and Code Standards

This guide covers automated code quality checks and formatting standards that can be enforced through PSScriptAnalyzer and consistent tooling.

## 1) Naming and Casing Standards

### Use PascalCase for commands and functions
- Prefer `Get-ServerInfo`, `Set-ConfigValue`, `Invoke-Backup`.
- Avoid `get-serverinfo`, `getServerInfo`, or `get_server_info` for function names.

### Use approved verb-noun naming
- Follow the `Verb-Noun` pattern for functions and scripts.
- Use singular nouns when possible: `Get-User`, not `Get-Users`.
- Keep nouns specific and consistent across a project.

### Function naming
- Function names must always use singular nouns.
- Never use plural nouns in function names.
- Prefer `Get-Service` over `Get-Services`.
- This aligns with PowerShell command naming conventions and improves discoverability.

### Variable naming style

#### Parameters in the param block
- Use PascalCase for parameters: `$UserName`, `$RetryCount`, `$ConfigurationPath`.
- PascalCase signals that these are formal function parameters with explicit types and validation.

Example:
```powershell
param
(
	[pscredential]$Credential,
	[int]$RetryCount,
	[string]$ConfigurationPath
)
```

#### Inline variables
- Use camelCase for local variables defined within the function body: `$userName`, `$retryCount`, `$configurationPath`.
- Use meaningful names over short names: `$configurationPath` is better than `$cp`.
- Use all caps only for environment variables or constants when needed.

Example:
```powershell
$userName = $Credential.UserName
$currentCount = $RetryCount - 1
$fullPath = Join-Path -Path $PSScriptRoot -ChildPath $ConfigurationPath
```

### Boolean and collection naming
- Name booleans as predicates: `$isEnabled`, `$hasAccess`, `$shouldRetry`.
- Use plural names for collections: `$servers`, `$modules`, `$results`.

### Keyword capitalization
- Use lowercase for all PowerShell language keywords: `param`, `if`, `else`, `foreach`, `switch`, `try`, `catch`, `finally`, `return`.
- Keep keyword casing consistent even though PowerShell is case-insensitive.

Preferred:
```powershell
if ($isEnabled)
{
	foreach ($item in $items)
	{
		return $item
	}
}
```

Avoid:
```powershell
If ($isEnabled)
{
	ForEach ($item in $items)
	{
		Return $item
	}
}
```

## 2) Approved Verbs

### Why it matters
- Approved verbs improve discoverability with `Get-Command`.
- They align your scripts with built-in PowerShell commands.

### Check approved verbs
```powershell
Get-Verb
```

### Common verb choices
- Retrieve data: `Get`
- Create resources: `New`
- Modify resources: `Set`
- Delete resources: `Remove`
- Execute an action: `Invoke`
- Test state or validity: `Test`
- Convert data: `ConvertTo`, `ConvertFrom`

### Avoid unapproved verbs
- Avoid verbs like `Fetch`, `Grab`, `Do`, `Run` unless no approved verb fits.
- Prefer `Get` over `Fetch`, `Invoke` over `Do`.

## 3) Code Formatting and Style

### Indentation and spacing
- Use 4 spaces for indentation.
- Keep one space around operators when readable:
```powershell
$total = $count + $offset
```

### Braces and blocks
- Put opening braces on the same line as keywords or function declarations.
- Put closing braces on their own line.
- Keep blocks consistently formatted.

### Line length
- Keep lines reasonably short (commonly 100 to 120 chars).
- For long commands, use splatting instead of backticks.

### Prefer splatting over backticks
```powershell
$params = @{
	Path        = $path
	Filter      = '*.log'
	ErrorAction = 'Stop'
}

Get-ChildItem @params
```
instead of:
```powershell
Get-ChildItem `
	-Path $path `
	-Filter '*.log' `
	-ErrorAction 'Stop'
```

### File encoding and end-of-file rules
- End every `.ps1`, `.psm1`, and `.psd1` file with exactly one newline.
- Use UTF-8 without BOM across the repository.
- If legacy tooling requires BOM, document that exception in your repo and enforce it only where needed.
- Never mix encodings in one repository.

Quick check examples:
```powershell
# Save without BOM
Set-Content -Path .\Script.ps1 -Value $content -Encoding utf8NoBOM

# In PowerShell 7+, utf8 is no BOM by default
Set-Content -Path .\Script.ps1 -Value $content -Encoding utf8
```

### Spacing and formatting details
- Avoid trailing spaces.
- Use one space after commas and around binary operators.
- Avoid semicolons as line terminators unless you intentionally need multiple statements on one line.
- Keep formatting changes separate from logic changes in source control.

### Code layout consistency
- Use one consistent brace style throughout the repository.
- Include one trailing newline at the end of each file.
- Enforce file encoding consistently across the repository.

## 4) VS Code `settings.json` Style Overrides

The workspace uses explicit PowerShell formatting overrides in `.vscode/settings.json`.

Current settings:
```json
{
	"[powershell]": {
		"editor.tabSize": 4,
		"editor.insertSpaces": true,
		"editor.formatOnSave": false,
		"editor.defaultFormatter": "ms-vscode.powershell",
		"files.eol": "\r\n",
		"files.encoding": "utf8",
		"files.autoGuessEncoding": false
	},
	"powershell.codeFormatting.preset": "Allman",
	"powershell.codeFormatting.newLineAfterOpenBrace": true,
	"powershell.codeFormatting.newLineAfterCloseBrace": true,
	"powershell.codeFormatting.openBraceOnSameLine": false,
	"powershell.codeFormatting.whitespaceBeforeOpenBrace": true,
	"powershell.codeFormatting.whitespaceBeforeOpenParen": true,
	"powershell.codeFormatting.whitespaceAroundOperator": true,
	"powershell.codeFormatting.whitespaceAfterSeparator": true,
	"powershell.codeFormatting.whitespaceBetweenParameters": true,
	"powershell.codeFormatting.whitespaceInsideBrace": true,
	"powershell.codeFormatting.ignoreOneLineBlock": false,
	"powershell.codeFormatting.alignPropertyValuePairs": true,
	"powershell.codeFormatting.useCorrectCasing": true,
	"powershell.codeFormatting.autoCorrectAliases": true,
	"powershell.codeFormatting.trimWhitespaceAroundPipe": false,
	"powershell.codeFormatting.useConstantStrings": true,
	"powershell.codeFormatting.pipelineIndentationStyle": "IncreaseIndentationForFirstPipeline"
}
```

Use `Examples/VSCodeSettings.ps1` to test these settings:
- Open `Examples/VSCodeSettings.ps1`.
- Run **Format Document** in VS Code (`Shift+Alt+F` on Windows).
- Review the changes to see how each override is applied (brace placement, spacing, alias correction, casing, and pipeline indentation).

## 5) PSScriptAnalyzer Configuration

### Enable linting in CI
Include PSScriptAnalyzer in your continuous integration pipeline.

Common setup command:
```powershell
Invoke-ScriptAnalyzer -Path .\MyScript.ps1 -Recurse
```

### Treat as build failures
- Treat critical warnings from PSScriptAnalyzer as build failures.
- Configure your analyzer rules to match team standards.

## 6) Quick Linting Checklist

- [ ] Uses approved verbs (`Get-Verb` validated)
- [ ] Function names follow `Verb-Noun` and use singular nouns (`Get-Service`, not `Get-Services`)
- [ ] Variables are correctly cased (PascalCase in `param`, camelCase for locals)
- [ ] Keywords are lowercase (`if`, `foreach`, `try`, `catch`, etc.)
- [ ] Indentation uses 4 spaces, no tabs
- [ ] Lines do not exceed 120 characters
- [ ] Uses splatting for long commands
- [ ] All opening braces on same line as keywords
- [ ] All closing braces on their own line
- [ ] No trailing spaces
- [ ] One newline at end of file
- [ ] UTF-8 encoding consistent
- [ ] No unapproved verb usage
