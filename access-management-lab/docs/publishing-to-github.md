# Publishing to GitHub

## First time (Phase 0)
1. **github.com → New repository** → name `access-management-lab` → **Public** → don't add a README → Create
2. PowerShell on your laptop:
   ```powershell
   cd "$env:USERPROFILE\Documents\access-management-lab"
   git init
   git add .
   git commit -m "Project plan, scripts and docs"
   git branch -M main
   git remote add origin https://github.com/<your-username>/access-management-lab.git
   git push -u origin main
   ```

## After each phase
```powershell
git add .
git commit -m "Phase X: <what you finished>"
git push
```

## Before every push 🔒
```powershell
git diff --cached
```
Make sure there are **no passwords**, no tenant admin emails you want private, and no ServiceNow admin password. Logs from the scripts contain usernames from your **lab** only, which is fine.

If a secret ever gets pushed: **change that password immediately**. Deleting the commit isn't enough.
