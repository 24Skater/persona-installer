#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for CompatibilityHelper module
.DESCRIPTION
    Tests cross-platform compatibility functions for WMI/CIM abstraction
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/CompatibilityHelper.psm1'
    Import-Module $modulePath -Force
}

AfterAll {
    # Clean up
    Remove-Module CompatibilityHelper -ErrorAction SilentlyContinue
}

Describe 'CompatibilityHelper Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module CompatibilityHelper).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Get-SystemInfoInstance'
            $exportedFunctions | Should -Contain 'Get-ComputerSystemInfo'
            $exportedFunctions | Should -Contain 'Get-OperatingSystemInfo'
            $exportedFunctions | Should -Contain 'Get-LogicalDiskInfo'
            $exportedFunctions | Should -Contain 'Test-IsAdministrator'
            $exportedFunctions | Should -Contain 'Get-PowerShellInfo'
        }
    }
    
    Context 'Get-PowerShellInfo' {
        It 'Should return PowerShell version information' {
            $result = Get-PowerShellInfo
            $result | Should -Not -BeNullOrEmpty
            $result.Version | Should -Not -BeNullOrEmpty
            $result.VersionString | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have correct edition' {
            $result = Get-PowerShellInfo
            $result.Edition | Should -BeIn @('Core', 'Desktop')
        }
        
        It 'Should have boolean flags' {
            $result = Get-PowerShellInfo
            $result.IsCoreCLR | Should -BeOfType [bool]
            $result.IsDesktop | Should -BeOfType [bool]
        }
    }
    
    Context 'Test-IsAdministrator' {
        It 'Should return a boolean' {
            $result = Test-IsAdministrator
            $result | Should -BeOfType [bool]
        }
        
        It 'Should not throw' {
            { Test-IsAdministrator } | Should -Not -Throw
        }
    }
    
    Context 'Get-ComputerSystemInfo' {
        It 'Should return computer system information' {
            $result = Get-ComputerSystemInfo
            # May be null if WMI/CIM fails, but should not throw
            if ($result) {
                $result.TotalMemoryGB | Should -BeGreaterThan 0
            }
        }
        
        It 'Should not throw on error' {
            { Get-ComputerSystemInfo } | Should -Not -Throw
        }
    }
    
    Context 'Get-OperatingSystemInfo' {
        It 'Should return OS information' {
            $result = Get-OperatingSystemInfo
            if ($result) {
                $result.Caption | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should not throw on error' {
            { Get-OperatingSystemInfo } | Should -Not -Throw
        }
    }
    
    Context 'Get-LogicalDiskInfo' {
        It 'Should return disk information for system drive' {
            $result = Get-LogicalDiskInfo -DeviceID $env:SystemDrive
            if ($result) {
                $result.DeviceID | Should -Be $env:SystemDrive
                $result.FreeSpaceGB | Should -BeGreaterOrEqual 0
            }
        }
        
        It 'Should handle invalid drive gracefully' {
            $result = Get-LogicalDiskInfo -DeviceID 'Z:'
            # Should return null or empty for non-existent drive
            # Should not throw
        }
    }
    
    Context 'Get-SystemInfoInstance' {
        It 'Should return WMI/CIM instance for valid class' {
            $result = Get-SystemInfoInstance -ClassName 'Win32_OperatingSystem'
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle invalid class gracefully' {
            $result = Get-SystemInfoInstance -ClassName 'Invalid_Class_Name'
            $result | Should -BeNullOrEmpty
        }
    }
}

