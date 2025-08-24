# Persona Installer — Setup Guide

This guide shows you how to quickly set up and run the **Persona Installer** on Windows.  
No advanced skills required — just follow the steps.

---

## ✅ Requirements
- Windows 10 or 11
- PowerShell 5+ (PowerShell 7 recommended)
- [winget (App Installer)](https://learn.microsoft.com/en-us/windows/package-manager/winget/) from Microsoft Store

---

## 📦 Get the Files

### Option A: Download ZIP (easiest)
1. On GitHub, click the green **Code** button → **Download ZIP**
2. Extract it to a folder (e.g., `C:\Users\YourName\Downloads\persona-installer`)
3. Open the extracted folder

### Option B: Clone with Git
```powershell
git clone https://github.com/24Skater/persona-installer.git
cd persona-installer
```

---

## ▶️ Run the Installer

1. Open the **scripts** folder inside the repo.
2. Right-click inside the folder → **Open in Terminal**  
   (or open PowerShell manually and `cd` into `scripts/`).
3. Run the following commands:

```powershell
# Allow this PowerShell session to run the script
Set-ExecutionPolicy Bypass -Scope Process -Force

# Dry run (preview only — no installs)
.\Main.ps1 -DryRun

# Real install
.\Main.ps1
```

4. Choose a **persona** (e.g., `dev`, `finance-pro`, `it-pro`, `cybersec-pro`, `personal`, `testbench`).
5. Select optional apps when prompted.
6. Confirm → sit back while it installs!

> Run as **Administrator** when prompted. This allows silent installs.

---

## 🧑‍💻 How It Works
- **Catalog**: all apps + winget IDs (`data/catalog.json`)
- **Personas**: profiles listing base + optional apps (`data/personas/*.json`)
- **Menu**: run `Main.ps1` to:
  - Install from a persona
  - Create a new persona
  - Edit existing personas
  - Add apps to the catalog
  - View/export the catalog

---

## 🧪 Testing Safely
- Use `.\Main.ps1 -DryRun` to preview.
- Try inside **Windows Sandbox** (Pro/Enterprise editions).  
  Everything resets when you close it.

---

## 🛠️ Troubleshooting

- **Script blocked** → Run `Set-ExecutionPolicy Bypass -Scope Process -Force` in the same window.  
- **`winget` not found** → Install *App Installer* from Microsoft Store, then re-run.  
- **App failed to install** → Check `logs/<AppName>.log`.  
- **Window closed unexpectedly** → Check transcript logs in `logs/session-YYYYMMDD-HHMMSS.txt`.  
- **No GUI for app selection** → That’s fine. A text menu appears instead.  

---

## 📂 Repo Structure
```
persona-installer/
├─ scripts/                # Run Main.ps1 here
├─ data/
│  ├─ catalog.json         # App catalog (name → winget ID)
│  └─ personas/            # Personas (JSON files)
├─ docs/
│  └─ setup-guide.md       # This guide
├─ logs/                   # Logs (auto-created)
├─ README.md
└─ LICENSE
```

---

## 🎯 Example Personas

- **Dev** → VS Code, GitHub CLI, Node.js, Docker, .NET SDK (+ optional Postman, DBeaver, cloud CLIs)  
- **Finance Pro** → Chrome, Microsoft 365, Power BI, Slack/Teams (+ optional Tableau, Citrix)  
- **IT Pro** → PowerShell 7, Notepad++, 7-Zip, Wireshark, Nmap, Rufus (+ optional Sysinternals, VLC)  
- **Cybersecurity Pro** → Wireshark, Burp Suite, ZAP, Ghidra, OpenSSL, Git (+ optional Docker, Node.js)  
- **Personal** → Git, Chrome, Notepad++, WhatsApp, Zoom (+ optional Steam, Office, Adobe CC)  
- **Testbench** → PowerShell 7, Python 3, Git

---

## 📝 Logs
- Per-app logs → `logs/<AppName>.log`  
- Full session transcript → `logs/session-YYYYMMDD-HHMMSS.txt`

---

## 📜 License
MIT — free to use, modify, and share.
