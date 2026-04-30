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

## Repository Structure

- [Best-Practices.md](Best-Practices.md) - Comprehensive guide on function design, error handling, security, and testing
- [Style-Guide.md](Style-Guide.md) - Code formatting standards, naming conventions, and linting configuration
- [Introduction.md](Introduction.md) - Overview and introduction to the standards
- [Examples/](Examples/) - Runnable examples demonstrating the standards

