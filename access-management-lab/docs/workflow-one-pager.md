# User Access Management Workflow: Onboarding & Offboarding

**Owner:** IT Access Management · **Version:** 1.0 · **Date:** 2026-11-24 · **Author:** Meetkumar Patel

**Purpose:** Accounts are only created or removed after an approved request, done the same way every time, with a record of who asked, who approved, who did the work and when.

**Systems:** ServiceNow (requests, approvals, tasks, KB) · Active Directory on Windows Server 2022 (accounts, groups) · PowerShell (fulfilment scripts)

## Onboarding (new employee)
| # | Step | Who | Where | Output |
|---|---|---|---|---|
| 1 | Submit *New Employee Access Request* at least 5 business days before the start date | HR / requester | ServiceNow catalog | RITM (e.g. RITM0010001) |
| 2 | Approve or reject | Requester's manager | ServiceNow approval | Approved → step 3 · Rejected → closed, no account made |
| 3 | Catalog task created automatically | Flow | ServiceNow | SCTASK assigned to *IT Access Management* |
| 4 | Run `01-New-UsersFromCsv.ps1` (`-WhatIf` first) | IT technician | Domain controller | Account in `LAB\Users`, groups added, log + results CSV |
| 5 | Add results to work notes, close task → request closes | IT technician | ServiceNow | Audit trail |

## Offboarding (employee leaving)
| # | Step | Who | Where | Output |
|---|---|---|---|---|
| 1 | Submit *Employee Offboarding Request* (username, last day, reason) | HR / manager | ServiceNow catalog | RITM (e.g. RITM0010005) |
| 2 | Approve | Manager | ServiceNow approval | SCTASK assigned to *IT Access Management* |
| 3 | Run `02-Disable-UserAccount.ps1` on or after the last working day | IT technician | Domain controller | Disabled, password randomised, groups removed (backup CSV), moved to `LAB\Disabled` |
| 4 | Paste script summary into work notes, close task | IT technician | ServiceNow | Audit trail |
| 5 | Keep the disabled account for the retention period; delete only on a separate request | IT | AD | Nothing lost too early |

## Approvals
- **Who approves:** the requester's manager (ServiceNow *Requested for → Manager*).
- **No approval, no access.** Technicians never create or remove access from an email or a verbal request.
- **Timeout (planned):** no decision in 3 days → request rejected or escalated and the requester notified.

## Exceptions
| Situation | What happens | Tested |
|---|---|---|
| Manager rejects | Request closed incomplete, no account created | ✅ RITM0010003 |
| Requester has no manager in ServiceNow | No approver found, request auto-closes. Fix: every user needs a manager, or add a fallback approver group | ✅ RITM0010002 |
| Username already exists | Script skips the user. A person checks: rehire (re-enable the old account) or a different person (new username) | ✅ RITM0010004 |
| Requested group doesn't exist | Account created, group skipped, incident raised | ✅ INC0010001 |
| Manager not found in AD | Account created without a manager, noted for follow-up | ✅ RITM0010004 |
| Missing data on the request | Row skipped, request goes back to the requester | ✅ RITM0010004 |
| **Immediate termination** | Disable straight away on HR's instruction, before normal approval. Approval recorded afterwards | Documented |
| Admin / privileged account | Script refuses; needs senior admin approval | ✅ |
| Already offboarded / user not found | Script stops, changes nothing, logs why | ✅ |
| Mistaken offboarding | Re-enable and restore groups from the `…-groups-removed.csv` backup | Documented |

## Records kept
RITM + SCTASK with approver, timestamps and work notes · script log and results/backup CSV · ticket number stamped in each AD account's description · KB0010003 *Onboard a new user*, KB0010006 *Offboard a user*
