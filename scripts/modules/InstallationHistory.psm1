<#
InstallationHistory.psm1 - Installation history tracking module
Tracks and manages installation history for Persona Installer v1.5.0
#>

# Schema version for history file format
$script:HistorySchemaVersion = "1.0"

function Initialize-InstallationHistory {
    <#
    .SYNOPSIS
        Initialize or load the installation history file
    .DESCRIPTION
        Creates the history directory and file if they don't exist,
        or loads existing history from disk
    .PARAMETER HistoryPath
        Path to the history JSON file
    .OUTPUTS
        History object with installations array
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath
    )
    
    try {
        $historyDir = Split-Path -Parent $HistoryPath
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $historyDir)) {
            New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
            Write-Verbose "Created history directory: $historyDir"
        }
        
        # Load existing or create new history
        if (Test-Path $HistoryPath) {
            $content = Get-Content $HistoryPath -Raw -ErrorAction Stop
            $history = $content | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose "Loaded existing history with $($history.installations.Count) records"
        } else {
            $history = [PSCustomObject]@{
                version = $script:HistorySchemaVersion
                installations = @()
            }
            
            # Save initial empty history
            $history | ConvertTo-Json -Depth 10 | Set-Content -Path $HistoryPath -Encoding UTF8
            Write-Verbose "Created new history file: $HistoryPath"
        }
        
        return $history
    }
    catch {
        Write-Warning "Failed to initialize installation history: $($_.Exception.Message)"
        
        # Return empty history object on failure
        return [PSCustomObject]@{
            version = $script:HistorySchemaVersion
            installations = @()
        }
    }
}

function Add-InstallationRecord {
    <#
    .SYNOPSIS
        Add a new installation record to history
    .DESCRIPTION
        Records details of a persona installation including apps, status, and timing
    .PARAMETER HistoryPath
        Path to the history JSON file
    .PARAMETER PersonaName
        Name of the installed persona
    .PARAMETER Apps
        Array of app result objects with name, wingetId, and status
    .PARAMETER TotalDuration
        Total installation duration as TimeSpan
    .PARAMETER Successful
        Count of successfully installed apps
    .PARAMETER Failed
        Count of failed installations
    .OUTPUTS
        The created installation record
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PersonaName,
        
        [Parameter(Mandatory = $true)]
        [array]$Apps,
        
        [Parameter(Mandatory = $false)]
        [TimeSpan]$TotalDuration = [TimeSpan]::Zero,
        
        [Parameter(Mandatory = $false)]
        [int]$Successful = 0,
        
        [Parameter(Mandatory = $false)]
        [int]$Failed = 0
    )
    
    try {
        # Load current history
        $history = Initialize-InstallationHistory -HistoryPath $HistoryPath
        
        # Create new record
        $record = [PSCustomObject]@{
            id = [Guid]::NewGuid().ToString()
            timestamp = (Get-Date).ToString('o')  # ISO 8601 format
            personaName = $PersonaName
            apps = @($Apps | ForEach-Object {
                [PSCustomObject]@{
                    name = $_.DisplayName
                    wingetId = $_.WingetId
                    status = $_.Status
                }
            })
            totalDuration = $TotalDuration.ToString()
            successful = $Successful
            failed = $Failed
        }
        
        # Add to history (prepend so newest is first)
        $history.installations = @($record) + @($history.installations)
        
        # Save updated history
        $history | ConvertTo-Json -Depth 10 | Set-Content -Path $HistoryPath -Encoding UTF8
        
        Write-Verbose "Added installation record: $($record.id) for persona '$PersonaName'"
        
        return $record
    }
    catch {
        Write-Warning "Failed to add installation record: $($_.Exception.Message)"
        return $null
    }
}

function Get-InstallationHistory {
    <#
    .SYNOPSIS
        Query installation history with optional filters
    .DESCRIPTION
        Retrieves installation records, optionally filtered by persona name or date range
    .PARAMETER HistoryPath
        Path to the history JSON file
    .PARAMETER PersonaName
        Filter by persona name (optional)
    .PARAMETER Days
        Filter to last N days (optional)
    .PARAMETER Limit
        Maximum number of records to return (optional)
    .OUTPUTS
        Array of installation records
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath,
        
        [Parameter(Mandatory = $false)]
        [string]$PersonaName = "",
        
        [Parameter(Mandatory = $false)]
        [int]$Days = 0,
        
        [Parameter(Mandatory = $false)]
        [int]$Limit = 0
    )
    
    try {
        $history = Initialize-InstallationHistory -HistoryPath $HistoryPath
        $results = @($history.installations)
        
        # Filter by persona name
        if ($PersonaName) {
            $results = @($results | Where-Object { $_.personaName -eq $PersonaName })
        }
        
        # Filter by date range
        if ($Days -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$Days)
            $results = @($results | Where-Object { 
                [DateTime]::Parse($_.timestamp) -ge $cutoffDate 
            })
        }
        
        # Apply limit
        if ($Limit -gt 0 -and $results.Count -gt $Limit) {
            $results = @($results | Select-Object -First $Limit)
        }
        
        Write-Verbose "Retrieved $($results.Count) history records"
        return $results
    }
    catch {
        Write-Warning "Failed to get installation history: $($_.Exception.Message)"
        return @()
    }
}

function Export-InstallationHistory {
    <#
    .SYNOPSIS
        Export installation history to CSV or JSON file
    .DESCRIPTION
        Exports history records to an external file for reporting or backup
    .PARAMETER HistoryPath
        Path to the history JSON file
    .PARAMETER OutputPath
        Path for the export file
    .PARAMETER Format
        Export format: CSV or JSON
    .PARAMETER Days
        Filter to last N days (optional)
    .OUTPUTS
        Path to exported file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('CSV', 'JSON')]
        [string]$Format = 'CSV',
        
        [Parameter(Mandatory = $false)]
        [int]$Days = 0
    )
    
    try {
        $records = Get-InstallationHistory -HistoryPath $HistoryPath -Days $Days
        
        if ($records.Count -eq 0) {
            Write-Warning "No records to export"
            return $null
        }
        
        switch ($Format) {
            'CSV' {
                # Flatten records for CSV export
                $flatRecords = @($records | ForEach-Object {
                    [PSCustomObject]@{
                        Id = $_.id
                        Timestamp = $_.timestamp
                        PersonaName = $_.personaName
                        AppCount = $_.apps.Count
                        Successful = $_.successful
                        Failed = $_.failed
                        Duration = $_.totalDuration
                    }
                })
                
                $flatRecords | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            }
            'JSON' {
                $records | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
            }
        }
        
        Write-Verbose "Exported $($records.Count) records to: $OutputPath"
        return $OutputPath
    }
    catch {
        Write-Warning "Failed to export installation history: $($_.Exception.Message)"
        return $null
    }
}

function Clear-InstallationHistory {
    <#
    .SYNOPSIS
        Clear old installation history records
    .DESCRIPTION
        Removes records older than specified days or clears all history
    .PARAMETER HistoryPath
        Path to the history JSON file
    .PARAMETER DaysToKeep
        Keep records from last N days (0 = clear all)
    .PARAMETER Force
        Skip confirmation prompt
    .OUTPUTS
        Number of records removed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HistoryPath,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToKeep = 0,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $history = Initialize-InstallationHistory -HistoryPath $HistoryPath
        $originalCount = $history.installations.Count
        
        if ($originalCount -eq 0) {
            Write-Verbose "History is already empty"
            return 0
        }
        
        if ($DaysToKeep -gt 0) {
            # Keep recent records
            $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
            $history.installations = @($history.installations | Where-Object {
                [DateTime]::Parse($_.timestamp) -ge $cutoffDate
            })
        } else {
            # Clear all
            if (-not $Force) {
                Write-Warning "This will clear all $originalCount installation records."
                $confirm = Read-Host "Are you sure? (Y/N)"
                if ($confirm -notmatch '^(y|yes)$') {
                    Write-Verbose "Clear operation cancelled"
                    return 0
                }
            }
            $history.installations = @()
        }
        
        # Save updated history
        $history | ConvertTo-Json -Depth 10 | Set-Content -Path $HistoryPath -Encoding UTF8
        
        $removedCount = $originalCount - $history.installations.Count
        Write-Verbose "Removed $removedCount records from history"
        
        return $removedCount
    }
    catch {
        Write-Warning "Failed to clear installation history: $($_.Exception.Message)"
        return 0
    }
}

# Export functions
Export-ModuleMember -Function Initialize-InstallationHistory, Add-InstallationRecord, Get-InstallationHistory, Export-InstallationHistory, Clear-InstallationHistory

