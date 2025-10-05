<#
EnhancedProgressManager.psm1 - Advanced progress tracking and user feedback
Provides rich progress indicators, ETA calculations, and interactive feedback
#>

function Initialize-ProgressManager {
    <#
    .SYNOPSIS
        Initialize the progress management system
    .DESCRIPTION
        Sets up progress tracking with customizable display options
    .PARAMETER TotalItems
        Total number of items to process
    .PARAMETER Title
        Title for the progress display
    .PARAMETER ShowETA
        Whether to show estimated time to completion
    .PARAMETER ShowSpeed
        Whether to show processing speed
    .OUTPUTS
        Progress manager object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$TotalItems,
        
        [Parameter(Mandatory = $false)]
        [string]$Title = "Processing",
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowETA,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowSpeed
    )
    
    $progressManager = [PSCustomObject]@{
        TotalItems = $TotalItems
        CompletedItems = 0
        CurrentItem = ""
        Title = $Title
        StartTime = Get-Date
        LastUpdateTime = Get-Date
        ShowETA = $ShowETA.IsPresent
        ShowSpeed = $ShowSpeed.IsPresent
        ItemHistory = @()
        EstimatedCompletion = $null
        AverageItemTime = [TimeSpan]::Zero
        Status = "Initializing"
        Cancelled = $false
        Paused = $false
        Errors = @()
        Warnings = @()
        LogPath = $null
    }
    
    Write-Verbose "Initialized progress manager for $TotalItems items"
    return $progressManager
}

function Update-Progress {
    <#
    .SYNOPSIS
        Update progress with current item information
    .DESCRIPTION
        Updates progress display with current status and calculations
    .PARAMETER ProgressManager
        Progress manager object
    .PARAMETER CurrentItem
        Name/description of current item being processed
    .PARAMETER Status
        Current status (Processing, Completed, Failed, etc.)
    .PARAMETER ItemResult
        Result of processing current item
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager,
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentItem = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "Processing",
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$ItemResult = $null
    )
    
    $now = Get-Date
    
    # Update item if completed
    if ($ItemResult) {
        $ProgressManager.CompletedItems++
        
        # Record item timing
        $itemDuration = $now - $ProgressManager.LastUpdateTime
        $ProgressManager.ItemHistory += [PSCustomObject]@{
            Item = $ProgressManager.CurrentItem
            Duration = $itemDuration
            Result = $ItemResult.Status
            Timestamp = $now
        }
        
        # Update average timing
        if ($ProgressManager.ItemHistory.Count -gt 0) {
            $totalTime = ($ProgressManager.ItemHistory | Measure-Object -Property Duration -Sum).Sum
            $ProgressManager.AverageItemTime = [TimeSpan]::FromTicks($totalTime.Ticks / $ProgressManager.ItemHistory.Count)
        }
        
        # Track errors and warnings
        if ($ItemResult.Status -eq 'Failed' -or $ItemResult.Status -eq 'Error') {
            $ProgressManager.Errors += $ProgressManager.CurrentItem
        } elseif ($ItemResult.Status -eq 'Warning' -or $ItemResult.Status -eq 'Skipped') {
            $ProgressManager.Warnings += $ProgressManager.CurrentItem
        }
    }
    
    # Update current state
    if ($CurrentItem) {
        $ProgressManager.CurrentItem = $CurrentItem
    }
    $ProgressManager.Status = $Status
    $ProgressManager.LastUpdateTime = $now
    
    # Calculate ETA if enabled
    if ($ProgressManager.ShowETA -and $ProgressManager.ItemHistory.Count -gt 0) {
        $remainingItems = $ProgressManager.TotalItems - $ProgressManager.CompletedItems
        if ($remainingItems -gt 0 -and $ProgressManager.AverageItemTime.TotalSeconds -gt 0) {
            $estimatedRemainingTime = [TimeSpan]::FromTicks($ProgressManager.AverageItemTime.Ticks * $remainingItems)
            $ProgressManager.EstimatedCompletion = $now.Add($estimatedRemainingTime)
        }
    }
    
    # Display the progress
    Show-ProgressDisplay -ProgressManager $ProgressManager
}

function Show-ProgressDisplay {
    <#
    .SYNOPSIS
        Display the current progress to user
    .DESCRIPTION
        Shows formatted progress with bar, percentages, ETA, and status
    .PARAMETER ProgressManager
        Progress manager object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager
    )
    
    $percentComplete = if ($ProgressManager.TotalItems -gt 0) {
        [Math]::Round(($ProgressManager.CompletedItems / $ProgressManager.TotalItems) * 100, 1)
    } else { 0 }
    
    # Create progress bar (40 characters wide)
    $barWidth = 40
    $filledWidth = [Math]::Round(($percentComplete / 100) * $barWidth)
    $emptyWidth = $barWidth - $filledWidth
    
    $progressBar = "█" * $filledWidth + "░" * $emptyWidth
    
    # Build status line
    $statusParts = @()
    $statusParts += "[$($ProgressManager.CompletedItems)/$($ProgressManager.TotalItems)]"
    $statusParts += "$percentComplete%"
    
    if ($ProgressManager.ShowSpeed -and $ProgressManager.ItemHistory.Count -gt 0) {
        $elapsed = (Get-Date) - $ProgressManager.StartTime
        if ($elapsed.TotalSeconds -gt 0) {
            $itemsPerSecond = [Math]::Round($ProgressManager.CompletedItems / $elapsed.TotalSeconds, 1)
            $statusParts += "${itemsPerSecond} items/sec"
        }
    }
    
    if ($ProgressManager.ShowETA -and $ProgressManager.EstimatedCompletion) {
        $eta = $ProgressManager.EstimatedCompletion - (Get-Date)
        if ($eta.TotalSeconds -gt 0) {
            $etaStr = if ($eta.TotalHours -ge 1) {
                "{0:hh\:mm\:ss}" -f $eta
            } else {
                "{0:mm\:ss}" -f $eta
            }
            $statusParts += "ETA: $etaStr"
        }
    }
    
    # Color coding based on status
    $statusColor = switch ($ProgressManager.Status) {
        'Processing' { 'Cyan' }
        'Completed' { 'Green' }
        'Failed' { 'Red' }
        'Warning' { 'Yellow' }
        'Paused' { 'Yellow' }
        default { 'White' }
    }
    
    # Display the progress
    Write-Host "`r[$progressBar] $($statusParts -join ' | ')" -NoNewline -ForegroundColor $statusColor
    
    if ($ProgressManager.CurrentItem) {
        Write-Host " - $($ProgressManager.CurrentItem)" -NoNewline -ForegroundColor Gray
    }
    
    # Use Write-Progress for Windows PowerShell compatibility
    $activity = "$($ProgressManager.Title) - $($ProgressManager.Status)"
    $statusDescription = if ($ProgressManager.CurrentItem) { $ProgressManager.CurrentItem } else { "Processing..." }
    
    Write-Progress -Activity $activity -Status $statusDescription -PercentComplete $percentComplete
    
    # Flush the display
    if ($ProgressManager.Status -in @('Completed', 'Failed', 'Cancelled')) {
        Write-Host ""  # New line when done
        Write-Progress -Activity $activity -Completed
    }
}

function Complete-Progress {
    <#
    .SYNOPSIS
        Complete the progress and show final summary
    .DESCRIPTION
        Finalizes progress tracking and displays completion summary
    .PARAMETER ProgressManager
        Progress manager object
    .PARAMETER ShowSummary
        Whether to show detailed completion summary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowSummary
    )
    
    $ProgressManager.Status = "Completed"
    $completionTime = Get-Date
    $totalDuration = $completionTime - $ProgressManager.StartTime
    
    # Final progress display
    Show-ProgressDisplay -ProgressManager $ProgressManager
    
    if ($ShowSummary) {
        Write-Host "`n=== Completion Summary ===" -ForegroundColor Green
        Write-Host "Total Duration: $($totalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor White
        Write-Host "Items Processed: $($ProgressManager.CompletedItems)/$($ProgressManager.TotalItems)" -ForegroundColor White
        
        $successCount = $ProgressManager.CompletedItems - $ProgressManager.Errors.Count - $ProgressManager.Warnings.Count
        Write-Host "✅ Successful: $successCount" -ForegroundColor Green
        
        if ($ProgressManager.Warnings.Count -gt 0) {
            Write-Host "⚠️  Warnings: $($ProgressManager.Warnings.Count)" -ForegroundColor Yellow
        }
        
        if ($ProgressManager.Errors.Count -gt 0) {
            Write-Host "❌ Errors: $($ProgressManager.Errors.Count)" -ForegroundColor Red
        }
        
        if ($ProgressManager.ItemHistory.Count -gt 0) {
            $avgTime = $ProgressManager.AverageItemTime.TotalSeconds
            Write-Host "Average Time per Item: $([Math]::Round($avgTime, 1))s" -ForegroundColor Gray
            
            $fastest = ($ProgressManager.ItemHistory | Sort-Object Duration | Select-Object -First 1)
            $slowest = ($ProgressManager.ItemHistory | Sort-Object Duration -Descending | Select-Object -First 1)
            
            Write-Host "Fastest: $($fastest.Item) ($([Math]::Round($fastest.Duration.TotalSeconds, 1))s)" -ForegroundColor Gray
            Write-Host "Slowest: $($slowest.Item) ($([Math]::Round($slowest.Duration.TotalSeconds, 1))s)" -ForegroundColor Gray
        }
    }
    
    Write-Verbose "Progress completed: $($ProgressManager.CompletedItems)/$($ProgressManager.TotalItems) items in $($totalDuration.ToString())"
}

function Pause-Progress {
    <#
    .SYNOPSIS
        Pause progress tracking
    .DESCRIPTION
        Temporarily pauses progress display and tracking
    .PARAMETER ProgressManager
        Progress manager object
    .PARAMETER Reason
        Reason for pausing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager,
        
        [Parameter(Mandatory = $false)]
        [string]$Reason = "User requested"
    )
    
    $ProgressManager.Paused = $true
    $ProgressManager.Status = "Paused"
    
    Write-Host "`n⏸️  Progress Paused: $Reason" -ForegroundColor Yellow
    Show-ProgressDisplay -ProgressManager $ProgressManager
}

function Resume-Progress {
    <#
    .SYNOPSIS
        Resume paused progress tracking
    .DESCRIPTION
        Resumes progress display and tracking
    .PARAMETER ProgressManager
        Progress manager object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager
    )
    
    $ProgressManager.Paused = $false
    $ProgressManager.Status = "Processing"
    $ProgressManager.LastUpdateTime = Get-Date
    
    Write-Host "`n▶️  Progress Resumed" -ForegroundColor Green
    Show-ProgressDisplay -ProgressManager $ProgressManager
}

function Cancel-Progress {
    <#
    .SYNOPSIS
        Cancel progress tracking
    .DESCRIPTION
        Cancels progress and shows cancellation summary
    .PARAMETER ProgressManager
        Progress manager object
    .PARAMETER Reason
        Reason for cancellation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager,
        
        [Parameter(Mandatory = $false)]
        [string]$Reason = "User cancelled"
    )
    
    $ProgressManager.Cancelled = $true
    $ProgressManager.Status = "Cancelled"
    
    Write-Host "`n🛑 Progress Cancelled: $Reason" -ForegroundColor Red
    Show-ProgressDisplay -ProgressManager $ProgressManager
    
    Write-Host "`nPartial Results:" -ForegroundColor Yellow
    Write-Host "  Completed: $($ProgressManager.CompletedItems)/$($ProgressManager.TotalItems)" -ForegroundColor White
    Write-Host "  Remaining: $($ProgressManager.TotalItems - $ProgressManager.CompletedItems)" -ForegroundColor Gray
}

function Get-ProgressStatistics {
    <#
    .SYNOPSIS
        Get detailed progress statistics
    .DESCRIPTION
        Returns comprehensive statistics about the progress session
    .PARAMETER ProgressManager
        Progress manager object
    .OUTPUTS
        Progress statistics object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager
    )
    
    $now = Get-Date
    $totalDuration = $now - $ProgressManager.StartTime
    
    $stats = [PSCustomObject]@{
        TotalItems = $ProgressManager.TotalItems
        CompletedItems = $ProgressManager.CompletedItems
        RemainingItems = $ProgressManager.TotalItems - $ProgressManager.CompletedItems
        PercentComplete = if ($ProgressManager.TotalItems -gt 0) { ($ProgressManager.CompletedItems / $ProgressManager.TotalItems) * 100 } else { 0 }
        TotalDuration = $totalDuration
        AverageItemTime = $ProgressManager.AverageItemTime
        EstimatedTimeToCompletion = $ProgressManager.EstimatedCompletion
        SuccessfulItems = $ProgressManager.CompletedItems - $ProgressManager.Errors.Count - $ProgressManager.Warnings.Count
        ErrorCount = $ProgressManager.Errors.Count
        WarningCount = $ProgressManager.Warnings.Count
        Status = $ProgressManager.Status
        IsPaused = $ProgressManager.Paused
        IsCancelled = $ProgressManager.Cancelled
        ItemsPerSecond = if ($totalDuration.TotalSeconds -gt 0) { $ProgressManager.CompletedItems / $totalDuration.TotalSeconds } else { 0 }
    }
    
    return $stats
}

function Export-ProgressReport {
    <#
    .SYNOPSIS
        Export progress report to file
    .DESCRIPTION
        Creates a detailed progress report and saves to file
    .PARAMETER ProgressManager
        Progress manager object
    .PARAMETER OutputPath
        Path for the report file
    .PARAMETER Format
        Report format (JSON, CSV, HTML)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProgressManager,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'CSV', 'HTML')]
        [string]$Format = 'JSON'
    )
    
    $stats = Get-ProgressStatistics -ProgressManager $ProgressManager
    
    switch ($Format) {
        'JSON' {
            $report = @{
                Summary = $stats
                ItemHistory = $ProgressManager.ItemHistory
                Errors = $ProgressManager.Errors
                Warnings = $ProgressManager.Warnings
                GeneratedAt = Get-Date
            }
            $report | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
        }
        
        'CSV' {
            $ProgressManager.ItemHistory | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }
        
        'HTML' {
            # Simple HTML report
            $html = @"
<!DOCTYPE html>
<html>
<head><title>Progress Report</title></head>
<body>
<h1>Progress Report</h1>
<h2>Summary</h2>
<p>Completed: $($stats.CompletedItems)/$($stats.TotalItems) ($([Math]::Round($stats.PercentComplete, 1))%)</p>
<p>Duration: $($stats.TotalDuration.ToString())</p>
<p>Errors: $($stats.ErrorCount), Warnings: $($stats.WarningCount)</p>
<h2>Item History</h2>
<table border="1">
<tr><th>Item</th><th>Duration</th><th>Result</th><th>Timestamp</th></tr>
"@
            foreach ($item in $ProgressManager.ItemHistory) {
                $html += "<tr><td>$($item.Item)</td><td>$($item.Duration.ToString())</td><td>$($item.Result)</td><td>$($item.Timestamp)</td></tr>"
            }
            $html += "</table></body></html>"
            $html | Set-Content -Path $OutputPath -Encoding UTF8
        }
    }
    
    Write-Verbose "Progress report exported to: $OutputPath"
}

# Export functions
Export-ModuleMember -Function Initialize-ProgressManager, Update-Progress, Complete-Progress, Pause-Progress, Resume-Progress, Cancel-Progress, Get-ProgressStatistics, Export-ProgressReport
