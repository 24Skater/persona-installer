<# 
Main.ps1 - Persona Installer v1.1.0
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
$Version = "1.2.0"

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

# ---------------- Load Configuration ----------------
function Load-Configuration {
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
    param([string]$ModulesPath)
    
    $modules = @('PersonaManager', 'CatalogManager', 'InstallEngine', 'UIHelper', 'Logger', 'DependencyManager', 'PersonaRecommendationEngine', 'EnhancedProgressManager')
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $ModulesPath "$module.psm1"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -DisableNameChecking
                Write-Verbose "Imported module: $module"
            }
            catch {
                Write-Error "Failed to import module '$module': $($_.Exception.Message)"
                throw
            }
        } else {
            Write-Error "Module not found: $modulePath"
            throw
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
            
            Show-Warning "This script should run as Administrator for best results. Some packages may prompt or fail."
            if (-not (Confirm-Action "Continue without elevation?")) {
                exit 1
            }
        }
    }
    
    # Check winget availability
    $checkWinget = if ($systemConfig.CheckWingetAvailability -ne $null) { $systemConfig.CheckWingetAvailability } else { $true }
    if ($checkWinget -and -not (Test-WingetAvailable)) {
        Show-Error "winget (App Installer) not found. Install from Microsoft Store: 'App Installer', then re-run."
        Wait-ForUser "Press Enter to exit..."
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
    
    $menuOptions = @(
        "🤖 Smart persona recommendations",
        "📦 Install from persona",
        "➕ Create new persona", 
        "✏️  Edit existing persona",
        "🛠️  Manage catalog (add package)",
        "📋 View catalog",
        "❌ Exit"
    )
    
    while ($true) {
        try {
            $choice = Show-Menu -Title "Persona Installer v$Version" -Options $menuOptions
            
            switch ($choice) {
                1 { Invoke-SmartRecommendations -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig }
                2 { Invoke-InstallPersona -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig }
                3 { Invoke-CreatePersona -Catalog $Catalog -Config $Config -LogConfig $LogConfig }
                4 { Invoke-EditPersona -Personas $Personas -Catalog $Catalog -Config $Config -LogConfig $LogConfig }
                5 { Invoke-ManageCatalog -Catalog $Catalog -Config $Config -LogConfig $LogConfig }
                6 { Invoke-ViewCatalog -Catalog $Catalog -Config $Config }
                7 { 
                    Show-Success "Thank you for using Persona Installer!"
                    break 
                }
                0 { Show-Warning "Invalid selection. Please choose 1-7." }
            }
        }
        catch {
            Write-ErrorLog -Message "Menu operation failed" -Exception $_.Exception -Config $LogConfig
            Show-Error "An error occurred: $($_.Exception.Message)"
            
            if (-not (Confirm-Action "Continue with the application?" -Default 'Y')) {
                break
            }
        }
    }
}

function Invoke-SmartRecommendations {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    if (-not $Config.Features.SmartRecommendations) {
        Show-Warning "Smart recommendations are disabled in configuration."
        Wait-ForUser
        return
    }
    
    Write-Host "`n🤖 Analyzing your system..." -ForegroundColor Cyan
    
    Write-Log -Level 'INFO' -Message "Starting smart persona recommendations" -Config $LogConfig
    
    try {
        # Perform system analysis
        $systemAnalysis = Get-SystemAnalysis
        Write-Log -Level 'INFO' -Message "System analysis completed" -Context @{ 
            user_type = $systemAnalysis.UserProfile.UserType
            memory_gb = $systemAnalysis.Hardware.TotalMemoryGB
            dev_tools = $systemAnalysis.Software.Development.Count
        } -Config $LogConfig
        
        # Get persona recommendations
        $recommendations = Get-PersonaRecommendations -SystemAnalysis $systemAnalysis
        
        # Show recommendations to user
        Show-PersonaRecommendations -Recommendations $recommendations -SystemAnalysis $systemAnalysis -ShowSystemInfo
        
        # Ask if user wants to install a recommended persona
        if ($recommendations.Count -gt 0) {
            Write-Host ""
            $installChoice = Read-Host "Would you like to install one of these recommended personas? (Y/N)"
            
            if ($installChoice -match '^(y|yes)$') {
                Write-Host "`nWhich persona would you like to install?"
                for ($i = 0; $i -lt [Math]::Min($recommendations.Count, 5); $i++) {
                    Write-Host " [$($i + 1)] $($recommendations[$i].PersonaName)" -ForegroundColor White
                }
                
                $selection = Read-Host "Enter number (1-$([Math]::Min($recommendations.Count, 5)))"
                
                if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le [Math]::Min($recommendations.Count, 5)) {
                    $selectedPersonaName = $recommendations[[int]$selection - 1].PersonaName
                    
                    # Find the actual persona object
                    $selectedPersona = $Personas | Where-Object { $_.name -eq $selectedPersonaName } | Select-Object -First 1
                    
                    if ($selectedPersona) {
                        Write-Log -Level 'INFO' -Message "User selected recommended persona" -Context @{ persona = $selectedPersonaName } -Config $LogConfig
                        
                        # Proceed with installation using enhanced dependency checking
                        Invoke-InstallPersonaWithDependencies -Persona $selectedPersona -Catalog $Catalog -Config $Config -LogConfig $LogConfig
                    } else {
                        Show-Error "Persona '$selectedPersonaName' not found."
                    }
                } else {
                    Show-Warning "Invalid selection."
                }
            }
        }
        
    } catch {
        Write-ErrorLog -Message "Smart recommendations failed" -Exception $_.Exception -Config $LogConfig
        Show-Error "Failed to generate recommendations: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

function Invoke-InstallPersonaWithDependencies {
    param($Persona, $Catalog, $Config, $LogConfig)
    
    Write-Host "`n🔍 Analyzing dependencies..." -ForegroundColor Yellow
    
    # Check if we should use enhanced catalog or convert legacy
    $enhancedCatalog = $Catalog
    if ($Catalog.Values | Where-Object { $_ -is [string] }) {
        Write-Verbose "Converting legacy catalog format"
        $enhancedCatalog = Convert-LegacyCatalog -LegacyCatalog $Catalog
        $enhancedCatalog = Add-CommonDependencies -Catalog $enhancedCatalog
    }
    
    # Combine base and optional apps selection
    $selectedOptional = @()
    if ($Persona.optional.Count -gt 0) {
        $selectedOptional = Select-Apps -Apps $Persona.optional -Title "Select optional apps for '$($Persona.name)'"
    }
    
    $allApps = @($Persona.base) + @($selectedOptional)
    
    # Resolve dependencies
    if ($Config.Features.DependencyChecking) {
        $dependencyAnalysis = Resolve-AppDependencies -AppList $allApps -Catalog $enhancedCatalog
        
        $canProceed = Show-DependencyAnalysis -Analysis $dependencyAnalysis -ShowDetails
        
        if (-not $canProceed) {
            $continue = Read-Host "Dependencies have issues. Continue anyway? (Y/N)"
            if ($continue -notmatch '^(y|yes)$') {
                Show-Warning "Installation cancelled due to dependency issues."
                return
            }
        }
        
        # Use resolved installation order
        $finalAppList = $dependencyAnalysis.InstallationOrder
    } else {
        $finalAppList = $allApps
    }
    
    # Show installation summary
    if (-not (Show-InstallationSummary -PersonaName $Persona.name -BaseApps $finalAppList -OptionalApps @() -DryRun:$DryRun)) {
        Show-Warning "Installation cancelled by user."
        return
    }
    
    # Enhanced installation with progress tracking
    if ($Config.Features.EnhancedProgress) {
        Invoke-InstallWithEnhancedProgress -AppList $finalAppList -Catalog $enhancedCatalog -Config $Config -LogConfig $LogConfig
    } else {
        # Fallback to standard installation
        $installSettings = $Config.Installation
        if (-not $installSettings) { $installSettings = @{} }
        
        $result = Install-PersonaApps -Persona $Persona -SelectedOptionalApps $selectedOptional -Catalog $Catalog -LogsDir $LogsDir -Settings $installSettings -DryRun:$DryRun
        Show-InstallationResults -Summary $result -ShowDetails:($Config.UI.ShowDetailedResults -eq $true)
    }
}

function Invoke-InstallWithEnhancedProgress {
    param($AppList, $Catalog, $Config, $LogConfig)
    
    Write-Log -Level 'INFO' -Message "Starting enhanced installation" -Context @{ app_count = $AppList.Count } -Config $LogConfig
    
    # Initialize enhanced progress manager
    $progressManager = Initialize-ProgressManager -TotalItems $AppList.Count -Title "Installing Applications" -ShowETA -ShowSpeed
    
    $successful = 0
    $failed = 0
    $skipped = 0
    
    try {
        foreach ($appName in $AppList) {
            if (-not $Catalog.ContainsKey($appName)) {
                Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status "Skipped" -ItemResult ([PSCustomObject]@{ Status = 'NotInCatalog' })
                $skipped++
                continue
            }
            
            $appInfo = $Catalog[$appName]
            $wingetId = if ($appInfo -is [string]) { $appInfo } else { $appInfo.id }
            
            Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status "Installing"
            
            $logFileName = ($appName -replace '[^\w\-\.]', '_') + '.log'
            $logPath = Join-Path $LogsDir $logFileName
            
            $installResult = Install-App -DisplayName $appName -WingetId $wingetId -LogPath $logPath -Settings $Config.Installation -DryRun:$DryRun
            
            Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status $installResult.Status -ItemResult $installResult
            
            switch ($installResult.Status) {
                'Success' { $successful++ }
                'AlreadyInstalled' { $skipped++ }
                'DryRun' { $skipped++ }
                default { $failed++ }
            }
            
            Write-InstallLog -AppName $appName -WingetId $wingetId -Status $installResult.Status -Message $installResult.Message -Duration $installResult.Duration -Config $LogConfig
        }
        
    } catch {
        Write-ErrorLog -Message "Enhanced installation error" -Exception $_.Exception -Config $LogConfig
        Cancel-Progress -ProgressManager $progressManager -Reason $_.Exception.Message
        throw
    }
    
    # Complete progress and show summary
    Complete-Progress -ProgressManager $progressManager -ShowSummary
    
    Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
    Write-Host "✅ Successful: $successful" -ForegroundColor Green
    Write-Host "⏭️  Skipped: $skipped" -ForegroundColor Gray
    Write-Host "❌ Failed: $failed" -ForegroundColor Red
    
    Write-Log -Level 'INFO' -Message "Enhanced installation completed" -Context @{ 
        successful = $successful
        failed = $failed 
        skipped = $skipped
    } -Config $LogConfig
}

function Invoke-InstallPersona {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    if ($Personas.Count -eq 0) {
        Show-Warning "No personas found in $PersonaDir"
        Wait-ForUser
        return
    }
    
    $selection = Show-PersonaList -Personas $Personas
    if ($selection -eq 0) {
        Show-Warning "Invalid persona selection."
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
    
    # Show installation summary and confirm
    if (-not (Show-InstallationSummary -PersonaName $persona.name -BaseApps $persona.base -OptionalApps $selectedOptional -DryRun:$DryRun)) {
        Show-Warning "Installation cancelled by user."
        return
    }
    
    # Perform installation
    $installSettings = $Config.Installation
    if (-not $installSettings) { $installSettings = @{} }
    
    $operation = Start-LoggedOperation -OperationName "InstallPersona-$($persona.name)" -Config $LogConfig
    
    try {
        $result = Install-PersonaApps -Persona $persona -SelectedOptionalApps $selectedOptional -Catalog $Catalog -LogsDir $LogsDir -Settings $installSettings -DryRun:$DryRun
        Show-InstallationResults -Summary $result -ShowDetails:($Config.UI.ShowDetailedResults -eq $true)
        
        Write-InstallLog -AppName $persona.name -WingetId "persona" -Status "Completed" -Message "Persona installation finished" -Duration $result.Duration -Config $LogConfig
    }
    finally {
        Stop-LoggedOperation -Operation $operation -Context @{ persona = $persona.name; total_apps = ($persona.base.Count + $selectedOptional.Count) }
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

function Invoke-CreatePersona {
    param($Catalog, $Config, $LogConfig)
    
    $personaName = Read-Host "New persona name (alphanumeric, dashes, underscores)"
    if ([string]::IsNullOrWhiteSpace($personaName)) {
        Show-Warning "Operation cancelled."
        return
    }
    
    Write-Log -Level 'INFO' -Message "Creating new persona: $personaName" -Config $LogConfig
    
    try {
        $personas = Load-Personas -PersonaDir $PersonaDir
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
        Show-Success "Created persona '$personaName' at: $savedPath"
        
        Write-Log -Level 'INFO' -Message "Persona created successfully" -Context @{ persona_name = $personaName; base_apps = $newPersona.base.Count; optional_apps = $newPersona.optional.Count } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to create persona" -Exception $_.Exception -Context @{ persona_name = $personaName } -Config $LogConfig
        Show-Error "Failed to create persona: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

function Invoke-EditPersona {
    param($Personas, $Catalog, $Config, $LogConfig)
    
    if ($Personas.Count -eq 0) {
        Show-Warning "No personas found to edit."
        Wait-ForUser
        return
    }
    
    $selection = Show-PersonaList -Personas $Personas
    if ($selection -eq 0) {
        Show-Warning "Invalid persona selection."
        return
    }
    
    $persona = $Personas[$selection - 1]
    Write-Log -Level 'INFO' -Message "Editing persona: $($persona.name)" -Config $LogConfig
    
    try {
        $catalogApps = @($Catalog.Keys | Sort-Object)
        $updatedPersona = Edit-Persona -Persona $persona -CatalogApps $catalogApps
        
        $savedPath = Save-Persona -Persona $updatedPersona -PersonaDir $PersonaDir
        Show-Success "Updated persona '$($persona.name)' at: $savedPath"
        
        Write-Log -Level 'INFO' -Message "Persona updated successfully" -Context @{ persona_name = $persona.name } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to edit persona" -Exception $_.Exception -Context @{ persona_name = $persona.name } -Config $LogConfig
        Show-Error "Failed to edit persona: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

function Invoke-ManageCatalog {
    param($Catalog, $Config, $LogConfig)
    
    Write-Host "`nAdd a package to catalog" -ForegroundColor Cyan
    $displayName = Read-Host "Display name (e.g., 'Node.js LTS')"
    $wingetId = Read-Host "Winget ID (exact, e.g., 'OpenJS.NodeJS.LTS')"
    
    if ([string]::IsNullOrWhiteSpace($displayName) -or [string]::IsNullOrWhiteSpace($wingetId)) {
        Show-Warning "Operation cancelled."
        return
    }
    
    Write-Log -Level 'INFO' -Message "Adding catalog entry" -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
    
    try {
        $updatedCatalog = Add-CatalogEntry -Catalog $Catalog -DisplayName $displayName -WingetId $wingetId
        Save-Catalog -Catalog $updatedCatalog -CatalogPath $CatalogPath
        
        Write-Log -Level 'INFO' -Message "Catalog entry added successfully" -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
    }
    catch {
        Write-ErrorLog -Message "Failed to add catalog entry" -Exception $_.Exception -Context @{ display_name = $displayName; winget_id = $wingetId } -Config $LogConfig
        Show-Error "Failed to add catalog entry: $($_.Exception.Message)"
    }
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

function Invoke-ViewCatalog {
    param($Catalog, $Config)
    
    Show-Catalog -Catalog $Catalog -DataDir $DataDir
    
    if ($Config.UI.PauseAfterOperations -ne $false) {
        Wait-ForUser
    }
}

# ---------------- Main Execution ----------------
try {
    # Load configuration
    $config = Load-Configuration -ConfigPath $ConfigPath
    
    # Import modules
    Import-PersonaModules -ModulesPath $ModulesDir
    
    # Initialize logging
    $logConfig = Initialize-Logging -LogsDir $LogsDir
    Write-Log -Level 'INFO' -Message "Persona Installer v$Version started" -Context @{ dry_run = $DryRun.IsPresent; config_path = $ConfigPath } -Config $logConfig
    
    # Check prerequisites
    Assert-Prerequisites -Config $config
    
    # Show welcome message
    if (-not $NoWelcome -and $config.UI.ShowWelcome -ne $false) {
        Show-WelcomeMessage -Version $Version -DryRun:$DryRun
    }
    
    # Load data
    Write-Verbose "Loading catalog and personas..."
    $catalog = Load-Catalog -CatalogPath $CatalogPath
    $personas = Load-Personas -PersonaDir $PersonaDir
    
    Write-Log -Level 'INFO' -Message "Data loaded" -Context @{ catalog_entries = $catalog.Count; personas_count = $personas.Count } -Config $logConfig
    
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
    
    Show-Error "Application error: $($_.Exception.Message)" -Exception $_.Exception
    Wait-ForUser "Press Enter to exit..."
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