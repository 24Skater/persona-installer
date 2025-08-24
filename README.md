# Persona Installer 🎛️

[![PowerShell](https://img.shields.io/badge/PowerShell-5%2B%20%7C%207-blue?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Winget](https://img.shields.io/badge/works%20with-winget-success?logo=windows)](https://learn.microsoft.com/windows/package-manager/winget/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/24Skater/persona-installer)](https://github.com/24Skater/persona-installer/releases)
[![Last commit](https://img.shields.io/github/last-commit/24Skater/persona-installer)](https://github.com/24Skater/persona-installer/commits/main)
[![PowerShell Lint](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml)

A modular, **UI-driven PowerShell installer** for Windows.  
Pick a **persona** (Dev, Finance Pro, IT Pro, Cybersecurity, Personal, Testbench), select optional apps, and the script installs everything for you — with progress and logs.

---

## ✨ Features

- **Personas**: JSON-based profiles (`data/personas/*.json`) with “base” apps and “optional” apps
- **Interactive menu**:
  - Install from a persona
  - Create or edit personas (no coding required)
  - Manage catalog (add new apps by winget ID)
  - View full catalog (exportable to CSV)
- **Dry Run mode**: preview installs without installing (`.\Main.ps1 -DryRun`)
- **Logging**: per-app logs + full session transcripts in `logs/`

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
```

Run as **Administrator** when prompted. This makes installs silent and smooth.

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

- Apps live in `data/catalog.json` as **friendly name → winget ID**
- View them from the menu (`5) View catalog`)
- Export to CSV for review
- Add new apps with (`4) Manage catalog`)

---

## 🛠️ Requirements

- Windows 10/11
- PowerShell 5+ (PowerShell 7 recommended)
- [winget (App Installer)](https://learn.microsoft.com/en-us/windows/package-manager/winget/) from Microsoft Store

---

## 📝 Example Catalog Entries

```json
{
  "Node.js (LTS)": "OpenJS.NodeJS.LTS",
  "Docker Desktop": "Docker.DockerDesktop",
  "Microsoft Teams": "Microsoft.Teams",
  "Wireshark": "WiresharkFoundation.Wireshark"
}
```

---

## 🧰 Logs

- Per-app install logs: `logs/<AppName>.log`
- Full session transcript: `logs/session-YYYYMMDD-HHMMSS.txt`

---

## 📜 License

MIT — free to use, modify, and share.
