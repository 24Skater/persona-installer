<#
CatalogManager.psm1 - Catalog operations module
Handles loading, saving, and managing the application catalog
#>

function Load-Catalog {
    <#
    .SYNOPSIS
        Load the application catalog from JSON file
    .DESCRIPTION
        Reads and parses the catalog.json file containing app name to winget ID mappings
    .PARAMETER CatalogPath
        Path to the catalog.json file
    .OUTPUTS
        Hashtable of catalog entries
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CatalogPath
    )
    
    Write-Verbose "Loading catalog from: $CatalogPath"
    
    if (-not (Test-Path $CatalogPath)) { 
        throw "Catalog not found at: $CatalogPath" 
    }
    
    try {
        $json = Get-Content $CatalogPath -Raw -ErrorAction Stop
        
        # Handle different PowerShell versions
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $catalog = ConvertFrom-Json -InputObject $json -AsHashtable -ErrorAction Stop
        } else {
            $obj = $json | ConvertFrom-Json -ErrorAction Stop
            $catalog = @{}
            foreach ($property in $obj.PSObject.Properties) { 
                $catalog[$property.Name] = $property.Value 
            }
        }
        
        Write-Verbose "Successfully loaded $($catalog.Count) catalog entries"
        return $catalog
    }
    catch {
        throw "Failed to parse catalog: $($_.Exception.Message)"
    }
}

function Save-Catalog {
    <#
    .SYNOPSIS
        Save the catalog to JSON file
    .DESCRIPTION
        Converts catalog hashtable to JSON and saves to disk
    .PARAMETER Catalog
        The catalog hashtable to save
    .PARAMETER CatalogPath
        Path where to save the catalog.json file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog,
        
        [Parameter(Mandatory = $true)]
        [string]$CatalogPath
    )
    
    try {
        Write-Verbose "Saving catalog to: $CatalogPath"
        $json = $Catalog | ConvertTo-Json -Depth 5 -ErrorAction Stop
        $json | Set-Content -Path $CatalogPath -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Successfully saved catalog with $($Catalog.Count) entries"
    }
    catch {
        throw "Failed to save catalog: $($_.Exception.Message)"
    }
}

function Add-CatalogEntry {
    <#
    .SYNOPSIS
        Add a new application to the catalog
    .DESCRIPTION
        Validates and adds a new app entry to the catalog
    .PARAMETER Catalog
        The catalog hashtable to modify
    .PARAMETER DisplayName
        Human-friendly display name for the app
    .PARAMETER WingetId
        Exact winget package ID
    .OUTPUTS
        Updated catalog hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$WingetId
    )
    
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        throw "Display name cannot be empty"
    }
    
    if ([string]::IsNullOrWhiteSpace($WingetId)) {
        throw "Winget ID cannot be empty"
    }
    
    if ($DisplayName.Length -gt 100) {
        throw "Display name too long (maximum 100 characters)"
    }
    
    # Check for duplicates
    if ($Catalog.ContainsKey($DisplayName)) {
        $overwrite = Read-Host "App '$DisplayName' already exists. Overwrite? (Y/N)"
        if ($overwrite -notmatch '^(y|yes)$') {
            Write-Host "Cancelled." -ForegroundColor Yellow
            return $Catalog
        }
    }
    
    # Validate winget ID format (basic validation)
    if ($WingetId -notmatch '^[a-zA-Z0-9\.\-_]+$') {
        Write-Warning "Winget ID '$WingetId' may not be valid. Ensure it follows winget naming conventions."
    }
    
    Write-Verbose "Adding catalog entry: '$DisplayName' -> '$WingetId'"
    $Catalog[$DisplayName] = $WingetId
    
    Write-Host "Added: $DisplayName -> $WingetId" -ForegroundColor Green
    return $Catalog
}

function Remove-CatalogEntry {
    <#
    .SYNOPSIS
        Remove an application from the catalog
    .DESCRIPTION
        Removes an app entry from the catalog with confirmation
    .PARAMETER Catalog
        The catalog hashtable to modify
    .PARAMETER DisplayName
        Display name of the app to remove
    .OUTPUTS
        Updated catalog hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )
    
    if (-not $Catalog.ContainsKey($DisplayName)) {
        Write-Warning "App '$DisplayName' not found in catalog"
        return $Catalog
    }
    
    $confirm = Read-Host "Remove '$DisplayName' from catalog? (Y/N)"
    if ($confirm -match '^(y|yes)$') {
        $Catalog.Remove($DisplayName)
        Write-Host "Removed: $DisplayName" -ForegroundColor Yellow
    } else {
        Write-Host "Cancelled." -ForegroundColor Gray
    }
    
    return $Catalog
}

function Show-Catalog {
    <#
    .SYNOPSIS
        Display the catalog in a user-friendly format
    .DESCRIPTION
        Shows catalog entries in a table format with optional export to CSV
    .PARAMETER Catalog
        The catalog hashtable to display
    .PARAMETER DataDir
        Directory for exporting CSV files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog,
        
        [Parameter(Mandatory = $false)]
        [string]$DataDir
    )
    
    Write-Host "`nCatalog entries ($($Catalog.Count) total):" -ForegroundColor Cyan
    
    # Convert to objects for better display
    $items = @()
    foreach ($key in ($Catalog.Keys | Sort-Object)) {
        $items += [PSCustomObject]@{ 
            Name = $key
            WingetId = $Catalog[$key] 
        }
    }
    
    # Try to use Out-GridView if available
    $hasGridView = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($hasGridView -and $items.Count -gt 0) {
        try { 
            $items | Out-GridView -Title "Catalog (Name ↔ WingetId)" -Wait
        } 
        catch { 
            $hasGridView = $false 
        }
    }
    
    # Fallback to console table
    if (-not $hasGridView -and $items.Count -gt 0) {
        $maxNameWidth = ($items | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
        $maxNameWidth = [Math]::Max($maxNameWidth, 4)  # Minimum width for "Name" header
        
        # Header
        $header = "{0}  {1}" -f ("Name".PadRight($maxNameWidth)), "WingetId"
        Write-Host $header
        Write-Host ("-" * ($header.Length + 10))
        
        # Entries
        foreach ($item in $items) {
            $line = "{0}  {1}" -f ($item.Name.PadRight($maxNameWidth)), $item.WingetId
            Write-Host $line
        }
    }
    
    if ($items.Count -eq 0) {
        Write-Host "  (no entries)" -ForegroundColor Gray
        return
    }
    
    # Offer CSV export
    if ($DataDir) {
        Write-Host ""
        $export = Read-Host "Export catalog to CSV? (Y/N)"
        if ($export -match '^(y|yes)$') {
            try {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $exportPath = Join-Path $DataDir "catalog-export-$timestamp.csv"
                $items | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
                $fullPath = [System.IO.Path]::GetFullPath($exportPath)
                Write-Host "Exported to: $fullPath" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to export catalog: $($_.Exception.Message)"
            }
        }
    }
}

function Test-WingetId {
    <#
    .SYNOPSIS
        Test if a winget ID exists and is valid
    .DESCRIPTION
        Attempts to search for the winget ID to validate it exists
    .PARAMETER WingetId
        The winget ID to test
    .OUTPUTS
        Boolean indicating if the ID is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetId
    )
    
    try {
        Write-Verbose "Testing winget ID: $WingetId"
        $result = & winget search --id $WingetId -e --disable-interactivity 2>$null
        $isValid = ($LASTEXITCODE -eq 0) -and ($result -match [Regex]::Escape($WingetId))
        
        if ($isValid) {
            Write-Verbose "Winget ID '$WingetId' is valid"
        } else {
            Write-Verbose "Winget ID '$WingetId' not found"
        }
        
        return $isValid
    }
    catch {
        Write-Verbose "Error testing winget ID '$WingetId': $($_.Exception.Message)"
        return $false
    }
}

function Find-WingetApps {
    <#
    .SYNOPSIS
        Search for apps in winget repository
    .DESCRIPTION
        Search winget for applications matching a query
    .PARAMETER Query
        Search term to look for
    .PARAMETER MaxResults
        Maximum number of results to return
    .OUTPUTS
        Array of search results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 10
    )
    
    try {
        Write-Verbose "Searching winget for: $Query"
        $output = & winget search $Query --disable-interactivity 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Winget search failed for query: $Query"
            return @()
        }
        
        # Parse winget output (simplified - winget output format can vary)
        $results = @()
        $lines = $output -split "`n" | Where-Object { $_ -and $_ -notmatch "^-+$" -and $_ -notmatch "Name.*Version.*Source" }
        
        foreach ($line in $lines | Select-Object -First $MaxResults) {
            if ($line -match "^(.+?)\s+(.+?)\s+(.+?)\s+(.+)$") {
                $results += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[2].Trim()
                    Version = $matches[3].Trim()
                    Source = $matches[4].Trim()
                }
            }
        }
        
        Write-Verbose "Found $($results.Count) results for query: $Query"
        return $results
    }
    catch {
        Write-Warning "Error searching winget: $($_.Exception.Message)"
        return @()
    }
}

function Get-CatalogStatistics {
    <#
    .SYNOPSIS
        Get statistics about the catalog
    .DESCRIPTION
        Returns useful statistics about catalog contents
    .PARAMETER Catalog
        The catalog hashtable to analyze
    .OUTPUTS
        Hashtable with statistics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog
    )
    
    $stats = @{
        TotalEntries = $Catalog.Count
        UniquePublishers = @()
        Categories = @{
            Microsoft = 0
            Google = 0
            Adobe = 0
            Developer = 0
            Other = 0
        }
    }
    
    foreach ($entry in $Catalog.GetEnumerator()) {
        $wingetId = $entry.Value
        $publisher = ($wingetId -split '\.')[0]
        
        if ($publisher -notin $stats.UniquePublishers) {
            $stats.UniquePublishers += $publisher
        }
        
        switch -Regex ($publisher) {
            '^Microsoft' { $stats.Categories.Microsoft++ }
            '^Google' { $stats.Categories.Google++ }
            '^Adobe' { $stats.Categories.Adobe++ }
            '^(Git|GitHub|Node|Python|Docker)' { $stats.Categories.Developer++ }
            default { $stats.Categories.Other++ }
        }
    }
    
    return $stats
}

# Export functions
Export-ModuleMember -Function Load-Catalog, Save-Catalog, Add-CatalogEntry, Remove-CatalogEntry, Show-Catalog, Test-WingetId, Find-WingetApps, Get-CatalogStatistics
