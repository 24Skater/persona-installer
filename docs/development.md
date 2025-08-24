# Development Guide

This document is for advanced users and contributors who want to understand and extend **Persona Installer**.

---

## 🔹 Script Structure

- **Main.ps1** (in `scripts/`)  
  - Entry point with interactive menu
  - Handles elevation, DryRun, transcript logging
  - Loads catalog & personas
  - Provides menu options (install, create/edit persona, manage/view catalog, exit)

- **data/catalog.json**  
  - Master list of apps (friendly name → winget ID)

- **data/personas/*.json**  
  - Persona profiles (base apps + optional apps)

- **logs/**  
  - Per-app install logs (`<AppName>.log`)
  - Session transcript logs (`session-YYYYMMDD-HHMMSS.txt`)

---

## 🔹 Main Script Flow

1. **Startup**
   - Ensures Administrator mode (relaunches with `-NoExit` if needed)
   - Starts transcript logging
   - Loads catalog as a hashtable
   - Loads persona JSONs into memory

2. **Menu Options**
   - `1) Install from persona` → choose persona, select optional apps, confirm, run install loop
   - `2) Create new persona` → build new JSON (clone or fresh)
   - `3) Edit existing persona` → modify base/optional apps
   - `4) Manage catalog` → add new package (name + winget ID)
   - `5) View catalog` → print/export to CSV
   - `6) Exit` → stop transcript, exit cleanly

3. **Install Logic**
   - Skips already installed apps (via `winget list` check)
   - Runs `winget install --id <id> -e --silent`
   - Retries without `--silent` if it fails
   - Logs every command to `logs/<AppName>.log`

4. **DryRun Mode**
   - `-DryRun` flag bypasses installs
   - Prints what *would* be installed

---

## 🔹 Development Workflow

### 1. Run Locally
```powershell
# Preview only
.\Main.ps1 -DryRun

# Full run
.\Main.ps1
```

### 2. Add New Catalog Entries
```powershell
winget search <app>
# Copy the Id field to catalog.json
```

### 3. Add/Edit Personas
- Edit JSON in `data/personas/`
- Or use menu option `2)` or `3)`

### 4. Test with PSScriptAnalyzer
```powershell
Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

---

## 🔹 GitHub Actions (CI/CD)

Two workflows live under `.github/workflows/`:

- **powershell-lint.yml**  
  Runs PSScriptAnalyzer on every push/PR.  
  - Shows warnings but only fails on errors.  
  - Uploads results as artifact.  

- **package-release.yml**  
  Runs on version tags (e.g., `v1.0.0`).  
  - Zips repo contents (excluding `.git` and logs).  
  - Creates a GitHub Release with the zip attached.  

### Badges
Add to README for visibility:
```markdown
[![PowerShell Lint](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/24Skater/persona-installer/actions/workflows/powershell-lint.yml)
[![Release](https://img.shields.io/github/v/release/24Skater/persona-installer)](https://github.com/24Skater/persona-installer/releases)
```

---

## 🔹 Debugging Tips

- Check logs in `logs/`
- Use `-Verbose` for detailed PowerShell output:
  ```powershell
  .\Main.ps1 -DryRun -Verbose
  ```
- Use `Write-Debug` statements for temporary debugging (enable with `$DebugPreference='Continue'`)

---

## 🔹 Future Improvements

- GUI wrapper (WinForms or WPF) for users who dislike the console
- More personas (gaming, design, education)
- Better error reporting (summarize failed apps at the end)
- Import/export personas via a community repo

---

Happy hacking! 🚀
