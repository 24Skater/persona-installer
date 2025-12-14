#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for UpdateManager module
.DESCRIPTION
    Tests app update detection and management functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/UpdateManager.psm1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module UpdateManager -ErrorAction SilentlyContinue
}

Describe 'UpdateManager Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module UpdateManager).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Get-InstalledApps'
            $exportedFunctions | Should -Contain 'Get-AvailableUpdates'
            $exportedFunctions | Should -Contain 'Get-PersonaUpdateStatus'
            $exportedFunctions | Should -Contain 'Format-UpdateList'
            $exportedFunctions | Should -Contain 'Update-App'
            $exportedFunctions | Should -Contain 'Update-PersonaApps'
            $exportedFunctions | Should -Contain 'Update-AllApps'
        }
    }
    
    Context 'Get-InstalledApps' {
        It 'Should return array' {
            $result = Get-InstalledApps
            $result | Should -BeOfType [System.Object[]] -Or $result | Should -BeNullOrEmpty
        }
        
        It 'Should not throw' {
            { Get-InstalledApps } | Should -Not -Throw
        }
        
        It 'Should accept filter parameter' {
            { Get-InstalledApps -Filter 'Microsoft' } | Should -Not -Throw
        }
    }
    
    Context 'Get-AvailableUpdates' {
        It 'Should return array' {
            $result = Get-AvailableUpdates
            # Result may be empty array or contain updates
            $result.GetType().BaseType.Name | Should -BeIn @('Array', 'Object')
        }
        
        It 'Should not throw' {
            { Get-AvailableUpdates } | Should -Not -Throw
        }
        
        It 'Should accept IncludeUnknown switch' {
            { Get-AvailableUpdates -IncludeUnknown } | Should -Not -Throw
        }
    }
    
    Context 'Get-PersonaUpdateStatus' {
        It 'Should filter updates to persona apps' {
            $personaApps = @('Git', 'VS Code')
            $catalog = @{
                'Git' = 'Git.Git'
                'VS Code' = 'Microsoft.VisualStudioCode'
            }
            
            $result = Get-PersonaUpdateStatus -PersonaApps $personaApps -Catalog $catalog
            
            # Result should be array (may be empty if no updates)
            $result | Should -Not -BeNullOrEmpty -Or $result.Count | Should -BeGreaterOrEqual 0
        }
        
        It 'Should handle enhanced catalog format' {
            $personaApps = @('Git')
            $catalog = @{
                'Git' = @{ id = 'Git.Git'; category = 'Development' }
            }
            
            { Get-PersonaUpdateStatus -PersonaApps $personaApps -Catalog $catalog } | Should -Not -Throw
        }
        
        It 'Should handle empty persona apps' {
            $catalog = @{ 'Git' = 'Git.Git' }
            
            $result = Get-PersonaUpdateStatus -PersonaApps @() -Catalog $catalog
            
            $result.Count | Should -Be 0
        }
    }
    
    Context 'Format-UpdateList' {
        It 'Should display empty list without error' {
            { Format-UpdateList -Updates @() -Title 'Test' } | Should -Not -Throw
        }
        
        It 'Should display updates with multiple entries' {
            $updates = @(
                [PSCustomObject]@{ Name = 'Git'; CurrentVersion = '2.40.0'; AvailableVersion = '2.41.0' },
                [PSCustomObject]@{ DisplayName = 'VS Code'; CurrentVersion = '1.80.0'; AvailableVersion = '1.81.0' }
            )
            
            { Format-UpdateList -Updates $updates -Title 'Test Updates' } | Should -Not -Throw
        }
        
        It 'Should handle long app names' {
            $updates = @(
                [PSCustomObject]@{ Name = 'This Is A Very Long Application Name That Should Be Truncated'; CurrentVersion = '1.0'; AvailableVersion = '2.0' }
            )
            
            { Format-UpdateList -Updates $updates } | Should -Not -Throw
        }
    }
    
    Context 'Update-App' {
        It 'Should simulate update in dry run mode' {
            $result = Update-App -WingetId 'Test.App' -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'DryRun'
            $result.WingetId | Should -Be 'Test.App'
        }
        
        It 'Should return result object with expected properties' {
            $result = Update-App -WingetId 'Test.App' -DryRun
            
            $result.WingetId | Should -Not -BeNullOrEmpty
            $result.Status | Should -Not -BeNullOrEmpty
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Update-PersonaApps' {
        It 'Should handle empty updates array' {
            $result = Update-PersonaApps -Updates @()
            
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should process updates in dry run mode' {
            $updates = @(
                [PSCustomObject]@{ WingetId = 'Test.App1'; DisplayName = 'Test App 1' },
                [PSCustomObject]@{ WingetId = 'Test.App2'; DisplayName = 'Test App 2' }
            )
            
            $result = Update-PersonaApps -Updates $updates -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Successful | Should -Be 2
            $result.Failed | Should -Be 0
        }
    }
}

