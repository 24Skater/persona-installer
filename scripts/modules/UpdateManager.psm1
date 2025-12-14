<#
UpdateManager.psm1 - App update detection and management module
Provides functionality to check for and apply updates via winget
Persona Installer v1.5.0
#>

function Get-InstalledApps {
    <#
    .SYNOPSIS
        Get list of installed apps from winget
    .DESCRIPTION
        Queries winget to get a list of installed applications with their versions
    .PARAMETER Filter
        Optional filter to search for specific apps
    .OUTPUTS
        Array of installed app objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Filter = ""
    )
    
    try {
        Write-Verbose "Querying installed apps from winget..."
        
        $args = @('list', '--disable-interactivity')
        if ($Filter) {
            $args += @('--query', $Filter)
        }
        
        $output = & winget @args 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget list command failed with exit code $LASTEXITCODE"
            return @()
        }
        
        # Parse winget output (skip header lines)
        $apps = @()
        $headerPassed = $false
        $separatorCount = 0
        
        foreach ($line in $output) {
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Look for separator line (dashes)
            if ($line -match '^-+') {
                $separatorCount++
                $headerPassed = $true
                continue
            }
            
            # Skip header
            if (-not $headerPassed) { continue }
            
            # Parse app line - winget output is column-based
            # Typical format: Name    Id    Version    Available    Source
            if ($line.Length -gt 20) {
                # Try to extract fields by position (approximate)
                $parts = $line -split '\s{2,}'
                
                if ($parts.Count -ge 3) {
                    $apps += [PSCustomObject]@{
                        Name = $parts[0].Trim()
                        Id = $parts[1].Trim()
                        Version = $parts[2].Trim()
                        Available = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }
                        Source = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "winget" }
                    }
                }
            }
        }
        
        Write-Verbose "Found $($apps.Count) installed apps"
        return $apps
    }
    catch {
        Write-Warning "Failed to get installed apps: $($_.Exception.Message)"
        return @()
    }
}

function Get-AvailableUpdates {
    <#
    .SYNOPSIS
        Check for available updates via winget
    .DESCRIPTION
        Queries winget upgrade to find apps with available updates
    .PARAMETER IncludeUnknown
        Include apps with unknown versions
    .OUTPUTS
        Array of apps with available updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeUnknown
    )
    
    try {
        Write-Verbose "Checking for available updates..."
        
        $output = & winget upgrade --disable-interactivity 2>$null
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
            # -1978335189 means no updates available
            Write-Verbose "winget upgrade returned exit code $LASTEXITCODE"
        }
        
        # Parse output
        $updates = @()
        $headerPassed = $false
        
        foreach ($line in $output) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Skip header section
            if ($line -match '^-+') {
                $headerPassed = $true
                continue
            }
            
            if (-not $headerPassed) { continue }
            
            # Skip summary lines
            if ($line -match 'upgrades available|winget upgrade') { continue }
            
            # Parse update line
            $parts = $line -split '\s{2,}'
            
            if ($parts.Count -ge 4) {
                $currentVersion = $parts[2].Trim()
                $availableVersion = $parts[3].Trim()
                
                # Skip if versions are unknown (unless requested)
                if (-not $IncludeUnknown -and ($currentVersion -eq 'Unknown' -or $availableVersion -eq 'Unknown')) {
                    continue
                }
                
                $updates += [PSCustomObject]@{
                    Name = $parts[0].Trim()
                    Id = $parts[1].Trim()
                    CurrentVersion = $currentVersion
                    AvailableVersion = $availableVersion
                    Source = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "winget" }
                }
            }
        }
        
        Write-Verbose "Found $($updates.Count) available updates"
        return $updates
    }
    catch {
        Write-Warning "Failed to check for updates: $($_.Exception.Message)"
        return @()
    }
}

function Get-PersonaUpdateStatus {
    <#
    .SYNOPSIS
        Check for updates for apps in a specific persona
    .DESCRIPTION
        Filters available updates to only show apps that belong to a persona
    .PARAMETER PersonaApps
        Array of app names from the persona
    .PARAMETER Catalog
        Catalog hashtable for winget ID lookup
    .OUTPUTS
        Array of persona apps with available updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$PersonaApps,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog
    )
    
    try {
        # Get all available updates
        $allUpdates = Get-AvailableUpdates
        
        if ($allUpdates.Count -eq 0) {
            Write-Verbose "No updates available"
            return @()
        }
        
        # Get winget IDs for persona apps
        $personaIds = @()
        foreach ($appName in $PersonaApps) {
            $catalogEntry = $Catalog[$appName]
            if ($catalogEntry) {
                $wingetId = if ($catalogEntry -is [string]) { $catalogEntry } else { $catalogEntry.id }
                $personaIds += [PSCustomObject]@{
                    Name = $appName
                    WingetId = $wingetId
                }
            }
        }
        
        # Filter updates to persona apps
        $personaUpdates = @()
        foreach ($update in $allUpdates) {
            $match = $personaIds | Where-Object { $_.WingetId -eq $update.Id }
            if ($match) {
                $personaUpdates += [PSCustomObject]@{
                    DisplayName = $match.Name
                    WingetId = $update.Id
                    CurrentVersion = $update.CurrentVersion
                    AvailableVersion = $update.AvailableVersion
                }
            }
        }
        
        Write-Verbose "Found $($personaUpdates.Count) updates for persona apps"
        return $personaUpdates
    }
    catch {
        Write-Warning "Failed to check persona update status: $($_.Exception.Message)"
        return @()
    }
}

function Format-UpdateList {
    <#
    .SYNOPSIS
        Format update list for display
    .DESCRIPTION
        Creates formatted output of available updates
    .PARAMETER Updates
        Array of update objects
    .PARAMETER Title
        Title for the update list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Updates,
        
        [Parameter(Mandatory = $false)]
        [string]$Title = "Available Updates"
    )
    
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Gray
    
    if ($Updates.Count -eq 0) {
        Write-Host "`nAll apps are up to date!" -ForegroundColor Green
        return
    }
    
    Write-Host "Found $($Updates.Count) update(s) available:" -ForegroundColor Yellow
    Write-Host ""
    
    $format = "{0,-30} {1,-15} {2,-15}"
    Write-Host ($format -f "App", "Current", "Available") -ForegroundColor Yellow
    Write-Host ("-" * 70) -ForegroundColor Gray
    
    foreach ($update in $Updates) {
        $name = if ($update.DisplayName) { $update.DisplayName } else { $update.Name }
        if ($name.Length -gt 28) { $name = $name.Substring(0, 25) + "..." }
        
        $current = if ($update.CurrentVersion) { $update.CurrentVersion } else { "Unknown" }
        if ($current.Length -gt 13) { $current = $current.Substring(0, 10) + "..." }
        
        $available = if ($update.AvailableVersion) { $update.AvailableVersion } else { "Unknown" }
        if ($available.Length -gt 13) { $available = $available.Substring(0, 10) + "..." }
        
        Write-Host ($format -f $name, $current, $available) -ForegroundColor White
    }
    
    Write-Host ""
}

function Update-App {
    <#
    .SYNOPSIS
        Update a single app via winget
    .DESCRIPTION
        Updates an app to the latest version using winget upgrade
    .PARAMETER WingetId
        Winget package ID to update
    .PARAMETER DryRun
        Simulate the update without making changes
    .OUTPUTS
        Update result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetId,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $result = [PSCustomObject]@{
        WingetId = $WingetId
        Status = 'Unknown'
        Message = ''
        StartTime = Get-Date
        Duration = [TimeSpan]::Zero
    }
    
    try {
        if ($DryRun) {
            Write-Host "[DryRun] Would update: $WingetId" -ForegroundColor Yellow
            $result.Status = 'DryRun'
            $result.Message = 'Update simulated (dry run)'
            return $result
        }
        
        Write-Verbose "Updating $WingetId..."
        
        $updateOutput = & winget upgrade --id $WingetId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
        
        $result.Duration = (Get-Date) - $result.StartTime
        
        if ($LASTEXITCODE -eq 0) {
            $result.Status = 'Success'
            $result.Message = 'Update completed successfully'
        } elseif ($LASTEXITCODE -eq -1978335212) {
            $result.Status = 'NoUpdate'
            $result.Message = 'No update available'
        } else {
            $result.Status = 'Failed'
            $result.Message = "Update failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        $result.Status = 'Error'
        $result.Message = $_.Exception.Message
        $result.Duration = (Get-Date) - $result.StartTime
    }
    
    return $result
}

function Update-PersonaApps {
    <#
    .SYNOPSIS
        Batch update all apps with available updates
    .DESCRIPTION
        Updates multiple apps and tracks progress
    .PARAMETER Updates
        Array of update objects to apply
    .PARAMETER DryRun
        Simulate updates without making changes
    .OUTPUTS
        Summary of update results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Updates,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    if ($Updates.Count -eq 0) {
        Write-Host "No updates to apply." -ForegroundColor Yellow
        return $null
    }
    
    $results = @()
    $successful = 0
    $failed = 0
    $startTime = Get-Date
    
    Write-Host "`nUpdating $($Updates.Count) app(s)..." -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Updates.Count; $i++) {
        $update = $Updates[$i]
        $wingetId = if ($update.WingetId) { $update.WingetId } else { $update.Id }
        $displayName = if ($update.DisplayName) { $update.DisplayName } else { $update.Name }
        
        Write-Host "[$($i + 1)/$($Updates.Count)] Updating $displayName..." -ForegroundColor White
        
        $result = Update-App -WingetId $wingetId -DryRun:$DryRun
        $result | Add-Member -NotePropertyName 'DisplayName' -NotePropertyValue $displayName -Force
        $results += $result
        
        if ($result.Status -eq 'Success' -or $result.Status -eq 'DryRun') {
            $successful++
            Write-Host "  [OK] $($result.Message)" -ForegroundColor Green
        } else {
            $failed++
            Write-Host "  [X] $($result.Message)" -ForegroundColor Red
        }
    }
    
    $totalDuration = (Get-Date) - $startTime
    
    Write-Host "`n=== Update Summary ===" -ForegroundColor Cyan
    Write-Host "Total: $($Updates.Count)" -ForegroundColor White
    Write-Host "Successful: $successful" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Duration: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor Gray
    
    return [PSCustomObject]@{
        Results = $results
        Successful = $successful
        Failed = $failed
        TotalDuration = $totalDuration
    }
}

function Update-AllApps {
    <#
    .SYNOPSIS
        Update all apps with available updates
    .DESCRIPTION
        Gets all available updates and applies them
    .PARAMETER DryRun
        Simulate updates without making changes
    .OUTPUTS
        Summary of update results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $updates = Get-AvailableUpdates
    
    if ($updates.Count -eq 0) {
        Write-Host "`nAll apps are up to date!" -ForegroundColor Green
        return $null
    }
    
    Format-UpdateList -Updates $updates -Title "All Available Updates"
    
    return Update-PersonaApps -Updates $updates -DryRun:$DryRun
}

# Export functions
Export-ModuleMember -Function Get-InstalledApps, Get-AvailableUpdates, Get-PersonaUpdateStatus, Format-UpdateList, Update-App, Update-PersonaApps, Update-AllApps

