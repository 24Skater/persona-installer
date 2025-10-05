# Changelog

All notable changes to this project will be documented here.  
This project follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

## [v1.3.0] - 2025-10-05
### Added
- **Smart Persona Recommendations Integration**: Fully functional menu option that analyzes your system and recommends optimal personas
  - Automatic hardware detection (RAM, CPU cores, disk space)
  - Software pattern analysis (development tools, business apps, security tools)
  - User type classification (Developer, Business User, General User)
  - Confidence-scored recommendations with detailed reasoning
  - One-click installation of recommended personas
  
- **Dependency Management Integration**: Automatic dependency resolution integrated into persona installation flow
  - Pre-installation dependency analysis
  - Dependency tree visualization with installation order
  - Conflict detection and warnings
  - Missing dependency identification
  - Circular dependency detection
  - User confirmation for installations with issues
  - Graceful fallback if resolution fails

- **Dynamic Module Loading**: Intelligent module loading system based on feature flags
  - Core modules always loaded
  - Optional v1.2.0+ modules load only when features enabled
  - Graceful degradation if optional modules fail
  - Improved startup performance

### Fixed
- **Unicode/Emoji Compatibility**: Resolved all remaining Unicode/emoji parsing errors in v1.2.0 modules
  - `DependencyManager.psm1`: Replaced box-drawing characters (├─, └─) with ASCII equivalents
  - `PersonaRecommendationEngine.psm1`: Replaced all emoji indicators with text-based equivalents
  - Ensures universal compatibility across PowerShell versions and Windows configurations

### Changed
- **Module Architecture**: Enhanced module loading to support conditional feature activation
- **Installation Flow**: Enhanced to include optional dependency resolution step
- **User Experience**: Clearer feedback during dependency analysis and resolution
- **Version**: Updated to v1.3.0 reflecting feature integration milestone

### Technical Improvements
- Feature flags now control module loading dynamically
- Improved error handling for optional features
- Better separation between core and advanced features
- Enhanced logging for dependency resolution operations

## [v1.2.0] - 2025-10-05
### Fixed
- **Unicode/Emoji Compatibility**: Removed all Unicode and emoji characters from PowerShell modules to prevent parsing errors
  - `CatalogManager.psm1`: Replaced `↔` arrow with ASCII hyphen
  - `InstallEngine.psm1`: Replaced emoji status indicators (✅❌⏭️📊🚨🔍❓) with ASCII equivalents ([OK], [X], [>>], [!], [?])
  - `UIHelper.psm1`: Replaced box-drawing characters (╔║╚) and emojis (🔍❌✅⚠️) with standard ASCII characters
  - `Main.ps1`: Removed emoji characters from menu options to ensure cross-platform compatibility

### Changed
- **Version**: Updated to v1.2.0
- **PowerShell Compatibility**: Improved compatibility with PowerShell's default encoding by using ASCII-only characters in code structure
- **User Interface**: Simplified visual elements while maintaining readability and clarity

### Technical Notes
- PowerShell scripts should avoid Unicode/emoji characters in code structure unless files are explicitly saved with UTF-8 BOM encoding
- Emoji characters can still be safely used in `Write-Host` output strings for display purposes
- This release ensures the script works reliably across different PowerShell environments and Windows configurations

## [v1.1.0] - 2025-10-05
### Added
- **Modular Architecture**: Completely refactored Main.ps1 into focused modules:
  - `PersonaManager.psm1` for persona operations (load, save, create, edit)
  - `CatalogManager.psm1` for catalog management and winget operations
  - `InstallEngine.psm1` for installation logic with enhanced retry mechanisms
  - `UIHelper.psm1` for user interface utilities and consistent formatting
  - `Logger.psm1` for structured logging with JSON output and performance tracking
- **Externalized Configuration**: New `config/Settings.psd1` file for all configurable options
- **Enhanced Error Handling**: Comprehensive error handling with retry logic and user-friendly messages
- **Structured Logging**: JSON-based logging with performance metrics and error tracking
- **Input Validation**: Robust validation for persona names, winget IDs, and user inputs
- **Improved UI**: Better progress indicators, consistent color coding, and enhanced user experience
- **Performance Monitoring**: Built-in timing and performance analysis for operations

### Changed
- **Main.ps1**: Reduced from 314 lines to 180 lines focused on orchestration
- **Installation Logic**: Enhanced with configurable retry attempts and fallback strategies
- **User Interface**: More consistent messaging and error reporting across all operations
- **Configuration**: All hardcoded values moved to externalized settings file

### Technical Improvements
- **Code Organization**: Clear separation of concerns with focused modules
- **Maintainability**: Each module has comprehensive documentation and type annotations
- **Extensibility**: Plugin-ready architecture for future enhancements
- **Testing Ready**: Modular structure enables unit testing of individual components
- **PowerShell Compatibility**: Support for both PowerShell 5.1 and 7.x

## [v1.0.1] - 2025-08-24
### Added
- Expanded documentation suite:
  - `docs/setup-guide.md` (step-by-step install guide)
  - `docs/personas.md` (persona overview table)
  - `docs/catalog-reference.md` (catalog format + winget ID tips)
  - `docs/troubleshooting.md` (common issues and fixes)
  - `docs/development.md` (internals, CI/CD, debugging)
- Added `CONTRIBUTING.md` (contribution guidelines)
- Added `CHANGELOG.md` baseline with entries
- Reformatted `README.md` with badges and clear persona list

### Changed
- Improved repo layout with full `docs/` folder for easy navigation

- Add new personas (gaming, design, etc.)
- Expand catalog with more professional tools
- Improve CI checks and automated testing

---

## [v1.0.0] - 2025-08-24
### Added
- Initial release 🎉
- Interactive PowerShell UI (Main.ps1)
- JSON-based personas and catalog system
- Built-in personas:
  - personal
  - testbench
  - dev
  - finance-pro
  - it-pro
  - cybersec-pro
- Logging (per-app + session transcript)
- DryRun mode for safe previews
- GitHub Actions CI (PSScriptAnalyzer lint)
- GitHub Actions Release workflow (auto-zip & publish)

---

## Template for future versions

## [vX.Y.Z] - YYYY-MM-DD
### Added
- ...

### Changed
- ...

### Fixed
- ...

### Removed
- ...
