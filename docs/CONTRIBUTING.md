# Contributing to Persona Installer

Thanks for your interest in improving Persona Installer! 🎉

## How to Contribute

### 1. Reporting Issues
- Use the GitHub Issues tab to report bugs or suggest features.
- Include steps to reproduce, expected behavior, and screenshots/logs if possible.

### 2. Adding to the Catalog
- Edit `data/catalog.json`.
- Format: `"Friendly App Name": "Winget.Package.ID"`
- Run `winget search <name>` to confirm the correct ID.
- Prefer LTS or stable versions where possible.

### 3. Creating or Updating Personas
- Personas live in `data/personas/` as JSON files.
- Format:
  ```json
  {
    "name": "persona-name",
    "base": ["App1","App2"],
    "optional": ["App3"]
  }
  ```
- Keep **base** apps minimal (essential only).
- Put everything else into **optional**.

### 4. PowerShell Coding Guidelines
- Scripts live in `scripts/`.
- Run lint locally before committing:
  ```powershell
  Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
  Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
  ```
- Fix **Errors** before pushing. Warnings are tolerated but keep them minimal.

### 5. Commit Messages
- Use clear, descriptive commit messages.
  - `feat(persona): add gaming persona`
  - `fix(script): handle missing catalog gracefully`
  - `docs: update setup guide`

### 6. Pull Requests
- Fork the repo, create a branch, commit your changes, and submit a PR.
- Make sure CI checks pass (lint).
- Keep PRs focused (one change/topic per PR).

---

## Development Workflow

1. Clone the repo and create a branch:
   ```powershell
   git clone https://github.com/24Skater/persona-installer.git
   cd persona-installer
   git checkout -b feature/my-change
   ```

2. Make changes and test locally (`-DryRun` is recommended).

3. Run lint:
   ```powershell
   Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
   ```

4. Commit & push:
   ```powershell
   git add .
   git commit -m "feat: describe your change"
   git push origin feature/my-change
   ```

5. Open a Pull Request on GitHub.

---

## Code of Conduct
Be respectful, constructive, and collaborative. Help make this project welcoming to everyone. 🚀
