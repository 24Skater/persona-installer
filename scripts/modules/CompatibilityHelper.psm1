<#
CompatibilityHelper.psm1 - PowerShell 5/7 Compatibility Layer
Provides cross-version compatible functions for WMI/CIM and other APIs
#>

function Get-SystemInfoInstance {
    <#
    .SYNOPSIS
        Get WMI/CIM instance with PowerShell version compatibility
    .DESCRIPTION
        Uses Get-CimInstance on PS6+ and Get-WmiObject on PS5.x
    .PARAMETER ClassName
        The WMI/CIM class name to query
    .PARAMETER Filter
        Optional WQL filter string
    .PARAMETER Property
        Optional properties to select
    .OUTPUTS
        CIM/WMI instance object(s)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClassName,
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = $null,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Property = $null
    )
    
    try {
        $params = @{
            ClassName = $ClassName
            ErrorAction = 'SilentlyContinue'
        }
        
        if ($Filter) {
            $params['Filter'] = $Filter
        }
        
        if ($Property) {
            $params['Property'] = $Property
        }
        
        # Use Get-CimInstance on PowerShell 6+ (Core), Get-WmiObject on PS5.x (Desktop)
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            return Get-CimInstance @params
        }
        else {
            # Convert CIM-style parameters to WMI-style
            $wmiParams = @{
                Class = $ClassName
                ErrorAction = 'SilentlyContinue'
            }
            
            if ($Filter) {
                $wmiParams['Filter'] = $Filter
            }
            
            if ($Property) {
                $wmiParams['Property'] = $Property
            }
            
            return Get-WmiObject @wmiParams
        }
    }
    catch {
        Write-Verbose "Failed to get $ClassName instance: $($_.Exception.Message)"
        return $null
    }
}

function Get-ComputerSystemInfo {
    <#
    .SYNOPSIS
        Get computer system information (memory, processors, model)
    .OUTPUTS
        Object with computer system details
    #>
    [CmdletBinding()]
    param()
    
    $cs = Get-SystemInfoInstance -ClassName 'Win32_ComputerSystem'
    
    if ($cs) {
        return [PSCustomObject]@{
            TotalPhysicalMemory = $cs.TotalPhysicalMemory
            TotalMemoryGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            NumberOfProcessors = $cs.NumberOfProcessors
            NumberOfLogicalProcessors = $cs.NumberOfLogicalProcessors
            Model = $cs.Model
            Manufacturer = $cs.Manufacturer
            SystemType = $cs.SystemType
        }
    }
    
    return $null
}

function Get-OperatingSystemInfo {
    <#
    .SYNOPSIS
        Get operating system information
    .OUTPUTS
        Object with OS details
    #>
    [CmdletBinding()]
    param()
    
    $os = Get-SystemInfoInstance -ClassName 'Win32_OperatingSystem'
    
    if ($os) {
        return [PSCustomObject]@{
            Caption = $os.Caption
            Version = $os.Version
            BuildNumber = $os.BuildNumber
            OSArchitecture = $os.OSArchitecture
            ServicePackMajorVersion = $os.ServicePackMajorVersion
            FreePhysicalMemory = $os.FreePhysicalMemory
            TotalVisibleMemorySize = $os.TotalVisibleMemorySize
        }
    }
    
    return $null
}

function Get-LogicalDiskInfo {
    <#
    .SYNOPSIS
        Get logical disk information
    .PARAMETER DeviceID
        Drive letter (e.g., 'C:')
    .OUTPUTS
        Object with disk details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DeviceID = $null
    )
    
    $filter = if ($DeviceID) { "DeviceID='$DeviceID'" } else { $null }
    $disks = Get-SystemInfoInstance -ClassName 'Win32_LogicalDisk' -Filter $filter
    
    if ($disks) {
        return $disks | ForEach-Object {
            [PSCustomObject]@{
                DeviceID = $_.DeviceID
                Size = $_.Size
                FreeSpace = $_.FreeSpace
                SizeGB = if ($_.Size) { [Math]::Round($_.Size / 1GB, 1) } else { 0 }
                FreeSpaceGB = if ($_.FreeSpace) { [Math]::Round($_.FreeSpace / 1GB, 1) } else { 0 }
                FileSystem = $_.FileSystem
                VolumeName = $_.VolumeName
            }
        }
    }
    
    return $null
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Check if current user has administrator privileges
    .OUTPUTS
        Boolean indicating admin status
    #>
    [CmdletBinding()]
    param()
    
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Verbose "Failed to check admin status: $($_.Exception.Message)"
        return $false
    }
}

function Get-PowerShellInfo {
    <#
    .SYNOPSIS
        Get PowerShell version and edition information
    .OUTPUTS
        Object with PowerShell details
    #>
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Version = $PSVersionTable.PSVersion
        VersionString = $PSVersionTable.PSVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        OS = $PSVersionTable.OS
        Platform = $PSVersionTable.Platform
        IsCoreCLR = $PSVersionTable.PSEdition -eq 'Core'
        IsDesktop = $PSVersionTable.PSEdition -eq 'Desktop'
    }
}

# Export functions
Export-ModuleMember -Function Get-SystemInfoInstance, Get-ComputerSystemInfo, Get-OperatingSystemInfo, Get-LogicalDiskInfo, Test-IsAdministrator, Get-PowerShellInfo

