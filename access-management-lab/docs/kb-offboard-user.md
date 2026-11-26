# How to: Offboard a user (disable + remove access)

**Applies to:** IT Access Management technicians · **Ticket type:** Employee Offboarding Request (RITM/SCTASK)

## Before you start
- The offboarding request (RITM) is **Approved**, **or** HR has asked for an **immediate termination** (in that case, disable first and record the approval afterwards).
- Run it **on or after the last working day**, unless it's an immediate termination.
- Confirm the **exact username** in the ticket (e.g. `dokafor`). The wrong username means you lock out the wrong person.

## Steps
1. Open PowerShell as Administrator on the domain controller:
   ```powershell
   cd C:\Lab\scripts
   .\02-Disable-UserAccount.ps1 -SamAccountName <username> -TicketNumber <RITM> -WhatIf
   ```
2. Read the **planned changes**. Is it the right person, and are those the groups you expect?
3. Run it without `-WhatIf` and type **Y** to confirm. The script:
   1. disables the account (access is cut first)
   2. resets the password to a random value
   3. saves the group list to a backup CSV, then removes all groups
   4. stamps the description: `DISABLED <date> per <RITM>`
   5. moves the account to `LAB\Disabled`
   6. checks its own work (3 × PASS)
4. Copy the **"Paste into the ServiceNow work notes"** block into the SCTASK work notes.
5. **Attach** the log and `…-groups-removed.csv` from `scripts\logs\`.
6. Set the SCTASK to **Closed Complete**.

⚠️ **Do not delete the account.** It stays disabled for the retention period. Deleting it needs a separate request.

## If something goes wrong
| Message | Meaning / action |
|---|---|
| "User not found" | Wrong username in the ticket. Ask the requester, and change nothing |
| "Refusing to offboard protected account" / "privileged group" | Admin accounts need senior admin approval and a manual process |
| "Already disabled and in the Disabled OU" | Already done. Check the ticket history for a duplicate request |
| A verify check shows **FAIL** | Read the log, fix that step manually in ADUC, and note it in the ticket |

## Undo a mistaken offboarding
1. ADUC → find the user in `LAB\Disabled` → **Enable Account** → **Reset Password**
2. Re-add the groups listed in `…-groups-removed.csv`
3. Move the user back to `LAB\Users`, and record everything in a new ticket
