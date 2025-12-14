# Persona Installer v1.3.0 → v1.4.0 Improvement Initiative

## 🎯 MISSION

Transform Persona Installer from a functional prototype into a production-ready, maintainable PowerShell application by executing a systematic 6-phase improvement plan. Fix all critical bugs, modernize deprecated APIs, complete orphaned features, and establish a proper testing infrastructure.

---

## 📋 CONTEXT

**Project:** Persona Installer - A PowerShell-based Windows app installer using winget  
**Current State:** v1.3.0 - Functional but with critical bugs, deprecated APIs, and orphaned code  
**Target State:** v1.4.0 - Production-ready, fully tested, PSScriptAnalyzer-clean  
**Reference Document:** `docs/IMPROVEMENT-PLAN.md`

---

## 🚨 CRITICAL BUGS TO FIX FIRST

### Bug 1: `$input` Variable Collision
- **File:** `scripts/modules/UIHelper.psm1` line 86
- **Problem:** Uses `$input` as variable name, which shadows PowerShell's automatic variable
- **Fix:** Rename to `$userSelection`

### Bug 2: `$OriginalList` Undefined
- **File:** `scripts/modules/DependencyManager.psm1` lines 273-274
- **Problem:** References variable that doesn't exist in scope
- **Fix:** Add as parameter to `Show-DependencyAnalysis` function

### Bug 3: Menu Offset Logic
- **File:** `scripts/Main.ps1` lines 182-236
- **Problem:** Fragile offset-based switch statement for dynamic menu
- **Fix:** Refactor to use explicit action mapping with ordered hashtable

### Bug 4: Nested Function Scope
- **File:** `scripts/modules/DependencyManager.psm1` lines 98-99
- **Problem:** `$circularDeps` in nested function doesn't update parent scope properly
- **Fix:** Use `[ref]` or script-scope variable

---

## 📦 PHASES TO EXECUTE

### Phase 1: Critical Bug Fixes ⚡ (IMMEDIATE)
```
□ Fix $input collision in UIHelper.psm1
□ Fix $OriginalList in DependencyManager.psm1  
□ Refactor menu system in Main.ps1
□ Fix scope issue in DependencyManager.psm1
```

### Phase 2: API Modernization 🔄
```
□ Replace Get-WmiObject with Get-CimInstance (4 files)
□ Fix verb naming: Load-→Import-/Get-, Confirm-→Test-
□ Standardize null checks
□ Create CompatibilityHelper.psm1 for PS5/PS7
```

### Phase 3: Feature Completion 🔧
```
□ Integrate or remove EnhancedProgressManager.psm1
□ Implement enhanced catalog format or remove references
□ Wire up all Settings.psd1 options that claim to work
□ Complete dependency resolution with actual catalog data
```

### Phase 4: Code Quality ✨
```
□ Extract hard-coded values to configuration
□ Remove duplicate progress display code
□ Consistent error handling patterns
□ Add proper input validation
```

### Phase 5: Testing Infrastructure 🧪
```
□ Set up Pester test framework
□ Unit tests for each module (80%+ coverage)
□ Integration tests for main workflows
□ CI/CD pipeline with PSScriptAnalyzer
```

### Phase 6: Documentation & Polish 📝
```
□ Update README with accurate feature status
□ Clean up Settings.psd1 "future feature" items
□ Standardize console output (consistent colors, no random emoji)
□ Add inline comments for complex logic
```

---

## 🔧 TECHNICAL REQUIREMENTS

1. **PowerShell Compatibility:** Must work on both PS 5.1 and PS 7.x
2. **No Breaking Changes:** Existing personas and catalog must continue to work
3. **PSScriptAnalyzer Clean:** Zero errors, minimal warnings
4. **Approved Verbs Only:** Follow PowerShell naming conventions
5. **Incremental Commits:** One logical change per commit
6. **Test Before Commit:** Run validation script after each phase

---

## 📁 FILES TO MODIFY (Priority Order)

| Priority | File | Key Changes |
|----------|------|-------------|
| 🔴 CRITICAL | `scripts/modules/UIHelper.psm1` | Fix `$input`, update WMI |
| 🔴 CRITICAL | `scripts/modules/DependencyManager.psm1` | Fix `$OriginalList`, scope, WMI |
| 🔴 CRITICAL | `scripts/Main.ps1` | Refactor menu, fix naming |
| 🟡 HIGH | `scripts/modules/PersonaRecommendationEngine.psm1` | Update WMI, fix verbs |
| 🟡 HIGH | `scripts/modules/EnhancedProgressManager.psm1` | Integrate or remove |
| 🟢 MEDIUM | `scripts/modules/CatalogManager.psm1` | Verb naming |
| 🟢 MEDIUM | `scripts/modules/PersonaManager.psm1` | Verb naming |
| 🟢 MEDIUM | `scripts/modules/InstallEngine.psm1` | Progress integration |
| 🔵 LOW | `scripts/modules/Logger.psm1` | Minor optimizations |
| 🔵 LOW | `scripts/config/Settings.psd1` | Clean unused settings |

---

## ✅ SUCCESS CRITERIA

**Phase 1 Complete:**
- [ ] All modules import without error
- [ ] Menu works with all feature flag combinations
- [ ] Dependency analysis shows correct counts
- [ ] No PSScriptAnalyzer critical errors

**Final v1.4.0 Release:**
- [ ] PSScriptAnalyzer: 0 errors
- [ ] Pester tests: 80%+ coverage
- [ ] All features work as documented
- [ ] Clean, consistent UX

---

## 🚀 EXECUTION COMMAND

Start with Phase 1 Critical Bug Fixes. For each fix:
1. Read the current file state
2. Apply the fix with proper context
3. Verify no new linter errors introduced
4. Move to next fix

Begin now with `UIHelper.psm1` - the `$input` variable collision.

