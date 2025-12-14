#
# Settings.psd1 - Configuration file for Persona Installer
# This file contains externalized configuration settings
#

@{
    # Installation Settings
    Installation = @{
        # Maximum number of retry attempts for failed installations
        MaxRetries = 3
        
        # Whether to try silent installation first (requires admin)
        SilentInstallFirst = $true
        
        # Delay between installation attempts (seconds)
        RetryDelay = 2
        
        # Maximum parallel installations (future feature)
        MaxConcurrency = 1
        
        # Timeout for individual app installations (seconds)
        InstallTimeout = 300
    }
    
    # Logging Settings
    Logging = @{
        # Number of days to retain log files
        LogRetentionDays = 30
        
        # Default log level (DEBUG, INFO, WARN, ERROR)
        DefaultLevel = 'INFO'
        
        # Whether to enable verbose logging
        VerboseLogging = $false
        
        # Whether to enable performance logging
        PerformanceLogging = $true
        
        # Maximum log file size in MB before rotation
        MaxLogSizeMB = 10
    }
    
    # User Interface Settings
    UI = @{
        # Whether to show welcome banner
        ShowWelcome = $true
        
        # Whether to show detailed installation results by default
        ShowDetailedResults = $false
        
        # Whether to use colors in console output
        UseColors = $true
        
        # Progress update frequency (milliseconds)
        ProgressUpdateInterval = 1000
        
        # Whether to pause after operations for user review
        PauseAfterOperations = $true
    }
    
    # System Settings
    System = @{
        # Whether to require administrator privileges
        RequireAdmin = $true
        
        # Whether to automatically elevate if not admin
        AutoElevate = $true
        
        # Whether to check for winget availability on startup
        CheckWingetAvailability = $true
        
        # Minimum required winget version
        MinWingetVersion = '1.0.0'
    }
    
    # Validation Settings
    Validation = @{
        # Maximum length for persona names
        MaxPersonaNameLength = 50
        
        # Maximum length for app display names
        MaxAppNameLength = 100
        
        # Whether to validate winget IDs when adding to catalog
        ValidateWingetIds = $true
        
        # Whether to backup personas before editing
        BackupPersonasOnEdit = $true
    }
    
    # Path Settings (relative to script root)
    Paths = @{
        # Data directory name
        DataDir = 'data'
        
        # Personas subdirectory name
        PersonasDir = 'personas'
        
        # Logs directory name
        LogsDir = 'logs'
        
        # Configuration directory name
        ConfigDir = 'config'
        
        # Backup directory name
        BackupDir = 'backup'
    }
    
    # Feature Flags
    Features = @{
        # Enable dependency checking (v1.2.0 feature)
        DependencyChecking = $true
        
        # Enable smart persona recommendations (v1.2.0 feature)
        SmartRecommendations = $true
        
        # Enable enhanced progress indicators (v1.2.0 feature)
        EnhancedProgress = $true
        
        # Use enhanced catalog with dependency metadata (v1.4.0 feature)
        # When enabled, uses catalog-enhanced.json instead of catalog.json
        UseEnhancedCatalog = $true
        
        # Enable installation queueing (future feature)
        InstallationQueue = $false
        
        # Enable community persona repository (future feature)
        CommunityRepository = $false
        
        # Enable GUI mode (future feature)
        GuiMode = $false
        
        # Enable parallel installations (future feature)
        ParallelInstallation = $false
    }
    
    # Error Handling Settings
    ErrorHandling = @{
        # Whether to continue on non-critical errors
        ContinueOnError = $true
        
        # Whether to show stack traces for errors
        ShowStackTrace = $false
        
        # Whether to prompt user on errors
        PromptOnError = $true
        
        # Maximum consecutive errors before aborting
        MaxConsecutiveErrors = 5
    }
    
    # Performance Settings
    Performance = @{
        # Whether to enable performance monitoring
        EnableMonitoring = $true
        
        # Whether to show performance metrics
        ShowMetrics = $false
        
        # Whether to optimize for memory usage
        OptimizeMemory = $false
        
        # Cache timeout in minutes
        CacheTimeout = 60
    }
    
    # Security Settings
    Security = @{
        # Whether to validate digital signatures (future feature)
        ValidateSignatures = $false
        
        # Whether to scan downloaded files (future feature)
        ScanDownloads = $false
        
        # Whether to use secure connections only
        SecureConnectionsOnly = $true
        
        # Trusted publishers list (future feature)
        TrustedPublishers = @()
    }
    
    # Update Settings (future feature)
    Updates = @{
        # Whether to check for updates automatically
        AutoCheckUpdates = $false
        
        # Update check frequency in days
        UpdateCheckInterval = 7
        
        # Whether to include pre-release versions
        IncludePreRelease = $false
        
        # Update source URL
        UpdateSource = 'https://api.github.com/repos/24Skater/persona-installer/releases'
    }
}
