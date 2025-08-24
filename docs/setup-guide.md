Persona Installer — Quick Setup Guide

This tool helps you set up a Windows PC in a few clicks. Pick a persona (e.g., Dev, Finance Pro, IT Pro, Cybersecurity), choose optional apps, and the script installs everything for you.

What you need

Windows 10 or 11

An internet connection

Administrator access on the PC

(Recommended) Latest App Installer / winget from Microsoft Store

If you don’t have winget, open the Microsoft Store and install App Installer. Most Windows 11 machines already have it.

1) Get the files
Option A: Download as ZIP (easiest)

Open the project page on GitHub.

Click the green Code button → Download ZIP.

Right-click the ZIP → Extract All… (remember where you put it).

Option B: Clone with Git (if you use Git)
git clone https://github.com/<your-username>/persona-installer.git

2) Run the installer

Open the folder you extracted/cloned.

Open the scripts folder.

Right-click an empty area → Open in Terminal (or open PowerShell and cd into the scripts folder).

Run these commands:

# Allow this PowerShell session to run the script
Set-ExecutionPolicy Bypass -Scope Process -Force

# Start the installer (Dry Run first so it doesn't install yet)
.\Main.ps1 -DryRun


You’ll see a menu. Pick 1) Install from persona and try one, like dev or it-pro. With -DryRun, nothing actually installs—it just shows what would happen.

If everything looks good, run it for real:

.\Main.ps1


If prompted, choose Yes to run as Administrator. This keeps installs smooth and silent.

3) How it works (in one minute)

Catalog: a big list of apps and their winget IDs (in data/catalog.json).

Personas: simple JSON files listing “base” apps and “optional” apps (in data/personas/).

UI: the script shows a menu, lets you pick a persona, and then choose optional apps (with a simple list—if available, a small selection window pops up).

4) Common tasks

Install from a persona
Menu → 1) Install from persona → choose a persona → select optional apps → confirm.

View all available apps
Menu → 5) View catalog (you can export to CSV, too).

Add a new app to the catalog
Menu → 4) Manage catalog (add package) → enter a friendly name and the exact winget ID.

Create or edit personas
Menu → 2) Create new persona or 3) Edit existing persona.
(No coding—just choose from the list of apps.)

5) Troubleshooting (quick fixes)

“Windows protected your PC” / script blocked
You already ran Set-ExecutionPolicy Bypass -Scope Process -Force — make sure you ran it in the same PowerShell window, then run the script again.

“winget not found”
Install App Installer from the Microsoft Store. Close and reopen PowerShell.

Window closes unexpectedly
Reopen the script. It now keeps a log and asks before closing. Check logs/session-YYYYMMDD-HHMMSS.txt for details.

Selection window doesn’t appear
That’s fine—there’s a text menu fallback. You can still pick options by number.

An app fails to install
The script continues with the rest. Check logs/<AppName>.log for the exact reason.
You can also try:

winget search "<app name>"
winget install --id Exact.ID.Here -e


If the ID changed, update it via the menu: 4) Manage catalog (add package).

6) Safety tips

Try Dry Run first:
.\Main.ps1 -DryRun shows everything without installing.

Use Windows Sandbox (optional)
On Windows Pro/Enterprise, enable Windows Sandbox and test the script in a throwaway VM. Close Sandbox to discard changes.

7) Where things are
persona-installer/
├─ scripts/
│  └─ Main.ps1              ← run this
├─ data/
│  ├─ catalog.json          ← apps & winget IDs
│  └─ personas/
│     ├─ dev.json
│     ├─ finance-pro.json
│     ├─ it-pro.json
│     └─ cybersec-pro.json
└─ logs/                    ← run & install logs

8) Need ideas for personas?

dev: Git, VS Code, GitHub Desktop/CLI, Node.js LTS, Python, Docker Desktop, .NET SDK (+ optional cloud CLIs, DB tools)

finance-pro: Chrome, Microsoft 365, Adobe Reader, Teams, Slack, Power BI (+ optional Tableau, Citrix)

it-pro: PowerShell 7, Notepad++, 7-Zip, Everything, Nmap, Wireshark, Rufus, Ventoy, PuTTY

cybersec-pro: Nmap, Wireshark, Burp Suite Community, OWASP ZAP, Ghidra, OpenSSL, Python, Git

That’s it!

If you can open PowerShell and press numbers, you can use this tool.
If you’re curious, the whole thing is just PowerShell + JSON—easy to customize.