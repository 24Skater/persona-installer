# Persona Installer 🎛️

A modular, **UI-driven** PowerShell installer for Windows post-build setup.  
Users pick a **persona**, confirm base apps, select optional apps, and watch installs with progress + logs.  
**Personas are simple JSON files** under `data/personas/`, so anyone can create or edit them.

## Quick Start
```powershell
# in an elevated PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
iwr https://raw.githubusercontent.com/<your-username>/persona-installer/main/scripts/Main.ps1 -OutFile Main.ps1
.\Main.ps1
```

Or clone:
```powershell
git clone https://github.com/<your-username>/persona-installer.git
cd persona-installer\scripts
.\Main.ps1
```

## How it works
- `data/catalog.json` maps **Display Name → winget ID**.
- `data/personas/*.json` define personas:
  ```json
  {
    "name": "personal",
    "base": ["Git","VS Code"],
    "optional": ["Steam"]
  }
  ```
- `scripts/Main.ps1` provides an interactive UI to:
  - Install from a persona
  - Create a new persona (from scratch or by cloning)
  - Edit a persona (add/remove apps)
  - Update the catalog with new winget packages

## Requirements
- Windows 10/11
- PowerShell 5+ (PowerShell 7 recommended)
- winget (App Installer)

## Logs
Installer output is saved to `./logs/*.log`.

## License
MIT
