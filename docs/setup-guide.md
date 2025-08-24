# Setup Guide

## Prerequisites
- Windows 10/11
- PowerShell 5+ (PowerShell 7 recommended)
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) installed

## Steps
1. Clone the repo:
   ```powershell
   git clone https://github.com/<your-username>/persona-installer.git
   cd persona-installer\scripts
Run the installer:

powershell
Copy
Edit
Set-ExecutionPolicy Bypass -Scope Process -Force
.\PersonaInstaller.ps1
Select your persona and optional apps.

Logs will be saved in ..\logs\.

yaml
Copy
Edit

---

⚡ Next Steps:  
- Create the folders (`mkdir scripts docs logs`) in your cloned repo.  
- Move `PersonaInstaller.ps1` into `scripts/`.  
- Commit + push.  

```powershell
git add .
git commit -m "Restructure repo with scripts/, docs/, and logs/"
git push