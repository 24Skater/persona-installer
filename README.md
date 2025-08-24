# Persona Installer 🎛️

A PowerShell-based **interactive installer** for Windows post-build setup.  
It lets you choose a **persona** (e.g., personal, testbench), installs base apps, then prompts you for optional apps — all automated with **winget**.

---

## ✨ Features
- **Persona-based installs**  
  Define multiple personas (`personal`, `testbench`, etc.) with their own base apps.  
- **Optional app selection**  
  Pick optional apps via GUI (Out-GridView) or console menu.  
- **Progress & logging**  
  See install progress and review logs in `.\logs`.  
- **Idempotent installs**  
  Skips apps already installed.  

---

## 🚀 Quick Start

1. Open **PowerShell as Administrator**.
2. Run the script directly from GitHub:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   iwr https://raw.githubusercontent.com/<your-username>/persona-installer/main/PersonaInstaller.ps1 -OutFile PersonaInstaller.ps1
   .\PersonaInstaller.ps1
Or clone the repo:

powershell
Copy
Edit
git clone https://github.com/<your-username>/persona-installer.git
cd persona-installer
.\PersonaInstaller.ps1
🧑‍💻 Personas
Personal
Base apps:

Git

VS Code

GitHub Desktop

Chrome

Notepad++

PowerShell 7

VLC

WhatsApp

Zoom

Optional apps:

Steam

Epic Games Launcher

Ubisoft Connect

WorshipTools Presenter

Microsoft 365 (Office)

Adobe Creative Cloud

Python 3 (latest)

Testbench
Base apps:

PowerShell 7

Python 3 (latest)

Git

⚙️ Customization
Edit PersonaInstaller.ps1 to add or remove personas.

Modify $Catalog to map display names → winget IDs.

Add more personas (e.g., gaming, workstation, lab).

📦 Requirements
Windows 10/11

PowerShell 5+ (PowerShell 7 recommended)

winget (App Installer from Microsoft Store)