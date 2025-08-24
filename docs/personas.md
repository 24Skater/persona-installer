# Personas

Persona Installer includes ready-to-use personas.  
Each persona has **base apps** (always installed) and **optional apps** (you choose).

---

## 📋 Persona Overview

| Persona         | Base Apps                                                                 | Optional Apps                                                                 |
|-----------------|---------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| **Personal**    | Git, VS Code, GitHub Desktop, Chrome, Notepad++, PowerShell 7, VLC, WhatsApp, Zoom | Steam, Epic Games, Ubisoft Connect, WorshipTools Presenter, Microsoft 365, Adobe Creative Cloud, Python 3 |
| **Testbench**   | PowerShell 7, Python 3, Git                                               | –                                                                             |
| **Dev**         | Git, VS Code, GitHub Desktop, GitHub CLI, Node.js (LTS), Python 3, Java (OpenJDK 17), Docker Desktop, .NET SDK | Visual Studio 2022, Postman, DBeaver, Go, Rust, Maven, Gradle, Yarn, Azure CLI, AWS CLI, Google Cloud SDK |
| **Finance Pro** | Chrome, Microsoft 365, Adobe Reader, Zoom, Teams, Slack, Power BI Desktop | Tableau Public, Citrix Workspace                                               |
| **IT Pro**      | PowerShell 7, Git, Notepad++, 7-Zip, Everything, Nmap, Wireshark, Rufus, Ventoy, PuTTY | Sysinternals Suite (Store), Chrome, VLC, Zoom                                 |
| **Cybersecurity Pro** | Nmap, Wireshark, Burp Suite Community, OWASP ZAP, Ghidra, OpenSSL, Python 3, Git | Docker CLI, Docker Desktop, GitHub CLI, Node.js (LTS)                          |

---

## 🧩 Adding or Editing Personas

- Personas are JSON files in `data/personas/`
- Example:
  ```json
  {
    "name": "my-persona",
    "base": ["Git", "VS Code"],
    "optional": ["Node.js (LTS)", "Docker Desktop"]
  }
  ```
- Add or edit them via the menu (`2) Create new persona` or `3) Edit existing persona`).
- Saved files are auto-loaded on next run.

---

## 💡 Tips

- Keep **base apps** to essentials (what *every* install should have).
- Use **optional apps** for extras that depend on the user’s needs.
- You can clone an existing persona when creating a new one.

