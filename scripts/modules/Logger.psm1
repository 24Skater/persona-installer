<#
Logger.psm1 - Logging utilities module
Handles structured logging, transcript management, and log analysis
#>

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system
    .DESCRIPTION
        Sets up logging directories and starts transcript logging
    .PARAMETER LogsDir
        Directory for log files
    .PARAMETER SessionPrefix
        Prefix for session log files
    .OUTPUTS
        Logging configuration object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogsDir,
        
        [Parameter(Mandatory = $false)]
        [string]$SessionPrefix = "session"
    )
    
    try {
        # Ensure logs directory exists
        if (-not (Test-Path $LogsDir)) {
            New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
            Write-Verbose "Created logs directory: $LogsDir"
        }
        
        # Generate session log filename
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $sessionLogName = "$SessionPrefix-$timestamp.txt"
        $sessionLogPath = Join-Path $LogsDir $sessionLogName
        
        # Start transcript logging
        try {
            Start-Transcript -Path $sessionLogPath -Force | Out-Null
            Write-Verbose "Started transcript logging: $sessionLogPath"
        }
        catch {
            Write-Warning "Failed to start transcript logging: $($_.Exception.Message)"
        }
        
        # Clean up old logs if needed
        Clear-OldLogs -LogsDir $LogsDir -RetentionDays 30
        
        $config = [PSCustomObject]@{
            LogsDir = $LogsDir
            SessionLogPath = $sessionLogPath
            StartTime = Get-Date
            LogLevel = 'INFO'
        }
        
        Write-Log -Level 'INFO' -Message "Logging initialized" -Config $config
        
        return $config
    }
    catch {
        Write-Error "Failed to initialize logging: $($_.Exception.Message)"
        throw
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Write structured log entry
    .DESCRIPTION
        Writes log entry with timestamp, level, and structured data
    .PARAMETER Level
        Log level (DEBUG, INFO, WARN, ERROR)
    .PARAMETER Message
        Log message
    .PARAMETER Context
        Additional context data
    .PARAMETER Config
        Logging configuration
    .PARAMETER LogPath
        Specific log file path (optional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = $null
    )
    
    try {
        $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        
        # Create structured log entry
        $logEntry = [PSCustomObject]@{
            timestamp = $timestamp
            level = $Level
            message = $Message
            context = $Context
            process_id = $PID
            thread_id = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        # Convert to JSON for structured logging
        $jsonLog = $logEntry | ConvertTo-Json -Compress
        
        # Determine log file path
        $targetLogPath = if ($LogPath) { 
            $LogPath 
        } elseif ($Config -and $Config.SessionLogPath) { 
            $Config.SessionLogPath 
        } else { 
            $null 
        }
        
        # Write to log file if path available
        if ($targetLogPath) {
            try {
                Add-Content -Path $targetLogPath -Value $jsonLog -Encoding UTF8
            }
            catch {
                Write-Warning "Failed to write to log file '$targetLogPath': $($_.Exception.Message)"
            }
        }
        
        # Also write to console with appropriate color
        $color = switch ($Level) {
            'DEBUG' { 'Gray' }
            'INFO' { 'White' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            default { 'White' }
        }
        
        $consoleMessage = "[$timestamp] [$Level] $Message"
        if ($Context.Count -gt 0) {
            $contextStr = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
            $consoleMessage += " | $contextStr"
        }
        
        Write-Host $consoleMessage -ForegroundColor $color
    }
    catch {
        Write-Warning "Error in Write-Log: $($_.Exception.Message)"
    }
}

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Write error log entry
    .DESCRIPTION
        Convenience function for error logging with exception details
    .PARAMETER Message
        Error message
    .PARAMETER Exception
        Exception object
    .PARAMETER Context
        Additional context
    .PARAMETER Config
        Logging configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception = $null,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null
    )
    
    if ($Exception) {
        $Context['exception_type'] = $Exception.GetType().Name
        $Context['exception_message'] = $Exception.Message
        if ($Exception.StackTrace) {
            $Context['stack_trace'] = $Exception.StackTrace
        }
    }
    
    Write-Log -Level 'ERROR' -Message $Message -Context $Context -Config $Config
}

function Write-PerformanceLog {
    <#
    .SYNOPSIS
        Write performance timing log entry
    .DESCRIPTION
        Logs performance metrics for operations
    .PARAMETER Operation
        Name of the operation
    .PARAMETER Duration
        Duration of the operation
    .PARAMETER Context
        Additional performance context
    .PARAMETER Config
        Logging configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null
    )
    
    $Context['operation'] = $Operation
    $Context['duration_ms'] = $Duration.TotalMilliseconds
    $Context['duration_formatted'] = $Duration.ToString('mm\:ss\.fff')
    
    $message = "Performance: $Operation completed in $($Duration.ToString('mm\:ss\.fff'))"
    Write-Log -Level 'INFO' -Message $message -Context $Context -Config $Config
}

function Start-LoggedOperation {
    <#
    .SYNOPSIS
        Start a logged operation with timing
    .DESCRIPTION
        Begins timing an operation and returns a stopwatch object
    .PARAMETER OperationName
        Name of the operation being timed
    .PARAMETER Config
        Logging configuration
    .OUTPUTS
        Operation tracking object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null
    )
    
    $operation = [PSCustomObject]@{
        Name = $OperationName
        StartTime = Get-Date
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Config = $Config
    }
    
    Write-Log -Level 'INFO' -Message "Starting operation: $OperationName" -Config $Config
    
    return $operation
}

function Stop-LoggedOperation {
    <#
    .SYNOPSIS
        Stop a logged operation and write performance log
    .DESCRIPTION
        Stops timing an operation and logs the performance metrics
    .PARAMETER Operation
        Operation tracking object from Start-LoggedOperation
    .PARAMETER Context
        Additional context for the performance log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Operation,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{}
    )
    
    if ($Operation.Stopwatch) {
        $Operation.Stopwatch.Stop()
        Write-PerformanceLog -Operation $Operation.Name -Duration $Operation.Stopwatch.Elapsed -Context $Context -Config $Operation.Config
    }
}

function Clear-OldLogs {
    <#
    .SYNOPSIS
        Clean up old log files
    .DESCRIPTION
        Removes log files older than specified retention period
    .PARAMETER LogsDir
        Directory containing log files
    .PARAMETER RetentionDays
        Number of days to retain logs
    .PARAMETER DryRun
        Preview what would be deleted without actually deleting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogsDir,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    try {
        if (-not (Test-Path $LogsDir)) {
            Write-Verbose "Logs directory does not exist: $LogsDir"
            return
        }
        
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldFiles = Get-ChildItem -Path $LogsDir -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldFiles.Count -eq 0) {
            Write-Verbose "No old log files to clean up"
            return
        }
        
        Write-Verbose "Found $($oldFiles.Count) log files older than $RetentionDays days"
        
        foreach ($file in $oldFiles) {
            if ($DryRun) {
                Write-Host "Would delete: $($file.FullName) ($(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd'))" -ForegroundColor Yellow
            } else {
                try {
                    Remove-Item -Path $file.FullName -Force
                    Write-Verbose "Deleted old log file: $($file.Name)"
                }
                catch {
                    Write-Warning "Failed to delete log file '$($file.Name)': $($_.Exception.Message)"
                }
            }
        }
        
        if (-not $DryRun) {
            Write-Verbose "Cleaned up $($oldFiles.Count) old log files"
        }
    }
    catch {
        Write-Warning "Error during log cleanup: $($_.Exception.Message)"
    }
}

function Get-LogStatistics {
    <#
    .SYNOPSIS
        Get statistics about log files
    .DESCRIPTION
        Analyzes log directory and returns usage statistics
    .PARAMETER LogsDir
        Directory containing log files
    .OUTPUTS
        Log statistics object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogsDir
    )
    
    try {
        if (-not (Test-Path $LogsDir)) {
            return $null
        }
        
        $logFiles = Get-ChildItem -Path $LogsDir -File
        $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
        $oldestFile = $logFiles | Sort-Object LastWriteTime | Select-Object -First 1
        $newestFile = $logFiles | Sort-Object LastWriteTime | Select-Object -Last 1
        
        $stats = [PSCustomObject]@{
            TotalFiles = $logFiles.Count
            TotalSizeBytes = $totalSize
            TotalSizeMB = [Math]::Round($totalSize / 1MB, 2)
            OldestLogDate = if ($oldestFile) { $oldestFile.LastWriteTime } else { $null }
            NewestLogDate = if ($newestFile) { $newestFile.LastWriteTime } else { $null }
            AverageFileSizeKB = if ($logFiles.Count -gt 0) { [Math]::Round($totalSize / $logFiles.Count / 1KB, 2) } else { 0 }
        }
        
        return $stats
    }
    catch {
        Write-Warning "Error getting log statistics: $($_.Exception.Message)"
        return $null
    }
}

function Stop-Logging {
    <#
    .SYNOPSIS
        Stop logging and clean up
    .DESCRIPTION
        Stops transcript logging and performs cleanup
    .PARAMETER Config
        Logging configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null
    )
    
    try {
        if ($Config) {
            $duration = (Get-Date) - $Config.StartTime
            Write-Log -Level 'INFO' -Message "Logging session ended" -Context @{ duration_minutes = [Math]::Round($duration.TotalMinutes, 2) } -Config $Config
        }
        
        # Stop transcript if it's running
        try {
            Stop-Transcript | Out-Null
            Write-Verbose "Stopped transcript logging"
        }
        catch {
            # Transcript may not be running, which is fine
            Write-Verbose "Transcript was not running or failed to stop"
        }
    }
    catch {
        Write-Warning "Error stopping logging: $($_.Exception.Message)"
    }
}

function Write-InstallLog {
    <#
    .SYNOPSIS
        Write installation-specific log entry
    .DESCRIPTION
        Convenience function for logging installation events
    .PARAMETER AppName
        Name of the app being installed
    .PARAMETER WingetId
        Winget package ID
    .PARAMETER Status
        Installation status
    .PARAMETER Message
        Log message
    .PARAMETER Duration
        Installation duration
    .PARAMETER Config
        Logging configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$WingetId,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [string]$Message = '',
        
        [Parameter(Mandatory = $false)]
        [TimeSpan]$Duration = [TimeSpan]::Zero,
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config = $null
    )
    
    $context = @{
        app_name = $AppName
        winget_id = $WingetId
        install_status = $Status
    }
    
    if ($Duration -gt [TimeSpan]::Zero) {
        $context.duration_seconds = [Math]::Round($Duration.TotalSeconds, 2)
    }
    
    $logLevel = switch ($Status.ToLower()) {
        'success' { 'INFO' }
        'failed' { 'ERROR' }
        'error' { 'ERROR' }
        'skipped' { 'INFO' }
        default { 'INFO' }
    }
    
    $logMessage = if ($Message) { $Message } else { "App installation: $AppName - $Status" }
    
    Write-Log -Level $logLevel -Message $logMessage -Context $context -Config $Config
}

# Export functions
Export-ModuleMember -Function Initialize-Logging, Write-Log, Write-ErrorLog, Write-PerformanceLog, Start-LoggedOperation, Stop-LoggedOperation, Clear-OldLogs, Get-LogStatistics, Stop-Logging, Write-InstallLog
