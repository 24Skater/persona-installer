# Persona Installer 🎛️ v1.3.0

[![PowerShell](https://img.shields.io/badge/PowerShell-5%2B%20%7C%207-blue?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Winget](https://img.shields.io/badge/works%20with-winget-success?logo=windows)](https://learn.microsoft.com/windows/package-manager/winget/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/24Skater/persona-installer)](https://github.com/24Skater/persona-installer/releases)
[![Last commit](https://img.shields.io/github/last-commit/24Skater/persona-installer)](https://github.com/24Skater/persona-installer/commits/main)
[![PowerShell Lint](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml)

A **intelligent, AI-powered PowerShell installer** for Windows.  
Pick a **persona** (Dev, Finance Pro, IT Pro, Cybersecurity, Personal, Testbench) or get **smart recommendations** based on your system, and the script installs everything for you — with dependency management, enhanced progress tracking, and enterprise-grade features.

## ✨ What's New in v1.3.0

- ✅ **Smart Recommendations - LIVE**: AI-powered persona suggestions now fully integrated into the menu
- ✅ **Dependency Resolution - LIVE**: Automatic dependency analysis before every installation with conflict detection
- 🎯 **Dynamic Feature Loading**: Modules load based on configuration flags for optimal performance
- 🔧 **PowerShell Compatibility**: All Unicode/emoji issues resolved for universal compatibility
- 📈 **Production Ready**: Complete v1.2.0 feature integration with stable, tested codebase

---

## ✨ Features

- **Personas**: JSON-based profiles (`data/personas/*.json`) with "base" apps and "optional" apps
- **Smart Recommendations**: AI-powered system analysis suggests optimal personas for your setup
- **Dependency Management**: Automatic prerequisite resolution with conflict detection and system requirements validation
- **Interactive menu**:
  - 🤖 Smart persona recommendations
  - 📦 Install from persona  
  - ➕ Create or edit personas (no coding required)
  - 🛠️ Manage catalog (add new apps by winget ID)
  - 📋 View full catalog (exportable to CSV)
- **Enhanced Progress**: Rich progress bars with ETA, speed monitoring, and performance analytics
- **Dry Run mode**: preview installs without installing (`.\Main.ps1 -DryRun`)
- **Advanced Logging**: per-app logs + structured session logs with performance metrics
- **Configurable Settings**: customize behavior via external configuration file
- **Intelligent Error Handling**: comprehensive validation, retry mechanisms, and graceful failure handling

---

## 🚀 Quick Start

### Download as ZIP
1. On GitHub → click **Code → Download ZIP**
2. Extract it
3. Open the **scripts** folder

### Run the installer

```powershell
cd persona-installer\scripts
Set-ExecutionPolicy Bypass -Scope Process -Force

# Preview only, no installs
.\Main.ps1 -DryRun

# Real install
.\Main.ps1

# With custom configuration
.\Main.ps1 -ConfigPath "C:\MyConfig\Settings.psd1"

# Skip welcome message
.\Main.ps1 -NoWelcome
```

Run as **Administrator** when prompted. This enables silent installs and optimal performance.

---

## 🧑‍💻 Personas

### Personal
**Base:** Git, VS Code, GitHub Desktop, Chrome, Notepad++, PowerShell 7, VLC, WhatsApp, Zoom  
**Optional:** Steam, Epic Games, Ubisoft Connect, WorshipTools Presenter, Microsoft 365, Adobe Creative Cloud, Python 3

### Testbench
**Base:** PowerShell 7, Python 3, Git

### Dev
**Base:** Git, VS Code, GitHub Desktop, GitHub CLI, Node.js (LTS), Python 3, Java (OpenJDK 17), Docker Desktop, .NET SDK  
**Optional:** Visual Studio 2022, Postman, DBeaver, Go, Rust, Maven, Gradle, Yarn, Azure CLI, AWS CLI, Google Cloud SDK

### Finance Pro
**Base:** Chrome, Microsoft 365, Adobe Reader, Zoom, Teams, Slack, Power BI Desktop  
**Optional:** Tableau Public, Citrix Workspace

### IT Pro
**Base:** PowerShell 7, Git, Notepad++, 7-Zip, Everything, Nmap, Wireshark, Rufus, Ventoy, PuTTY  
**Optional:** Sysinternals Suite (Store), Chrome, VLC, Zoom

### Cybersecurity Pro
**Base:** Nmap, Wireshark, Burp Suite Community, OWASP ZAP, Ghidra, OpenSSL, Python 3, Git  
**Optional:** Docker CLI, Docker Desktop, GitHub CLI, Node.js (LTS)

---

## 📚 Catalog

- Apps live in `data/catalog.json` with **enhanced dependency support**
- **Legacy format**: Simple friendly name → winget ID mapping  
- **Enhanced format**: Rich metadata with dependencies, conflicts, and system requirements
- View them from the menu (`📋 View catalog`)
- Export to CSV for review
- Add new apps with dependency information (`🛠️ Manage catalog`)

---

## 🛠️ Requirements

- Windows 10/11
- PowerShell 5+ (PowerShell 7 recommended)
- [winget (App Installer)](https://learn.microsoft.com/en-us/windows/package-manager/winget/) from Microsoft Store

---

## 📝 Example Catalog Entries

**Legacy format (still supported):**
```json
{
  "Node.js (LTS)": "OpenJS.NodeJS.LTS",
  "Microsoft Teams": "Microsoft.Teams"
}
```

**Enhanced format (v1.2.0+):**
```json
{
  "Docker Desktop": {
    "id": "Docker.DockerDesktop",
    "dependencies": ["WSL2"],
    "system_requirements": {
      "min_windows_version": "10.0.19041",
      "min_memory_gb": 4,
      "requires_admin": true
    }
  },
  "GitHub CLI": {
    "id": "GitHub.cli", 
    "dependencies": ["Git"],
    "category": "Development"
  }
}
```

---

## 🧰 Logs

- **Per-app install logs**: `logs/<AppName>.log` with detailed winget output
- **Structured session logs**: `logs/session-YYYYMMDD-HHMMSS.txt` with JSON performance data
- **Performance analytics**: Installation timing, success rates, and system metrics
- **Enhanced error tracking**: Comprehensive error context and troubleshooting information

---

## 📜 License

MIT — free to use, modify, and share.
