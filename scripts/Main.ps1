<# 
Main.ps1 - Persona Installer v1.2.0
Modular, UI-driven PowerShell installer for Windows
- Loads personas from data\personas\*.json
- Loads catalog from data\catalog.json
- Menu: install, create persona, edit persona, view catalog, manage catalog, exit
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoWelcome,
    [string]$ConfigPath = ""
)

# Version
$Version = "1.4.0"

$ErrorActionPreference = "Stop"

# ---------------- Path Setup ----------------
$ScriptRoot = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path $ScriptRoot
$ModulesDir = Join-Path $ScriptRoot "modules"
$ConfigDir = Join-Path $ScriptRoot "config"
$DataDir = Join-Path $RepoRoot "data"
$PersonaDir = Join-Path $DataDir "personas"
$CatalogPath = Join-Path $DataDir "catalog.json"
$LogsDir = Join-Path $RepoRoot "logs"

# ---------------- Import Configuration ----------------
function Import-Configuration {
    param([string]$ConfigPath = "")
    
    $defaultConfigPath = Join-Path $ConfigDir "Settings.psd1"
    $configFile = if ($ConfigPath -and (Test-Path $ConfigPath)) { $ConfigPath } else { $defaultConfigPath }
    
    try {
        if (Test-Path $configFile) {
            $config = Import-PowerShellDataFile -Path $configFile
            Write-Verbose "Loaded configuration from: $configFile"
            return $config
        } else {
            Write-Warning "Configuration file not found: $configFile. Using defaults."
            return @{}
        }
    }
    catch {
        Write-Warning "Failed to load configuration: $($_.Exception.Message). Using defaults."
        return @{}
    }
}

# ---------------- Module Loading ----------------
function Import-PersonaModules {
    param([string]$ModulesPath, [hashtable]$Config = @{})
    
    # Core modules (always load) - CompatibilityHelper first for cross-version support
    $coreModules = @('CompatibilityHelper', 'PersonaManager', 'CatalogManager', 'InstallEngine', 'UIHelper', 'Logger')
    
    # Optional v1.2.0+ modules (load based on feature flags)
    $optionalModules = @()
    if ($Config.Features.DependencyChecking) {
        $optionalModules += 'DependencyManager'
    }
    if ($Config.Features.SmartRecommendations) {
        $optionalModules += 'PersonaRecommendationEngine'
    }
    if ($Config.Features.EnhancedProgress) {
        $optionalModules += 'EnhancedProgressManager'
    }
    
    $allModules = $coreModules + $optionalModules
    
    foreach ($module in $allModules) {
        $modulePath = Join-Path $ModulesPath "$module.psm1"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -DisableNameChecking
                Write-Verbose "Imported module: $module"
            }
            catch {
                # Optional modules can fail gracefully
                if ($module -in $optionalModules) {
                    Write-Warning "Optional module '$module' failed to load: $($_.Exception.Message)"
                } else {
                    Write-Error "Failed to import module '$module': $($_.Exception.Message)"
                    throw
                }
            }
        } else {
            if ($module -in $optionalModules) {
                Write-Verbose "Optional module not found: $modulePath"
            } else {
                Write-Error "Module not found: $modulePath"
                throw
            }
        }
    }
}

# ---------------- Admin & Prerequisites ----------------
function Assert-Prerequisites {
    param([hashtable]$Config)
    
    $systemConfig = $Config.System
    if (-not $systemConfig) { $systemConfig = @{} }
    
    # Check admin privileges
    $requireAdmin = if ($systemConfig.RequireAdmin -ne $null) { $systemConfig.RequireAdmin } else { $true }
    $autoElevate = if ($systemConfig.AutoElevate -ne $null) { $systemConfig.AutoElevate } else { $true }
    
    if ($requireAdmin) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if (-not $isAdmin) {
            if ($autoElevate) {
                Write-Host "Administrator privileges required. Attempting to elevate..." -ForegroundColor Yellow
                $arguments = @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
                if ($DryRun) { $arguments += '-DryRun' }
                if ($NoWelcome) { $arguments += '-NoWelcome' }
                if ($ConfigPath) { $arguments += @('-ConfigPath', "`"$ConfigPath`"") }
                
                try {
                    Start-Process 'powershell.exe' -ArgumentList $arguments -Verb 'RunAs' -WindowStyle 'Normal'
                    exit 0
                }
                catch {
                    Write-Warning "Failed to elevate privileges: $($_.Exception.Message)"
                }
            }
            
            Write-Host "This script should run as Administrator for best results. Some packages may prompt or fail." -ForegroundColor Yellow
            $continue = Read-Host "Continue without elevation? (Y/N)"
            if ($continue -notmatch '^(y|yes)$') {
                exit 1
            }
        }
    }
    
    # Check winget availability
    $checkWinget = if ($systemConfig.CheckWingetAvailability -ne $null) { $systemConfig.CheckWingetAvailability } else { $true }
    if ($checkWinget -and -not (Test-WingetAvailable)) {
        Write-Host "winget (App Installer) not found. Install from Microsoft Store: 'App Installer', then re-run." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

# ---------------- Main Menu Logic ----------------
function Invoke-MainMenu {
    param(
        [array]$Personas,
        [hashtable]$Catalog,
        [hashtable]$Config,
        [PSCustomObject]$LogConfig
    )
    
    # Build dynamic menu with explicit action mapping (no confusing offset logic)
    # Using ordered hashtable to maintain menu order
    $menuActions = [ordered]@{}
    
    # Smart Recommendations (if feature enabled)
    if ($Config.Features.SmartRecommendations) {
        $menuActions["Smart persona recommendations"] = "SmartRecommendations"
    }
    
    # Core menu options with their action identifiers
    $menuActions["Install from persona"] = "InstallPersona"
    $menuActions["Create new persona"] = "CreatePersona"
    $menuActions["Edit existing persona"] = "EditPersona"
    $menuActions["Manage catalog (add package)"] = "ManageCatalog"
    $menuActions["View catalog"] = "ViewCatalog"
    $menuActions["Exit"] = "Exit"
    
    # Extract menu options (keys) as array for display
    $menuOptions = @($menuActions.Keys)
    
    $exitMenu = $false
    
    while (-not $exitMenu) {
        try {
            $choice = Show-Menu -Title "Persona Installer v$Version" -Options $menuOptions
            
            # Validate selection
            if ($choice -lt 1 -or $choice -gt $menuOptions.Count) {
                Write-Host "Invalid selection. Please choose 1-$($menuOptions.Count)." -ForegroundColor Yellow
                continue
            }
            
            # Get the action for selected menu item
            $selectedOption = $menuOptions[$choice - 1]
            $action = $menuActions[$selectedOption]
            
            # Execute the appropriate action
            switch ($action) {
                "SmartRecommendations" {
                    Invoke-SmartRecommendations -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                }
                "InstallPersona" {
                    Invoke-InstallPersona -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                }
                "CreatePersona" {
                    Invoke-CreatePersona -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                }
                "EditPersona" {
                    Invoke-EditPersona -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                }
                "ManageCatalog" {
                    Invoke-ManageCatalog -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                }
                "ViewCatalog" {
                    Invoke-ViewCatalog -Catalog $Catalog -Config $Config
                }
                "Exit" {
                    Write-Host "`nThank you for using Persona Installer!" -ForegroundColor Green
                    $exitMenu = $true
                }
                default {
                    Write-Host "Unknown action: $action" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-ErrorLog -Message "Menu operation failed" -Exception $_.Exception -Config $LogConfig
            Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
            
            $continue = Read-Host "Continue with the application? (Y/N)"
            if ($continue -notmatch '^(y|yes)$') {
                $exitMenu = $true
            }
        }
    }
}

function Invoke-SmartRecommendations {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    Write-Log -Level 'INFO' -Message "Smart recommendations requested" -Config $LogConfig
    
    try {
        # Analyze system
        $systemAnalysis = Get-SystemAnalysis
        
        # Get recommendations (function generates recommendations internally based on system analysis)
        $recommendations = Get-PersonaRecommendations -SystemAnalysis $systemAnalysis
        
        # Show recommendations
        Show-PersonaRecommendations -Recommendations $recommendations -SystemAnalysis $systemAnalysis -ShowSystemInfo
        
        if ($recommendations.Count -eq 0) {
            Write-Host "`nNo specific recommendations. All personas are available for selection." -ForegroundColor Yellow
            Read-Host "Press Enter to continue"
            return
        }
        
        # Offer to install top recommendation
        Write-Host "`nWould you like to install the top recommended persona?" -ForegroundColor Yellow
        $install = Read-Host "Enter 'Y' to install, or any other key to return to menu"
        
        if ($install -match '^(y|yes)$') {
            $topRecommendation = $recommendations[0]
            $persona = $Personas | Where-Object { $_.name -eq $topRecommendation.PersonaName } | Select-Object -First 1
            
            if ($persona) {
                Write-Log -Level 'INFO' -Message "Installing recommended persona: $($persona.name)" -Config $LogConfig
                
                # Show persona details
                Write-Host (Get-PersonaSummary -Persona $persona) -ForegroundColor Cyan
                
                # Select optional apps
                $selectedOptional = @()
                if ($persona.optional.Count -gt 0) {
                    $selectedOptional = Select-Apps -Apps $persona.optional -Title "Select optional apps for '$($persona.name)'"
                }
                
                # Show installation summary and confirm
                if (-not (Show-InstallationSummary -PersonaName $persona.name -BaseApps $persona.base -OptionalApps $selectedOptional -DryRun:$DryRun)) {
                    Write-Host "Installation cancelled by user."
                    return
                }
                
                # Perform installation
                $installSettings = $Config.Installation
                if (-not $installSettings) { $installSettings = @{} }
                
                $operation = Start-LoggedOperation -OperationName "InstallPersona-$($persona.name)" -Config $LogConfig
                
                try {
                    $useEnhanced = $Config.Features.EnhancedProgress -eq $true
                    $result = Install-PersonaApps -Persona $persona -SelectedOptionalApps $selectedOptional -Catalog $Catalog -LogsDir $LogsDir -Settings $installSettings -UseEnhancedProgress:$useEnhanced -DryRun:$DryRun
                    Show-InstallationResults -Summary $result -ShowDetails:($Config.UI.ShowDetailedResults -eq $true)
                    
                    Write-InstallLog -AppName $persona.name -WingetId "persona" -Status "Completed" -Message "Persona installation finished" -Duration $result.Duration -Config $LogConfig
                }
                finally {
                    Stop-LoggedOperation -Operation $operation -Context @{ persona = $persona.name; total_apps = ($persona.base.Count + $selectedOptional.Count) }
                }
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Smart recommendations failed" -Exception $_.Exception -Config $LogConfig
        Write-Host "An error occurred during smart recommendations: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-InstallPersona {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    if ($Personas.Count -eq 0) {
        Write-Host "No personas found in $PersonaDir" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $selection = Show-PersonaList -Personas $Personas
    if ($selection -eq 0) {
        Write-Host "Invalid persona selection."
        return
    }
    
    $persona = $Personas[$selection - 1]
    Write-Log -Level 'INFO' -Message "Selected persona: $($persona.name)" -Config $LogConfig
    
    # Show persona details
    Write-Host (Get-PersonaSummary -Persona $persona) -ForegroundColor Cyan
    
    # Select optional apps
    $selectedOptional = @()
    if ($persona.optional.Count -gt 0) {
        $selectedOptional = Select-Apps -Apps $persona.optional -Title "Select optional apps for '$($persona.name)'"
    }
    
    # Combine base and optional apps for dependency resolution
    $allApps = $persona.base + $selectedOptional
    
    # Resolve dependencies (if feature enabled)
    $finalAppList = $allApps
    if ($Config.Features.DependencyChecking) {
        Write-Host "`nAnalyzing dependencies..." -ForegroundColor Cyan
        
        try {
            $dependencyAnalysis = Resolve-AppDependencies -AppList $allApps -Catalog $Catalog
            
            # Show dependency analysis
            Show-DependencyAnalysis -Analysis $dependencyAnalysis -OriginalList $allApps -ShowDetails
            
            # Check for blocking issues
            if ($dependencyAnalysis.HasIssues) {
                Write-Host "`n[WARNING] Dependency issues detected. Review above before continuing." -ForegroundColor Yellow
                $continue = Read-Host "Continue with installation? (Y/N)"
                if ($continue -notmatch '^(y|yes)$') {
                    Write-Host "Installation cancelled by user."
                    return
                }
            }
            
            # Use resolved app list (in correct order with dependencies)
            if ($dependencyAnalysis.ResolvedApps.Count -gt 0) {
                $finalAppList = $dependencyAnalysis.ResolvedApps | ForEach-Object { $_.AppName }
                Write-Log -Level 'INFO' -Message "Dependencies resolved" -Context @{ original_count = $allApps.Count; final_count = $finalAppList.Count } -Config $LogConfig
            }
        }
        catch {
            Write-Warning "Dependency resolution failed: $($_.Exception.Message). Continuing with original app list."
            Write-Log -Level 'WARN' -Message "Dependency resolution failed" -Exception $_.Exception -Config $LogConfig
        }
    }
    
    # Show installation summary and confirm
    if (-not (Show-InstallationSummary -PersonaName $persona.name -BaseApps $persona.base -OptionalApps $selectedOptional -DryRun:$DryRun)) {
        Write-Host "Installation cancelled by user."
        return
    }
    
    # Perform installation
    $installSettings = $Config.Installation
    if (-not $installSettings) { $installSettings = @{} }
    
    $operation = Start-LoggedOperation -OperationName "InstallPersona-$($persona.name)" -Config $LogConfig
    
    try {
        # Create modified persona with resolved app list if dependencies were checked
        if ($Config.Features.DependencyChecking -and $finalAppList.Count -ne $allApps.Count) {
            # Separate back into base and optional for display purposes
            $resolvedBase = $finalAppList | Where-Object { $_ -in $persona.base }
            $resolvedOptional = $finalAppList | Where-Object { $_ -notin $persona.base }
            
            $modifiedPersona = [PSCustomObject]@{
                name = $persona.name
                description = $persona.description
                base = @($resolvedBase)
                optional = @($resolvedOptional)
            }
            
            $useEnhanced = $Config.Features.EnhancedProgress -eq $true
            $result = Install-PersonaApps -Persona $modifiedPersona -SelectedOptionalApps $resolvedOptional -Catalog $Catalog -LogsDir $LogsDir -Settings $installSettings -UseEnhancedProgress:$useEnhanced -DryRun:$DryRun
        } else {
            $useEnhanced = $Config.Features.EnhancedProgress -eq $true
            $result = Install-PersonaApps -Persona $persona -SelectedOptionalApps $selectedOptional -Catalog $Catalog -LogsDir $LogsDir -Settings $installSettings -UseEnhancedProgress:$useEnhanced -DryRun:$DryRun
        }
        Show-InstallationResults -Summary $result -ShowDetails:($Config.UI.ShowDetailedResults -eq $true)
        
        Write-InstallLog -AppName $persona.name -WingetId "persona" -Status "Completed" -Message "Persona installation finished" -Duration $result.Duration -Config $LogConfig
    }
    finally {
        Stop-LoggedOperation -Operation $operation -Context @{ persona = $persona.name; total_apps = ($persona.base.Count + $selectedOptional.Count) }
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-CreatePersona {
    param($Catalog, $Config, $LogConfig)
    
    $personaName = Read-Host "New persona name (alphanumeric, dashes, underscores)"
    if ([string]::IsNullOrWhiteSpace($personaName)) {
        Write-Host "Operation cancelled."
        return
    }
    
    Write-Log -Level 'INFO' -Message "Creating new persona: $personaName" -Config $LogConfig
    
    try {
        $personas = Import-Personas -PersonaDir $PersonaDir
        $sourcePersona = $null
        
        if ($personas.Count -gt 0) {
            if (Confirm-Action "Clone from existing persona?") {
                $selection = Show-PersonaList -Personas $personas
                if ($selection -gt 0) {
                    $sourcePersona = $personas[$selection - 1]
                }
            }
        }
        
        $catalogApps = @($Catalog.Keys | Sort-Object)
        $newPersona = New-Persona -Name $personaName -CatalogApps $catalogApps -SourcePersona $sourcePersona
        
        $savedPath = Save-Persona -Persona $newPersona -PersonaDir $PersonaDir
        Write-Host "Created persona '$personaName' at: $savedPath"
        
        Write-Log -Level 'INFO' -Message "Persona created successfully" -Context @{ persona_name = $personaName; base_apps = $newPersona.base.Count; optional_apps = $newPersona.optional.Count } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to create persona" -Exception $_.Exception -Context @{ persona_name = $personaName } -Config $LogConfig
        Write-Host "Failed to create persona: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-EditPersona {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    if ($Personas.Count -eq 0) {
        Write-Host "No personas found to edit."
        Read-Host "Press Enter to continue"
        return
    }
    
    $selection = Show-PersonaList -Personas $Personas
    if ($selection -eq 0) {
        Write-Host "Invalid persona selection."
        return
    }
    
    $persona = $Personas[$selection - 1]
    Write-Log -Level 'INFO' -Message "Editing persona: $($persona.name)" -Config $LogConfig
    
    try {
        $catalogApps = @($Catalog.Keys | Sort-Object)
        $updatedPersona = Edit-Persona -Persona $persona -CatalogApps $catalogApps
        
        $savedPath = Save-Persona -Persona $updatedPersona -PersonaDir $PersonaDir
        Write-Host "Updated persona '$($persona.name)' at: $savedPath"
        
        Write-Log -Level 'INFO' -Message "Persona updated successfully" -Context @{ persona_name = $persona.name } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to edit persona" -Exception $_.Exception -Context @{ persona_name = $persona.name } -Config $LogConfig
        Write-Host "Failed to edit persona: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-ManageCatalog {
    param($Catalog, $Config, $LogConfig)
    
    Write-Host "`nAdd a package to catalog" -ForegroundColor Cyan
    $displayName = Read-Host "Display name (e.g., 'Node.js LTS')"
    $wingetId = Read-Host "Winget ID (exact, e.g., 'OpenJS.NodeJS.LTS')"
    
    if ([string]::IsNullOrWhiteSpace($displayName) -or [string]::IsNullOrWhiteSpace($wingetId)) {
        Write-Host "Operation cancelled."
        return
    }
    
    Write-Log -Level 'INFO' -Message "Adding catalog entry" -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
    
    try {
        $updatedCatalog = Add-CatalogEntry -Catalog $Catalog -DisplayName $displayName -WingetId $wingetId
        Export-Catalog -Catalog $updatedCatalog -CatalogPath $CatalogPath
        
        Write-Log -Level 'INFO' -Message "Catalog entry added successfully" -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to add catalog entry" -Exception $_.Exception -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
        Write-Host "Failed to add catalog entry: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-ViewCatalog {
    param($Catalog, $Config)
    
    Show-Catalog -Catalog $Catalog -DataDir $DataDir
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Read-Host "Press Enter to continue"
    }
}

# ---------------- Main Execution ----------------
try {
    # Import configuration
    $config = Import-Configuration -ConfigPath $ConfigPath
    
    # Import modules (with feature flags from config)
    Import-PersonaModules -ModulesPath $ModulesDir -Config $config
    
    # Initialize logging with configurable retention
    $logRetentionDays = if ($config.Logging.LogRetentionDays) { $config.Logging.LogRetentionDays } else { 30 }
    $logConfig = Initialize-Logging -LogsDir $LogsDir -RetentionDays $logRetentionDays
    Write-Log -Level 'INFO' -Message "Persona Installer v$Version started" -Context @{ dry_run = $DryRun.IsPresent; config_path = $ConfigPath } -Config $logConfig
    
    # Check prerequisites
    Assert-Prerequisites -Config $config
    
    # Show welcome message
    if (-not $NoWelcome -and $config.UI.ShowWelcome -ne $false) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "   Persona Installer v$Version" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        if ($DryRun) {
            Write-Host "`nDRY RUN MODE - No apps will be installed" -ForegroundColor Yellow
        }
    }
    
    # Load data
    Write-Verbose "Loading catalog and personas..."
    
    # Use enhanced catalog if feature enabled and file exists
    $catalogToLoad = $CatalogPath
    if ($config.Features.UseEnhancedCatalog) {
        $enhancedCatalogPath = Join-Path $DataDir "catalog-enhanced.json"
        if (Test-Path $enhancedCatalogPath) {
            $catalogToLoad = $enhancedCatalogPath
            Write-Verbose "Using enhanced catalog with dependency metadata"
        } else {
            Write-Verbose "Enhanced catalog not found, falling back to standard catalog"
        }
    }
    
    $catalog = Import-Catalog -CatalogPath $catalogToLoad
    $personas = Import-Personas -PersonaDir $PersonaDir
    
    $catalogType = if ($catalogToLoad -eq $CatalogPath) { "standard" } else { "enhanced" }
    Write-Log -Level 'INFO' -Message "Data loaded" -Context @{ catalog_entries = $catalog.Count; personas_count = $personas.Count; catalog_type = $catalogType } -Config $logConfig
    
    # Start main menu
    Invoke-MainMenu -Personas $personas -Catalog $catalog -Config $config -LogConfig $logConfig
    
    Write-Log -Level 'INFO' -Message "Application completed successfully" -Config $logConfig
}
catch {
    try {
        if ($logConfig) {
            Write-ErrorLog -Message "Application error" -Exception $_.Exception -Config $logConfig
        }
    } catch {}
    
    Write-Host "`nApplication error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit 1
}
finally {
    # Cleanup
    try {
        if ($logConfig) {
            Stop-Logging -Config $logConfig
        }
    } catch {
        Write-Warning "Error during cleanup: $($_.Exception.Message)"
    }
}
