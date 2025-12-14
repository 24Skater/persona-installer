#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for PersonaManager module
.DESCRIPTION
    Tests persona loading, saving, and validation functions
#>

BeforeAll {
    # Import required modules
    $compatPath = Join-Path $PSScriptRoot '../../scripts/modules/CompatibilityHelper.psm1'
    $uiHelperPath = Join-Path $PSScriptRoot '../../scripts/modules/UIHelper.psm1'
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/PersonaManager.psm1'
    
    Import-Module $compatPath -Force
    Import-Module $uiHelperPath -Force
    Import-Module $modulePath -Force
    
    # Create test personas directory
    $script:testPersonaDir = Join-Path $TestDrive 'personas'
    New-Item -ItemType Directory -Path $script:testPersonaDir -Force | Out-Null
    
    # Create test persona files
    $devPersona = @{
        name = 'dev'
        base = @('Git', 'VS Code')
        optional = @('Docker', 'Node.js')
    }
    $devPersona | ConvertTo-Json | Set-Content -Path (Join-Path $script:testPersonaDir 'dev.json')
    
    $personalPersona = @{
        name = 'personal'
        base = @('Chrome', 'VLC')
        optional = @('Steam')
    }
    $personalPersona | ConvertTo-Json | Set-Content -Path (Join-Path $script:testPersonaDir 'personal.json')
    
    # Create invalid persona file
    $invalidPersona = @{
        invalid = 'no name property'
    }
    $invalidPersona | ConvertTo-Json | Set-Content -Path (Join-Path $script:testPersonaDir 'invalid.json')
}

AfterAll {
    Remove-Module PersonaManager -ErrorAction SilentlyContinue
    Remove-Module UIHelper -ErrorAction SilentlyContinue
    Remove-Module CompatibilityHelper -ErrorAction SilentlyContinue
}

Describe 'PersonaManager Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module PersonaManager).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Import-Personas'
            $exportedFunctions | Should -Contain 'Save-Persona'
            $exportedFunctions | Should -Contain 'New-Persona'
            $exportedFunctions | Should -Contain 'Edit-Persona'
            $exportedFunctions | Should -Contain 'Test-PersonaName'
            $exportedFunctions | Should -Contain 'Get-PersonaSummary'
        }
    }
    
    Context 'Test-PersonaName' {
        It 'Should accept valid persona names' {
            Test-PersonaName -Name 'dev' | Should -Be $true
            Test-PersonaName -Name 'my-persona' | Should -Be $true
            Test-PersonaName -Name 'my_persona' | Should -Be $true
            Test-PersonaName -Name 'MyPersona123' | Should -Be $true
        }
        
        It 'Should reject whitespace-only names' {
            # Empty string throws because Name is mandatory
            # Test with whitespace instead
            Test-PersonaName -Name '   ' | Should -Be $false
        }
        
        It 'Should reject names with invalid characters' {
            Test-PersonaName -Name 'my persona' | Should -Be $false
            Test-PersonaName -Name 'my@persona' | Should -Be $false
            Test-PersonaName -Name 'my.persona' | Should -Be $false
        }
        
        It 'Should reject names exceeding max length' {
            $longName = 'a' * 51
            Test-PersonaName -Name $longName | Should -Be $false
        }
        
        It 'Should accept names at max length' {
            $maxName = 'a' * 50
            Test-PersonaName -Name $maxName | Should -Be $true
        }
    }
    
    Context 'Import-Personas' {
        It 'Should load valid personas from directory' {
            $personas = Import-Personas -PersonaDir $script:testPersonaDir
            $personas | Should -Not -BeNullOrEmpty
            $personas.Count | Should -BeGreaterOrEqual 2
        }
        
        It 'Should skip personas without name property' {
            $personas = Import-Personas -PersonaDir $script:testPersonaDir
            $invalidPersona = $personas | Where-Object { $_.name -eq 'invalid' }
            $invalidPersona | Should -BeNullOrEmpty
        }
        
        It 'Should create directory if it does not exist' {
            $newDir = Join-Path $TestDrive 'newpersonas'
            $personas = Import-Personas -PersonaDir $newDir
            Test-Path $newDir | Should -Be $true
            $personas.Count | Should -Be 0
        }
        
        It 'Should return personas with expected structure' {
            $personas = Import-Personas -PersonaDir $script:testPersonaDir
            $devPersona = $personas | Where-Object { $_.name -eq 'dev' }
            
            $devPersona.name | Should -Be 'dev'
            $devPersona.base | Should -Contain 'Git'
            $devPersona.base | Should -Contain 'VS Code'
            $devPersona.optional | Should -Contain 'Docker'
        }
    }
    
    Context 'Save-Persona' {
        It 'Should save persona to file' {
            $persona = [PSCustomObject]@{
                name = 'test-save'
                base = @('App1')
                optional = @('App2')
            }
            
            $savePath = Save-Persona -Persona $persona -PersonaDir $script:testPersonaDir
            
            Test-Path $savePath | Should -Be $true
            $saved = Get-Content $savePath -Raw | ConvertFrom-Json
            $saved.name | Should -Be 'test-save'
        }
        
        It 'Should throw for persona without name' {
            $persona = [PSCustomObject]@{
                base = @('App1')
            }
            
            { Save-Persona -Persona $persona -PersonaDir $script:testPersonaDir } | Should -Throw
        }
        
        It 'Should throw for invalid persona name' {
            $persona = [PSCustomObject]@{
                name = 'invalid name!'
                base = @()
            }
            
            { Save-Persona -Persona $persona -PersonaDir $script:testPersonaDir } | Should -Throw
        }
        
        It 'Should add empty base array if missing' {
            $persona = [PSCustomObject]@{
                name = 'no-base'
            }
            
            $savePath = Save-Persona -Persona $persona -PersonaDir $script:testPersonaDir
            $saved = Get-Content $savePath -Raw | ConvertFrom-Json
            
            # Empty arrays serialize as empty in JSON, verify the property exists
            $saved.PSObject.Properties.Name | Should -Contain 'base'
            @($saved.base).Count | Should -Be 0
        }
    }
    
    Context 'Get-PersonaSummary' {
        It 'Should return formatted summary' {
            $persona = [PSCustomObject]@{
                name = 'test'
                base = @('App1', 'App2')
                optional = @('App3')
            }
            
            $summary = Get-PersonaSummary -Persona $persona
            
            $summary | Should -Not -BeNullOrEmpty
            $summary | Should -Match 'test'
            $summary | Should -Match 'App1'
            $summary | Should -Match 'App2'
        }
        
        It 'Should handle empty base and optional' {
            $persona = [PSCustomObject]@{
                name = 'empty'
                base = @()
                optional = @()
            }
            
            $summary = Get-PersonaSummary -Persona $persona
            
            $summary | Should -Match '\(none\)'
        }
    }
}

