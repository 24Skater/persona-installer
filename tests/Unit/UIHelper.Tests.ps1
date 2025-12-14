#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for UIHelper module
.DESCRIPTION
    Tests UI display and user interaction functions
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/UIHelper.psm1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module UIHelper -ErrorAction SilentlyContinue
}

Describe 'UIHelper Module' {
    
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }
        
        It 'Should export expected functions' {
            $exportedFunctions = (Get-Module UIHelper).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Select-Apps'
            $exportedFunctions | Should -Contain 'Show-Menu'
            $exportedFunctions | Should -Contain 'Show-PersonaList'
            $exportedFunctions | Should -Contain 'Show-InstallationSummary'
            $exportedFunctions | Should -Contain 'Show-Progress'
            $exportedFunctions | Should -Contain 'Wait-ForUser'
            $exportedFunctions | Should -Contain 'Confirm-Action'
            $exportedFunctions | Should -Contain 'Show-Error'
            $exportedFunctions | Should -Contain 'Show-Success'
            $exportedFunctions | Should -Contain 'Show-Warning'
            $exportedFunctions | Should -Contain 'Read-ValidatedInput'
        }
    }
    
    Context 'Show-Progress' {
        It 'Should not throw for valid parameters' {
            { Show-Progress -Current 5 -Total 10 -Activity 'Testing' } | Should -Not -Throw
        }
        
        It 'Should handle edge cases' {
            { Show-Progress -Current 0 -Total 10 -Activity 'Starting' } | Should -Not -Throw
            { Show-Progress -Current 10 -Total 10 -Activity 'Complete' } | Should -Not -Throw
        }
        
        It 'Should handle zero total gracefully' {
            { Show-Progress -Current 0 -Total 0 -Activity 'Empty' } | Should -Not -Throw
        }
    }
    
    Context 'Show-PersonaList' {
        It 'Should display personas without error' {
            $personas = @(
                [PSCustomObject]@{ name = 'dev'; base = @('Git'); optional = @('Docker') },
                [PSCustomObject]@{ name = 'personal'; base = @('Chrome'); optional = @() }
            )
            
            { Show-PersonaList -Personas $personas } | Should -Not -Throw
        }
        
        It 'Should handle empty persona list' {
            { Show-PersonaList -Personas @() } | Should -Not -Throw
        }
    }
    
    Context 'Show-InstallationSummary' {
        It 'Should display summary without error' {
            $results = @(
                [PSCustomObject]@{ DisplayName = 'Git'; Status = 'Success' },
                [PSCustomObject]@{ DisplayName = 'Docker'; Status = 'Failed' }
            )
            
            { Show-InstallationSummary -Results $results } | Should -Not -Throw
        }
        
        It 'Should handle empty results' {
            { Show-InstallationSummary -Results @() } | Should -Not -Throw
        }
    }
    
    Context 'Show-Error' {
        It 'Should display error message' {
            { Show-Error -Message 'Test error' } | Should -Not -Throw
        }
        
        It 'Should accept exception object' {
            try { throw 'Test' } catch { $ex = $_.Exception }
            { Show-Error -Message 'Error with exception' -Exception $ex } | Should -Not -Throw
        }
    }
    
    Context 'Show-Success' {
        It 'Should display success message' {
            { Show-Success -Message 'Test success' } | Should -Not -Throw
        }
    }
    
    Context 'Show-Warning' {
        It 'Should display warning message' {
            { Show-Warning -Message 'Test warning' } | Should -Not -Throw
        }
    }
    
    Context 'Show-WelcomeMessage' {
        It 'Should display welcome message' {
            { Show-WelcomeMessage -Version '1.3.0' } | Should -Not -Throw
        }
    }
}

