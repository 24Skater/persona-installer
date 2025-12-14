<#
InstallEngine.psm1 - Installation logic module
Handles winget operations, app installation, and verification
#>

function Test-AppInstalled {
    <#
    .SYNOPSIS
        Test if an application is already installed
    .DESCRIPTION
        Checks winget list to see if app with given ID is installed
    .PARAMETER WingetId
        The winget package ID to check
    .OUTPUTS
        Boolean indicating if app is installed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetId
    )
    
    try {
        Write-Verbose "Checking if '$WingetId' is installed"
        $result = & winget list --id $WingetId -e --disable-interactivity 2>$null
        $isInstalled = ($LASTEXITCODE -eq 0) -and ($result -match [Regex]::Escape($WingetId))
        
        Write-Verbose "App '$WingetId' installed: $isInstalled"
        return $isInstalled
    }
    catch {
        Write-Verbose "Error checking installation status for '$WingetId': $($_.Exception.Message)"
        return $false
    }
}

function Install-App {
    <#
    .SYNOPSIS
        Install a single application using winget
    .DESCRIPTION
        Installs app with retry logic and comprehensive logging
    .PARAMETER DisplayName
        Human-friendly name of the app
    .PARAMETER WingetId
        Winget package ID
    .PARAMETER LogPath
        Path to log file for this installation
    .PARAMETER Settings
        Installation settings hashtable
    .PARAMETER DryRun
        Whether to simulate installation
    .OUTPUTS
        Installation result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$WingetId,
        
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $result = [PSCustomObject]@{
        DisplayName = $DisplayName
        WingetId = $WingetId
        Status = 'Unknown'
        Message = ''
        Duration = [TimeSpan]::Zero
        LogPath = $LogPath
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Write-Verbose "Starting installation: $DisplayName ($WingetId)"
        
        if ($DryRun) {
            $result.Status = 'DryRun'
            $result.Message = "Would install $DisplayName ($WingetId)"
            Write-Verbose "DRY RUN: Would install $DisplayName"
            return $result
        }
        
        # Check if already installed
        if (Test-AppInstalled -WingetId $WingetId) {
            $result.Status = 'AlreadyInstalled'
            $result.Message = 'Application is already installed'
            Write-Verbose "App '$DisplayName' is already installed"
            return $result
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Initial installation attempt with settings
        $maxRetries = if ($Settings.MaxRetries) { $Settings.MaxRetries } else { 3 }
        $silentFirst = if ($Settings.SilentInstallFirst -ne $null) { $Settings.SilentInstallFirst } else { $true }
        $retryDelay = if ($Settings.RetryDelay) { $Settings.RetryDelay } else { 2 }
        
        $installResult = Install-AppWithRetry -WingetId $WingetId -LogPath $LogPath -MaxRetries $maxRetries -SilentFirst $silentFirst -RetryDelaySeconds $retryDelay
        
        $result.Status = $installResult.Status
        $result.Message = $installResult.Message
        
        Write-Verbose "Installation completed: $DisplayName - Status: $($result.Status)"
        
    }
    catch {
        $result.Status = 'Error'
        $result.Message = $_.Exception.Message
        Write-Error "Installation failed for '$DisplayName': $($_.Exception.Message)"
    }
    finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed
    }
    
    return $result
}

function Install-AppWithRetry {
    <#
    .SYNOPSIS
        Install app with retry logic and different strategies
    .DESCRIPTION
        Attempts installation with silent mode first, then interactive, with retries
    .PARAMETER WingetId
        Winget package ID
    .PARAMETER LogPath
        Path to log file
    .PARAMETER MaxRetries
        Maximum number of retry attempts
    .PARAMETER SilentFirst
        Whether to try silent installation first
    .PARAMETER RetryDelaySeconds
        Seconds to wait between retry attempts
    .OUTPUTS
        Installation result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetId,
        
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [bool]$SilentFirst = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 2
    )
    
    $attempts = 0
    $strategies = @()
    
    # Define installation strategies
    if ($SilentFirst) {
        $strategies += @{
            Name = 'Silent'
            Args = @('install', '--id', $WingetId, '-e', '--accept-source-agreements', '--accept-package-agreements', '--silent')
        }
    }
    
    $strategies += @{
        Name = 'Interactive'
        Args = @('install', '--id', $WingetId, '-e', '--accept-source-agreements', '--accept-package-agreements')
    }
    
    foreach ($strategy in $strategies) {
        $attempts++
        Write-Verbose "Attempt $attempts using $($strategy.Name) mode for '$WingetId'"
        
        try {
            # Log the command being executed
            $commandLine = "winget $($strategy.Args -join ' ')"
            Add-Content -Path $LogPath -Value "=== Attempt $attempts ($($strategy.Name)) - $(Get-Date) ===" -Encoding UTF8
            Add-Content -Path $LogPath -Value "Command: $commandLine" -Encoding UTF8
            
            # Execute winget install
            $output = & winget @($strategy.Args) 2>&1
            $exitCode = $LASTEXITCODE
            
            # Log the output
            $output | ForEach-Object { Add-Content -Path $LogPath -Value $_ -Encoding UTF8 }
            Add-Content -Path $LogPath -Value "Exit Code: $exitCode" -Encoding UTF8
            Add-Content -Path $LogPath -Value "=== End Attempt $attempts ===" -Encoding UTF8
            
            # Check if installation was successful
            if ($exitCode -eq 0 -or (Test-AppInstalled -WingetId $WingetId)) {
                return [PSCustomObject]@{
                    Status = 'Success'
                    Message = "Successfully installed using $($strategy.Name) mode"
                }
            }
            
            Write-Verbose "Attempt $attempts failed with exit code: $exitCode"
            
        }
        catch {
            Write-Verbose "Attempt $attempts threw exception: $($_.Exception.Message)"
            Add-Content -Path $LogPath -Value "Exception: $($_.Exception.Message)" -Encoding UTF8
        }
        
        # Don't retry if we've reached max attempts
        if ($attempts -ge $MaxRetries) {
            break
        }
        
        # Brief delay between attempts (configurable)
        if ($RetryDelaySeconds -gt 0) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    
    # All attempts failed
    return [PSCustomObject]@{
        Status = 'Failed'
        Message = "Installation failed after $attempts attempts. Check log: $LogPath"
    }
}

function Install-PersonaApps {
    <#
    .SYNOPSIS
        Install all apps for a persona
    .DESCRIPTION
        Installs base and optional apps with progress tracking.
        Uses EnhancedProgressManager when available for ETA, speed metrics, and better feedback.
    .PARAMETER Persona
        Persona object containing app lists
    .PARAMETER SelectedOptionalApps
        Array of selected optional apps
    .PARAMETER Catalog
        Catalog hashtable for winget ID lookup
    .PARAMETER LogsDir
        Directory for log files
    .PARAMETER Settings
        Installation settings
    .PARAMETER UseEnhancedProgress
        Use enhanced progress manager with ETA and speed metrics
    .PARAMETER DryRun
        Whether to simulate installation
    .OUTPUTS
        Installation summary object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Persona,
        
        [Parameter(Mandatory = $false)]
        [array]$SelectedOptionalApps = @(),
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog,
        
        [Parameter(Mandatory = $true)]
        [string]$LogsDir,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$UseEnhancedProgress,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    Write-Verbose "Installing persona: $($Persona.name)"
    
    # Combine base and selected optional apps
    $allApps = @($Persona.base) + @($SelectedOptionalApps)
    $totalApps = $allApps.Count
    
    if ($totalApps -eq 0) {
        Write-Warning "No apps to install for persona '$($Persona.name)'"
        return [PSCustomObject]@{
            PersonaName = $Persona.name
            TotalApps = 0
            Successful = 0
            Failed = 0
            Skipped = 0
            Results = @()
            Duration = [TimeSpan]::Zero
        }
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $results = @()
    $successful = 0
    $failed = 0
    $skipped = 0
    
    Write-Verbose "Installing $totalApps apps: $($allApps -join ', ')"
    
    # Initialize enhanced progress manager if available and requested
    $progressManager = $null
    $useEnhanced = $UseEnhancedProgress.IsPresent -and (Get-Command 'Initialize-ProgressManager' -ErrorAction SilentlyContinue)
    
    if ($useEnhanced) {
        $progressManager = Initialize-ProgressManager -TotalItems $totalApps -Title "Installing $($Persona.name)" -ShowETA -ShowSpeed
        Write-Verbose "Using enhanced progress manager"
    }
    
    for ($i = 0; $i -lt $allApps.Count; $i++) {
        $appName = $allApps[$i]
        $currentIndex = $i + 1
        
        # Update progress display
        if ($useEnhanced -and $progressManager) {
            Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status "Installing"
        } else {
            # Fallback to basic progress
            Write-Progress -Activity "Installing Apps" -Status "[$currentIndex/$totalApps] $appName" -PercentComplete (($currentIndex / $totalApps) * 100)
        }
        
        # Check if app exists in catalog
        if (-not $Catalog.ContainsKey($appName)) {
            Write-Warning "App '$appName' not found in catalog. Skipping."
            $installResult = [PSCustomObject]@{
                DisplayName = $appName
                WingetId = 'Unknown'
                Status = 'NotInCatalog'
                Message = 'App not found in catalog'
                Duration = [TimeSpan]::Zero
                LogPath = ''
            }
            $results += $installResult
            $skipped++
            
            # Update enhanced progress with result
            if ($useEnhanced -and $progressManager) {
                Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status "Skipped" -ItemResult $installResult
            }
            continue
        }
        
        # Get winget ID - handle both legacy (string) and enhanced (object) catalog formats
        $catalogEntry = $Catalog[$appName]
        $wingetId = if ($catalogEntry -is [string]) { $catalogEntry } else { $catalogEntry.id }
        
        $logFileName = ($appName -replace '[^\w\-\.]', '_') + '.log'
        $logPath = Join-Path $LogsDir $logFileName
        
        # Install the app
        $installResult = Install-App -DisplayName $appName -WingetId $wingetId -LogPath $logPath -Settings $Settings -DryRun:$DryRun
        $results += $installResult
        
        # Update counters
        switch ($installResult.Status) {
            'Success' { $successful++ }
            'AlreadyInstalled' { $skipped++ }
            'DryRun' { $skipped++ }
            default { $failed++ }
        }
        
        # Update enhanced progress with result
        if ($useEnhanced -and $progressManager) {
            Update-Progress -ProgressManager $progressManager -CurrentItem $appName -Status $installResult.Status -ItemResult $installResult
        }
        
        # Brief pause between installations (configurable, default 1 second)
        if (-not $DryRun -and $i -lt ($allApps.Count - 1)) {
            $pauseSeconds = if ($Settings.InstallPauseSeconds) { $Settings.InstallPauseSeconds } else { 1 }
            if ($pauseSeconds -gt 0) {
                Start-Sleep -Seconds $pauseSeconds
            }
        }
    }
    
    # Complete progress tracking
    if ($useEnhanced -and $progressManager) {
        Complete-Progress -ProgressManager $progressManager -ShowSummary
    } else {
        Write-Progress -Activity "Installing Apps" -Completed
    }
    
    $stopwatch.Stop()
    
    $summary = [PSCustomObject]@{
        PersonaName = $Persona.name
        TotalApps = $totalApps
        Successful = $successful
        Failed = $failed
        Skipped = $skipped
        Results = $results
        Duration = $stopwatch.Elapsed
    }
    
    Write-Verbose "Installation summary: $successful successful, $failed failed, $skipped skipped"
    
    return $summary
}

function Show-InstallationResults {
    <#
    .SYNOPSIS
        Display installation results summary
    .DESCRIPTION
        Shows formatted results of persona installation
    .PARAMETER Summary
        Installation summary object
    .PARAMETER ShowDetails
        Whether to show detailed results for each app
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Summary,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )
    
    Write-Host "`n=== Installation Results ===" -ForegroundColor Cyan
    Write-Host "Persona: $($Summary.PersonaName)" -ForegroundColor White
    Write-Host "Duration: $($Summary.Duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host ""
    
    # Summary stats
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  [OK] Successful: $($Summary.Successful)" -ForegroundColor Green
    Write-Host "  [X] Failed: $($Summary.Failed)" -ForegroundColor Red
    Write-Host "  [>>] Skipped: $($Summary.Skipped)" -ForegroundColor Gray
    Write-Host "  Total: $($Summary.TotalApps)" -ForegroundColor White
    
    if ($ShowDetails -and $Summary.Results.Count -gt 0) {
        Write-Host "`nDetailed Results:" -ForegroundColor Yellow
        
        foreach ($result in $Summary.Results) {
            $statusIcon = switch ($result.Status) {
                'Success' { '[OK]' }
                'AlreadyInstalled' { '[>>]' }
                'Failed' { '[X]' }
                'Error' { '[!]' }
                'DryRun' { '[?]' }
                'NotInCatalog' { '[?]' }
                default { '[?]' }
            }
            
            $statusColor = switch ($result.Status) {
                'Success' { 'Green' }
                'AlreadyInstalled' { 'Gray' }
                'Failed' { 'Red' }
                'Error' { 'Red' }
                'DryRun' { 'Yellow' }
                'NotInCatalog' { 'Yellow' }
                default { 'White' }
            }
            
            Write-Host "  $statusIcon $($result.DisplayName)" -ForegroundColor $statusColor
            if ($result.Message) {
                Write-Host "     $($result.Message)" -ForegroundColor Gray
            }
            if ($result.Duration -gt [TimeSpan]::Zero) {
                Write-Host "     Duration: $($result.Duration.ToString('mm\:ss'))" -ForegroundColor Gray
            }
        }
    }
    
    # Show failed apps with log paths
    $failedApps = $Summary.Results | Where-Object { $_.Status -in @('Failed', 'Error') }
    if ($failedApps.Count -gt 0) {
        Write-Host "`nFailed Installations:" -ForegroundColor Red
        foreach ($failed in $failedApps) {
            Write-Host "  [X] $($failed.DisplayName)" -ForegroundColor Red
            if ($failed.LogPath -and (Test-Path $failed.LogPath)) {
                Write-Host "     Log: $($failed.LogPath)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
}

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Test if winget is available and functional
    .DESCRIPTION
        Checks if winget command is available and responds correctly
    .OUTPUTS
        Boolean indicating if winget is available
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Testing winget availability"
        $result = & winget --version 2>$null
        $available = ($LASTEXITCODE -eq 0) -and ($result -match 'v[\d\.]+')
        
        if ($available) {
            Write-Verbose "Winget is available: $result"
        } else {
            Write-Verbose "Winget test failed"
        }
        
        return $available
    }
    catch {
        Write-Verbose "Winget availability test threw exception: $($_.Exception.Message)"
        return $false
    }
}

function Get-WingetVersion {
    <#
    .SYNOPSIS
        Get the installed winget version
    .DESCRIPTION
        Returns the version string of the installed winget
    .OUTPUTS
        Version string or null if not available
    #>
    [CmdletBinding()]
    param()
    
    try {
        $output = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $output -match 'v([\d\.]+)') {
            return $matches[1]
        }
        return $null
    }
    catch {
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Test-AppInstalled, Install-App, Install-AppWithRetry, Install-PersonaApps, Show-InstallationResults, Test-WingetAvailable, Get-WingetVersion
