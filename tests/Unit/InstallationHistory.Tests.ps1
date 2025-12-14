#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for InstallationHistory module
.DESCRIPTION
    Tests installation history tracking functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/InstallationHistory.psm1'
    Import-Module $modulePath -Force
    
    # Create test directory for history files
    $script:testHistoryDir = Join-Path $TestDrive 'history'
    New-Item -ItemType Directory -Path $script:testHistoryDir -Force | Out-Null
    $script:testHistoryPath = Join-Path $script:testHistoryDir 'test-history.json'
}

AfterAll {
    Remove-Module InstallationHistory -ErrorAction SilentlyContinue
}

Describe 'InstallationHistory Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module InstallationHistory).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Initialize-InstallationHistory'
            $exportedFunctions | Should -Contain 'Add-InstallationRecord'
            $exportedFunctions | Should -Contain 'Get-InstallationHistory'
            $exportedFunctions | Should -Contain 'Export-InstallationHistory'
            $exportedFunctions | Should -Contain 'Clear-InstallationHistory'
        }
    }
    
    Context 'Initialize-InstallationHistory' {
        BeforeEach {
            # Clean up before each test
            if (Test-Path $script:testHistoryPath) {
                Remove-Item $script:testHistoryPath -Force
            }
        }
        
        It 'Should create history file if it does not exist' {
            $result = Initialize-InstallationHistory -HistoryPath $script:testHistoryPath
            
            Test-Path $script:testHistoryPath | Should -Be $true
            $result | Should -Not -BeNullOrEmpty
            $result.version | Should -Be '1.0'
            $result.installations | Should -Not -BeNullOrEmpty
            $result.installations.Count | Should -Be 0
        }
        
        It 'Should load existing history file' {
            # Create initial file
            $initialHistory = @{
                version = '1.0'
                installations = @(
                    @{
                        id = 'test-id-1'
                        timestamp = (Get-Date).ToString('o')
                        personaName = 'dev'
                        apps = @()
                        successful = 1
                        failed = 0
                    }
                )
            }
            $initialHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $script:testHistoryPath
            
            $result = Initialize-InstallationHistory -HistoryPath $script:testHistoryPath
            
            $result.installations.Count | Should -Be 1
            $result.installations[0].personaName | Should -Be 'dev'
        }
        
        It 'Should create directory if it does not exist' {
            $newDir = Join-Path $TestDrive 'newhistorydir'
            $newPath = Join-Path $newDir 'history.json'
            
            $result = Initialize-InstallationHistory -HistoryPath $newPath
            
            Test-Path $newDir | Should -Be $true
            Test-Path $newPath | Should -Be $true
        }
    }
    
    Context 'Add-InstallationRecord' {
        BeforeEach {
            # Start with clean history
            if (Test-Path $script:testHistoryPath) {
                Remove-Item $script:testHistoryPath -Force
            }
            Initialize-InstallationHistory -HistoryPath $script:testHistoryPath | Out-Null
        }
        
        It 'Should add installation record to history' {
            $apps = @(
                [PSCustomObject]@{ DisplayName = 'Git'; WingetId = 'Git.Git'; Status = 'Success' },
                [PSCustomObject]@{ DisplayName = 'VS Code'; WingetId = 'Microsoft.VisualStudioCode'; Status = 'Success' }
            )
            
            $record = Add-InstallationRecord -HistoryPath $script:testHistoryPath -PersonaName 'dev' -Apps $apps -Successful 2 -Failed 0
            
            $record | Should -Not -BeNullOrEmpty
            $record.id | Should -Not -BeNullOrEmpty
            $record.personaName | Should -Be 'dev'
            $record.apps.Count | Should -Be 2
            $record.successful | Should -Be 2
            $record.failed | Should -Be 0
        }
        
        It 'Should persist record to file' {
            $apps = @(
                [PSCustomObject]@{ DisplayName = 'Git'; WingetId = 'Git.Git'; Status = 'Success' }
            )
            
            Add-InstallationRecord -HistoryPath $script:testHistoryPath -PersonaName 'test' -Apps $apps -Successful 1
            
            # Reload and verify
            $history = Get-Content $script:testHistoryPath -Raw | ConvertFrom-Json
            $history.installations.Count | Should -Be 1
            $history.installations[0].personaName | Should -Be 'test'
        }
        
        It 'Should prepend new records (newest first)' {
            $apps = @([PSCustomObject]@{ DisplayName = 'App1'; WingetId = 'Test.App1'; Status = 'Success' })
            
            Add-InstallationRecord -HistoryPath $script:testHistoryPath -PersonaName 'first' -Apps $apps
            Start-Sleep -Milliseconds 100
            Add-InstallationRecord -HistoryPath $script:testHistoryPath -PersonaName 'second' -Apps $apps
            
            $history = Get-Content $script:testHistoryPath -Raw | ConvertFrom-Json
            $history.installations[0].personaName | Should -Be 'second'
            $history.installations[1].personaName | Should -Be 'first'
        }
    }
    
    Context 'Get-InstallationHistory' {
        BeforeAll {
            # Set up test data
            if (Test-Path $script:testHistoryPath) {
                Remove-Item $script:testHistoryPath -Force
            }
            
            $testHistory = @{
                version = '1.0'
                installations = @(
                    @{
                        id = 'id-1'
                        timestamp = (Get-Date).ToString('o')
                        personaName = 'dev'
                        apps = @(@{ name = 'Git'; wingetId = 'Git.Git'; status = 'Success' })
                        successful = 1
                        failed = 0
                    },
                    @{
                        id = 'id-2'
                        timestamp = (Get-Date).AddDays(-5).ToString('o')
                        personaName = 'personal'
                        apps = @(@{ name = 'Chrome'; wingetId = 'Google.Chrome'; status = 'Success' })
                        successful = 1
                        failed = 0
                    },
                    @{
                        id = 'id-3'
                        timestamp = (Get-Date).AddDays(-40).ToString('o')
                        personaName = 'dev'
                        apps = @(@{ name = 'VS Code'; wingetId = 'Microsoft.VisualStudioCode'; status = 'Success' })
                        successful = 1
                        failed = 0
                    }
                )
            }
            $testHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $script:testHistoryPath
        }
        
        It 'Should return all records when no filter specified' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath
            
            $results.Count | Should -Be 3
        }
        
        It 'Should filter by persona name' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath -PersonaName 'dev'
            
            $results.Count | Should -Be 2
            $results | ForEach-Object { $_.personaName | Should -Be 'dev' }
        }
        
        It 'Should filter by days' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath -Days 7
            
            $results.Count | Should -Be 2
        }
        
        It 'Should filter by days and persona combined' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath -PersonaName 'dev' -Days 7
            
            $results.Count | Should -Be 1
        }
        
        It 'Should apply limit' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath -Limit 2
            
            $results.Count | Should -Be 2
        }
        
        It 'Should return empty array for non-existent persona' {
            $results = Get-InstallationHistory -HistoryPath $script:testHistoryPath -PersonaName 'nonexistent'
            
            $results.Count | Should -Be 0
        }
    }
    
    Context 'Export-InstallationHistory' {
        BeforeAll {
            # Set up test data
            $exportHistoryPath = Join-Path $script:testHistoryDir 'export-test-history.json'
            $testHistory = @{
                version = '1.0'
                installations = @(
                    @{
                        id = 'export-1'
                        timestamp = (Get-Date).ToString('o')
                        personaName = 'dev'
                        apps = @(@{ name = 'Git'; wingetId = 'Git.Git'; status = 'Success' })
                        totalDuration = '00:01:30'
                        successful = 1
                        failed = 0
                    }
                )
            }
            $testHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $exportHistoryPath
            $script:exportHistoryPath = $exportHistoryPath
        }
        
        It 'Should export to CSV format' {
            $outputPath = Join-Path $script:testHistoryDir 'export.csv'
            
            $result = Export-InstallationHistory -HistoryPath $script:exportHistoryPath -OutputPath $outputPath -Format CSV
            
            Test-Path $outputPath | Should -Be $true
            $result | Should -Be $outputPath
            
            $csv = Import-Csv $outputPath
            $csv.PersonaName | Should -Be 'dev'
        }
        
        It 'Should export to JSON format' {
            $outputPath = Join-Path $script:testHistoryDir 'export.json'
            
            $result = Export-InstallationHistory -HistoryPath $script:exportHistoryPath -OutputPath $outputPath -Format JSON
            
            Test-Path $outputPath | Should -Be $true
            $result | Should -Be $outputPath
            
            $json = Get-Content $outputPath -Raw | ConvertFrom-Json
            $json[0].personaName | Should -Be 'dev'
        }
    }
    
    Context 'Clear-InstallationHistory' {
        BeforeEach {
            # Set up fresh test data
            $clearHistoryPath = Join-Path $script:testHistoryDir 'clear-test-history.json'
            $testHistory = @{
                version = '1.0'
                installations = @(
                    @{ id = '1'; timestamp = (Get-Date).ToString('o'); personaName = 'dev'; apps = @(); successful = 1; failed = 0 },
                    @{ id = '2'; timestamp = (Get-Date).AddDays(-10).ToString('o'); personaName = 'personal'; apps = @(); successful = 1; failed = 0 },
                    @{ id = '3'; timestamp = (Get-Date).AddDays(-40).ToString('o'); personaName = 'old'; apps = @(); successful = 1; failed = 0 }
                )
            }
            $testHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $clearHistoryPath
            $script:clearHistoryPath = $clearHistoryPath
        }
        
        It 'Should clear records older than specified days' {
            $removed = Clear-InstallationHistory -HistoryPath $script:clearHistoryPath -DaysToKeep 30
            
            $removed | Should -Be 1
            
            $history = Get-Content $script:clearHistoryPath -Raw | ConvertFrom-Json
            $history.installations.Count | Should -Be 2
        }
        
        It 'Should clear all records with Force flag' {
            $removed = Clear-InstallationHistory -HistoryPath $script:clearHistoryPath -DaysToKeep 0 -Force
            
            $removed | Should -Be 3
            
            $history = Get-Content $script:clearHistoryPath -Raw | ConvertFrom-Json
            $history.installations.Count | Should -Be 0
        }
        
        It 'Should return 0 for empty history' {
            Clear-InstallationHistory -HistoryPath $script:clearHistoryPath -Force | Out-Null
            
            $removed = Clear-InstallationHistory -HistoryPath $script:clearHistoryPath -Force
            
            $removed | Should -Be 0
        }
    }
}

