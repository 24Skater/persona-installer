<#
DependencyManager.psm1 - Dependency resolution and management module
Handles app dependencies, conflicts, and prerequisites
#>

function Get-AppDependencies {
    <#
    .SYNOPSIS
        Get dependencies for a specific app
    .DESCRIPTION
        Retrieves dependency information from enhanced catalog structure
    .PARAMETER AppName
        Name of the app to get dependencies for
    .PARAMETER Catalog
        Enhanced catalog with dependency information
    .OUTPUTS
        Dependency information object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [object]$Catalog
    )
    
    Write-Verbose "Getting dependencies for: $AppName"
    
    if (-not $Catalog.ContainsKey($AppName)) {
        Write-Warning "App '$AppName' not found in catalog"
        return $null
    }
    
    $appInfo = $Catalog[$AppName]
    
    # Handle both old (string) and new (object) catalog formats
    if ($appInfo -is [string]) {
        # Legacy format - no dependencies
        return [PSCustomObject]@{
            AppName = $AppName
            WingetId = $appInfo
            Dependencies = @()
            Conflicts = @()
            Prerequisites = @()
            SystemRequirements = @{}
        }
    }
    
    # New enhanced format
    return [PSCustomObject]@{
        AppName = $AppName
        WingetId = $appInfo.id
        Dependencies = if ($appInfo.dependencies) { @($appInfo.dependencies) } else { @() }
        Conflicts = if ($appInfo.conflicts) { @($appInfo.conflicts) } else { @() }
        Prerequisites = if ($appInfo.prerequisites) { @($appInfo.prerequisites) } else { @() }
        SystemRequirements = if ($appInfo.system_requirements) { $appInfo.system_requirements } else { @{} }
        Optional = if ($appInfo.optional -ne $null) { $appInfo.optional } else { $false }
        Category = if ($appInfo.category) { $appInfo.category } else { 'General' }
        Description = if ($appInfo.description) { $appInfo.description } else { '' }
    }
}

function Resolve-AppDependencies {
    <#
    .SYNOPSIS
        Resolve complete dependency tree for a list of apps
    .DESCRIPTION
        Analyzes dependencies and creates installation order with conflict detection
    .PARAMETER AppList
        List of apps to resolve dependencies for
    .PARAMETER Catalog
        Enhanced catalog with dependency information
    .OUTPUTS
        Resolved dependency information with installation order
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$AppList,
        
        [Parameter(Mandatory = $true)]
        [object]$Catalog
    )
    
    Write-Verbose "Resolving dependencies for $($AppList.Count) apps"
    
    # Use a state hashtable to allow nested function to modify parent scope
    $state = @{
        ResolvedApps = [System.Collections.ArrayList]::new()
        Conflicts = [System.Collections.ArrayList]::new()
        MissingDeps = [System.Collections.ArrayList]::new()
        CircularDeps = [System.Collections.ArrayList]::new()
        ProcessedApps = @{}
        CurrentPath = [System.Collections.ArrayList]::new()
    }
    
    function Resolve-Single {
        param(
            [string]$AppName, 
            [int]$Depth = 0,
            [hashtable]$State,
            [object]$Cat
        )
        
        if ($Depth -gt 10) {
            [void]$State.CircularDeps.Add("Circular dependency detected: $($State.CurrentPath -join ' -> ') -> $AppName")
            return
        }
        
        if ($State.ProcessedApps.ContainsKey($AppName)) {
            return
        }
        
        [void]$State.CurrentPath.Add($AppName)
        
        try {
            $appDep = Get-AppDependencies -AppName $AppName -Catalog $Cat
            if (-not $appDep) {
                [void]$State.MissingDeps.Add($AppName)
                return
            }
            
            # Check for conflicts with already resolved apps
            foreach ($conflict in $appDep.Conflicts) {
                if ($State.ProcessedApps.ContainsKey($conflict)) {
                    [void]$State.Conflicts.Add("Conflict: $AppName conflicts with $conflict")
                }
            }
            
            # Resolve dependencies first (depth-first)
            foreach ($dep in $appDep.Dependencies) {
                if (-not $State.ProcessedApps.ContainsKey($dep)) {
                    Resolve-Single -AppName $dep -Depth ($Depth + 1) -State $State -Cat $Cat
                }
            }
            
            # Add this app to resolved list
            if (-not $State.ProcessedApps.ContainsKey($AppName)) {
                [void]$State.ResolvedApps.Add($appDep)
                $State.ProcessedApps[$AppName] = $true
                Write-Verbose "Resolved: $AppName (depth: $Depth)"
            }
        }
        finally {
            if ($State.CurrentPath.Count -gt 0) {
                $State.CurrentPath.RemoveAt($State.CurrentPath.Count - 1)
            }
        }
    }
    
    # Resolve each app in the original list
    foreach ($app in $AppList) {
        $state.CurrentPath.Clear()
        Resolve-Single -AppName $app -State $state -Cat $Catalog
    }
    
    # Convert ArrayLists back to arrays for output
    $resolvedApps = @($state.ResolvedApps)
    $conflicts = @($state.Conflicts)
    $missingDeps = @($state.MissingDeps)
    $circularDeps = @($state.CircularDeps)
    
    return [PSCustomObject]@{
        ResolvedApps = $resolvedApps
        InstallationOrder = $resolvedApps | ForEach-Object { $_.AppName }
        Conflicts = $conflicts
        MissingDependencies = $missingDeps
        CircularDependencies = $circularDeps
        TotalApps = $resolvedApps.Count
        HasIssues = ($conflicts.Count -gt 0) -or ($missingDeps.Count -gt 0) -or ($circularDeps.Count -gt 0)
    }
}

function Test-SystemRequirements {
    <#
    .SYNOPSIS
        Test if system meets requirements for an app
    .DESCRIPTION
        Checks system against app requirements like OS version, memory, etc.
    .PARAMETER AppDependencies
        App dependency object with system requirements
    .OUTPUTS
        System compatibility result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AppDependencies
    )
    
    $requirements = $AppDependencies.SystemRequirements
    $issues = @()
    $warnings = @()
    
    try {
        # Check Windows version
        if ($requirements.min_windows_version) {
            $currentVersion = [System.Environment]::OSVersion.Version
            $requiredVersion = [Version]$requirements.min_windows_version
            
            if ($currentVersion -lt $requiredVersion) {
                $issues += "Windows version $requiredVersion or higher required (current: $currentVersion)"
            }
        }
        
        # Check memory (uses CompatibilityHelper for cross-version WMI/CIM support)
        if ($requirements.min_memory_gb) {
            $computerInfo = Get-ComputerSystemInfo
            $totalMemoryGB = if ($computerInfo) { $computerInfo.TotalMemoryGB } else { 0 }
            
            if ($totalMemoryGB -lt $requirements.min_memory_gb) {
                $issues += "Minimum $($requirements.min_memory_gb)GB RAM required (current: ${totalMemoryGB}GB)"
            }
        }
        
        # Check disk space (uses CompatibilityHelper for cross-version WMI/CIM support)
        if ($requirements.min_disk_space_gb) {
            $systemDrive = $env:SystemDrive
            $diskInfo = Get-LogicalDiskInfo -DeviceID $systemDrive
            $freeSpaceGB = if ($diskInfo) { $diskInfo.FreeSpaceGB } else { 0 }
            
            if ($freeSpaceGB -lt $requirements.min_disk_space_gb) {
                $issues += "Minimum $($requirements.min_disk_space_gb)GB free space required (current: ${freeSpaceGB}GB)"
            }
        }
        
        # Check PowerShell version
        if ($requirements.min_powershell_version) {
            $currentPSVersion = $PSVersionTable.PSVersion
            $requiredPSVersion = [Version]$requirements.min_powershell_version
            
            if ($currentPSVersion -lt $requiredPSVersion) {
                $warnings += "PowerShell $requiredPSVersion recommended (current: $currentPSVersion)"
            }
        }
        
        # Check architecture
        if ($requirements.architecture) {
            $currentArch = $env:PROCESSOR_ARCHITECTURE
            if ($currentArch -ne $requirements.architecture) {
                $issues += "Architecture $($requirements.architecture) required (current: $currentArch)"
            }
        }
        
        # Check if running as admin (for certain apps)
        if ($requirements.requires_admin) {
            if (-not (Test-IsAdministrator)) {
                $warnings += "Administrator privileges recommended for optimal installation"
            }
        }
        
    } catch {
        $warnings += "Could not fully verify system requirements: $($_.Exception.Message)"
    }
    
    return [PSCustomObject]@{
        AppName = $AppDependencies.AppName
        Compatible = $issues.Count -eq 0
        Issues = $issues
        Warnings = $warnings
        Checked = Get-Date
    }
}

function Show-DependencyAnalysis {
    <#
    .SYNOPSIS
        Display dependency analysis results to user
    .DESCRIPTION
        Shows resolved dependencies, conflicts, and installation order
    .PARAMETER Analysis
        Dependency analysis result from Resolve-AppDependencies
    .PARAMETER OriginalList
        The original list of apps requested (before dependency resolution)
    .PARAMETER ShowDetails
        Whether to show detailed dependency tree
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Analysis,
        
        [Parameter(Mandatory = $false)]
        [array]$OriginalList = @(),
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )
    
    Write-Host "`n=== Dependency Analysis ===" -ForegroundColor Cyan
    
    # Summary
    $originalCount = if ($OriginalList.Count -gt 0) {
        ($Analysis.ResolvedApps | Where-Object { $_.AppName -in $OriginalList } | Measure-Object).Count
    } else {
        $Analysis.TotalApps
    }
    $additionalDeps = $Analysis.TotalApps - $originalCount
    
    Write-Host "Total apps to install: $($Analysis.TotalApps)" -ForegroundColor Green
    Write-Host "Original request: $originalCount" -ForegroundColor White
    Write-Host "Additional dependencies: $additionalDeps" -ForegroundColor Yellow
    
    # Issues
    if ($Analysis.HasIssues) {
        Write-Host "`n[WARNING] Issues Found:" -ForegroundColor Red
        
        if ($Analysis.Conflicts.Count -gt 0) {
            Write-Host "Conflicts:" -ForegroundColor Red
            $Analysis.Conflicts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
        
        if ($Analysis.MissingDependencies.Count -gt 0) {
            Write-Host "Missing Dependencies:" -ForegroundColor Red
            $Analysis.MissingDependencies | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
        
        if ($Analysis.CircularDependencies.Count -gt 0) {
            Write-Host "Circular Dependencies:" -ForegroundColor Red
            $Analysis.CircularDependencies | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
    } else {
        Write-Host "`n[OK] No conflicts detected" -ForegroundColor Green
    }
    
    # Installation order
    if ($ShowDetails -and $Analysis.ResolvedApps.Count -gt 0) {
        Write-Host "`nInstallation Order:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Analysis.ResolvedApps.Count; $i++) {
            $app = $Analysis.ResolvedApps[$i]
            $number = ($i + 1).ToString().PadLeft(2)
            $prefix = if ($app.Dependencies.Count -gt 0) { "|-" } else { "+-" }
            
            Write-Host "  $number. $prefix $($app.AppName)" -ForegroundColor White
            
            if ($app.Dependencies.Count -gt 0) {
                Write-Host "       Dependencies: $($app.Dependencies -join ', ')" -ForegroundColor Gray
            }
        }
    }
    
    return -not $Analysis.HasIssues
}

function Convert-LegacyCatalog {
    <#
    .SYNOPSIS
        Convert legacy catalog format to enhanced format
    .DESCRIPTION
        Upgrades simple string catalog to object-based format with dependency support
    .PARAMETER LegacyCatalog
        Old catalog format (string values)
    .OUTPUTS
        Enhanced catalog format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LegacyCatalog
    )
    
    Write-Verbose "Converting legacy catalog to enhanced format"
    
    $enhancedCatalog = @{}
    
    foreach ($entry in $LegacyCatalog.GetEnumerator()) {
        $enhancedCatalog[$entry.Key] = @{
            id = $entry.Value
            dependencies = @()
            conflicts = @()
            prerequisites = @()
            system_requirements = @{}
            category = 'General'
            description = ''
            optional = $false
        }
    }
    
    Write-Verbose "Converted $($enhancedCatalog.Count) catalog entries"
    return $enhancedCatalog
}

function Add-CommonDependencies {
    <#
    .SYNOPSIS
        Add common dependency relationships to catalog
    .DESCRIPTION
        Defines well-known dependencies between common applications
    .PARAMETER Catalog
        Enhanced catalog to update with dependencies
    .OUTPUTS
        Updated catalog with common dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Catalog
    )
    
    Write-Verbose "Adding common dependency relationships"
    
    # Common dependency relationships
    $commonDeps = @{
        'Docker Desktop' = @{
            dependencies = @('WSL2')
            system_requirements = @{
                min_windows_version = '10.0.19041'
                min_memory_gb = 4
                requires_admin = $true
            }
        }
        'Visual Studio 2022 Community' = @{
            system_requirements = @{
                min_disk_space_gb = 4
                min_memory_gb = 4
            }
        }
        'GitHub CLI' = @{
            dependencies = @('Git')
        }
        'GitHub Desktop' = @{
            dependencies = @('Git')
        }
        'Azure CLI' = @{
            dependencies = @('PowerShell 7')
        }
        'AWS CLI v2' = @{
            dependencies = @('PowerShell 7')
        }
        'Google Cloud SDK' = @{
            dependencies = @('Python 3 (latest)')
        }
    }
    
    foreach ($app in $commonDeps.Keys) {
        if ($Catalog.ContainsKey($app)) {
            $appInfo = $Catalog[$app]
            
            if ($commonDeps[$app].dependencies) {
                $appInfo.dependencies += $commonDeps[$app].dependencies
            }
            
            if ($commonDeps[$app].system_requirements) {
                foreach ($req in $commonDeps[$app].system_requirements.GetEnumerator()) {
                    $appInfo.system_requirements[$req.Key] = $req.Value
                }
            }
            
            Write-Verbose "Updated dependencies for: $app"
        }
    }
    
    return $Catalog
}

# Export functions
Export-ModuleMember -Function Get-AppDependencies, Resolve-AppDependencies, Test-SystemRequirements, Show-DependencyAnalysis, Convert-LegacyCatalog, Add-CommonDependencies
