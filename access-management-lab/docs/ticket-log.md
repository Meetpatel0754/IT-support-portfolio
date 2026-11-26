# Ticket Log: Test Runs

Every test run was logged as a ticket in ServiceNow, the same way a real help desk records its work.

| # | Scenario | Ticket(s) | Approver / decision | Fulfilment | Result | Evidence |
|---|---|---|---|---|---|---|
| T1 | Onboarding, approved (batch of 5) | RITM0010001 / SCTASK0010001 | Abel Tuter: Approved | `01-New-UsersFromCsv.ps1` | 4 created, 1 created with warning | `04-request-approved`, `13-ad-users`, `15-onboarding-log` |
| T2 | Onboarding, rejected | RITM0010003 | Abel Tuter: Rejected | none | Closed Incomplete, no account created | `05-request-rejected` |
| T2b | Requester with no manager (unplanned) | RITM0010002 | No approver found | none | Auto-closed as Closed Incomplete | `06-no-manager-exception` |
| T3 | Onboarding exceptions (duplicate, missing name, unknown manager) | RITM0010004 / SCTASK0010002 | Abel Tuter: Approved | `01-New-UsersFromCsv.ps1` (test-exceptions.csv) | 2 skipped, 1 created with warning | `evidence/logs` |
| T4 | Follow-up: AD group ACCESS-Payroll missing | INC0010001 | n/a | manual | Open | `09-incident` |
| T5 | Offboarding: dokafor | RITM0010005 / SCTASK0010003 | Abel Tuter: Approved | `02-Disable-UserAccount.ps1` | 3/3 checks PASS | `08-sctask-worknotes`, `14-ad-disabled-user`, `16-offboarding-log` |
| T6 | Offboarding safety (already offboarded, Administrator, unknown user) | noted in SCTASK0010003 | n/a | script | All refused, nothing changed | `evidence/logs` |

## Knowledge base

| Article | Number |
|---|---|
| How to: Onboard a new user | KB0010003 |
| How to: Offboard a user | KB0010006 |

## Notes
- T3 was first run with the wrong ticket number in the CSV (RITM0010003). The AD description on `akhan` was corrected to RITM0010004 afterwards (see build log).
- T2b wasn't planned. It came from submitting a request as the admin account, which has no manager.
