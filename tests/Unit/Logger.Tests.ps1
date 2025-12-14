#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for Logger module
.DESCRIPTION
    Tests logging initialization, log writing, and cleanup functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/Logger.psm1'
    Import-Module $modulePath -Force
    
    # Create test logs directory
    $script:testLogsDir = Join-Path $TestDrive 'logs'
    New-Item -ItemType Directory -Path $script:testLogsDir -Force | Out-Null
}

AfterAll {
    # Stop any running transcript
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    Remove-Module Logger -ErrorAction SilentlyContinue
}

Describe 'Logger Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module Logger).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Initialize-Logging'
            $exportedFunctions | Should -Contain 'Write-Log'
            $exportedFunctions | Should -Contain 'Write-ErrorLog'
            $exportedFunctions | Should -Contain 'Write-PerformanceLog'
            $exportedFunctions | Should -Contain 'Start-LoggedOperation'
            $exportedFunctions | Should -Contain 'Stop-LoggedOperation'
            $exportedFunctions | Should -Contain 'Clear-OldLogs'
            $exportedFunctions | Should -Contain 'Stop-Logging'
        }
    }
    
    Context 'Initialize-Logging' {
        BeforeEach {
            try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
        }
        
        It 'Should create logs directory if it does not exist' {
            $newLogsDir = Join-Path $TestDrive 'newlogs'
            $config = Initialize-Logging -LogsDir $newLogsDir
            
            Test-Path $newLogsDir | Should -Be $true
            
            Stop-Logging -Config $config
        }
        
        It 'Should return configuration object' {
            $config = Initialize-Logging -LogsDir $script:testLogsDir
            
            $config | Should -Not -BeNullOrEmpty
            $config.LogsDir | Should -Be $script:testLogsDir
            $config.SessionLogPath | Should -Not -BeNullOrEmpty
            $config.StartTime | Should -Not -BeNullOrEmpty
            
            Stop-Logging -Config $config
        }
        
        It 'Should accept custom session prefix' {
            $config = Initialize-Logging -LogsDir $script:testLogsDir -SessionPrefix 'custom'
            
            $config.SessionLogPath | Should -Match 'custom-'
            
            Stop-Logging -Config $config
        }
        
        It 'Should accept retention days parameter' {
            $config = Initialize-Logging -LogsDir $script:testLogsDir -RetentionDays 7
            
            $config | Should -Not -BeNullOrEmpty
            
            Stop-Logging -Config $config
        }
    }
    
    Context 'Write-Log' {
        BeforeAll {
            try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
            $script:logConfig = Initialize-Logging -LogsDir $script:testLogsDir -SessionPrefix 'writetest'
        }
        
        AfterAll {
            Stop-Logging -Config $script:logConfig
        }
        
        It 'Should not throw for INFO level' {
            { Write-Log -Level 'INFO' -Message 'Test info message' -Config $script:logConfig } | Should -Not -Throw
        }
        
        It 'Should not throw for WARN level' {
            { Write-Log -Level 'WARN' -Message 'Test warning message' -Config $script:logConfig } | Should -Not -Throw
        }
        
        It 'Should not throw for ERROR level' {
            { Write-Log -Level 'ERROR' -Message 'Test error message' -Config $script:logConfig } | Should -Not -Throw
        }
        
        It 'Should not throw for DEBUG level' {
            { Write-Log -Level 'DEBUG' -Message 'Test debug message' -Config $script:logConfig } | Should -Not -Throw
        }
        
        It 'Should accept context hashtable' {
            { Write-Log -Level 'INFO' -Message 'Test with context' -Context @{ key = 'value' } -Config $script:logConfig } | Should -Not -Throw
        }
    }
    
    Context 'Write-ErrorLog' {
        BeforeAll {
            try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
            $script:errorLogConfig = Initialize-Logging -LogsDir $script:testLogsDir -SessionPrefix 'errortest'
        }
        
        AfterAll {
            Stop-Logging -Config $script:errorLogConfig
        }
        
        It 'Should not throw for error message' {
            { Write-ErrorLog -Message 'Test error' -Config $script:errorLogConfig } | Should -Not -Throw
        }
        
        It 'Should accept exception object' {
            try { throw 'Test exception' } catch { $testException = $_.Exception }
            { Write-ErrorLog -Message 'Error with exception' -Exception $testException -Config $script:errorLogConfig } | Should -Not -Throw
        }
    }
    
    Context 'Start-LoggedOperation and Stop-LoggedOperation' {
        BeforeAll {
            try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
            $script:opLogConfig = Initialize-Logging -LogsDir $script:testLogsDir -SessionPrefix 'optest'
        }
        
        AfterAll {
            Stop-Logging -Config $script:opLogConfig
        }
        
        It 'Should track operation timing' {
            $operation = Start-LoggedOperation -OperationName 'TestOperation' -Config $script:opLogConfig
            
            $operation | Should -Not -BeNullOrEmpty
            $operation.Name | Should -Be 'TestOperation'
            $operation.Stopwatch | Should -Not -BeNullOrEmpty
            
            Start-Sleep -Milliseconds 100
            
            { Stop-LoggedOperation -Operation $operation } | Should -Not -Throw
        }
    }
    
    Context 'Clear-OldLogs' {
        It 'Should remove old log files' {
            # Create old log file
            $oldLogPath = Join-Path $script:testLogsDir 'old-log.txt'
            'old log content' | Set-Content -Path $oldLogPath
            (Get-Item $oldLogPath).LastWriteTime = (Get-Date).AddDays(-35)
            
            # Create new log file
            $newLogPath = Join-Path $script:testLogsDir 'new-log.txt'
            'new log content' | Set-Content -Path $newLogPath
            
            Clear-OldLogs -LogsDir $script:testLogsDir -RetentionDays 30
            
            Test-Path $oldLogPath | Should -Be $false
            Test-Path $newLogPath | Should -Be $true
        }
        
        It 'Should support dry run mode' {
            $dryRunLogPath = Join-Path $script:testLogsDir 'dryrun-log.txt'
            'dryrun content' | Set-Content -Path $dryRunLogPath
            (Get-Item $dryRunLogPath).LastWriteTime = (Get-Date).AddDays(-35)
            
            Clear-OldLogs -LogsDir $script:testLogsDir -RetentionDays 30 -DryRun
            
            Test-Path $dryRunLogPath | Should -Be $true
        }
    }
    
    Context 'Get-LogStatistics' {
        It 'Should return log statistics for directory with files' {
            # Create a test log file first
            $testLogFile = Join-Path $script:testLogsDir 'stats-test.log'
            'test content' | Set-Content -Path $testLogFile
            
            $stats = Get-LogStatistics -LogsDir $script:testLogsDir
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalFiles | Should -BeGreaterOrEqual 1
        }
        
        It 'Should handle non-existent directory' {
            $stats = Get-LogStatistics -LogsDir (Join-Path $TestDrive 'nonexistent')
            $stats | Should -BeNullOrEmpty
        }
    }
}

