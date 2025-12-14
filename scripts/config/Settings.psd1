#
# Settings.psd1 - Configuration file for Persona Installer v1.4.0
# All settings are optional - defaults are applied if not specified
#

@{
    # ============================================================================
    # INSTALLATION SETTINGS
    # Controls how apps are installed via winget
    # ============================================================================
    Installation = @{
        # Maximum retry attempts for failed installations (default: 3)
        MaxRetries = 3
        
        # Try silent installation first - requires admin (default: true)
        SilentInstallFirst = $true
        
        # Seconds to wait between retry attempts (default: 2)
        RetryDelay = 2
        
        # Seconds to pause between app installations (0 = no pause)
        InstallPauseSeconds = 1
        
        # Timeout for individual installations in seconds (default: 300)
        InstallTimeout = 300
        
        # [PLANNED] Maximum parallel installations (currently ignored)
        MaxConcurrency = 1
    }
    
    # ============================================================================
    # LOGGING SETTINGS
    # Controls log file behavior and retention
    # ============================================================================
    Logging = @{
        # Days to retain log files before auto-cleanup (default: 30)
        LogRetentionDays = 30
        
        # Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
        DefaultLevel = 'INFO'
        
        # Enable verbose logging output (default: false)
        VerboseLogging = $false
        
        # Log performance metrics for each installation (default: true)
        PerformanceLogging = $true
        
        # [PLANNED] Maximum log file size in MB before rotation
        MaxLogSizeMB = 10
    }
    
    # ============================================================================
    # USER INTERFACE SETTINGS
    # Controls console output and user interaction
    # ============================================================================
    UI = @{
        # Show welcome banner on startup (default: true)
        ShowWelcome = $true
        
        # Show detailed per-app results after installation (default: false)
        ShowDetailedResults = $false
        
        # Use colored console output (default: true)
        UseColors = $true
        
        # Progress update interval in milliseconds (default: 1000)
        ProgressUpdateInterval = 1000
        
        # Pause for user review after operations (default: true)
        PauseAfterOperations = $true
    }
    
    # ============================================================================
    # SYSTEM SETTINGS
    # Controls system-level behavior and prerequisites
    # ============================================================================
    System = @{
        # Require administrator privileges (default: true)
        RequireAdmin = $true
        
        # Attempt auto-elevation if not admin (default: true)
        AutoElevate = $true
        
        # Verify winget is available on startup (default: true)
        CheckWingetAvailability = $true
        
        # Minimum winget version required (default: 1.0.0)
        MinWingetVersion = '1.0.0'
    }
    
    # ============================================================================
    # VALIDATION SETTINGS
    # Controls input validation and safety checks
    # ============================================================================
    Validation = @{
        # Maximum characters for persona names (default: 50)
        MaxPersonaNameLength = 50
        
        # Maximum characters for app display names (default: 100)
        MaxAppNameLength = 100
        
        # Validate winget IDs when adding to catalog (default: true)
        ValidateWingetIds = $true
        
        # Create backup before editing personas (default: true)
        BackupPersonasOnEdit = $true
    }
    
    # ============================================================================
    # PATH SETTINGS
    # Directory names relative to script root
    # ============================================================================
    Paths = @{
        DataDir = 'data'
        PersonasDir = 'personas'
        LogsDir = 'logs'
        ConfigDir = 'config'
        BackupDir = 'backup'
    }
    
    # ============================================================================
    # FEATURE FLAGS
    # Toggle optional features on/off
    # ============================================================================
    Features = @{
        # === ACTIVE FEATURES ===
        
        # Automatic dependency resolution before installation
        DependencyChecking = $true
        
        # AI-powered persona recommendations based on system analysis
        SmartRecommendations = $true
        
        # Rich progress bars with ETA and speed metrics
        EnhancedProgress = $true
        
        # Use catalog-enhanced.json with dependency metadata
        UseEnhancedCatalog = $true
        
        # === PLANNED FEATURES (not yet implemented) ===
        
        # [PLANNED] Queue installations for sequential processing
        InstallationQueue = $false
        
        # [PLANNED] Download/share personas from community repository
        CommunityRepository = $false
        
        # [PLANNED] Graphical user interface mode
        GuiMode = $false
        
        # [PLANNED] Install multiple apps simultaneously
        ParallelInstallation = $false
    }
    
    # ============================================================================
    # ERROR HANDLING SETTINGS
    # Controls behavior when errors occur
    # ============================================================================
    ErrorHandling = @{
        # Continue processing on non-critical errors (default: true)
        ContinueOnError = $true
        
        # Show stack traces for debugging (default: false)
        ShowStackTrace = $false
        
        # Prompt user when errors occur (default: true)
        PromptOnError = $true
        
        # Stop after this many consecutive errors (default: 5)
        MaxConsecutiveErrors = 5
    }
    
    # ============================================================================
    # PERFORMANCE SETTINGS
    # Controls performance monitoring and optimization
    # ============================================================================
    Performance = @{
        # Track and display performance metrics (default: true)
        EnableMonitoring = $true
        
        # Show metrics in console output (default: false)
        ShowMetrics = $false
        
        # [PLANNED] Optimize for low memory systems
        OptimizeMemory = $false
        
        # [PLANNED] Cache timeout in minutes
        CacheTimeout = 60
    }
    
    # ============================================================================
    # SECURITY SETTINGS
    # [PLANNED] Security features for future versions
    # ============================================================================
    Security = @{
        # [PLANNED] Validate digital signatures on packages
        ValidateSignatures = $false
        
        # [PLANNED] Scan downloaded files for malware
        ScanDownloads = $false
        
        # Only use HTTPS connections (default: true)
        SecureConnectionsOnly = $true
        
        # [PLANNED] List of trusted package publishers
        TrustedPublishers = @()
    }
    
    # ============================================================================
    # UPDATE SETTINGS
    # [PLANNED] Auto-update features for future versions
    # ============================================================================
    Updates = @{
        # [PLANNED] Check for updates automatically
        AutoCheckUpdates = $false
        
        # [PLANNED] Days between update checks
        UpdateCheckInterval = 7
        
        # [PLANNED] Include pre-release versions
        IncludePreRelease = $false
        
        # [PLANNED] Update source URL
        UpdateSource = 'https://api.github.com/repos/24Skater/persona-installer/releases'
    }
}
