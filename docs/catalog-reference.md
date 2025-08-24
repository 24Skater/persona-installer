# Catalog Reference

The **catalog** is the master list of apps available for installation.  
It lives in: `data/catalog.json`

Each entry is a mapping of **friendly name → winget ID**.

---

## 📝 Example

```json
{
  "Node.js (LTS)": "OpenJS.NodeJS.LTS",
  "Docker Desktop": "Docker.DockerDesktop",
  "Microsoft Teams": "Microsoft.Teams",
  "Wireshark": "WiresharkFoundation.Wireshark"
}
```

---

## 🔎 Finding Winget IDs

Use the built-in `winget search` command:

```powershell
winget search nodejs
winget search docker
winget search teams
```

The output looks like:

```
Name                Id                           Version   Source
---------------------------------------------------------------
Node.js LTS         OpenJS.NodeJS.LTS            20.14.0   winget
Node.js             OpenJS.NodeJS                22.4.1    winget
```

Use the **Id** column as the value in `catalog.json`.

---

## 📦 Popular Winget IDs

Here are some useful IDs already included in the catalog:

- **Developer Tools**
  - Node.js LTS → `OpenJS.NodeJS.LTS`
  - Python 3 (latest) → `Python.Python.3`
  - Git → `Git.Git`
  - GitHub CLI → `GitHub.cli`
  - Visual Studio Code → `Microsoft.VisualStudioCode`
  - Visual Studio 2022 Community → `Microsoft.VisualStudio.2022.Community`
  - Docker Desktop → `Docker.DockerDesktop`
  - Postman → `Postman.Postman`
  - DBeaver (Community) → `DBeaver.DBeaver.Community`

- **Productivity & Finance**
  - Google Chrome → `Google.Chrome`
  - Microsoft 365 (Office) → `Microsoft.Office`
  - Microsoft Teams → `Microsoft.Teams`
  - Slack → `SlackTechnologies.Slack`
  - Power BI Desktop → `Microsoft.PowerBI`
  - Tableau Public → `Tableau.TableauPublic`
  - Adobe Acrobat Reader → `Adobe.Acrobat.Reader.64-bit`

- **IT & Utilities**
  - PowerShell 7 → `Microsoft.PowerShell`
  - Notepad++ → `Notepad++.Notepad++`
  - 7-Zip → `7zip.7zip`
  - Everything Search → `voidtools.Everything`
  - Rufus → `Rufus.Rufus`
  - Ventoy → `Ventoy.Ventoy`
  - PuTTY → `PuTTY.PuTTY`
  - Sysinternals Suite (Store) → `9P7KNL5RWT25`

- **Cybersecurity**
  - Nmap → `Insecure.Nmap`
  - Wireshark → `WiresharkFoundation.Wireshark`
  - Burp Suite Community → `PortSwigger.BurpSuiteCommunity`
  - OWASP ZAP → `OWASP.ZAP`
  - Ghidra → `NSA.Ghidra`
  - OpenSSL (Win64) → `ShiningLight.OpenSSL.Light`

---

## 🛠️ Adding New Apps

1. Run `winget search <app>` to find the correct ID.
2. Add it to `data/catalog.json` like so:

```json
"App Friendly Name": "Exact.Winget.ID"
```

3. Save and commit the change.

---

## ⚡ Tips

- Use `--exact` (`-e`) flag when installing to avoid ambiguity:
  ```powershell
  winget install --id OpenJS.NodeJS.LTS -e
  ```
- Prefer **LTS or stable releases** for long-term setups.
- Avoid duplicate names — keep them consistent and human-friendly.

---
