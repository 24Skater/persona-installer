# Persona Installer v1.4.0

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Winget](https://img.shields.io/badge/works%20with-winget-success?logo=windows)](https://learn.microsoft.com/windows/package-manager/winget/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://github.com/24Skater/persona-installer/actions/workflows/test.yml/badge.svg)](https://github.com/24Skater/persona-installer/actions/workflows/test.yml)

A modular, intelligent PowerShell installer for Windows. Pick a **persona** (Dev, Finance Pro, IT Pro, Cybersecurity, Personal, Testbench) or get **smart recommendations** based on your system analysis.

---

## What's New in v1.4.0

- **Testing Infrastructure**: Comprehensive Pester test suite with unit and integration tests
- **CI/CD Pipeline**: GitHub Actions workflow with PSScriptAnalyzer linting
- **Code Quality**: Configurable delays, validation helpers, consistent error handling
- **API Modernization**: Full PowerShell 5.1 and 7.x compatibility with CIM abstraction
- **Enhanced Catalog**: Dependency metadata, categories, and system requirements

---

## Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Persona-based Install** | Active | JSON profiles with base + optional apps |
| **Smart Recommendations** | Active | AI-powered persona suggestions based on system analysis |
| **Dependency Management** | Active | Automatic prerequisite resolution with conflict detection |
| **Enhanced Progress** | Active | Rich progress bars with ETA and speed metrics |
| **Dry Run Mode** | Active | Preview installations without changes |
| **Structured Logging** | Active | JSON-formatted logs with performance metrics |
| **Configurable Settings** | Active | External `Settings.psd1` for all behavior |
| **Dual Catalog Format** | Active | Legacy (simple) and enhanced (with dependencies) |
| **PowerShell Compatibility** | Active | Works on PS 5.1 and PS 7.x |

### Planned Features

| Feature | Status | Description |
|---------|--------|-------------|
| Parallel Installation | Planned | Install multiple apps simultaneously |
| Community Repository | Planned | Share and download community personas |
| GUI Mode | Planned | Graphical interface option |
| Auto-Updates | Planned | Check for installer updates |

---

## Quick Start

### 1. Download

```powershell
# Clone or download ZIP from GitHub
git clone https://github.com/24Skater/persona-installer.git
cd persona-installer/scripts
```

### 2. Run

```powershell
# Set execution policy for session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Preview mode (no actual installs)
.\Main.ps1 -DryRun

# Normal installation
.\Main.ps1

# With custom configuration
.\Main.ps1 -ConfigPath "C:\MyConfig\Settings.psd1"

# Skip welcome banner
.\Main.ps1 -NoWelcome
```

> **Tip**: Run as Administrator for silent installations and optimal performance.

---

## Personas

| Persona | Base Apps | Use Case |
|---------|-----------|----------|
| **Personal** | Git, VS Code, Chrome, VLC, WhatsApp, Zoom | General home use |
| **Dev** | Git, VS Code, Node.js, Python, Docker, .NET SDK | Software development |
| **Finance Pro** | Microsoft 365, Power BI, Teams, Slack | Financial/business work |
| **IT Pro** | PowerShell 7, Sysinternals, Wireshark, PuTTY | System administration |
| **Cybersec Pro** | Nmap, Wireshark, Burp Suite, Ghidra | Security testing |
| **Testbench** | PowerShell 7, Python, Git | Minimal testing setup |

Each persona has optional apps you can select during installation.

---

## Configuration

All settings are in `scripts/config/Settings.psd1`:

```powershell
@{
    Installation = @{
        MaxRetries = 3              # Retry failed installations
        SilentInstallFirst = $true  # Try silent mode first
        RetryDelay = 2              # Seconds between retries
        InstallPauseSeconds = 1     # Pause between apps
    }
    
    Features = @{
        DependencyChecking = $true      # Resolve dependencies
        SmartRecommendations = $true    # Enable AI recommendations
        EnhancedProgress = $true        # Rich progress bars
        UseEnhancedCatalog = $true      # Use catalog-enhanced.json
    }
    
    Logging = @{
        LogRetentionDays = 30       # Auto-cleanup old logs
        PerformanceLogging = $true  # Track install timing
    }
}
```

---

## Catalog Formats

### Legacy Format (Simple)

```json
{
  "Git": "Git.Git",
  "VS Code": "Microsoft.VisualStudioCode"
}
```

### Enhanced Format (With Dependencies)

```json
{
  "Docker Desktop": {
    "id": "Docker.DockerDesktop",
    "category": "Development",
    "dependencies": ["WSL2"],
    "system_requirements": {
      "min_memory_gb": 4,
      "requires_admin": true
    }
  }
}
```

Both formats are supported. Enable enhanced catalog in Settings.psd1:
```powershell
Features = @{ UseEnhancedCatalog = $true }
```

---

## Project Structure

```
persona-installer/
├── scripts/
│   ├── Main.ps1                    # Entry point
│   ├── config/
│   │   └── Settings.psd1           # Configuration
│   └── modules/
│       ├── CatalogManager.psm1     # Catalog operations
│       ├── PersonaManager.psm1     # Persona operations
│       ├── InstallEngine.psm1      # Installation logic
│       ├── DependencyManager.psm1  # Dependency resolution
│       ├── UIHelper.psm1           # User interface
│       ├── Logger.psm1             # Logging system
│       ├── EnhancedProgressManager.psm1  # Rich progress
│       ├── PersonaRecommendationEngine.psm1  # AI recommendations
│       └── CompatibilityHelper.psm1  # PS5/7 compatibility
├── data/
│   ├── catalog.json                # Legacy catalog
│   ├── catalog-enhanced.json       # Enhanced catalog
│   └── personas/                   # Persona definitions
├── tests/
│   ├── Unit/                       # Unit tests
│   ├── Integration/                # Integration tests
│   └── Invoke-Tests.ps1            # Test runner
├── docs/                           # Documentation
└── logs/                           # Installation logs
```

---

## Testing

```powershell
# Run unit tests
.\tests\Invoke-Tests.ps1 -TestType Unit

# Run all tests with coverage
.\tests\Invoke-Tests.ps1 -TestType All -Coverage

# Run integration tests
.\tests\Invoke-Tests.ps1 -TestType Integration
```

> Requires Pester 5.0+: `Install-Module Pester -MinimumVersion 5.0.0 -Force`

---

## Logs

| Log Type | Location | Content |
|----------|----------|---------|
| **App Logs** | `logs/<AppName>.log` | Detailed winget output |
| **Session Logs** | `logs/session-*.txt` | Full session transcript |
| **Performance** | Embedded in session | Timing and metrics |

Logs are auto-cleaned after 30 days (configurable).

---

## Requirements

- Windows 10/11
- PowerShell 5.1+ (PowerShell 7 recommended)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/) (App Installer from Microsoft Store)

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `.\tests\Invoke-Tests.ps1 -TestType All`
4. Submit a pull request

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.

---

## License

MIT - free to use, modify, and share.

---

## Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history.
