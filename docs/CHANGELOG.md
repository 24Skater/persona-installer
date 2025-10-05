# Changelog

All notable changes to this project will be documented here.  
This project follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

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
