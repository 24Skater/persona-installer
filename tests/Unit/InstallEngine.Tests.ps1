#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for InstallEngine module
.DESCRIPTION
    Tests installation functions including winget integration
#>

BeforeAll {
    # Import required modules
    $compatPath = Join-Path $PSScriptRoot '../../scripts/modules/CompatibilityHelper.psm1'
    $loggerPath = Join-Path $PSScriptRoot '../../scripts/modules/Logger.psm1'
    $progressPath = Join-Path $PSScriptRoot '../../scripts/modules/EnhancedProgressManager.psm1'
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/InstallEngine.psm1'
    
    Import-Module $compatPath -Force
    Import-Module $loggerPath -Force
    Import-Module $progressPath -Force
    Import-Module $modulePath -Force
    
    # Create test directories
    $script:testLogsDir = Join-Path $TestDrive 'logs'
    New-Item -ItemType Directory -Path $script:testLogsDir -Force | Out-Null
}

AfterAll {
    Remove-Module InstallEngine -ErrorAction SilentlyContinue
    Remove-Module EnhancedProgressManager -ErrorAction SilentlyContinue
    Remove-Module Logger -ErrorAction SilentlyContinue
    Remove-Module CompatibilityHelper -ErrorAction SilentlyContinue
}

Describe 'InstallEngine Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module InstallEngine).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Test-AppInstalled'
            $exportedFunctions | Should -Contain 'Install-App'
            $exportedFunctions | Should -Contain 'Install-AppWithRetry'
            $exportedFunctions | Should -Contain 'Install-PersonaApps'
            $exportedFunctions | Should -Contain 'Show-InstallationResults'
            $exportedFunctions | Should -Contain 'Test-WingetAvailable'
            $exportedFunctions | Should -Contain 'Get-WingetVersion'
        }
    }
    
    Context 'Test-WingetAvailable' {
        It 'Should return boolean' {
            $result = Test-WingetAvailable
            $result | Should -BeOfType [bool]
        }
        
        It 'Should not throw' {
            { Test-WingetAvailable } | Should -Not -Throw
        }
    }
    
    Context 'Get-WingetVersion' {
        It 'Should return version or null' {
            $version = Get-WingetVersion
            # Either returns version string or null if winget not installed
            if ($version) {
                $version | Should -Match '\d+\.\d+'
            }
        }
        
        It 'Should not throw' {
            { Get-WingetVersion } | Should -Not -Throw
        }
    }
    
    Context 'Test-AppInstalled' {
        It 'Should return boolean' {
            $result = Test-AppInstalled -WingetId 'Git.Git'
            $result | Should -BeOfType [bool]
        }
        
        It 'Should return false for non-existent app' {
            $result = Test-AppInstalled -WingetId 'NonExistent.Package.12345'
            $result | Should -Be $false
        }
    }
    
    Context 'Install-App with DryRun' {
        It 'Should simulate installation in dry run mode' {
            $result = Install-App -DisplayName 'Test App' -WingetId 'Test.App' -LogPath (Join-Path $script:testLogsDir 'test.log') -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'DryRun'
            $result.DisplayName | Should -Be 'Test App'
        }
        
        It 'Should accept settings parameter' {
            $settings = @{
                MaxRetries = 3
                SilentInstallFirst = $true
            }
            
            $result = Install-App -DisplayName 'Test App' -WingetId 'Test.App' -LogPath (Join-Path $script:testLogsDir 'test.log') -Settings $settings -DryRun
            
            $result.Status | Should -Be 'DryRun'
        }
    }
    
    Context 'Install-AppWithRetry Parameters' {
        It 'Should accept retry delay parameter' {
            # In dry run, we can't test actual retry behavior
            # But we can verify the function accepts the parameter
            $logPath = Join-Path $script:testLogsDir 'retry-test.log'
            
            { 
                Install-AppWithRetry -WingetId 'Test.App' -LogPath $logPath -MaxRetries 1 -SilentFirst $false -RetryDelaySeconds 1 
            } | Should -Not -Throw -Because "Function should accept RetryDelaySeconds parameter"
        }
    }
    
    Context 'Install-PersonaApps with DryRun' {
        It 'Should simulate persona installation in dry run mode' {
            $persona = [PSCustomObject]@{
                name = 'test'
                base = @('Git', 'VS Code')
                optional = @()
            }
            
            $catalog = @{
                'Git' = 'Git.Git'
                'VS Code' = 'Microsoft.VisualStudioCode'
            }
            
            $summary = Install-PersonaApps -Persona $persona -Catalog $catalog -LogsDir $script:testLogsDir -DryRun
            
            $summary | Should -Not -BeNullOrEmpty
            $summary.TotalApps | Should -Be 2
            $summary.Results[0].Status | Should -Be 'DryRun'
        }
        
        It 'Should handle enhanced catalog format' {
            $persona = [PSCustomObject]@{
                name = 'test'
                base = @('Git')
                optional = @()
            }
            
            $catalog = @{
                'Git' = @{
                    id = 'Git.Git'
                    category = 'Development'
                    dependencies = @()
                }
            }
            
            $summary = Install-PersonaApps -Persona $persona -Catalog $catalog -LogsDir $script:testLogsDir -DryRun
            
            $summary | Should -Not -BeNullOrEmpty
            $summary.Results[0].WingetId | Should -Be 'Git.Git'
        }
        
        It 'Should handle optional apps' {
            $persona = [PSCustomObject]@{
                name = 'test'
                base = @('Git')
                optional = @('Docker')
            }
            
            $catalog = @{
                'Git' = 'Git.Git'
                'Docker' = 'Docker.DockerDesktop'
            }
            
            $summary = Install-PersonaApps -Persona $persona -SelectedOptionalApps @('Docker') -Catalog $catalog -LogsDir $script:testLogsDir -DryRun
            
            $summary | Should -Not -BeNullOrEmpty
            $summary.TotalApps | Should -Be 2
        }
    }
    
    Context 'Show-InstallationResults' {
        It 'Should display results without error' {
            $summary = [PSCustomObject]@{
                PersonaName = 'test'
                Results = @(
                    [PSCustomObject]@{ DisplayName = 'Git'; Status = 'Success'; WingetId = 'Git.Git'; Duration = [TimeSpan]::FromSeconds(30); LogPath = ''; Message = '' },
                    [PSCustomObject]@{ DisplayName = 'Docker'; Status = 'Failed'; WingetId = 'Docker.DockerDesktop'; Duration = [TimeSpan]::FromSeconds(60); LogPath = ''; Message = 'Failed' }
                )
                TotalApps = 2
                Successful = 1
                Failed = 1
                Skipped = 0
                Duration = [TimeSpan]::FromSeconds(90)
            }
            
            { Show-InstallationResults -Summary $summary } | Should -Not -Throw
        }
        
        It 'Should handle empty results' {
            $summary = [PSCustomObject]@{
                PersonaName = 'empty'
                Results = @()
                TotalApps = 0
                Successful = 0
                Failed = 0
                Skipped = 0
                Duration = [TimeSpan]::Zero
            }
            
            { Show-InstallationResults -Summary $summary } | Should -Not -Throw
        }
        
        It 'Should handle all success results' {
            $summary = [PSCustomObject]@{
                PersonaName = 'success'
                Results = @(
                    [PSCustomObject]@{ DisplayName = 'Git'; Status = 'Success'; Duration = [TimeSpan]::FromSeconds(10); LogPath = ''; Message = '' },
                    [PSCustomObject]@{ DisplayName = 'VS Code'; Status = 'Success'; Duration = [TimeSpan]::FromSeconds(20); LogPath = ''; Message = '' }
                )
                TotalApps = 2
                Successful = 2
                Failed = 0
                Skipped = 0
                Duration = [TimeSpan]::FromSeconds(30)
            }
            
            { Show-InstallationResults -Summary $summary } | Should -Not -Throw
        }
        
        It 'Should handle dry run results' {
            $summary = [PSCustomObject]@{
                PersonaName = 'dryrun'
                Results = @(
                    [PSCustomObject]@{ DisplayName = 'Git'; Status = 'DryRun'; Duration = [TimeSpan]::Zero; LogPath = ''; Message = '' }
                )
                TotalApps = 1
                Successful = 0
                Failed = 0
                Skipped = 1
                Duration = [TimeSpan]::Zero
            }
            
            { Show-InstallationResults -Summary $summary } | Should -Not -Throw
        }
    }
}

