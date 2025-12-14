<#
UIHelper.psm1 - User interface utilities module
Handles user interaction, menus, and app selection
#>

function Select-Apps {
    <#
    .SYNOPSIS
        Present user with app selection interface
    .DESCRIPTION
        Uses Out-GridView if available, falls back to console-based selection
    .PARAMETER Apps
        Array of available apps to choose from
    .PARAMETER Title
        Title for the selection dialog
    .PARAMETER CurrentSelection
        Currently selected apps (for editing scenarios)
    .OUTPUTS
        Array of selected app names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Apps,
        
        [Parameter(Mandatory = $false)]
        [string]$Title = "Select apps",
        
        [Parameter(Mandatory = $false)]
        [array]$CurrentSelection = @()
    )
    
    $selectedApps = @()
    
    if ($Apps.Count -eq 0) {
        Write-Host "No apps available for selection." -ForegroundColor Yellow
        return $selectedApps
    }
    
    Write-Verbose "Presenting app selection: $Title"
    Write-Verbose "Available apps: $($Apps.Count)"
    Write-Verbose "Current selection: $($CurrentSelection.Count)"
    
    # Try Out-GridView first (if available)
    $hasGridView = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($hasGridView) {
        try {
            # Pre-select current selection if editing
            if ($CurrentSelection.Count -gt 0) {
                $appsWithSelection = $Apps | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_
                        Selected = ($_ -in $CurrentSelection)
                    }
                }
                $selected = $appsWithSelection | Out-GridView -PassThru -Title $Title
                $selectedApps = $selected | ForEach-Object { $_.Name }
            } else {
                $selectedApps = $Apps | Out-GridView -PassThru -Title $Title
            }
            
            Write-Verbose "GridView selection: $($selectedApps.Count) apps"
            return $selectedApps
        }
        catch {
            Write-Verbose "GridView failed, falling back to console selection"
            $hasGridView = $false
        }
    }
    
    # Fallback to console-based selection
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host "Available apps:" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $marker = if ($Apps[$i] -in $CurrentSelection) { "[*]" } else { "[ ]" }
        $color = if ($Apps[$i] -in $CurrentSelection) { "Green" } else { "White" }
        Write-Host ("{0} {1}: {2}" -f $marker, ($i + 1), $Apps[$i]) -ForegroundColor $color
    }
    
    Write-Host "`nInstructions:" -ForegroundColor Gray
    Write-Host "- Enter numbers separated by commas (e.g., 1,3,5)" -ForegroundColor Gray
    Write-Host "- Enter 'all' to select all apps" -ForegroundColor Gray
    Write-Host "- Enter 'none' or leave empty to select none" -ForegroundColor Gray
    
    $userSelection = Read-Host "Your selection"
    
    if ([string]::IsNullOrWhiteSpace($userSelection) -or $userSelection -eq "none") {
        Write-Verbose "User selected no apps"
        return @()
    }
    
    if ($userSelection -eq "all") {
        Write-Verbose "User selected all apps"
        return $Apps
    }
    
    # Parse comma-separated numbers
    $indices = $userSelection -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    
    foreach ($index in $indices) {
        if ($index -ge 1 -and $index -le $Apps.Count) {
            $selectedApps += $Apps[$index - 1]
        } else {
            Write-Warning "Invalid selection: $index (valid range: 1-$($Apps.Count))"
        }
    }
    
    Write-Verbose "Console selection: $($selectedApps.Count) apps"
    return $selectedApps
}

function Show-Menu {
    <#
    .SYNOPSIS
        Display the main application menu
    .DESCRIPTION
        Shows formatted menu options and handles user selection
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of menu options
    .OUTPUTS
        Selected menu option
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [array]$Options
    )
    
    Write-Host "`n=== $Title ===" -ForegroundColor Green
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host " $($i + 1)) $($Options[$i])"
    }
    
    Write-Host ""
    $choice = Read-Host "Choose an option (1-$($Options.Count))"
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Options.Count) {
        return [int]$choice
    }
    
    return 0  # Invalid selection
}

function Show-PersonaList {
    <#
    .SYNOPSIS
        Display available personas for selection
    .DESCRIPTION
        Shows formatted list of personas with descriptions
    .PARAMETER Personas
        Array of persona objects
    .OUTPUTS
        Selected persona index (1-based) or 0 for invalid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Personas
    )
    
    if ($Personas.Count -eq 0) {
        Write-Host "No personas found." -ForegroundColor Yellow
        return 0
    }
    
    Write-Host "`nAvailable personas:" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Personas.Count; $i++) {
        $persona = $Personas[$i]
        Write-Host " [$($i + 1)] $($persona.name)" -ForegroundColor White
        
        if ($persona.base.Count -gt 0) {
            $baseApps = $persona.base -join ", "
            if ($baseApps.Length -gt 60) { 
                $baseApps = $baseApps.Substring(0, 57) + "..." 
            }
            Write-Host "      Base: $baseApps" -ForegroundColor Gray
        }
        
        if ($persona.optional.Count -gt 0) {
            Write-Host "      Optional: $($persona.optional.Count) apps available" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    $selection = Read-Host "Select persona (1-$($Personas.Count))"
    
    if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $Personas.Count) {
        return [int]$selection
    }
    
    return 0
}

function Show-InstallationSummary {
    <#
    .SYNOPSIS
        Display installation summary and get user confirmation
    .DESCRIPTION
        Shows what will be installed and asks for confirmation
    .PARAMETER PersonaName
        Name of the selected persona
    .PARAMETER BaseApps
        Array of base apps to install
    .PARAMETER OptionalApps
        Array of selected optional apps
    .PARAMETER DryRun
        Whether this is a dry run
    .OUTPUTS
        Boolean indicating whether user confirmed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PersonaName,
        
        [Parameter(Mandatory = $true)]
        [array]$BaseApps,
        
        [Parameter(Mandatory = $false)]
        [array]$OptionalApps = @(),
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $totalApps = $BaseApps.Count + $OptionalApps.Count
    $action = if ($DryRun) { "PREVIEW" } else { "INSTALL" }
    
    Write-Host "`n=== Installation Summary ===" -ForegroundColor Cyan
    Write-Host "Persona: $PersonaName" -ForegroundColor White
    Write-Host "Total apps: $totalApps" -ForegroundColor White
    
    if ($BaseApps.Count -gt 0) {
        Write-Host "`nBase apps ($($BaseApps.Count)):" -ForegroundColor Yellow
        $BaseApps | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
    }
    
    if ($OptionalApps.Count -gt 0) {
        Write-Host "`nOptional apps ($($OptionalApps.Count)):" -ForegroundColor Yellow
        $OptionalApps | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
    }
    
    if ($totalApps -eq 0) {
        Write-Host "`nNo apps selected for installation." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host ""
    if ($DryRun) {
        Write-Host "This is a DRY RUN - no apps will actually be installed." -ForegroundColor Yellow
        $response = Read-Host "Continue with preview? (Y/N)"
    } else {
        Write-Host "Ready to install $totalApps apps." -ForegroundColor Green
        $response = Read-Host "Continue with installation? (Y/N)"
    }
    
    return $response -match '^(y|yes)$'
}

function Show-Progress {
    <#
    .SYNOPSIS
        Display installation progress
    .DESCRIPTION
        Shows progress bar and current app being installed
    .PARAMETER Current
        Current app index
    .PARAMETER Total
        Total number of apps
    .PARAMETER AppName
        Name of current app being installed
    .PARAMETER Action
        Action being performed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Current,
        
        [Parameter(Mandatory = $true)]
        [int]$Total,
        
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $false)]
        [string]$Action = "Installing"
    )
    
    if ($Total -eq 0) { return }
    
    $percent = [int](($Current / $Total) * 100)
    $progressChars = [int]($percent / 5)  # 20 character progress bar
    $progressBar = "#" * $progressChars + "-" * (20 - $progressChars)
    
    $status = "[$Current/$Total] $Action $AppName"
    
    # Use Write-Progress for Windows PowerShell compatibility
    Write-Progress -Activity "Installing Apps" -Status $status -PercentComplete $percent
    
    # Also show console progress for better visibility
    Write-Host "[$progressBar] $percent% - $status" -ForegroundColor Cyan
}

function Wait-ForUser {
    <#
    .SYNOPSIS
        Pause execution and wait for user input
    .DESCRIPTION
        Shows a message and waits for user to press Enter
    .PARAMETER Message
        Message to display
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "Press Enter to continue..."
    )
    
    try {
        Write-Host ""
        Read-Host $Message | Out-Null
    }
    catch {
        # Handle cases where input might not be available
        Start-Sleep -Seconds 2
    }
}

function Show-WelcomeMessage {
    <#
    .SYNOPSIS
        Display welcome message and system information
    .DESCRIPTION
        Shows application banner and basic system info
    .PARAMETER Version
        Application version
    .PARAMETER DryRun
        Whether running in dry run mode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Version = "1.1.0",
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "                 Persona Installer v$Version                    " -ForegroundColor Green
    Write-Host "           Modular Windows App Installation Tool                " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "`n[DRY RUN] MODE - No apps will be installed" -ForegroundColor Yellow
    }
    
    # Show system info (uses CompatibilityHelper for cross-version WMI/CIM support)
    try {
        $psVersion = $PSVersionTable.PSVersion.ToString()
        $osInfo = Get-OperatingSystemInfo
        
        Write-Host "`nSystem Information:" -ForegroundColor Gray
        Write-Host "  PowerShell: $psVersion" -ForegroundColor Gray
        if ($osInfo -and $osInfo.Caption) {
            Write-Host "  OS: $($osInfo.Caption)" -ForegroundColor Gray
        }
    }
    catch {
        # Ignore errors in system info gathering
    }
}

function Confirm-Action {
    <#
    .SYNOPSIS
        Get user confirmation for an action
    .DESCRIPTION
        Displays a confirmation prompt with custom message
    .PARAMETER Message
        Confirmation message
    .PARAMETER Default
        Default response (Y or N)
    .OUTPUTS
        Boolean indicating user confirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Y', 'N')]
        [string]$Default = 'N'
    )
    
    $prompt = if ($Default -eq 'Y') { "$Message (Y/n)" } else { "$Message (y/N)" }
    $response = Read-Host $prompt
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default -eq 'Y'
    }
    
    return $response -match '^(y|yes)$'
}

function Show-Error {
    <#
    .SYNOPSIS
        Display formatted error message
    .DESCRIPTION
        Shows error with consistent formatting
    .PARAMETER Message
        Error message
    .PARAMETER Exception
        Optional exception object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception = $null
    )
    
    Write-Host "`n[ERROR] $Message" -ForegroundColor Red
    
    if ($Exception) {
        Write-Host "Details: $($Exception.Message)" -ForegroundColor Red
    }
}

function Show-Success {
    <#
    .SYNOPSIS
        Display formatted success message
    .DESCRIPTION
        Shows success message with consistent formatting
    .PARAMETER Message
        Success message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "`n[OK] $Message" -ForegroundColor Green
}

function Show-Warning {
    <#
    .SYNOPSIS
        Display formatted warning message
    .DESCRIPTION
        Shows warning with consistent formatting
    .PARAMETER Message
        Warning message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    Write-Host "`n[WARNING] $Message" -ForegroundColor Yellow
}

# Export functions
Export-ModuleMember -Function Select-Apps, Show-Menu, Show-PersonaList, Show-InstallationSummary, Show-Progress, Wait-ForUser, Show-WelcomeMessage, Confirm-Action, Show-Error, Show-Success, Show-Warning
