# Agent Guidelines

This repository is maintained with the help of AI coding assistants and automated tools.  
To ensure consistency, maintainability, and security, please follow these rules when suggesting, generating, or committing code.

---

## 🚫 Language Restrictions
- **Do NOT use PHP** for any new code.  
- This project is migrating away from PHP completely.  
- All scripts, automation, and tooling must be written in **pure Bash** (POSIX-compliant) with **`jq`** for JSON parsing.

---

## ✅ Allowed Tools & Standards
- **Shell scripting:** Bash (target POSIX-compatible usage where possible).
- **JSON handling:** `jq`.
- **Text processing:** `grep`, `awk`, `sed`, `cut`, `tr`, etc.
- **Version control:** Git best practices (atomic commits, meaningful messages).

---

## 🧹 Code Style & Practices
- Keep scripts **modular and readable** (functions > inline spaghetti).
- Add **comments** explaining non-obvious logic.
- Use **strict mode** in Bash where possible:
  ```bash
  set -euo pipefail
  IFS=$'\n\t'
