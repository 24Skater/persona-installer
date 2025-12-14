#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for DependencyManager module
.DESCRIPTION
    Tests dependency resolution and conflict detection
#>

BeforeAll {
    # Import required modules
    $compatPath = Join-Path $PSScriptRoot '../../scripts/modules/CompatibilityHelper.psm1'
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/DependencyManager.psm1'
    
    Import-Module $compatPath -Force
    Import-Module $modulePath -Force
    
    # Create test catalog with dependencies
    $script:testCatalog = @{
        'Git' = @{
            id = 'Git.Git'
            dependencies = @()
            conflicts = @()
        }
        'GitHub CLI' = @{
            id = 'GitHub.cli'
            dependencies = @('Git')
            conflicts = @()
        }
        'GitHub Desktop' = @{
            id = 'GitHub.GitHubDesktop'
            dependencies = @('Git')
            conflicts = @()
        }
        'Docker Desktop' = @{
            id = 'Docker.DockerDesktop'
            dependencies = @('WSL2')
            conflicts = @()
            system_requirements = @{
                min_memory_gb = 4
            }
        }
        'WSL2' = @{
            id = 'Microsoft.WSL'
            dependencies = @()
            conflicts = @()
        }
        'Node.js' = @{
            id = 'OpenJS.NodeJS'
            dependencies = @()
            conflicts = @('Node.js LTS')
        }
        'Node.js LTS' = @{
            id = 'OpenJS.NodeJS.LTS'
            dependencies = @()
            conflicts = @('Node.js')
        }
    }
    
    # Legacy format catalog for testing
    $script:legacyCatalog = @{
        'Git' = 'Git.Git'
        'VS Code' = 'Microsoft.VisualStudioCode'
    }
}

AfterAll {
    Remove-Module DependencyManager -ErrorAction SilentlyContinue
    Remove-Module CompatibilityHelper -ErrorAction SilentlyContinue
}

Describe 'DependencyManager Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module DependencyManager).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Get-AppDependencies'
            $exportedFunctions | Should -Contain 'Resolve-AppDependencies'
            $exportedFunctions | Should -Contain 'Test-SystemRequirements'
            $exportedFunctions | Should -Contain 'Show-DependencyAnalysis'
        }
    }
    
    Context 'Get-AppDependencies' {
        It 'Should return dependencies for enhanced catalog entry' {
            $deps = Get-AppDependencies -AppName 'GitHub CLI' -Catalog $script:testCatalog
            
            $deps | Should -Not -BeNullOrEmpty
            $deps.AppName | Should -Be 'GitHub CLI'
            $deps.WingetId | Should -Be 'GitHub.cli'
            $deps.Dependencies | Should -Contain 'Git'
        }
        
        It 'Should handle legacy catalog format' {
            $deps = Get-AppDependencies -AppName 'Git' -Catalog $script:legacyCatalog
            
            $deps | Should -Not -BeNullOrEmpty
            $deps.AppName | Should -Be 'Git'
            $deps.WingetId | Should -Be 'Git.Git'
            $deps.Dependencies.Count | Should -Be 0
        }
        
        It 'Should return null for missing app' {
            $deps = Get-AppDependencies -AppName 'NonExistentApp' -Catalog $script:testCatalog
            
            $deps | Should -BeNullOrEmpty
        }
        
        It 'Should include system requirements' {
            $deps = Get-AppDependencies -AppName 'Docker Desktop' -Catalog $script:testCatalog
            
            $deps.SystemRequirements | Should -Not -BeNullOrEmpty
            $deps.SystemRequirements.min_memory_gb | Should -Be 4
        }
    }
    
    Context 'Resolve-AppDependencies' {
        It 'Should resolve simple dependency chain' {
            $analysis = Resolve-AppDependencies -AppList @('GitHub CLI') -Catalog $script:testCatalog
            
            $analysis | Should -Not -BeNullOrEmpty
            $analysis.ResolvedApps.Count | Should -BeGreaterOrEqual 2
            $analysis.InstallationOrder | Should -Contain 'Git'
            $analysis.InstallationOrder | Should -Contain 'GitHub CLI'
        }
        
        It 'Should order dependencies before dependents' {
            $analysis = Resolve-AppDependencies -AppList @('GitHub CLI') -Catalog $script:testCatalog
            
            $gitIndex = $analysis.InstallationOrder.IndexOf('Git')
            $cliIndex = $analysis.InstallationOrder.IndexOf('GitHub CLI')
            
            $gitIndex | Should -BeLessThan $cliIndex
        }
        
        It 'Should detect missing dependencies' {
            $incompleteApp = @{
                'Missing Dep App' = @{
                    id = 'Missing.App'
                    dependencies = @('NonExistent')
                    conflicts = @()
                }
            }
            
            $analysis = Resolve-AppDependencies -AppList @('Missing Dep App') -Catalog $incompleteApp
            
            $analysis.MissingDependencies | Should -Contain 'NonExistent'
            $analysis.HasIssues | Should -Be $true
        }
        
        It 'Should handle apps with no dependencies' {
            $analysis = Resolve-AppDependencies -AppList @('Git') -Catalog $script:testCatalog
            
            $analysis.ResolvedApps.Count | Should -Be 1
            $analysis.HasIssues | Should -Be $false
        }
        
        It 'Should resolve multi-level dependencies' {
            $analysis = Resolve-AppDependencies -AppList @('Docker Desktop') -Catalog $script:testCatalog
            
            $analysis.InstallationOrder | Should -Contain 'WSL2'
            $analysis.InstallationOrder | Should -Contain 'Docker Desktop'
            
            $wslIndex = $analysis.InstallationOrder.IndexOf('WSL2')
            $dockerIndex = $analysis.InstallationOrder.IndexOf('Docker Desktop')
            
            $wslIndex | Should -BeLessThan $dockerIndex
        }
        
        It 'Should not duplicate apps in resolved list' {
            $analysis = Resolve-AppDependencies -AppList @('GitHub CLI', 'GitHub Desktop') -Catalog $script:testCatalog
            
            $gitCount = ($analysis.InstallationOrder | Where-Object { $_ -eq 'Git' }).Count
            $gitCount | Should -Be 1
        }
    }
    
    Context 'Test-SystemRequirements' {
        It 'Should return compatibility result' {
            $deps = Get-AppDependencies -AppName 'Docker Desktop' -Catalog $script:testCatalog
            $result = Test-SystemRequirements -AppDependencies $deps
            
            $result | Should -Not -BeNullOrEmpty
            $result.AppName | Should -Be 'Docker Desktop'
            $result.Compatible | Should -BeOfType [bool]
        }
        
        It 'Should detect insufficient memory' {
            $lowMemApp = @{
                AppName = 'HighMemApp'
                SystemRequirements = @{
                    min_memory_gb = 1024  # Impossible requirement
                }
            }
            
            $result = Test-SystemRequirements -AppDependencies ([PSCustomObject]$lowMemApp)
            
            $result.Compatible | Should -Be $false
            $result.Issues | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Show-DependencyAnalysis' {
        It 'Should not throw for valid analysis' {
            $analysis = Resolve-AppDependencies -AppList @('Git') -Catalog $script:testCatalog
            
            { Show-DependencyAnalysis -Analysis $analysis -OriginalList @('Git') } | Should -Not -Throw
        }
        
        It 'Should accept ShowDetails switch' {
            $analysis = Resolve-AppDependencies -AppList @('GitHub CLI') -Catalog $script:testCatalog
            
            { Show-DependencyAnalysis -Analysis $analysis -OriginalList @('GitHub CLI') -ShowDetails } | Should -Not -Throw
        }
    }
}

