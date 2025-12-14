<#
.SYNOPSIS
    Test runner script for Persona Installer
.DESCRIPTION
    Runs Pester tests with configurable options for unit tests, integration tests, and code coverage
.PARAMETER TestType
    Type of tests to run: Unit, Integration, or All
.PARAMETER Coverage
    Enable code coverage reporting
.PARAMETER OutputPath
    Path for test results output
.EXAMPLE
    .\Invoke-Tests.ps1 -TestType Unit
.EXAMPLE
    .\Invoke-Tests.ps1 -TestType All -Coverage
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$TestType = 'Unit',
    
    [Parameter(Mandatory = $false)]
    [switch]$Coverage,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = './tests'
)

$ErrorActionPreference = 'Stop'

# Check for Pester module
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]'5.0.0' }
if (-not $pesterModule) {
    Write-Host "Pester 5.0+ is required. Installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0.0

# Get script paths
$testsRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $testsRoot
$modulesPath = Join-Path $projectRoot 'scripts/modules'

# Build Pester configuration
$pesterConfig = @{
    Run = @{
        Path = $testsRoot
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = Join-Path $OutputPath 'testResults.xml'
    }
}

# Configure test filtering based on TestType
switch ($TestType) {
    'Unit' {
        $pesterConfig.Filter = @{
            ExcludeTag = @('Integration', 'Slow')
        }
        Write-Host "`n=== Running Unit Tests ===" -ForegroundColor Cyan
    }
    'Integration' {
        $pesterConfig.Filter = @{
            Tag = @('Integration')
        }
        Write-Host "`n=== Running Integration Tests ===" -ForegroundColor Cyan
    }
    'All' {
        $pesterConfig.Filter = @{}
        Write-Host "`n=== Running All Tests ===" -ForegroundColor Cyan
    }
}

# Configure code coverage if requested
if ($Coverage) {
    $pesterConfig.CodeCoverage = @{
        Enabled = $true
        Path = @(Get-ChildItem -Path $modulesPath -Filter '*.psm1' | ForEach-Object { $_.FullName })
        OutputFormat = 'JaCoCo'
        OutputPath = Join-Path $OutputPath 'coverage.xml'
    }
    Write-Host "Code coverage enabled" -ForegroundColor Green
}

# Create Pester configuration object
$config = New-PesterConfiguration -Hashtable $pesterConfig

# Run tests
Write-Host "`nStarting tests at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
$results = Invoke-Pester -Configuration $config

# Display summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total:   $($results.TotalCount)" -ForegroundColor White
Write-Host "Passed:  $($results.PassedCount)" -ForegroundColor Green
Write-Host "Failed:  $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped: $($results.SkippedCount)" -ForegroundColor Yellow

if ($Coverage) {
    Write-Host "`nCode Coverage: $([Math]::Round($results.CodeCoverage.CoveragePercent, 2))%" -ForegroundColor $(
        if ($results.CodeCoverage.CoveragePercent -ge 80) { 'Green' }
        elseif ($results.CodeCoverage.CoveragePercent -ge 50) { 'Yellow' }
        else { 'Red' }
    )
}

# Return exit code based on test results
if ($results.FailedCount -gt 0) {
    Write-Host "`nTests FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nTests PASSED" -ForegroundColor Green
    exit 0
}

