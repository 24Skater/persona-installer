<# 
Main.ps1 - Modular UI & logic for persona-based installs
- Loads personas from data\personas\*.json
- Loads catalog from data\catalog.json
- Lets users install, create, or edit personas
- Runs installs with progress + logs via winget
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ---------------- Paths ----------------
$Root = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path $Root
$DataDir = Join-Path $RepoRoot "data"
$PersonaDir = Join-Path $DataDir "personas"
$CatalogPath = Join-Path $DataDir "catalog.json"
$LogsDir = Join-Path $RepoRoot "logs"

# ---------------- Utils ----------------
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "This script should run as Administrator for unattended installs." -ForegroundColor Yellow
        $resp = Read-Host "Re-launch elevated now? (Y/N)"
        if ($resp -match '^(y|yes)$') {
            $psi = @{
                FilePath = "powershell.exe"
                ArgumentList = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
                Verb = "RunAs"
                WindowStyle = "Normal"
            }
            Start-Process @psi
            exit
        } else {
            Write-Host "Continuing without elevation. Some packages may prompt or fail." -ForegroundColor Yellow
        }
    }
}

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget (App Installer) not found." -ForegroundColor Red
        Write-Host "Install from Microsoft Store: 'App Installer', then re-run." -ForegroundColor Yellow
        throw "winget missing"
    }
}

function Load-Catalog {
    if (-not (Test-Path $CatalogPath)) { throw "Catalog not found at $CatalogPath" }
    return Get-Content $CatalogPath -Raw | ConvertFrom-Json
}
function Save-Catalog($cat) { ($cat | ConvertTo-Json -Depth 5) | Set-Content -Path $CatalogPath -Encoding UTF8 }

function Load-Personas {
    if (-not (Test-Path $PersonaDir)) { New-Item -ItemType Directory -Path $PersonaDir -Force | Out-Null }
    $files = Get-ChildItem $PersonaDir -Filter *.json -File
    $persons = @()
    foreach ($f in $files) {
        $obj = Get-Content $f.FullName -Raw | ConvertFrom-Json
        if ($obj.name) { $persons += $obj }
    }
    return $persons
}
function Save-Persona($persona) {
    if (-not $persona.name) { throw "Persona requires 'name'." }
    $path = Join-Path $PersonaDir ("{0}.json" -f $persona.name)
    ($persona | ConvertTo-Json -Depth 5) | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Out-SelectableList {
    param([string[]]$Options,[string]$Title="Select items")
    $selected = @()
    $hasOGV = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($hasOGV -and $Options.Count -gt 0) {
        try { $selected = $Options | Out-GridView -PassThru -Title $Title } catch { $hasOGV=$false }
    }
    if (-not $hasOGV -and $Options.Count -gt 0) {
        Write-Host "`n$Title" -ForegroundColor Cyan
        for ($i=0;$i -lt $Options.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $Options[$i]) }
        $raw = Read-Host "Enter numbers separated by commas (or Enter for none)"
        if ($raw) {
            $idx = $raw -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            foreach ($n in $idx) { if ($n -ge 1 -and $n -le $Options.Count) { $selected += $Options[$n-1] } }
        }
    }
    return ,$selected
}

function Test-Installed([string]$WingetId) {
    $res = winget list --id $WingetId -e --disable-interactivity 2>$null
    return ($LASTEXITCODE -eq 0 -and $res -match [Regex]::Escape($WingetId))
}

function Install-One([string]$DisplayName,[string]$WingetId,[int]$Index,[int]$Total) {
    $status = "[{0}/{1}] {2}" -f $Index, $Total, $DisplayName
    if (Test-Installed $WingetId) {
        Write-Host "$status : already installed." -ForegroundColor DarkGray
        return
    }
    Write-Progress -Activity "Installing apps" -Status "$status" -PercentComplete ([int](($Index/$Total)*100))
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    $log = Join-Path $LogsDir ("{0}.log" -f ($DisplayName -replace '[^\w\-\.]','_'))
    Write-Host "$status : installing ($WingetId)..." -ForegroundColor Green
    $args = @("install","--id",$WingetId,"-e","--accept-source-agreements","--accept-package-agreements","--silent")
    & winget @args *>&1 | Tee-Object -FilePath $log -Append
    if (-not (Test-Installed $WingetId)) {
        Write-Host " -> Retrying without --silent..." -ForegroundColor Yellow
        $args = @("install","--id",$WingetId,"-e","--accept-source-agreements","--accept-package-agreements")
        & winget @args *>&1 | Tee-Object -FilePath $log -Append
    }
    if (Test-Installed $WingetId) { Write-Host " -> Installed." -ForegroundColor Green }
    else { Write-Host " -> FAILED. See log: $log" -ForegroundColor Red }
}

# -------- Persona editing --------
function Add-To-Catalog([hashtable]$Catalog) {
    Write-Host "`nAdd a package to catalog" -ForegroundColor Cyan
    $name = Read-Host "Display name (e.g., 'Node.js LTS')"
    $id   = Read-Host "winget ID (exact, e.g., 'OpenJS.NodeJS.LTS')"
    if (-not $name -or -not $id) { Write-Host "Cancelled."; return $Catalog }
    $Catalog[$name] = $id
    Save-Catalog $Catalog
    Write-Host "Added: $name -> $id"
    return $Catalog
}

function Create-Persona([hashtable]$Catalog) {
    $pname = Read-Host "New persona name (alphanumeric and dashes)"
    if (-not $pname) { Write-Host "Cancelled."; return $null }
    $source = $null
    $persons = Load-Personas
    if ($persons.Count -gt 0) {
        Write-Host "Clone from existing? (Enter for none)"
        for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
        $sel = Read-Host "Number to clone, or Enter"
        if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) { $source = $persons[[int]$sel-1] }
    }
    if ($source) { $persona = [ordered]@{ name=$pname; base=@($source.base); optional=@($source.optional) } }
    else { $persona = [ordered]@{ name=$pname; base=@(); optional=@() } }

    # Choose base
    $options = @($Catalog.Keys | Sort-Object)
    $chosenBase = Out-SelectableList -Options $options -Title "Select BASE apps for '$pname'"
    $persona.base = @($chosenBase)

    # Choose optional
    $chosenOpt = Out-SelectableList -Options $options -Title "Select OPTIONAL apps for '$pname'"
    $persona.optional = @($chosenOpt)

    $path = Save-Persona ($persona | ConvertTo-Json | ConvertFrom-Json) # normalize
    Write-Host "Saved persona to $path" -ForegroundColor Green
    return $persona
}

function Edit-Persona([pscustomobject]$persona,[hashtable]$Catalog) {
    $currentBase = @($persona.base)
    $currentOpt  = @($persona.optional)
    $options = @($Catalog.Keys | Sort-Object)

    Write-Host "`nEditing persona '$($persona.name)'" -ForegroundColor Cyan
    $chosenBase = Out-SelectableList -Options $options -Title "Select BASE apps"
    if ($chosenBase.Count -gt 0) { $currentBase = $chosenBase }
    $chosenOpt = Out-SelectableList -Options $options -Title "Select OPTIONAL apps"
    if ($chosenOpt.Count -gt 0) { $currentOpt = $chosenOpt }

    $persona.base = @($currentBase)
    $persona.optional = @($currentOpt)
    $path = Save-Persona ($persona | ConvertTo-Json | ConvertFrom-Json)
    Write-Host "Saved updates to $path" -ForegroundColor Green
    return $persona
}

# -------- Install flow --------
function Run-Install([pscustomobject]$persona,[hashtable]$Catalog) {
    Write-Host "`nPersona: $($persona.name)" -ForegroundColor Cyan
    Write-Host "Base apps:" -ForegroundColor Cyan
    $persona.base | ForEach-Object { Write-Host " - $_" }
    if ($persona.optional.Count -gt 0) {
        Write-Host "Optional apps available:" -ForegroundColor Cyan
        $persona.optional | ForEach-Object { Write-Host " - $_" }
    }

    $selectedOpt = @()
    if ($persona.optional.Count -gt 0) {
        $selectedOpt = Out-SelectableList -Options $persona.optional -Title "Select optional apps for '$($persona.name)'"
    }

    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host " Base:"; $persona.base | ForEach-Object { Write-Host "  - $_" }
    if ($selectedOpt.Count -gt 0) { Write-Host " Optional:"; $selectedOpt | ForEach-Object { Write-Host "  - $_" } }
    else { Write-Host " Optional: (none)" }

    $go = Read-Host "Proceed with installation? (Y/N)"
    if ($go -notmatch '^(y|yes)$') { Write-Host "Cancelled."; return }

    $queue = @($persona.base + $selectedOpt)
    $total = $queue.Count
    $i = 0
    foreach ($app in $queue) {
        $i++
        if (-not $Catalog.ContainsKey($app)) {
            Write-Host "[SKIP] '$app' not in catalog. Add it via 'Manage catalog'." -ForegroundColor Yellow
            continue
        }
        Install-One -DisplayName $app -WingetId $Catalog[$app] -Index $i -Total $total
    }
    Write-Progress -Activity "Installing apps" -Completed
    Write-Host "`nDone. Logs in $LogsDir" -ForegroundColor Cyan
}

# ---------------- Main Menu ----------------
try {
    Assert-Admin
    Assert-Winget
    $catalog = Load-Catalog
    if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

    while ($true) {
        Write-Host "`n=== Persona Installer ===" -ForegroundColor Green
        Write-Host " 1) Install from persona"
        Write-Host " 2) Create new persona"
        Write-Host " 3) Edit existing persona"
        Write-Host " 4) Manage catalog (add package)"
        Write-Host " 5) Exit"
        $choice = Read-Host "Choose an option"
        switch ($choice) {
            '1' {
                $persons = Load-Personas
                if ($persons.Count -eq 0) { Write-Host "No personas found in $PersonaDir"; break }
                Write-Host "`nSelect persona:" -ForegroundColor Cyan
                for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
                $sel = Read-Host "Number"
                if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) {
                    Run-Install -persona $persons[[int]$sel-1] -Catalog $catalog
                } else { Write-Host "Invalid selection." }
            }
            '2' { $newp = Create-Persona -Catalog $catalog }
            '3' {
                $persons = Load-Personas
                if ($persons.Count -eq 0) { Write-Host "No personas found."; break }
                Write-Host "`nSelect persona to edit:" -ForegroundColor Cyan
                for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
                $sel = Read-Host "Number"
                if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) {
                    $edited = Edit-Persona -persona $persons[[int]$sel-1] -Catalog $catalog
                } else { Write-Host "Invalid selection." }
            }
            '4' { $catalog = Add-To-Catalog -Catalog $catalog }
            '5' { break }
            default { Write-Host "Invalid option." }
        }
    }

} catch {
    Write-Progress -Activity "Installing apps" -Completed
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
