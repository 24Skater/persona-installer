# Phase 1: v1.5.0 Implementation Plan
## User Experience Enhancements

> **Target Version:** 1.5.0  
> **Status:** NOT STARTED  
> **Created:** December 14, 2025

---

## Overview

This phase focuses on improving the user experience with app update management, installation history tracking, and persona backup/restore capabilities.

---

## Implementation Order (DO NOT REORDER)

Execute in this exact sequence. Each section must be completed before moving to the next.

---

## SECTION 1: Installation History Module
**Estimated Time:** 2-3 hours

### 1.1 Create InstallationHistory.psm1

- [ ] **1.1.1** Create new file `scripts/modules/InstallationHistory.psm1`
- [ ] **1.1.2** Add module header with synopsis and description
- [ ] **1.1.3** Define history JSON schema:
  ```json
  {
    "version": "1.0",
    "installations": [
      {
        "id": "guid",
        "timestamp": "ISO8601",
        "personaName": "string",
        "apps": [{ "name": "string", "wingetId": "string", "status": "string" }],
        "totalDuration": "timespan",
        "successful": 0,
        "failed": 0
      }
    ]
  }
  ```

### 1.2 Implement Core Functions

- [ ] **1.2.1** `Initialize-InstallationHistory` - Create/load history file
- [ ] **1.2.2** `Add-InstallationRecord` - Record new installation
- [ ] **1.2.3** `Get-InstallationHistory` - Query history with filters
- [ ] **1.2.4** `Export-InstallationHistory` - Export to CSV/JSON
- [ ] **1.2.5** `Clear-InstallationHistory` - Purge old records

### 1.3 Write Unit Tests

- [ ] **1.3.1** Create `tests/Unit/InstallationHistory.Tests.ps1`
- [ ] **1.3.2** Test `Initialize-InstallationHistory` creates file
- [ ] **1.3.3** Test `Add-InstallationRecord` adds entry
- [ ] **1.3.4** Test `Get-InstallationHistory` returns records
- [ ] **1.3.5** Test `Get-InstallationHistory` filters by date/persona
- [ ] **1.3.6** Test `Export-InstallationHistory` creates file
- [ ] **1.3.7** Run tests: `Invoke-Pester tests/Unit/InstallationHistory.Tests.ps1`

### 1.4 Integration

- [ ] **1.4.1** Add `InstallationHistory` to core modules in `Main.ps1`
- [ ] **1.4.2** Call `Add-InstallationRecord` after `Install-PersonaApps` completes
- [ ] **1.4.3** Add history path to `Settings.psd1` under Paths section
- [ ] **1.4.4** Run full test suite to verify no regressions

### 1.5 Commit Checkpoint

- [ ] **1.5.1** `git add -A`
- [ ] **1.5.2** `git commit -m "feat(history): Add InstallationHistory module with core functions"`

---

## SECTION 2: View Installation History Menu
**Estimated Time:** 1-2 hours

### 2.1 Add Menu Option

- [ ] **2.1.1** Add "View installation history" to `$menuActions` in `Main.ps1`
- [ ] **2.1.2** Create `Invoke-ViewHistory` function in `Main.ps1`

### 2.2 Implement History Display

- [ ] **2.2.1** Add `Show-InstallationHistory` function to `UIHelper.psm1`
- [ ] **2.2.2** Format output with columns: Date, Persona, Apps, Success/Failed
- [ ] **2.2.3** Add pagination for long history (10 items per page)
- [ ] **2.2.4** Add filter options: last 7 days, last 30 days, all

### 2.3 Write Tests

- [ ] **2.3.1** Add `Show-InstallationHistory` tests to `UIHelper.Tests.ps1`
- [ ] **2.3.2** Test display with empty history
- [ ] **2.3.3** Test display with multiple records
- [ ] **2.3.4** Run tests

### 2.4 Commit Checkpoint

- [ ] **2.4.1** `git add -A`
- [ ] **2.4.2** `git commit -m "feat(history): Add installation history menu and display"`

---

## SECTION 3: App Update Detection
**Estimated Time:** 2-3 hours

### 3.1 Create UpdateManager.psm1

- [ ] **3.1.1** Create new file `scripts/modules/UpdateManager.psm1`
- [ ] **3.1.2** Add module header

### 3.2 Implement Update Detection Functions

- [ ] **3.2.1** `Get-InstalledApps` - List apps from winget with versions
- [ ] **3.2.2** `Get-AvailableUpdates` - Check for updates via `winget upgrade`
- [ ] **3.2.3** `Get-PersonaUpdateStatus` - Check updates for persona apps only
- [ ] **3.2.4** `Format-UpdateList` - Format updates for display

### 3.3 Write Unit Tests

- [ ] **3.3.1** Create `tests/Unit/UpdateManager.Tests.ps1`
- [ ] **3.3.2** Test `Get-InstalledApps` returns list
- [ ] **3.3.3** Test `Get-AvailableUpdates` parses winget output
- [ ] **3.3.4** Test `Get-PersonaUpdateStatus` filters correctly
- [ ] **3.3.5** Run tests

### 3.4 Commit Checkpoint

- [ ] **3.4.1** `git add -A`
- [ ] **3.4.2** `git commit -m "feat(updates): Add UpdateManager module with detection functions"`

---

## SECTION 4: Batch Update Installation
**Estimated Time:** 2-3 hours

### 4.1 Implement Update Functions

- [ ] **4.1.1** `Update-App` - Update single app via winget
- [ ] **4.1.2** `Update-PersonaApps` - Batch update all persona apps
- [ ] **4.1.3** `Update-AllApps` - Update everything with available updates
- [ ] **4.1.4** Add progress tracking for batch updates

### 4.2 Add Menu Options

- [ ] **4.2.1** Add "Check for updates" to `$menuActions` in `Main.ps1`
- [ ] **4.2.2** Create `Invoke-CheckUpdates` function
- [ ] **4.2.3** Show available updates with option to install

### 4.3 Write Tests

- [ ] **4.3.1** Add update function tests to `UpdateManager.Tests.ps1`
- [ ] **4.3.2** Test `Update-App` with DryRun mode
- [ ] **4.3.3** Test `Update-PersonaApps` integration
- [ ] **4.3.4** Run tests

### 4.4 Integration

- [ ] **4.4.1** Add `UpdateManager` to optional modules in `Main.ps1`
- [ ] **4.4.2** Add `EnableUpdates` feature flag to `Settings.psd1`
- [ ] **4.4.3** Run full test suite

### 4.5 Commit Checkpoint

- [ ] **4.5.1** `git add -A`
- [ ] **4.5.2** `git commit -m "feat(updates): Add batch update installation and menu"`

---

## SECTION 5: Persona Backup/Restore
**Estimated Time:** 2-3 hours

### 5.1 Implement Backup Functions

- [ ] **5.1.1** Add `Export-PersonaBackup` to `PersonaManager.psm1`
  - Creates timestamped ZIP with persona JSON + metadata
- [ ] **5.1.2** Add `Import-PersonaBackup` to `PersonaManager.psm1`
  - Extracts and validates backup, handles conflicts
- [ ] **5.1.3** Add `Get-PersonaBackups` - List available backups

### 5.2 Add Menu Options

- [ ] **5.2.1** Add "Backup/Restore personas" to `$menuActions`
- [ ] **5.2.2** Create `Invoke-PersonaBackup` function with submenu:
  - Backup all personas
  - Backup single persona
  - Restore from backup
  - View backups

### 5.3 Write Tests

- [ ] **5.3.1** Add backup tests to `PersonaManager.Tests.ps1`
- [ ] **5.3.2** Test `Export-PersonaBackup` creates valid archive
- [ ] **5.3.3** Test `Import-PersonaBackup` restores correctly
- [ ] **5.3.4** Test conflict handling (overwrite prompt)
- [ ] **5.3.5** Run tests

### 5.4 Commit Checkpoint

- [ ] **5.4.1** `git add -A`
- [ ] **5.4.2** `git commit -m "feat(backup): Add persona backup and restore functionality"`

---

## SECTION 6: Installation Profiles
**Estimated Time:** 1-2 hours

### 6.1 Implement Profile Functions

- [ ] **6.1.1** Add `Save-InstallationProfile` to `PersonaManager.psm1`
  - Saves: selected optional apps, settings used, timestamp
- [ ] **6.1.2** Add `Get-InstallationProfile` - Load saved profile
- [ ] **6.1.3** Add `Remove-InstallationProfile` - Delete profile

### 6.2 Integration

- [ ] **6.2.1** Modify `Invoke-InstallPersona` to offer "Use saved profile?"
- [ ] **6.2.2** After installation, prompt "Save this configuration as profile?"
- [ ] **6.2.3** Store profiles in `data/profiles/<persona-name>.json`

### 6.3 Write Tests

- [ ] **6.3.1** Test `Save-InstallationProfile` creates file
- [ ] **6.3.2** Test `Get-InstallationProfile` loads correctly
- [ ] **6.3.3** Run tests

### 6.4 Commit Checkpoint

- [ ] **6.4.1** `git add -A`
- [ ] **6.4.2** `git commit -m "feat(profiles): Add installation profile save/load"`

---

## SECTION 7: Enhanced Visual Feedback
**Estimated Time:** 1 hour

### 7.1 Improve Console Output

- [ ] **7.1.1** Add `Get-StatusIcon` helper to `UIHelper.psm1`:
  - Success: `[OK]` (green)
  - Failed: `[X]` (red)
  - Warning: `[!]` (yellow)
  - Info: `[i]` (cyan)
  - Pending: `[.]` (gray)
- [ ] **7.1.2** Update `Show-InstallationResults` to use new icons
- [ ] **7.1.3** Update `Show-DependencyAnalysis` to use new icons
- [ ] **7.1.4** Add color configuration to `Settings.psd1` (for accessibility)

### 7.2 Commit Checkpoint

- [ ] **7.2.1** `git add -A`
- [ ] **7.2.2** `git commit -m "feat(ui): Enhance visual feedback with consistent status icons"`

---

## SECTION 8: Documentation & Finalization
**Estimated Time:** 1-2 hours

### 8.1 Update Documentation

- [ ] **8.1.1** Update `README.md` with new features
- [ ] **8.1.2** Add new features to `docs/CHANGELOG.md`
- [ ] **8.1.3** Update `Settings.psd1` comments for new options
- [ ] **8.1.4** Update `ROADMAP.md` to mark Phase 1 complete

### 8.2 Integration Testing

- [ ] **8.2.1** Run full test suite: `.\tests\Invoke-Tests.ps1 -TestType All`
- [ ] **8.2.2** Manual test: Install persona → Check history → Check updates
- [ ] **8.2.3** Manual test: Backup persona → Delete → Restore
- [ ] **8.2.4** Manual test: Save profile → Reinstall using profile

### 8.3 Version Bump

- [ ] **8.3.1** Update `$Version` in `Main.ps1` to `"1.5.0"`
- [ ] **8.3.2** Update version in module headers

### 8.4 Final Commit & Tag

- [ ] **8.4.1** `git add -A`
- [ ] **8.4.2** `git commit -m "release: v1.5.0 - User Experience Enhancements"`
- [ ] **8.4.3** `git tag -a v1.5.0 -m "v1.5.0 - Installation history, updates, backup/restore"`
- [ ] **8.4.4** `git push origin main --tags`

---

## Summary Checklist

| Section | Description | Status |
|---------|-------------|--------|
| 1 | Installation History Module | ⬜ Not Started |
| 2 | View History Menu | ⬜ Not Started |
| 3 | App Update Detection | ⬜ Not Started |
| 4 | Batch Update Installation | ⬜ Not Started |
| 5 | Persona Backup/Restore | ⬜ Not Started |
| 6 | Installation Profiles | ⬜ Not Started |
| 7 | Enhanced Visual Feedback | ⬜ Not Started |
| 8 | Documentation & Finalization | ⬜ Not Started |

---

## Files to Create

| File | Section |
|------|---------|
| `scripts/modules/InstallationHistory.psm1` | 1 |
| `scripts/modules/UpdateManager.psm1` | 3 |
| `tests/Unit/InstallationHistory.Tests.ps1` | 1 |
| `tests/Unit/UpdateManager.Tests.ps1` | 3 |
| `data/history/install-history.json` | 1 (auto-created) |
| `data/profiles/` | 6 (directory) |
| `data/backups/` | 5 (directory) |

---

## Files to Modify

| File | Sections |
|------|----------|
| `scripts/Main.ps1` | 1, 2, 4, 5, 6, 8 |
| `scripts/modules/UIHelper.psm1` | 2, 7 |
| `scripts/modules/PersonaManager.psm1` | 5, 6 |
| `scripts/config/Settings.psd1` | 1, 4, 7 |
| `tests/Unit/UIHelper.Tests.ps1` | 2 |
| `tests/Unit/PersonaManager.Tests.ps1` | 5, 6 |
| `README.md` | 8 |
| `docs/CHANGELOG.md` | 8 |
| `docs/ROADMAP.md` | 8 |

---

## Rollback Plan

If issues arise, revert to last stable commit:
```powershell
git log --oneline -10  # Find last stable commit
git revert HEAD~N      # Revert N commits
# OR
git reset --hard <commit-hash>  # Nuclear option
```

---

## Notes

- Execute sections in order (1 → 8)
- Commit after each section completes
- Run tests before and after each section
- Do not skip ahead or reorder tasks
- Mark checkboxes as completed: `- [x]`

---

*Start with Section 1.1.1 and proceed sequentially.*

