<#
PersonaManager.psm1 - Persona operations module
Handles loading, saving, creating, and editing personas
#>

function Import-Personas {
    <#
    .SYNOPSIS
        Import all persona files from the personas directory
    .DESCRIPTION
        Scans the personas directory for JSON files and imports them into memory
    .PARAMETER PersonaDir
        Path to the personas directory
    .OUTPUTS
        Array of persona objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PersonaDir
    )
    
    Write-Verbose "Importing personas from: $PersonaDir"
    
    if (-not (Test-Path $PersonaDir)) { 
        Write-Verbose "Creating personas directory: $PersonaDir"
        New-Item -ItemType Directory -Path $PersonaDir -Force | Out-Null 
    }
    
    $files = Get-ChildItem $PersonaDir -Filter *.json -File
    $personas = @()
    
    foreach ($file in $files) {
        try {
            Write-Verbose "Loading persona: $($file.Name)"
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            $persona = $content | ConvertFrom-Json -ErrorAction Stop
            
            if ($persona.name) {
                $personas += $persona
                Write-Verbose "Successfully loaded persona: $($persona.name)"
            } else {
                Write-Warning "Skipping persona file '$($file.Name)' - missing 'name' property"
            }
        }
        catch {
            Write-Warning "Failed to load persona '$($file.Name)': $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "Imported $($personas.Count) personas"
    return $personas
}

function Save-Persona {
    <#
    .SYNOPSIS
        Save a persona to disk
    .DESCRIPTION
        Validates and saves a persona object to a JSON file
    .PARAMETER Persona
        The persona object to save
    .PARAMETER PersonaDir
        Path to the personas directory
    .OUTPUTS
        Path to the saved file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Persona,
        
        [Parameter(Mandatory = $true)]
        [string]$PersonaDir
    )
    
    # Validate persona structure
    if (-not $Persona.name) { 
        throw "Persona requires 'name' property" 
    }
    
    if (-not (Test-PersonaName -Name $Persona.name)) {
        throw "Invalid persona name. Use only alphanumeric characters, dashes, and underscores (1-50 characters)"
    }
    
    if (-not $Persona.base) { 
        $Persona | Add-Member -NotePropertyName 'base' -NotePropertyValue @() -Force
    }
    
    if (-not $Persona.optional) { 
        $Persona | Add-Member -NotePropertyName 'optional' -NotePropertyValue @() -Force
    }
    
    # Ensure arrays are properly formatted
    $Persona.base = @($Persona.base)
    $Persona.optional = @($Persona.optional)
    
    $fileName = "{0}.json" -f $Persona.name
    $filePath = Join-Path $PersonaDir $fileName
    
    try {
        Write-Verbose "Saving persona '$($Persona.name)' to: $filePath"
        $json = $Persona | ConvertTo-Json -Depth 5 -ErrorAction Stop
        $json | Set-Content -Path $filePath -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Successfully saved persona: $($Persona.name)"
        return $filePath
    }
    catch {
        throw "Failed to save persona '$($Persona.name)': $($_.Exception.Message)"
    }
}

function New-Persona {
    <#
    .SYNOPSIS
        Create a new persona interactively
    .DESCRIPTION
        Guides user through creating a new persona with base and optional apps
    .PARAMETER Name
        Name for the new persona
    .PARAMETER CatalogApps
        Available apps from catalog
    .PARAMETER SourcePersona
        Optional source persona to clone from
    .OUTPUTS
        New persona object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [array]$CatalogApps,
        
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$SourcePersona = $null
    )
    
    Write-Verbose "Creating new persona: $Name"
    
    # Validate name
    if (-not (Test-PersonaName -Name $Name)) {
        throw "Invalid persona name"
    }
    
    # Initialize persona structure
    if ($SourcePersona) {
        Write-Host "Cloning from persona: $($SourcePersona.name)" -ForegroundColor Cyan
        $persona = [PSCustomObject]@{
            name = $Name
            base = @($SourcePersona.base)
            optional = @($SourcePersona.optional)
        }
    } else {
        $persona = [PSCustomObject]@{
            name = $Name
            base = @()
            optional = @()
        }
    }
    
    # Select base apps
    Write-Host "`nSelecting BASE apps for '$Name'" -ForegroundColor Yellow
    Write-Host "Base apps are installed automatically with this persona." -ForegroundColor Gray
    $selectedBase = Select-Apps -Apps $CatalogApps -Title "Select BASE apps for '$Name'" -CurrentSelection $persona.base
    $persona.base = @($selectedBase)
    
    # Select optional apps
    Write-Host "`nSelecting OPTIONAL apps for '$Name'" -ForegroundColor Yellow
    Write-Host "Optional apps can be chosen during installation." -ForegroundColor Gray
    $selectedOptional = Select-Apps -Apps $CatalogApps -Title "Select OPTIONAL apps for '$Name'" -CurrentSelection $persona.optional
    $persona.optional = @($selectedOptional)
    
    Write-Verbose "Created persona with $($persona.base.Count) base apps and $($persona.optional.Count) optional apps"
    return $persona
}

function Edit-Persona {
    <#
    .SYNOPSIS
        Edit an existing persona interactively
    .DESCRIPTION
        Allows user to modify base and optional apps for an existing persona
    .PARAMETER Persona
        The persona to edit
    .PARAMETER CatalogApps
        Available apps from catalog
    .OUTPUTS
        Updated persona object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Persona,
        
        [Parameter(Mandatory = $true)]
        [array]$CatalogApps
    )
    
    Write-Host "`nEditing persona: $($Persona.name)" -ForegroundColor Cyan
    Write-Verbose "Current base apps: $($Persona.base -join ', ')"
    Write-Verbose "Current optional apps: $($Persona.optional -join ', ')"
    
    # Edit base apps
    Write-Host "`nCurrent BASE apps:" -ForegroundColor Yellow
    if ($Persona.base.Count -gt 0) {
        $Persona.base | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
    
    $editBase = Read-Host "Edit base apps? (Y/N)"
    if ($editBase -match '^(y|yes)$') {
        $selectedBase = Select-Apps -Apps $CatalogApps -Title "Edit BASE apps for '$($Persona.name)'" -CurrentSelection $Persona.base
        $Persona.base = @($selectedBase)
    }
    
    # Edit optional apps
    Write-Host "`nCurrent OPTIONAL apps:" -ForegroundColor Yellow
    if ($Persona.optional.Count -gt 0) {
        $Persona.optional | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
    
    $editOptional = Read-Host "Edit optional apps? (Y/N)"
    if ($editOptional -match '^(y|yes)$') {
        $selectedOptional = Select-Apps -Apps $CatalogApps -Title "Edit OPTIONAL apps for '$($Persona.name)'" -CurrentSelection $Persona.optional
        $Persona.optional = @($selectedOptional)
    }
    
    Write-Verbose "Updated persona with $($Persona.base.Count) base apps and $($Persona.optional.Count) optional apps"
    return $Persona
}

function Test-PersonaName {
    <#
    .SYNOPSIS
        Test if persona name format is valid
    .DESCRIPTION
        Ensures persona name follows naming conventions
    .PARAMETER Name
        Name to validate
    .OUTPUTS
        Boolean indicating if name is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Verbose "Persona name cannot be empty"
        return $false
    }
    
    if ($Name.Length -gt 50) {
        Write-Verbose "Persona name too long (max 50 characters)"
        return $false
    }
    
    if ($Name -notmatch '^[a-zA-Z0-9\-_]+$') {
        Write-Verbose "Persona name contains invalid characters"
        return $false
    }
    
    return $true
}

function Get-PersonaSummary {
    <#
    .SYNOPSIS
        Get a summary of persona contents
    .DESCRIPTION
        Returns formatted summary of persona's base and optional apps
    .PARAMETER Persona
        The persona to summarize
    .OUTPUTS
        Formatted string summary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Persona
    )
    
    $summary = @()
    $summary += "Persona: $($Persona.name)"
    $summary += "Base apps ($($Persona.base.Count)):"
    
    if ($Persona.base.Count -gt 0) {
        $Persona.base | ForEach-Object { $summary += "  - $_" }
    } else {
        $summary += "  (none)"
    }
    
    $summary += "Optional apps ($($Persona.optional.Count)):"
    if ($Persona.optional.Count -gt 0) {
        $Persona.optional | ForEach-Object { $summary += "  - $_" }
    } else {
        $summary += "  (none)"
    }
    
    return $summary -join "`n"
}

# Export functions
Export-ModuleMember -Function Import-Personas, Save-Persona, New-Persona, Edit-Persona, Test-PersonaName, Get-PersonaSummary
