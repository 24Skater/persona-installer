<#
Test-V1.1.0.ps1 - Basic validation script for v1.1.0 modular structure
This script validates that all modules load correctly and basic functionality works
#>

[CmdletBinding()]
param(
    [switch]$ShowVerbose
)

if ($ShowVerbose) { $VerbosePreference = 'Continue' }

$ErrorActionPreference = "Stop"
$TestResults = @()

function Add-TestResult {
    param($Test, $Status, $Message = "")
    $TestResults += [PSCustomObject]@{
        Test = $Test
        Status = $Status
        Message = $Message
    }
}

function Test-ModuleStructure {
    Write-Host "`n=== Testing Module Structure ===" -ForegroundColor Cyan
    
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $ModulesDir = Join-Path $ScriptRoot "modules"
    
    # Test modules directory exists
    try {
        if (Test-Path $ModulesDir) {
            Add-TestResult "Modules Directory" "PASS" "Found at $ModulesDir"
        } else {
            Add-TestResult "Modules Directory" "FAIL" "Not found at $ModulesDir"
            return
        }
    } catch {
        Add-TestResult "Modules Directory" "ERROR" $_.Exception.Message
        return
    }
    
    # Test individual module files
    $expectedModules = @('PersonaManager', 'CatalogManager', 'InstallEngine', 'UIHelper', 'Logger')
    
    foreach ($module in $expectedModules) {
        $modulePath = Join-Path $ModulesDir "$module.psm1"
        try {
            if (Test-Path $modulePath) {
                Add-TestResult "Module File: $module" "PASS" "Found at $modulePath"
            } else {
                Add-TestResult "Module File: $module" "FAIL" "Not found at $modulePath"
            }
        } catch {
            Add-TestResult "Module File: $module" "ERROR" $_.Exception.Message
        }
    }
}

function Test-ModuleLoading {
    Write-Host "`n=== Testing Module Loading ===" -ForegroundColor Cyan
    
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $ModulesDir = Join-Path $ScriptRoot "modules"
    $expectedModules = @('PersonaManager', 'CatalogManager', 'InstallEngine', 'UIHelper', 'Logger')
    
    foreach ($module in $expectedModules) {
        $modulePath = Join-Path $ModulesDir "$module.psm1"
        try {
            Import-Module $modulePath -Force -DisableNameChecking
            Add-TestResult "Module Import: $module" "PASS" "Successfully imported"
        } catch {
            Add-TestResult "Module Import: $module" "FAIL" $_.Exception.Message
        }
    }
}

function Test-Configuration {
    Write-Host "`n=== Testing Configuration System ===" -ForegroundColor Cyan
    
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $ConfigDir = Join-Path $ScriptRoot "config"
    $ConfigPath = Join-Path $ConfigDir "Settings.psd1"
    
    try {
        if (Test-Path $ConfigPath) {
            Add-TestResult "Config File" "PASS" "Found at $ConfigPath"
            
            # Test loading configuration
            $config = Import-PowerShellDataFile -Path $ConfigPath
            if ($config -and $config.Count -gt 0) {
                Add-TestResult "Config Loading" "PASS" "Loaded $($config.Count) configuration sections"
                
                # Test specific sections
                $expectedSections = @('Installation', 'Logging', 'UI', 'System')
                foreach ($section in $expectedSections) {
                    if ($config.$section) {
                        Add-TestResult "Config Section: $section" "PASS" "Found with $($config.$section.Count) settings"
                    } else {
                        Add-TestResult "Config Section: $section" "WARN" "Section not found"
                    }
                }
            } else {
                Add-TestResult "Config Loading" "FAIL" "Configuration file appears empty or invalid"
            }
        } else {
            Add-TestResult "Config File" "FAIL" "Not found at $ConfigPath"
        }
    } catch {
        Add-TestResult "Configuration System" "ERROR" $_.Exception.Message
    }
}

function Test-DataFiles {
    Write-Host "`n=== Testing Data Files ===" -ForegroundColor Cyan
    
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $RepoRoot = Split-Path $ScriptRoot
    $DataDir = Join-Path $RepoRoot "data"
    $CatalogPath = Join-Path $DataDir "catalog.json"
    $PersonaDir = Join-Path $DataDir "personas"
    
    # Test catalog
    try {
        if (Test-Path $CatalogPath) {
            $catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
            $catalogHash = @{}
            foreach ($prop in $catalog.PSObject.Properties) {
                $catalogHash[$prop.Name] = $prop.Value
            }
            Add-TestResult "Catalog File" "PASS" "Found with $($catalogHash.Count) entries"
        } else {
            Add-TestResult "Catalog File" "FAIL" "Not found at $CatalogPath"
        }
    } catch {
        Add-TestResult "Catalog File" "ERROR" $_.Exception.Message
    }
    
    # Test personas directory
    try {
        if (Test-Path $PersonaDir) {
            $personaFiles = Get-ChildItem $PersonaDir -Filter "*.json" -File
            Add-TestResult "Personas Directory" "PASS" "Found with $($personaFiles.Count) persona files"
            
            # Test loading a persona
            if ($personaFiles.Count -gt 0) {
                $testPersona = Get-Content $personaFiles[0].FullName -Raw | ConvertFrom-Json
                if ($testPersona.name -and $testPersona.base) {
                    Add-TestResult "Persona Structure" "PASS" "Valid structure in $($personaFiles[0].Name)"
                } else {
                    Add-TestResult "Persona Structure" "WARN" "Invalid structure in $($personaFiles[0].Name)"
                }
            }
        } else {
            Add-TestResult "Personas Directory" "FAIL" "Not found at $PersonaDir"
        }
    } catch {
        Add-TestResult "Personas Directory" "ERROR" $_.Exception.Message
    }
}

function Test-FunctionAvailability {
    Write-Host "`n=== Testing Key Function Availability ===" -ForegroundColor Cyan
    
    # Test key functions from each module
    $functionsToTest = @{
        'PersonaManager' = @('Load-Personas', 'Save-Persona', 'New-Persona')
        'CatalogManager' = @('Load-Catalog', 'Save-Catalog', 'Show-Catalog')
        'InstallEngine' = @('Test-AppInstalled', 'Install-App')
        'UIHelper' = @('Select-Apps', 'Show-Menu', 'Show-Progress')
        'Logger' = @('Initialize-Logging', 'Write-Log')
    }
    
    foreach ($module in $functionsToTest.Keys) {
        foreach ($function in $functionsToTest[$module]) {
            try {
                if (Get-Command $function -ErrorAction SilentlyContinue) {
                    Add-TestResult "Function: $function" "PASS" "Available from $module"
                } else {
                    Add-TestResult "Function: $function" "FAIL" "Not available from $module"
                }
            } catch {
                Add-TestResult "Function: $function" "ERROR" $_.Exception.Message
            }
        }
    }
}

function Test-MainScript {
    Write-Host "`n=== Testing Main Script Structure ===" -ForegroundColor Cyan
    
    $ScriptRoot = Split-Path -Parent $PSCommandPath
    $MainPath = Join-Path $ScriptRoot "Main.ps1"
    
    try {
        if (Test-Path $MainPath) {
            $mainContent = Get-Content $MainPath -Raw
            
            # Check for key elements
            $checks = @{
                'Module Loading' = $mainContent -match 'Import-Module.*PersonaManager'
                'Configuration Loading' = $mainContent -match 'Load-Configuration'
                'Error Handling' = $mainContent -match 'try.*catch'
                'Parameter Support' = $mainContent -match '\[CmdletBinding\(\)\]'
                'Version Info' = $mainContent -match '\$Version\s*=\s*"1\.1\.0"'
            }
            
            foreach ($check in $checks.GetEnumerator()) {
                if ($check.Value) {
                    Add-TestResult "Main Script: $($check.Key)" "PASS" "Found in Main.ps1"
                } else {
                    Add-TestResult "Main Script: $($check.Key)" "WARN" "Not found in Main.ps1"
                }
            }
            
            Add-TestResult "Main Script File" "PASS" "Found and analyzed"
        } else {
            Add-TestResult "Main Script File" "FAIL" "Not found at $MainPath"
        }
    } catch {
        Add-TestResult "Main Script" "ERROR" $_.Exception.Message
    }
}

function Show-TestResults {
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Green
    
    $passed = ($TestResults | Where-Object { $_.Status -eq 'PASS' }).Count
    $failed = ($TestResults | Where-Object { $_.Status -eq 'FAIL' }).Count
    $errors = ($TestResults | Where-Object { $_.Status -eq 'ERROR' }).Count
    $warnings = ($TestResults | Where-Object { $_.Status -eq 'WARN' }).Count
    
    Write-Host "Total Tests: $($TestResults.Count)" -ForegroundColor White
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor Red
    Write-Host "Errors: $errors" -ForegroundColor Magenta
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    
    # Show detailed results
    Write-Host "`nDetailed Results:" -ForegroundColor Yellow
    foreach ($result in $TestResults) {
        $color = switch ($result.Status) {
            'PASS' { 'Green' }
            'FAIL' { 'Red' }
            'ERROR' { 'Magenta' }
            'WARN' { 'Yellow' }
            default { 'White' }
        }
        
        $line = "  [$($result.Status.PadRight(5))] $($result.Test)"
        if ($result.Message) {
            $line += " - $($result.Message)"
        }
        Write-Host $line -ForegroundColor $color
    }
    
    # Overall status
    Write-Host ""
    if ($failed -eq 0 -and $errors -eq 0) {
        Write-Host "🎉 All critical tests passed! v1.1.0 structure is ready." -ForegroundColor Green
        return $true
    } elseif ($errors -eq 0) {
        Write-Host "⚠️  Some tests failed but no errors. Review failures before release." -ForegroundColor Yellow
        return $false
    } else {
        Write-Host "❌ Critical errors found. Fix these before proceeding." -ForegroundColor Red
        return $false
    }
}

# Run all tests
try {
    Write-Host "Persona Installer v1.1.0 - Structure Validation" -ForegroundColor Green
    Write-Host "=" * 50
    
    Test-ModuleStructure
    Test-ModuleLoading
    Test-Configuration
    Test-DataFiles
    Test-FunctionAvailability
    Test-MainScript
    
    $success = Show-TestResults
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
    
} catch {
    Write-Host "`n❌ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
