<#
PersonaRecommendationEngine.psm1 - Smart persona recommendation system
Analyzes system and user context to suggest appropriate personas
#>

function Get-SystemAnalysis {
    <#
    .SYNOPSIS
        Analyze current system for installed software and capabilities
    .DESCRIPTION
        Detects existing software, hardware capabilities, and usage patterns
    .OUTPUTS
        System analysis object with recommendations
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Analyzing system for persona recommendations"
    
    $analysis = [PSCustomObject]@{
        Hardware = @{}
        Software = @{}
        Environment = @{}
        UserProfile = @{}
        Capabilities = @{}
        Timestamp = Get-Date
    }
    
    try {
        # Hardware Analysis
        $computerSystem = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($computerSystem) {
            $analysis.Hardware = @{
                TotalMemoryGB = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 1)
                NumberOfProcessors = $computerSystem.NumberOfProcessors
                Model = $computerSystem.Model
                Manufacturer = $computerSystem.Manufacturer
            }
        }
        
        # Operating System Info
        $osInfo = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osInfo) {
            $analysis.Environment.WindowsVersion = $osInfo.Caption
            $analysis.Environment.Architecture = $osInfo.OSArchitecture
            $analysis.Environment.ServicePack = $osInfo.ServicePackMajorVersion
        }
        
        # PowerShell Version
        $analysis.Environment.PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        $analysis.Environment.PowerShellEdition = $PSVersionTable.PSEdition
        
        # Detect Existing Software
        $analysis.Software = Find-ExistingSoftware
        
        # User Environment Analysis
        $analysis.UserProfile = Analyze-UserEnvironment
        
        # Determine System Capabilities
        $analysis.Capabilities = Determine-SystemCapabilities -Hardware $analysis.Hardware -Software $analysis.Software
        
        Write-Verbose "System analysis completed successfully"
        
    } catch {
        Write-Warning "Partial system analysis completed: $($_.Exception.Message)"
    }
    
    return $analysis
}

function Find-ExistingSoftware {
    <#
    .SYNOPSIS
        Detect existing software installations
    .DESCRIPTION
        Searches for common development tools, applications, and indicators
    .OUTPUTS
        Hashtable of detected software categories
    #>
    [CmdletBinding()]
    param()
    
    $software = @{
        Development = @()
        Business = @()
        Creative = @()
        Gaming = @()
        Security = @()
        Utilities = @()
        Unknown = @()
    }
    
    # Common software detection patterns
    $detectionPatterns = @{
        Development = @(
            @{ Name = 'Git'; Path = 'git.exe'; Category = 'VersionControl' }
            @{ Name = 'Visual Studio Code'; Path = 'Code.exe'; Category = 'Editor' }
            @{ Name = 'Visual Studio'; Path = 'devenv.exe'; Category = 'IDE' }
            @{ Name = 'Node.js'; Path = 'node.exe'; Category = 'Runtime' }
            @{ Name = 'Python'; Path = 'python.exe'; Category = 'Language' }
            @{ Name = 'Docker Desktop'; Path = 'Docker Desktop.exe'; Category = 'Container' }
            @{ Name = 'GitHub Desktop'; Path = 'GitHubDesktop.exe'; Category = 'VersionControl' }
        )
        Business = @(
            @{ Name = 'Microsoft Office'; Path = 'WINWORD.EXE'; Category = 'Productivity' }
            @{ Name = 'Microsoft Teams'; Path = 'Teams.exe'; Category = 'Communication' }
            @{ Name = 'Slack'; Path = 'slack.exe'; Category = 'Communication' }
            @{ Name = 'Zoom'; Path = 'Zoom.exe'; Category = 'Communication' }
            @{ Name = 'Power BI Desktop'; Path = 'PBIDesktop.exe'; Category = 'Analytics' }
        )
        Security = @(
            @{ Name = 'Wireshark'; Path = 'Wireshark.exe'; Category = 'NetworkAnalysis' }
            @{ Name = 'Nmap'; Path = 'nmap.exe'; Category = 'NetworkScanning' }
            @{ Name = 'Burp Suite'; Path = 'BurpSuiteCommunity.exe'; Category = 'WebSecurity' }
        )
        Gaming = @(
            @{ Name = 'Steam'; Path = 'steam.exe'; Category = 'Gaming' }
            @{ Name = 'Epic Games Launcher'; Path = 'EpicGamesLauncher.exe'; Category = 'Gaming' }
        )
    }
    
    foreach ($category in $detectionPatterns.Keys) {
        foreach ($pattern in $detectionPatterns[$category]) {
            try {
                if (Get-Command $pattern.Path -ErrorAction SilentlyContinue) {
                    $software[$category] += [PSCustomObject]@{
                        Name = $pattern.Name
                        Category = $pattern.Category
                        DetectedPath = (Get-Command $pattern.Path).Source
                        Method = 'Command'
                    }
                    Write-Verbose "Detected $($pattern.Name) via command path"
                }
            } catch {
                # Try registry detection for some apps
                $registryPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )
                
                foreach ($regPath in $registryPaths) {
                    try {
                        $installed = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | 
                            Where-Object { $_.DisplayName -like "*$($pattern.Name)*" } |
                            Select-Object -First 1
                        
                        if ($installed) {
                            $software[$category] += [PSCustomObject]@{
                                Name = $pattern.Name
                                Category = $pattern.Category
                                DetectedPath = $installed.InstallLocation
                                Method = 'Registry'
                                Version = $installed.DisplayVersion
                            }
                            Write-Verbose "Detected $($pattern.Name) via registry"
                            break
                        }
                    } catch {
                        # Continue to next detection method
                    }
                }
            }
        }
    }
    
    return $software
}

function Analyze-UserEnvironment {
    <#
    .SYNOPSIS
        Analyze user environment and usage patterns
    .DESCRIPTION
        Examines user profile, common directories, and environment variables
    .OUTPUTS
        User profile analysis object
    #>
    [CmdletBinding()]
    param()
    
    $userProfile = @{
        UserType = 'Unknown'
        WorkflowIndicators = @()
        EnvironmentClues = @()
        DirectoryStructure = @()
    }
    
    try {
        # Check for development indicators
        $devIndicators = @()
        
        # Common dev directories
        $devPaths = @(
            "$env:USERPROFILE\source",
            "$env:USERPROFILE\src", 
            "$env:USERPROFILE\dev",
            "$env:USERPROFILE\projects",
            "$env:USERPROFILE\code",
            "$env:USERPROFILE\repos",
            "$env:USERPROFILE\github"
        )
        
        foreach ($path in $devPaths) {
            if (Test-Path $path) {
                $devIndicators += "Development directory: $(Split-Path $path -Leaf)"
                $userProfile.DirectoryStructure += $path
            }
        }
        
        # Check environment variables for dev tools
        $envVars = @('JAVA_HOME', 'PYTHON_PATH', 'NODE_PATH', 'GOPATH', 'CARGO_HOME')
        foreach ($var in $envVars) {
            if (Get-ChildItem Env: | Where-Object Name -eq $var) {
                $devIndicators += "Environment variable: $var"
            }
        }
        
        # SSH keys indicate development/admin work
        if (Test-Path "$env:USERPROFILE\.ssh") {
            $devIndicators += "SSH configuration found"
        }
        
        # Check for common config files
        $configFiles = @('.gitconfig', '.npmrc', '.vimrc', '.bashrc')
        foreach ($config in $configFiles) {
            if (Test-Path "$env:USERPROFILE\$config") {
                $devIndicators += "Config file: $config"
            }
        }
        
        # Determine user type based on indicators
        if ($devIndicators.Count -ge 3) {
            $userProfile.UserType = 'Developer'
        } elseif (Test-Path "$env:USERPROFILE\Documents") {
            try {
                $docCount = (Get-ChildItem "$env:USERPROFILE\Documents" -Directory -ErrorAction SilentlyContinue).Count
                if ($docCount -gt 10) {
                    $userProfile.UserType = 'BusinessUser'
                } else {
                    $userProfile.UserType = 'GeneralUser'
                }
            } catch {
                $userProfile.UserType = 'GeneralUser'
            }
        } else {
            $userProfile.UserType = 'GeneralUser'
        }
        
        $userProfile.WorkflowIndicators = $devIndicators
        
        # Check for admin privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if ($isAdmin) {
            $userProfile.EnvironmentClues += "Running as Administrator"
        }
        
        Write-Verbose "Identified user type: $($userProfile.UserType)"
        
    } catch {
        Write-Warning "Could not fully analyze user environment: $($_.Exception.Message)"
    }
    
    return $userProfile
}

function Determine-SystemCapabilities {
    <#
    .SYNOPSIS
        Determine what the system is capable of running
    .DESCRIPTION
        Analyzes hardware and software to determine suitable persona types
    .PARAMETER Hardware
        Hardware analysis results
    .PARAMETER Software
        Software detection results
    .OUTPUTS
        System capabilities assessment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Hardware,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Software
    )
    
    $capabilities = @{
        CanRunDevelopmentTools = $false
        CanRunVirtualization = $false
        CanRunBusinessApps = $true  # Generally true for modern systems
        CanRunSecurityTools = $true
        CanRunGamingPlatforms = $true
        RecommendedPersonas = @()
        Limitations = @()
        Strengths = @()
    }
    
    # Memory-based capabilities
    if ($Hardware.TotalMemoryGB -ge 8) {
        $capabilities.CanRunDevelopmentTools = $true
        $capabilities.CanRunVirtualization = $true
        $capabilities.Strengths += "Sufficient memory for development work (${Hardware.TotalMemoryGB}GB)"
    } elseif ($Hardware.TotalMemoryGB -ge 4) {
        $capabilities.CanRunDevelopmentTools = $true
        $capabilities.Limitations += "Limited memory may affect performance with heavy IDEs"
    } else {
        $capabilities.CanRunDevelopmentTools = $false
        $capabilities.CanRunVirtualization = $false
        $capabilities.Limitations += "Low memory (${Hardware.TotalMemoryGB}GB) limits development capabilities"
    }
    
    # Processor-based capabilities
    if ($Hardware.NumberOfProcessors -ge 4) {
        $capabilities.Strengths += "Multi-core processor suitable for parallel development tasks"
    }
    
    # Existing software influences
    if ($Software.Development.Count -gt 0) {
        $capabilities.RecommendedPersonas += 'dev'
        $capabilities.Strengths += "Existing development tools detected"
    }
    
    if ($Software.Business.Count -gt 0) {
        $capabilities.RecommendedPersonas += 'finance-pro'
        $capabilities.Strengths += "Business applications detected"
    }
    
    if ($Software.Security.Count -gt 0) {
        $capabilities.RecommendedPersonas += 'cybersec-pro'
        $capabilities.Strengths += "Security tools detected"
    }
    
    if ($Software.Gaming.Count -gt 0) {
        $capabilities.RecommendedPersonas += 'personal'
        $capabilities.Strengths += "Gaming platforms detected"
    }
    
    # Default recommendations if nothing specific detected
    if ($capabilities.RecommendedPersonas.Count -eq 0) {
        if ($capabilities.CanRunDevelopmentTools) {
            $capabilities.RecommendedPersonas += 'personal'
            $capabilities.RecommendedPersonas += 'it-pro'
        } else {
            $capabilities.RecommendedPersonas += 'personal'
        }
    }
    
    # Remove duplicates
    $capabilities.RecommendedPersonas = $capabilities.RecommendedPersonas | Select-Object -Unique
    
    return $capabilities
}

function Get-PersonaRecommendations {
    <#
    .SYNOPSIS
        Get personalized persona recommendations
    .DESCRIPTION
        Combines system analysis with user preferences to recommend personas
    .PARAMETER SystemAnalysis
        Results from Get-SystemAnalysis
    .PARAMETER UserPreferences
        Optional user preference indicators
    .OUTPUTS
        Ranked persona recommendations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemAnalysis,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$UserPreferences = @{}
    )
    
    Write-Verbose "Generating persona recommendations"
    
    $recommendations = @()
    
    # Base recommendations from system capabilities
    foreach ($persona in $SystemAnalysis.Capabilities.RecommendedPersonas) {
        $score = 50  # Base score
        $reasons = @()
        
        # Adjust score based on detected software and user type
        switch ($persona) {
            'dev' {
                if ($SystemAnalysis.Software.Development.Count -gt 0) {
                    $score += 30
                    $reasons += "Existing development tools detected"
                }
                if ($SystemAnalysis.UserProfile.UserType -eq 'Developer') {
                    $score += 25
                    $reasons += "Developer usage patterns identified"
                }
                if ($SystemAnalysis.Capabilities.CanRunVirtualization) {
                    $score += 15
                    $reasons += "System supports virtualization (Docker, etc.)"
                }
            }
            
            'finance-pro' {
                if ($SystemAnalysis.Software.Business.Count -gt 0) {
                    $score += 30
                    $reasons += "Business applications detected"
                }
                if ($SystemAnalysis.UserProfile.UserType -eq 'BusinessUser') {
                    $score += 25
                    $reasons += "Business user patterns identified"
                }
            }
            
            'cybersec-pro' {
                if ($SystemAnalysis.Software.Security.Count -gt 0) {
                    $score += 35
                    $reasons += "Security tools already installed"
                }
                if ($SystemAnalysis.UserProfile.EnvironmentClues -contains "Running as Administrator") {
                    $score += 10
                    $reasons += "Administrative access available"
                }
            }
            
            'it-pro' {
                if ($SystemAnalysis.UserProfile.EnvironmentClues -contains "Running as Administrator") {
                    $score += 20
                    $reasons += "Administrative privileges suggest IT role"
                }
                if ($SystemAnalysis.Environment.PowerShellEdition -eq 'Core') {
                    $score += 10
                    $reasons += "PowerShell Core indicates advanced usage"
                }
            }
            
            'personal' {
                if ($SystemAnalysis.Software.Gaming.Count -gt 0) {
                    $score += 20
                    $reasons += "Gaming platforms detected"
                }
                # Personal is always a reasonable fallback
                $score += 10
                $reasons += "Good general-purpose option"
            }
        }
        
        # Hardware-based adjustments
        if ($SystemAnalysis.Hardware.TotalMemoryGB -ge 16) {
            if ($persona -in @('dev', 'cybersec-pro')) {
                $score += 10
                $reasons += "High memory supports resource-intensive tools"
            }
        }
        
        # Apply user preferences if provided
        if ($UserPreferences.PreferredCategories) {
            foreach ($category in $UserPreferences.PreferredCategories) {
                if (($category -eq 'development' -and $persona -eq 'dev') -or
                    ($category -eq 'business' -and $persona -eq 'finance-pro') -or
                    ($category -eq 'security' -and $persona -eq 'cybersec-pro')) {
                    $score += 20
                    $reasons += "Matches stated preference for $category"
                }
            }
        }
        
        $recommendations += [PSCustomObject]@{
            PersonaName = $persona
            Score = $score
            Confidence = if ($score -ge 80) { 'High' } elseif ($score -ge 60) { 'Medium' } else { 'Low' }
            Reasons = $reasons
            SystemCompatibility = 'Compatible'
            EstimatedApps = 0  # Will be filled in later
        }
    }
    
    # Sort by score (highest first)
    $recommendations = $recommendations | Sort-Object Score -Descending
    
    # Add testbench as a lightweight option if system is limited
    if ($SystemAnalysis.Hardware.TotalMemoryGB -lt 4) {
        $recommendations += [PSCustomObject]@{
            PersonaName = 'testbench'
            Score = 40
            Confidence = 'Medium'
            Reasons = @('Lightweight option for limited systems')
            SystemCompatibility = 'Compatible'
            EstimatedApps = 3
        }
    }
    
    Write-Verbose "Generated $($recommendations.Count) persona recommendations"
    
    return $recommendations
}

function Show-PersonaRecommendations {
    <#
    .SYNOPSIS
        Display persona recommendations to user
    .DESCRIPTION
        Shows ranked recommendations with explanations and system analysis
    .PARAMETER Recommendations
        Persona recommendations from Get-PersonaRecommendations
    .PARAMETER SystemAnalysis
        System analysis results
    .PARAMETER ShowSystemInfo
        Whether to show detailed system information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Recommendations,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemAnalysis,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowSystemInfo
    )
    
    Write-Host "`n🤖 Smart Persona Recommendations" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    if ($ShowSystemInfo) {
        Write-Host "`nSystem Analysis:" -ForegroundColor Yellow
        Write-Host "  💻 Memory: $($SystemAnalysis.Hardware.TotalMemoryGB)GB" -ForegroundColor White
        Write-Host "  🖥️  Processors: $($SystemAnalysis.Hardware.NumberOfProcessors)" -ForegroundColor White
        Write-Host "  🔧 PowerShell: $($SystemAnalysis.Environment.PowerShellVersion)" -ForegroundColor White
        Write-Host "  👤 User Type: $($SystemAnalysis.UserProfile.UserType)" -ForegroundColor White
        
        if ($SystemAnalysis.Software.Development.Count -gt 0) {
            Write-Host "  🛠️  Development Tools: $($SystemAnalysis.Software.Development.Count) detected" -ForegroundColor Green
        }
        if ($SystemAnalysis.Software.Business.Count -gt 0) {
            Write-Host "  💼 Business Apps: $($SystemAnalysis.Software.Business.Count) detected" -ForegroundColor Green
        }
        if ($SystemAnalysis.Software.Security.Count -gt 0) {
            Write-Host "  🛡️  Security Tools: $($SystemAnalysis.Software.Security.Count) detected" -ForegroundColor Green
        }
    }
    
    Write-Host "`nRecommended Personas:" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt [Math]::Min($Recommendations.Count, 3); $i++) {
        $rec = $Recommendations[$i]
        $rank = $i + 1
        
        $confidenceColor = switch ($rec.Confidence) {
            'High' { 'Green' }
            'Medium' { 'Yellow' }
            'Low' { 'Red' }
            default { 'White' }
        }
        
        $medal = switch ($rank) {
            1 { "🥇" }
            2 { "🥈" } 
            3 { "🥉" }
            default { "  " }
        }
        
        Write-Host "`n$medal $rank. $($rec.PersonaName.ToUpper())" -ForegroundColor White
        Write-Host "   Confidence: $($rec.Confidence) ($($rec.Score)% match)" -ForegroundColor $confidenceColor
        
        if ($rec.Reasons.Count -gt 0) {
            Write-Host "   Why this fits:" -ForegroundColor Gray
            foreach ($reason in $rec.Reasons) {
                Write-Host "   • $reason" -ForegroundColor Gray
            }
        }
    }
    
    if ($SystemAnalysis.Capabilities.Limitations.Count -gt 0) {
        Write-Host "`n⚠️  System Considerations:" -ForegroundColor Yellow
        foreach ($limitation in $SystemAnalysis.Capabilities.Limitations) {
            Write-Host "  • $limitation" -ForegroundColor Yellow
        }
    }
    
    if ($SystemAnalysis.Capabilities.Strengths.Count -gt 0) {
        Write-Host "`n✨ System Strengths:" -ForegroundColor Green
        foreach ($strength in $SystemAnalysis.Capabilities.Strengths) {
            Write-Host "  • $strength" -ForegroundColor Green
        }
    }
    
    Write-Host "`n💡 Tip: You can still choose any persona manually, or create a custom one!" -ForegroundColor Cyan
}

# Export functions
Export-ModuleMember -Function Get-SystemAnalysis, Get-PersonaRecommendations, Show-PersonaRecommendations
