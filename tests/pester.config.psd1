@{
    Run = @{
        Path = './tests'
        PassThru = $true
        Exit = $true
    }
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            './scripts/modules/*.psm1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = './tests/coverage.xml'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './tests/testResults.xml'
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    Filter = @{
        Tag = @()
        ExcludeTag = @('Integration', 'Slow')
    }
}

