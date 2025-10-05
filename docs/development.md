# Development Guide - v1.1.0

This document is for advanced users and contributors who want to understand and extend **Persona Installer**.

---

## 🔹 Architecture Overview (v1.1.0)

The application has been completely refactored into a modular architecture:

### **Core Modules**
- **Main.ps1** (in `scripts/`)  
  - Entry point and orchestration (180 lines, down from 314)
  - Handles configuration loading, module imports, and main menu
  - Coordinates between modules for complex operations

- **PersonaManager.psm1** (`scripts/modules/`)  
  - Persona CRUD operations (Create, Read, Update, Delete)
  - Validation of persona structure and naming
  - Interactive persona editing with user selection

- **CatalogManager.psm1** (`scripts/modules/`)  
  - Catalog loading, saving, and management
  - Winget ID validation and app search functionality
  - Import/export capabilities and statistics

- **InstallEngine.psm1** (`scripts/modules/`)  
  - Core installation logic with retry mechanisms
  - App installation status checking and verification
  - Parallel installation support (prepared for future)

- **UIHelper.psm1** (`scripts/modules/`)  
  - User interface utilities and consistent formatting
  - Cross-platform app selection (GridView + console fallback)
  - Progress indicators and user messaging

- **Logger.psm1** (`scripts/modules/`)  
  - Structured JSON logging with performance metrics
  - Session transcript management and log rotation
  - Error tracking and performance analysis

### **Configuration System**
- **config/Settings.psd1**  
  - Externalized configuration for all settings
  - Feature flags for future functionality
  - Environment-specific overrides support

---

## 🔹 New Development Workflow (v1.1.0)

### 1. Local Development Setup
```powershell
# Clone and setup
git clone https://github.com/24Skater/persona-installer.git
cd persona-installer

# Test the modular structure
.\scripts\Main.ps1 -DryRun -Verbose

# Load individual modules for testing
Import-Module .\scripts\modules\PersonaManager.psm1 -Force
Load-Personas -PersonaDir .\data\personas\
```

### 2. Module Development
Each module follows consistent patterns:
```powershell
# Module template structure
<#
ModuleName.psm1 - Module description
Brief explanation of module responsibilities
#>

function Public-Function {
    <#
    .SYNOPSIS
        Brief description
    .DESCRIPTION
        Detailed description
    .PARAMETER ParamName
        Parameter description
    .OUTPUTS
        Return type description
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParamName
    )
    
    Write-Verbose "Function operation details"
    # Implementation
}

# Export only public functions
Export-ModuleMember -Function Public-Function
```

### 3. Configuration Management
```powershell
# Load configuration in your functions
$config = Import-PowerShellDataFile -Path $configPath
$installSettings = $config.Installation

# Access settings with defaults
$maxRetries = if ($installSettings.MaxRetries) { $installSettings.MaxRetries } else { 3 }
```

### 4. Logging Integration
```powershell
# Initialize logging
$logConfig = Initialize-Logging -LogsDir $LogsDir

# Log with context
Write-Log -Level 'INFO' -Message "Operation started" -Context @{ 
    operation = 'InstallPersona'
    persona = $personaName 
} -Config $logConfig

# Performance logging
$operation = Start-LoggedOperation -OperationName "MyOperation" -Config $logConfig
try {
    # Your operation here
} finally {
    Stop-LoggedOperation -Operation $operation
}
```

---

## 🔹 Testing Strategy

### Unit Testing Preparation
The modular structure enables comprehensive testing:

```powershell
# Test individual modules
Import-Module .\scripts\modules\PersonaManager.psm1 -Force

# Mock dependencies for testing
$mockCatalog = @{ "Test App" = "Test.App.ID" }
$testPersona = New-Persona -Name "test" -CatalogApps @("Test App")
```

### Integration Testing
```powershell
# Test full workflow with mocks
$testConfig = @{
    Installation = @{ MaxRetries = 1; SilentInstallFirst = $false }
    Logging = @{ DefaultLevel = 'DEBUG' }
}

# Test configuration loading
$config = Load-Configuration -ConfigPath ".\test-config.psd1"
```

---

## 🔹 Module Responsibilities

### **PersonaManager.psm1**
- `Load-Personas`: Read all persona JSON files
- `Save-Persona`: Write persona with validation
- `New-Persona`: Interactive persona creation
- `Edit-Persona`: Modify existing personas
- `Confirm-PersonaName`: Validate naming conventions

### **CatalogManager.psm1**
- `Load-Catalog`: Parse catalog JSON with PS version compatibility
- `Save-Catalog`: Write catalog to disk
- `Add-CatalogEntry`: Add new apps with validation
- `Show-Catalog`: Display with optional export
- `Test-WingetId`: Validate package IDs

### **InstallEngine.psm1**
- `Install-PersonaApps`: Orchestrate full persona installation
- `Install-App`: Single app installation with retry
- `Test-AppInstalled`: Check installation status
- `Show-InstallationResults`: Display formatted results

### **UIHelper.psm1**
- `Select-Apps`: Cross-platform app selection interface
- `Show-Menu`: Consistent menu presentation
- `Show-Progress`: Installation progress with bars
- `Show-WelcomeMessage`: Branded application startup

### **Logger.psm1**
- `Initialize-Logging`: Setup logging system
- `Write-Log`: Structured logging with JSON output
- `Start-LoggedOperation`/`Stop-LoggedOperation`: Performance tracking
- `Clear-OldLogs`: Automatic log cleanup

---

## 🔹 Extension Points

### Adding New Modules
1. Create `scripts/modules/YourModule.psm1`
2. Follow the established patterns and documentation
3. Add to module loading in `Main.ps1`
4. Export only public functions

### Configuration Extensions
Add new sections to `config/Settings.psd1`:
```powershell
YourFeature = @{
    Setting1 = 'DefaultValue'
    Setting2 = $true
}
```

### New Menu Options
Extend the main menu in `Invoke-MainMenu`:
```powershell
$menuOptions += "Your New Option"
# Add corresponding switch case
```

---

## 🔹 Performance Considerations

### Module Loading
- Modules are loaded once at startup
- Use `-DisableNameChecking` to avoid cmdlet conflicts
- Lazy loading for optional modules (future enhancement)

### Memory Management
- Large catalogs are loaded as hashtables for O(1) lookup
- JSON parsing handles both PS 5.1 and 7.x efficiently
- Log files use streaming for large outputs

### Installation Optimization
- Built-in retry logic with exponential backoff
- Prepared for parallel installation (future feature)
- Installation status caching to avoid redundant checks

---

## 🔹 Debugging and Troubleshooting

### Verbose Mode
```powershell
.\Main.ps1 -DryRun -Verbose
```

### Module-Level Debugging
```powershell
# Enable verbose for specific modules
Import-Module .\scripts\modules\PersonaManager.psm1 -Force -Verbose

# Test individual functions
Load-Personas -PersonaDir .\data\personas\ -Verbose
```

### Log Analysis
- Session logs: `logs/session-YYYYMMDD-HHMMSS.txt`
- Structured logs contain JSON for easy parsing
- Performance metrics help identify bottlenecks

### Configuration Debugging
```powershell
# Test configuration loading
$config = Load-Configuration -ConfigPath .\scripts\config\Settings.psd1
$config | ConvertTo-Json -Depth 5
```

---

## 🔹 Future Roadmap

### Phase 2 (v1.2.0)
- Dependency management system
- Installation queueing and scheduling
- Enhanced persona recommendations

### Phase 3 (v1.3.0)
- GUI wrapper using WPF/WinForms
- Community persona repository
- Rollback and snapshot functionality

### Phase 4 (v1.4.0)
- Comprehensive testing suite
- Performance optimization
- Enterprise policy management

---

Happy hacking with the new modular architecture! 🚀
