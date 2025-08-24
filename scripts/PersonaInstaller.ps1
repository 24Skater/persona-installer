<# 
PersonaInstaller.ps1
Author: ChatGPT for Emerson
Purpose: Interactive, persona-driven post-install automation using winget.
Usage: 
  1) Right-click > Run with PowerShell (or run in an elevated PowerShell console)
  2) Follow prompts to select a persona and optional apps
Notes:
  - Requires Windows 10/11 with winget (App Installer) available.
  - Designed to be edited easily: add/edit personas and package IDs below.
#>

[CmdletBinding()]
param(
    [ValidateSet("personal","testbench")]
    [string]$Persona
)

# -------------------------- CONFIG: Personas & Packages --------------------------
# DisplayName => Winget ID (exact)
$Catalog = @{
    "Git"                       = "Git.Git"
    "VS Code"                   = "Microsoft.VisualStudioCode"
    "GitHub Desktop"            = "GitHub.GitHubDesktop"
    "Google Chrome"             = "Google.Chrome"
    "Notepad++"                 = "Notepad++.Notepad++"
    "PowerShell 7"              = "Microsoft.PowerShell"
    "VLC"                       = "VideoLAN.VLC"
    "WhatsApp"                  = "WhatsApp.WhatsApp"
    "Zoom"                      = "Zoom.Zoom"
    "Steam"                     = "Valve.Steam"
    "Epic Games Launcher"       = "EpicGames.EpicGamesLauncher"
    "Ubisoft Connect"           = "Ubisoft.Connect"
    "WorshipTools Presenter"    = "WorshipTools.Presenter"
    "Microsoft 365 (Office)"    = "Microsoft.Office"
    "Adobe Creative Cloud"      = "Adobe.CreativeCloud"
    "Python 3 (latest)"         = "Python.Python.3"
}

$Personas = @{
    personal = @{
        Base = @(
            "Git",
            "VS Code",
            "GitHub Desktop",
            "Google Chrome",
            "Notepad++",
            "PowerShell 7",
            "VLC",
            "WhatsApp",
            "Zoom"
        )
        Optional = @(
            "Steam",
            "Epic Games Launcher",
            "Ubisoft Connect",
            "WorshipTools Presenter",
            "Microsoft 365 (Office)",
            "Adobe Creative Cloud",
            "Python 3 (latest)"
        )
    }
    testbench = @{
        Base = @(
            "PowerShell 7",
            "Python 3 (latest)",
            "Git"
        )
        Optional = @() # none for now, add as needed
    }
}

# -------------------------- Helpers --------------------------
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "This script needs to run as Administrator for unattended installs." -ForegroundColor Yellow
        $resp = Read-Host "Re-launch elevated now? (Y/N)"
        if ($resp -match '^(y|yes)$') {
            $psi = @{
                FilePath = "powershell.exe"
                ArgumentList = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
                Verb = "RunAs"
                WindowStyle = "Normal"
            }
            if ($Persona) { $psi.ArgumentList += @("-Persona", $Persona) }
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
        Write-Host "Install from Microsoft Store: 'App Installer' (a.k.a. winget), then re-run this script." -ForegroundColor Yellow
        throw "winget missing"
    }
}

function Choose-Persona {
    param([string]$DefaultPersona)
    $keys = $Personas.Keys
    if ($DefaultPersona -and $Personas.ContainsKey($DefaultPersona)) { return $DefaultPersona }
    Write-Host ""
    Write-Host "Select a persona:" -ForegroundColor Cyan
    $i = 1
    $map = @{}
    foreach ($k in $keys) {
        Write-Host " [$i] $k"
        $map[$i] = $k
        $i++
    }
    $sel = Read-Host "Enter number"
    if ($sel -as [int] -and $map.ContainsKey([int]$sel)) { return $map[[int]$sel] }
    throw "Invalid selection."
}

function Out-SelectableList {
    <#
      Shows a selectable UI for optional apps if Out-GridView is available.
      Falls back to console comma-separated input.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Options,
        [string]$Title = "Select optional apps (Ctrl+Click to multi-select)"
    )
    $selected = @()
    $hasOGV = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($hasOGV) {
        try {
            $selected = $Options | Out-GridView -PassThru -Title $Title
        } catch {
            $hasOGV = $false
        }
    }
    if (-not $hasOGV) {
        Write-Host ""
        Write-Host $Title -ForegroundColor Cyan
        for ($i=0; $i -lt $Options.Count; $i++) {
            Write-Host (" [{0}] {1}" -f ($i+1), $Options[$i])
        }
        $raw = Read-Host "Enter numbers separated by commas (or press Enter for none)"
        if ($raw) {
            $idx = $raw -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            foreach ($n in $idx) {
                if ($n -ge 1 -and $n -le $Options.Count) { $selected += $Options[$n-1] }
            }
        }
    }
    return ,$selected
}

function Test-Installed {
    param([string]$WingetId)
    # Quick check using winget list exact ID
    $res = winget list --id $WingetId -e --disable-interactivity 2>$null
    return ($LASTEXITCODE -eq 0 -and $res -match $WingetId)
}

function Install-Package {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$WingetId,
        [int]$Index,
        [int]$Total
    )
    $status = "[{0}/{1}] {2}" -f $Index, $Total, $DisplayName
    if (Test-Installed -WingetId $WingetId) {
        Write-Host "$status : already installed." -ForegroundColor DarkGray
        return
    }
    Write-Progress -Activity "Installing apps" -Status "$status" -PercentComplete ([int](($Index / $Total) * 100))
    $logDir = "$PSScriptRoot\logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $log = Join-Path $logDir ("{0}.log" -f ($DisplayName -replace '[^\w\-\.]','_'))

    Write-Host "$status : installing ($WingetId)..." -ForegroundColor Green
    $args = @(
        "install","--id",$WingetId,"-e",
        "--accept-source-agreements","--accept-package-agreements",
        "--silent"
    )
    # Try without --silent if it fails (some installers ignore silent flags)
    & winget @args *>&1 | Tee-Object -FilePath $log -Append

    if (-not (Test-Installed -WingetId $WingetId)) {
        Write-Host " -> Silent install may have failed or requires interaction. Retrying without --silent..." -ForegroundColor Yellow
        $args = @("install","--id",$WingetId,"-e","--accept-source-agreements","--accept-package-agreements")
        & winget @args *>&1 | Tee-Object -FilePath $log -Append
    }

    if (Test-Installed -WingetId $WingetId)) {
        Write-Host " -> Installed." -ForegroundColor Green
    } else {
        Write-Host " -> FAILED to confirm installation. Check log: $log" -ForegroundColor Red
    }
}

# -------------------------- Main --------------------------
try {
    Assert-Admin
    Assert-Winget

    $chosenPersona = Choose-Persona -DefaultPersona $Persona

    $base = @($Personas[$chosenPersona].Base)
    $optional = @($Personas[$chosenPersona].Optional)

    Write-Host ""
    Write-Host "Persona: $chosenPersona" -ForegroundColor Cyan
    Write-Host "Base apps:" -ForegroundColor Cyan
    $base | ForEach-Object { Write-Host " - $_" }
    if ($optional.Count -gt 0) {
        Write-Host "Optional apps available:" -ForegroundColor Cyan
        $optional | ForEach-Object { Write-Host " - $_" }
    }

    # Pick optional
    $selectedOptional = @()
    if ($optional.Count -gt 0) {
        $selectedOptional = Out-SelectableList -Options $optional -Title "Select optional apps for '$chosenPersona'"
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host " Base:"
    $base | ForEach-Object { Write-Host "  - $_" }
    if ($selectedOptional.Count -gt 0) {
        Write-Host " Optional:"
        $selectedOptional | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host " Optional: (none)"
    }

    $go = Read-Host "Proceed with installation? (Y/N)"
    if ($go -notmatch '^(y|yes)$') { throw "User cancelled." }

    $queue = @($base + $selectedOptional)
    $total = $queue.Count
    $i = 0
    foreach ($app in $queue) {
        $i++
        if (-not $Catalog.ContainsKey($app)) {
            Write-Host "[SKIP] '$app' is not mapped in Catalog. Add it to `$Catalog." -ForegroundColor Yellow
            continue
        }
        $id = $Catalog[$app]
        Install-Package -DisplayName $app -WingetId $id -Index $i -Total $total
    }

    Write-Progress -Activity "Installing apps" -Completed
    Write-Host ""
    Write-Host "All done. Check logs folder for installer output: $PSScriptRoot\logs" -ForegroundColor Cyan

} catch {
    Write-Progress -Activity "Installing apps" -Completed
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
