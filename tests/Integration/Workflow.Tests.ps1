#Requires -Modules Pester

<#
.SYNOPSIS
    Integration tests for Persona Installer workflows
.DESCRIPTION
    Tests end-to-end workflows including module loading, configuration, and data processing
#>

BeforeAll {
    # Get project paths
    $script:projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:scriptsPath = Join-Path $script:projectRoot 'scripts'
    $script:modulesPath = Join-Path $script:scriptsPath 'modules'
    $script:configPath = Join-Path $script:scriptsPath 'config'
    $script:dataPath = Join-Path $script:projectRoot 'data'
    
    # Import all modules
    $modules = @(
        'CompatibilityHelper',
        'Logger',
        'UIHelper',
        'CatalogManager',
        'PersonaManager',
        'DependencyManager',
        'InstallEngine',
        'EnhancedProgressManager',
        'PersonaRecommendationEngine'
    )
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $script:modulesPath "$module.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -DisableNameChecking
        }
    }
    
    # Create test directories
    $script:testDataDir = Join-Path $TestDrive 'data'
    $script:testLogsDir = Join-Path $TestDrive 'logs'
    $script:testPersonaDir = Join-Path $script:testDataDir 'personas'
    
    New-Item -ItemType Directory -Path $script:testDataDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:testLogsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:testPersonaDir -Force | Out-Null
}

AfterAll {
    # Clean up modules
    $modules = @(
        'PersonaRecommendationEngine',
        'EnhancedProgressManager',
        'InstallEngine',
        'DependencyManager',
        'PersonaManager',
        'CatalogManager',
        'UIHelper',
        'Logger',
        'CompatibilityHelper'
    )
    
    foreach ($module in $modules) {
        Remove-Module $module -ErrorAction SilentlyContinue
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    
    Context 'Module Loading Workflow' {
        It 'Should load all core modules without errors' {
            $coreModules = @('CompatibilityHelper', 'CatalogManager', 'PersonaManager', 'InstallEngine', 'UIHelper', 'Logger')
            
            foreach ($module in $coreModules) {
                Get-Module $module | Should -Not -BeNullOrEmpty -Because "$module should be loaded"
            }
        }
        
        It 'Should load optional modules without errors' {
            $optionalModules = @('DependencyManager', 'EnhancedProgressManager', 'PersonaRecommendationEngine')
            
            foreach ($module in $optionalModules) {
                Get-Module $module | Should -Not -BeNullOrEmpty -Because "$module should be loaded"
            }
        }
    }
    
    Context 'Configuration Loading' {
        It 'Should load settings file' {
            $settingsPath = Join-Path $script:configPath 'Settings.psd1'
            
            Test-Path $settingsPath | Should -Be $true
            
            $settings = Import-PowerShellDataFile -Path $settingsPath
            $settings | Should -Not -BeNullOrEmpty
            $settings.Installation | Should -Not -BeNullOrEmpty
            $settings.Features | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Catalog Workflow' {
        It 'Should load real catalog file' {
            $catalogPath = Join-Path $script:dataPath 'catalog.json'
            
            Test-Path $catalogPath | Should -Be $true
            
            $catalog = Import-Catalog -CatalogPath $catalogPath
            $catalog | Should -Not -BeNullOrEmpty
            $catalog.Count | Should -BeGreaterThan 0
        }
        
        It 'Should load enhanced catalog file' {
            $enhancedPath = Join-Path $script:dataPath 'catalog-enhanced.json'
            
            if (Test-Path $enhancedPath) {
                $catalog = Import-Catalog -CatalogPath $enhancedPath
                $catalog | Should -Not -BeNullOrEmpty
                
                # Check for enhanced format
                $firstEntry = $catalog.Values | Select-Object -First 1
                $firstEntry.id | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context 'Persona Workflow' {
        It 'Should load real persona files' {
            $personaDir = Join-Path $script:dataPath 'personas'
            
            Test-Path $personaDir | Should -Be $true
            
            $personas = Import-Personas -PersonaDir $personaDir
            $personas | Should -Not -BeNullOrEmpty
            $personas.Count | Should -BeGreaterThan 0
        }
        
        It 'Should have valid structure for all personas' {
            $personaDir = Join-Path $script:dataPath 'personas'
            $personas = Import-Personas -PersonaDir $personaDir
            
            foreach ($persona in $personas) {
                $persona.name | Should -Not -BeNullOrEmpty
                $persona.base | Should -Not -BeNullOrEmpty
                Test-PersonaName -Name $persona.name | Should -Be $true
            }
        }
        
        It 'Should create and save new persona' {
            $newPersona = [PSCustomObject]@{
                name = 'integration-test'
                base = @('Git', 'VS Code')
                optional = @('Docker')
            }
            
            $savedPath = Save-Persona -Persona $newPersona -PersonaDir $script:testPersonaDir
            
            Test-Path $savedPath | Should -Be $true
            
            $loaded = Import-Personas -PersonaDir $script:testPersonaDir
            $found = $loaded | Where-Object { $_.name -eq 'integration-test' }
            $found | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Dependency Resolution Workflow' {
        It 'Should resolve dependencies for real catalog' {
            $enhancedPath = Join-Path $script:dataPath 'catalog-enhanced.json'
            
            if (Test-Path $enhancedPath) {
                $catalog = Import-Catalog -CatalogPath $enhancedPath
                
                # Test with GitHub CLI which depends on Git
                $analysis = Resolve-AppDependencies -AppList @('GitHub CLI') -Catalog $catalog
                
                $analysis | Should -Not -BeNullOrEmpty
                $analysis.InstallationOrder | Should -Contain 'Git'
                $analysis.InstallationOrder | Should -Contain 'GitHub CLI'
            }
        }
    }
    
    Context 'Logging Workflow' {
        It 'Should initialize and write logs' {
            $logConfig = Initialize-Logging -LogsDir $script:testLogsDir -SessionPrefix 'integration'
            
            $logConfig | Should -Not -BeNullOrEmpty
            
            Write-Log -Level 'INFO' -Message 'Integration test log entry' -Config $logConfig
            
            # Check that session log was created
            Test-Path $logConfig.SessionLogPath | Should -Be $true
            
            Stop-Logging -Config $logConfig
        }
    }
    
    Context 'System Analysis Workflow' {
        It 'Should analyze system and return results' {
            $analysis = Get-SystemAnalysis
            
            $analysis | Should -Not -BeNullOrEmpty
            $analysis.Hardware | Should -Not -BeNullOrEmpty
            $analysis.Environment | Should -Not -BeNullOrEmpty
            $analysis.Capabilities | Should -Not -BeNullOrEmpty
        }
        
        It 'Should generate persona recommendations' {
            $analysis = Get-SystemAnalysis
            $recommendations = Get-PersonaRecommendations -SystemAnalysis $analysis
            
            $recommendations | Should -Not -BeNullOrEmpty
            $recommendations.Count | Should -BeGreaterThan 0
            $recommendations[0].PersonaName | Should -Not -BeNullOrEmpty
            $recommendations[0].Score | Should -BeGreaterThan 0
        }
    }
    
    Context 'Progress Manager Workflow' {
        It 'Should initialize progress manager' {
            $pm = Initialize-ProgressManager -TotalItems 3 -Title 'Test'
            
            $pm | Should -Not -BeNullOrEmpty
            $pm.TotalItems | Should -Be 3
            $pm.CompletedItems | Should -Be 0
            $pm.Title | Should -Be 'Test'
        }
        
        It 'Should have required functions exported' {
            Get-Command Initialize-ProgressManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Update-Progress -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Complete-Progress -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

