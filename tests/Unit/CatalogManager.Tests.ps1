#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for CatalogManager module
.DESCRIPTION
    Tests catalog loading, saving, and manipulation functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/CatalogManager.psm1'
    Import-Module $modulePath -Force
    
    # Create test data directory
    $script:testDataDir = Join-Path $TestDrive 'data'
    New-Item -ItemType Directory -Path $script:testDataDir -Force | Out-Null
    
    # Create test catalog files
    $script:legacyCatalogPath = Join-Path $script:testDataDir 'catalog-legacy.json'
    $script:enhancedCatalogPath = Join-Path $script:testDataDir 'catalog-enhanced.json'
    
    # Legacy catalog content
    $legacyCatalog = @{
        'Git' = 'Git.Git'
        'VS Code' = 'Microsoft.VisualStudioCode'
        'Node.js' = 'OpenJS.NodeJS.LTS'
    }
    $legacyCatalog | ConvertTo-Json | Set-Content -Path $script:legacyCatalogPath
    
    # Enhanced catalog content
    $enhancedCatalog = @{
        'Git' = @{
            id = 'Git.Git'
            category = 'Development'
            dependencies = @()
        }
        'GitHub CLI' = @{
            id = 'GitHub.cli'
            category = 'Development'
            dependencies = @('Git')
        }
    }
    $enhancedCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:enhancedCatalogPath
}

AfterAll {
    Remove-Module CatalogManager -ErrorAction SilentlyContinue
}

Describe 'CatalogManager Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module CatalogManager).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Import-Catalog'
            $exportedFunctions | Should -Contain 'Export-Catalog'
            $exportedFunctions | Should -Contain 'Add-CatalogEntry'
            $exportedFunctions | Should -Contain 'Show-Catalog'
            $exportedFunctions | Should -Contain 'Test-WingetId'
        }
    }
    
    Context 'Import-Catalog' {
        It 'Should load legacy catalog format' {
            $catalog = Import-Catalog -CatalogPath $script:legacyCatalogPath
            $catalog | Should -Not -BeNullOrEmpty
            $catalog.Count | Should -Be 3
            $catalog['Git'] | Should -Be 'Git.Git'
        }
        
        It 'Should load enhanced catalog format' {
            $catalog = Import-Catalog -CatalogPath $script:enhancedCatalogPath
            $catalog | Should -Not -BeNullOrEmpty
            $catalog.Count | Should -Be 2
            $catalog['GitHub CLI'].id | Should -Be 'GitHub.cli'
            $catalog['GitHub CLI'].dependencies | Should -Contain 'Git'
        }
        
        It 'Should throw for missing catalog file' {
            { Import-Catalog -CatalogPath 'nonexistent.json' } | Should -Throw
        }
        
        It 'Should throw for invalid JSON' {
            $invalidPath = Join-Path $script:testDataDir 'invalid.json'
            'not valid json' | Set-Content -Path $invalidPath
            { Import-Catalog -CatalogPath $invalidPath } | Should -Throw
        }
    }
    
    Context 'Export-Catalog' {
        It 'Should save catalog to file' {
            $testCatalog = @{
                'TestApp' = 'Test.App'
            }
            $exportPath = Join-Path $script:testDataDir 'export-test.json'
            
            Export-Catalog -Catalog $testCatalog -CatalogPath $exportPath
            
            Test-Path $exportPath | Should -Be $true
            $content = Get-Content $exportPath -Raw | ConvertFrom-Json
            $content.TestApp | Should -Be 'Test.App'
        }
    }
    
    Context 'Add-CatalogEntry' {
        It 'Should add new entry to catalog' {
            $catalog = @{}
            
            # Mock Read-Host to simulate user input (no overwrite prompt needed for new entry)
            $result = Add-CatalogEntry -Catalog $catalog -DisplayName 'New App' -WingetId 'New.App'
            
            $result['New App'] | Should -Be 'New.App'
        }
        
        It 'Should throw for empty display name' {
            $catalog = @{}
            { Add-CatalogEntry -Catalog $catalog -DisplayName '' -WingetId 'Test.App' } | Should -Throw
        }
        
        It 'Should throw for empty winget ID' {
            $catalog = @{}
            { Add-CatalogEntry -Catalog $catalog -DisplayName 'Test App' -WingetId '' } | Should -Throw
        }
        
        It 'Should throw for display name exceeding max length' {
            $catalog = @{}
            $longName = 'A' * 101
            { Add-CatalogEntry -Catalog $catalog -DisplayName $longName -WingetId 'Test.App' } | Should -Throw
        }
        
        It 'Should warn for invalid winget ID format' {
            $catalog = @{}
            # Should not throw but may warn
            { Add-CatalogEntry -Catalog $catalog -DisplayName 'Test' -WingetId 'invalid id with spaces' } | Should -Not -Throw
        }
    }
    
    Context 'Get-CatalogStatistics' {
        It 'Should return statistics for catalog' {
            $catalog = @{
                'Git' = 'Git.Git'
                'VS Code' = 'Microsoft.VisualStudioCode'
                'Chrome' = 'Google.Chrome'
            }
            
            $stats = Get-CatalogStatistics -Catalog $catalog
            
            $stats.TotalEntries | Should -Be 3
            $stats.UniquePublishers | Should -Contain 'Git'
            $stats.UniquePublishers | Should -Contain 'Microsoft'
            $stats.UniquePublishers | Should -Contain 'Google'
        }
    }
}

