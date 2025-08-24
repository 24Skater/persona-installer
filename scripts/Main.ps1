<# 
Main.ps1 - Modular UI & logic for persona-based installs
- Loads personas from data\personas\*.json
- Loads catalog from data\catalog.json
- Menu: install, create persona, edit persona, view catalog, manage catalog, exit
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ---------------- Paths ----------------
$Root = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path $Root
$DataDir = Join-Path $RepoRoot "data"
$PersonaDir = Join-Path $DataDir "personas"
$CatalogPath = Join-Path $DataDir "catalog.json"
$LogsDir = Join-Path $RepoRoot "logs"

# --- Transcript logging ---
try {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $TranscriptPath = Join-Path $LogsDir ("session-{0}.txt" -f $ts)
    Start-Transcript -Path $TranscriptPath -Force | Out-Null
} catch {
    Write-Host "Failed to start transcript: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---------------- Utils ----------------
function Prompt-Exit {
    try {
        Write-Host ""
        Read-Host "Press Enter to close this window"
    } catch {}
    try { Stop-Transcript | Out-Null } catch {}
}

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "This script should run as Administrator for unattended installs." -ForegroundColor Yellow
        $resp = Read-Host "Re-launch elevated now? (Y/N)"
        if ($resp -match '^(y|yes)$') {
            $psi = @{
                FilePath = "powershell.exe"
                ArgumentList = @("-NoExit","-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
                Verb = "RunAs"
                WindowStyle = "Normal"
            }
            if ($DryRun) { $psi.ArgumentList += "-DryRun" }
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
    $json = Get-Content $CatalogPath -Raw
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return ConvertFrom-Json -InputObject $json -AsHashtable
        } else {
            $obj = $json | ConvertFrom-Json
            $ht = @{}
            foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
            return $ht
        }
    } catch {
        throw "Failed to parse catalog: $($_.Exception.Message)"
    }
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
    if ($hasOGV -and $Options -and $Options.Count -gt 0) {
        try { $selected = $Options | Out-GridView -PassThru -Title $Title } catch { $hasOGV=$false }
    }
    if (-not $hasOGV -and $Options -and $Options.Count -gt 0) {
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
    if ($DryRun) {
        Write-Host "$status : would install ($WingetId)" -ForegroundColor Yellow
        return
    }
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

function Show-Catalog([hashtable]$Catalog) {
    Write-Host "`nCatalog entries:" -ForegroundColor Cyan
    $items = @()
    foreach ($k in ($Catalog.Keys | Sort-Object)) {
        $items += [pscustomobject]@{ Name = $k; WingetId = $Catalog[$k] }
    }

    $hasOGV = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($hasOGV) {
        try { $items | Out-GridView -Title "Catalog (Name ↔ WingetId)" } catch { $hasOGV = $false }
    }
    if (-not $hasOGV) {
        $widthName = ($items | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
        if (-not $widthName) { $widthName = 4 }
        ("{0}  {1}" -f ("Name".PadRight($widthName)), "WingetId") | Write-Host
        ("-" * ($widthName + 2 + 32)) | Write-Host
        foreach ($it in $items) {
            ("{0}  {1}" -f ($it.Name.PadRight($widthName)), $it.WingetId) | Write-Host
        }
    }

    $export = Read-Host "Export to CSV? (Y/N)"
    if ($export -match '^(y|yes)$') {
        $outPath = Join-Path $DataDir "catalog-export.csv"
        $items | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
        Write-Host "Exported to $([IO.Path]::GetFullPath($outPath))" -ForegroundColor Green
    }
}

# ---------------- Main ----------------
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
        Write-Host " 5) View catalog"
        Write-Host " 6) Exit"
        $choice = Read-Host "Choose an option"
        switch ($choice) {
            '1' {
                $persons = Load-Personas
                if ($persons.Count -eq 0) { Write-Host "No personas found in $PersonaDir"; continue }
                Write-Host "`nSelect persona:" -ForegroundColor Cyan
                for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
                $sel = Read-Host "Number"
                if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) {
                    $persona = $persons[[int]$sel-1]

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
                    if ($go -notmatch '^(y|yes)$') { Write-Host "Cancelled."; continue }

                    $queue = @($persona.base + $selectedOpt)
                    $total = $queue.Count
                    $i = 0
                    foreach ($app in $queue) {
                        $i++
                        if (-not $catalog.ContainsKey($app)) {
                            Write-Host "[SKIP] '$app' not in catalog. Add it via 'Manage catalog'." -ForegroundColor Yellow
                            continue
                        }
                        Install-One -DisplayName $app -WingetId $catalog[$app] -Index $i -Total $total
                    }
                    Write-Progress -Activity "Installing apps" -Completed
                    Write-Host "`nDone. Logs in $LogsDir" -ForegroundColor Cyan

                } else { Write-Host "Invalid selection." }
            }
            '2' {
                # Create new persona
                $pname = Read-Host "New persona name (alphanumeric and dashes)"
                if (-not $pname) { Write-Host "Cancelled."; continue }
                $persons = Load-Personas
                $source = $null
                if ($persons.Count -gt 0) {
                    Write-Host "Clone from existing? (Enter for none)"
                    for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
                    $sel = Read-Host "Number to clone, or Enter"
                    if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) { $source = $persons[[int]$sel-1] }
                }
                if ($source) { $persona = [ordered]@{ name=$pname; base=@($source.base); optional=@($source.optional) } }
                else { $persona = [ordered]@{ name=$pname; base=@(); optional=@() } }

                $options = @($catalog.Keys | Sort-Object)
                $chosenBase = Out-SelectableList -Options $options -Title "Select BASE apps for '$pname'"
                $persona.base = @($chosenBase)
                $chosenOpt = Out-SelectableList -Options $options -Title "Select OPTIONAL apps for '$pname'"
                $persona.optional = @($chosenOpt)

                $path = Save-Persona ($persona | ConvertTo-Json | ConvertFrom-Json)
                Write-Host "Saved persona to $path" -ForegroundColor Green
            }
            '3' {
                # Edit existing persona
                $persons = Load-Personas
                if ($persons.Count -eq 0) { Write-Host "No personas found."; continue }
                Write-Host "`nSelect persona to edit:" -ForegroundColor Cyan
                for ($i=0;$i -lt $persons.Count;$i++){ Write-Host (" [{0}] {1}" -f ($i+1), $persons[$i].name) }
                $sel = Read-Host "Number"
                if ($sel -and $sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $persons.Count) {
                    $persona = $persons[[int]$sel-1]
                    $options = @($catalog.Keys | Sort-Object)
                    $chosenBase = Out-SelectableList -Options $options -Title "Select BASE apps"
                    if ($chosenBase.Count -gt 0) { $persona.base = @($chosenBase) }
                    $chosenOpt = Out-SelectableList -Options $options -Title "Select OPTIONAL apps"
                    if ($chosenOpt.Count -gt 0) { $persona.optional = @($chosenOpt) }
                    $path = Save-Persona ($persona | ConvertTo-Json | ConvertFrom-Json)
                    Write-Host "Saved updates to $path" -ForegroundColor Green
                } else { Write-Host "Invalid selection." }
            }
            '4' {
                # Manage catalog (add package)
                Write-Host "`nAdd a package to catalog" -ForegroundColor Cyan
                $name = Read-Host "Display name (e.g., 'Node.js LTS')"
                $id   = Read-Host "winget ID (exact, e.g., 'OpenJS.NodeJS.LTS')"
                if (-not $name -or -not $id) { Write-Host "Cancelled."; continue }
                $catalog[$name] = $id
                Save-Catalog $catalog
                Write-Host "Added: $name -> $id"
            }
            '5' { Show-Catalog -Catalog $catalog }
            '6' { Prompt-Exit; exit }
            default { Write-Host "Invalid option." }
        }
    }

} catch {
    Write-Progress -Activity "Installing apps" -Completed
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Prompt-Exit
    exit 1
}

# Normal end (should not reach here due to exit in menu)
