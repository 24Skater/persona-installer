# Troubleshooting

Common problems and fixes when using **Persona Installer**.

---

## ❌ Script blocked / cannot run

**Symptom:**  
```
File C:\...\Main.ps1 cannot be loaded because running scripts is disabled on this system.
```

**Fix:**  
Run this in the same PowerShell window before starting the script:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

---

## ❌ `winget` not recognized

**Symptom:**  
```
winget : The term 'winget' is not recognized...
```

**Fix:**  
Install **App Installer** from the Microsoft Store.  
1. Open the Microsoft Store  
2. Search for **App Installer**  
3. Install/Update it  
4. Restart PowerShell

---

## ❌ Window closes immediately

**Symptom:**  
The PowerShell window disappears after running the script.

**Fix:**  
- Make sure you ran the script in **Administrator mode**.  
- Logs are saved in `logs/session-YYYYMMDD-HHMMSS.txt`. Check this file to see the error.  

---

## ❌ App fails to install

**Symptom:**  
One app doesn’t install, but the script continues.

**Fix:**  
1. Check its log in `logs/<AppName>.log`  
2. Run manually:  
   ```powershell
   winget install --id Exact.Winget.ID -e
   ```
3. If the ID changed, update it in `data/catalog.json` or use the menu:  
   - `4) Manage catalog (add package)`

---

## ❌ No selection window for optional apps

**Symptom:**  
The GUI selection (Out-GridView) doesn’t appear.

**Fix:**  
- That’s normal if Out-GridView isn’t available.  
- The script falls back to a text-based picker (enter numbers separated by commas).

---

## 🧪 Safe Testing

- Always try a **Dry Run** first:  
  ```powershell
  .\Main.ps1 -DryRun
  ```

- Use **Windows Sandbox** (Pro/Enterprise only):  
  1. Enable Windows Sandbox feature in Windows Features.  
  2. Run the Sandbox.  
  3. Copy the repo in and test freely.  
  4. Closing Sandbox discards all changes.

---

## 📄 Logs

- **App logs:** `logs/<AppName>.log`  
- **Session transcript:** `logs/session-YYYYMMDD-HHMMSS.txt`

These are useful for debugging and sharing error reports.

---

## 🆘 Still stuck?

- Open an issue on GitHub with:  
  - The persona you used  
  - The error message  
  - The relevant log file contents
