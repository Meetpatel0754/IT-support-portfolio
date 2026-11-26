# How to: Onboard a new user (AD account + access)

**Applies to:** IT Access Management technicians · **Ticket type:** New Employee Access Request (RITM/SCTASK)

## Before you start
- The request (RITM) is **Approved** by the employee's manager. **No approval → don't create anything.**
- The catalog task (SCTASK) is assigned to you and set to **Work in Progress**.
- You are logged in to the domain controller as an administrator.

## Steps
1. Open the RITM and check the details: name, department, title, start date, access needed.
2. Add the user to the onboarding CSV (`data\new-hires.csv`):
   `FirstName,LastName,Department,Title,Manager,Groups,TicketNumber`
   - **Groups:** the department group (`DEPT-…`) plus the requested access groups (`ACCESS-…`), separated by `;`
   - **TicketNumber:** the RITM number
3. Open PowerShell as Administrator:
   ```powershell
   cd C:\Lab\scripts
   .\01-New-UsersFromCsv.ps1 -CsvPath ..\data\new-hires.csv -WhatIf
   ```
   Check the preview. Is it the right user and the right groups?
4. Run it for real (without `-WhatIf`) and enter the temporary password.
5. Check the results table:
   - **Created** → done
   - **Created with warnings** → read the note (missing group or manager) and raise a follow-up incident if needed
   - **Skipped: username already exists** → **stop**. Check whether this is a rehire or a different person before doing anything.
6. Check in **Active Directory Users and Computers** → `LAB\Users`: the user exists, the **Member Of** tab is correct, and the **Organization** tab shows the manager.
7. Give the temporary password to the **manager** securely (in person or by phone, never in the ticket). The user must change it at first logon.
8. In the SCTASK: paste the results into the **work notes**, **attach** the log and results CSV from `scripts\logs\`, then set **Closed Complete**.

## Troubleshooting
| Problem | Fix |
|---|---|
| "Target OU not found" | Run `00-Setup-LabStructure.ps1` first |
| "running scripts is disabled" | `Set-ExecutionPolicy -Scope Process Bypass` in that window |
| Group not found | Check the spelling. If the group really is missing, raise an incident to create it |
