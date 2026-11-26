# 🛠️ Build Guide: User Access Management & Workflow Automation Lab

Follow this from top to bottom. **Don't skip ahead, don't add extras.** Each step ends with a **✅ Done when** check. Don't move on until it's true.

---

## 🧭 Rules (read once)

1. **One phase per session.** Sessions are 60–120 min. Stop at the end of a phase, not in the middle.
2. **Tick the boxes** `[ ]` → `[x]` in this file as you go (or print it). Your progress is always visible.
3. **Parking lot.** Got a new idea ("ooh, I could also add…")? Write it in [`PARKING-LOT.md`](PARKING-LOT.md) and carry on. Extras come **after** Phase 5.
4. **20-minute rule.** Stuck for 20 minutes? Write the error in `docs/build-log.md`, take a screenshot, and ask for help. Don't fall down a rabbit hole.
5. **Screenshot as you go.** Every 📸 means: take a screenshot now and save it in `screenshots/` with the name shown. You won't remember to do it later.
6. **Never commit passwords.** Store them in a password manager, not in these files.

---

## 🗺️ The plan

| Phase | What | Time | Session |
|---|---|---|---|
| 0 | Setup: accounts, downloads, free disk space | 60–90 min (mostly waiting) | 1 |
| 1 | ServiceNow: catalog items, approval flow, assignment group | 90 min | 2 |
| 2 | Windows Server 2022 AD lab + PowerShell scripts | 2–3 h (incl. install) | 3 |
| 3 | Microsoft Forms + Power Automate approval | 90 min | 4 |
| 4 | Log test runs as tickets + 2 knowledge base articles | 60 min | 5 |
| 5 | One-page workflow document + publish to GitHub | 60 min | 5 |

**Names used everywhere (don't change them, or the scripts and docs won't match):**

| Thing | Name |
|---|---|
| AD domain | `lab.internal` (NetBIOS `LAB`) |
| DC computer name | `DC01` |
| OUs | `LAB` → `Users`, `Groups`, `Disabled` |
| ServiceNow group | `IT Access Management` |
| ServiceNow catalog items | `New Employee Access Request`, `Employee Offboarding Request` |
| ServiceNow flow | `Access Request Fulfillment` |
| Power Automate flow | `New Employee Access Approval` |

---

## Phase 0: Setup (session 1)

### 0.1 Free up disk space
You need **~60 GB free** for the Windows Server VM.
- [ ] Check free space on **E:** (it had ~78 GB). If it's lower, clean up first (the `C:\adobeTemp` folder, the macOS VM).
- [ ] Create the folder `E:\VMs`

✅ **Done when:** E: has 60 GB+ free.

### 0.2 Request your ServiceNow developer instance (do this first, it can take a while)
- [ ] Go to **developer.servicenow.com** → **Sign up** (free) → verify your email
- [ ] Click **Request Instance** → pick the **latest release** offered → wait until it says **Ready**
- [ ] Save in your password manager: the **instance URL** (`https://devXXXXXX.service-now.com`), username `admin`, and the **password** shown

⚠️ **Keep it alive:** ServiceNow puts free instances to sleep after about 10 days without use, and can reclaim them. Log in at least every few days until the project is finished.

✅ **Done when:** you can log in to your instance as `admin`.

### 0.3 Download Windows Server 2022 (start it now, it's ~5 GB)
- [ ] Go to **microsoft.com/evalcenter** → **Windows Server 2022** → fill in the form → **ISO downloads → English (United States)**
- [ ] Save the ISO to `E:\VMs`

Note: it's a free 180-day evaluation. It activates itself automatically over the internet, so keep the VM connected for its first boots.

✅ **Done when:** the `.iso` file is fully downloaded.

### 0.4 Microsoft 365 tenant: pick ONE path
Phase 3 needs a Microsoft 365 work tenant (Forms + Power Automate + Outlook).

- [ ] **Path A: You already have a tenant from your M365 lab** → use it. Skip to 0.5.
- [ ] **Path B: Free 1-month business trial.** Go to the Microsoft 365 **Business Basic** (or Business Premium) page → **Try free for one month** → create a new tenant (e.g. `yournamelab.onmicrosoft.com`).
  - ⚠️ A **credit card is required**. **Right after signing up**, go to **admin.microsoft.com → Billing → Your products → the subscription → turn OFF Recurring billing**, so you're never charged.
  - Do Phase 3 **within the month**.
- [ ] **Path C: No tenant possible right now** → do Phases 1, 2, 4 and 5 first. Do Phase 3 later. Don't let this block you.

✅ **Done when:** you can sign in to **admin.microsoft.com** as the tenant admin (or you've chosen Path C).

### 0.5 Set up the GitHub repo
- [ ] Unzip this project to `C:\Users\<you>\Documents\access-management-lab`
- [ ] Create a **public** GitHub repo `access-management-lab` and push it (commands in `docs/publishing-to-github.md`)

✅ **Done when:** you can see the repo on github.com.

🛑 **End of session 1.**

---

## Phase 1: ServiceNow (session 2, ~90 min)

Log in to your instance. The left menu is called **All**. Type in its filter box to find things.

### 1.1 Prepare test users (10 min)
We'll use the demo users that come with the instance:
- **Beth Anglin** = the employee who submits requests (the "requester")
- **Abel Tuter** = Beth's manager, who approves

- [ ] **All → User Administration → Users** → open **Beth Anglin** → set **Manager** = **Abel Tuter** → **Update**
- [ ] If Beth or Abel don't exist, create two users with **New** and use those names instead

✅ **Done when:** Beth Anglin's record shows Manager = Abel Tuter.

### 1.2 Create the assignment group (5 min)
- [ ] **All → User Administration → Groups → New**
  - **Name:** `IT Access Management`
  - **Description:** `Fulfils account and access requests (onboarding/offboarding)`
- [ ] **Right-click the grey header → Save** (stays on the form)
- [ ] At the bottom, **Group Members** tab → **Edit…** → add **System Administrator** (you) → **Save**

✅ **Done when:** the group exists with you as a member.

### 1.3 Create the onboarding catalog item (25 min)
- [ ] **All → Service Catalog → Catalog Definitions → Maintain Items → New**
  - **Name:** `New Employee Access Request`
  - **Catalogs:** `Service Catalog`
  - **Category:** any existing category (e.g. *Software*)
  - **Short description:** `Request accounts and access for a new employee`
  - **Description:** `Submit at least 5 business days before the start date. The employee's manager must approve. IT Access Management creates the account and group access.`
- [ ] **Right-click header → Save**
- [ ] Scroll to the **Variables** tab → **New**, and create these one at a time (for each one: **Type**, then **Question**, then the **Name**, and tick **Mandatory** where shown → **Submit**):

| # | Type | Question | Name | Mandatory |
|---|---|---|---|---|
| 1 | Single Line Text | Employee first name | `employee_first_name` | ✅ |
| 2 | Single Line Text | Employee last name | `employee_last_name` | ✅ |
| 3 | Select Box | Department | `department` | ✅ |
| 4 | Single Line Text | Job title | `job_title` | ✅ |
| 5 | Date | Start date | `start_date` | ✅ |
| 6 | Multi Line Text | Access needed (VPN, shared drive, CRM…) and business reason | `access_needed` | ✅ |

- [ ] For **Department** (#3): open it → **Question Choices** tab → **New** → add `IT`, `HR`, `Sales`, `Finance` (Text and Value the same)

✅ **Done when:** the item has 6 variables, and Department has 4 choices.

### 1.4 Create the offboarding catalog item (10 min)
- [ ] **Maintain Items → New**
  - **Name:** `Employee Offboarding Request`
  - **Catalogs:** `Service Catalog` · **Category:** same as before
  - **Short description:** `Remove access for an employee who is leaving`
- [ ] **Save**, then add the variables:

| # | Type | Question | Name | Mandatory |
|---|---|---|---|---|
| 1 | Single Line Text | Employee username (e.g. dokafor) | `employee_username` | ✅ |
| 2 | Date | Last working day | `last_day` | ✅ |
| 3 | Select Box (choices: `Resignation`, `Termination`, `Contract ended`) | Reason | `reason` | ✅ |
| 4 | CheckBox | Immediate termination: disable access now | `immediate` | |

✅ **Done when:** the second item exists with 4 variables.

### 1.5 Build the approval flow (30 min)
- [ ] **All → Process Automation → Workflow Studio** (older versions call it **Flow Designer**) → **New → Flow**
  - **Name:** `Access Request Fulfillment` → **Build flow** / **Submit**

**Trigger**
- [ ] **Add a trigger → Service Catalog** (no settings needed) → **Done**

**Action 1: Ask For Approval**
- [ ] **Add an Action → Ask For Approval**
  - **Record:** drag the pill **Trigger → Requested Item Record**
  - **Rules → Approve When:** *Anyone approves* → **Users** → in the data panel, expand **Requested Item Record → Requested for → Manager** and drag **Manager** in
  - **Reject When:** *Anyone rejects*
  - If you see a **Due Date** option: set **3 days**, action **Reject** (that's the "manager never answered" exception)
  - **Done**

**Flow logic: If approved**
- [ ] **Add flow logic → If**
  - **Condition:** drag **1 → Approval State** → `is` → `Approved`

**Action 2 (inside the If): Create Catalog Task**
- [ ] **Add an Action → Create Catalog Task**
  - **Requested Item:** drag **Trigger → Requested Item Record**
  - **Wait:** ✅ ticked (the flow pauses until the task is closed)
  - **Fields:**
    - **Short description:** `Fulfil access request: ` + drag **Requested Item Record → Item → Name**
    - **Assignment group:** `IT Access Management`
  - **Done**

**Action 3 (inside the If, after the task): Update Record**
- [ ] **Add an Action → Update Record** → **Record:** **Trigger → Requested Item Record** → **Fields:** **State** = `Closed Complete` → **Done**

**Else (rejected)**
- [ ] Click **Else** under the If → **Add an Action → Update Record** → **Record:** **Requested Item Record** → **State** = `Closed Incomplete` → **Done**

- [ ] **Save** → **Activate**

📸 `screenshots/01-servicenow-flow.png`: the whole flow

✅ **Done when:** the flow shows **Active**.

### 1.6 Connect the flow to both catalog items (5 min)
- [ ] Open **New Employee Access Request** → find the **Process Engine** tab → **Flow:** `Access Request Fulfillment` → **Update**
- [ ] Do the same for **Employee Offboarding Request**

✅ **Done when:** both items show the flow on the Process Engine tab.

### 1.7 Test it: approve path + reject path (15 min)
**Run 1: approved**
- [ ] Click your **profile picture (top right) → Impersonate user → Beth Anglin**
- [ ] Open the **Service Portal**: go to `https://devXXXXXX.service-now.com/sp` → search `New Employee Access Request`
- [ ] Fill it in: *Priya Shah, Sales, Sales Manager, start date next Monday, "CRM + VPN for sales role"* → **Submit**
- [ ] Write down the **RITM number** (e.g. RITM0010001) in `docs/ticket-log.md`
- [ ] **Impersonate → Abel Tuter** → in the portal, open **Approvals** (or **All → Self-Service → My Approvals**) → open it → **Approve**
- [ ] **Impersonate → System Administrator** (end impersonation) → **All → Service Desk → My Groups Work** (or Catalog Tasks) → you should see the new **SCTASK** assigned to **IT Access Management**

📸 `screenshots/02-servicenow-request-form.png` · `03-servicenow-approval.png` · `04-servicenow-sctask.png`

**Run 2: rejected**
- [ ] As **Beth**, submit another onboarding request (any name) → as **Abel**, **Reject** with a comment ("Headcount not approved") → back as admin, check the RITM state is **Closed Incomplete**
- [ ] Record the RITM number in `docs/ticket-log.md`

**Run 3: submit (don't work it yet)**
- [ ] As **Beth**, submit one more onboarding request (*Aisha Khan, IT*) → as **Abel**, approve it. You'll use it for the exceptions test in Phase 2.
- [ ] As **Beth**, submit an **Employee Offboarding Request** for `dokafor` → as **Abel**, approve it. You'll use it in Phase 2.
- [ ] Record all RITM numbers in `docs/ticket-log.md`

✅ **Done when:** you have 1 rejected RITM and 3 approved RITMs, each with an open SCTASK.

🛑 **End of session 2.** Commit: `git commit -am "Phase 1: ServiceNow catalog items and approval flow"`

---

## Phase 2: Active Directory lab + PowerShell (session 3, 2–3 h)

### 2.1 Create the VM (15 min)
In **VirtualBox** → **New**:
- [ ] **Name:** `WS-DC01` · **Folder:** `E:\VMs` · **ISO:** the Server 2022 ISO
- [ ] **Type:** Microsoft Windows · **Version:** Windows Server 2022 (64-bit)
- [ ] ✅ Tick **Skip Unattended Installation** (avoids the problems we saw before)
- [ ] **Memory:** 4096 MB · **CPUs:** 2 · **Disk:** 60 GB
- [ ] **Finish**. Leave the network on **NAT**.

### 2.2 Install Windows Server (30–45 min, mostly waiting)
- [ ] Start the VM → **Install** → when asked for the edition, pick **Windows Server 2022 Standard Evaluation (Desktop Experience)** (Desktop Experience = with GUI. Important!)
- [ ] **Custom install** → select the disk → Next → wait
- [ ] Set the **Administrator password** → save it in your password manager
- [ ] Log in (VirtualBox menu: **Input → Keyboard → Insert Ctrl-Alt-Del**)
- [ ] **Devices → Insert Guest Additions CD** → open the CD in File Explorer → run **VBoxWindowsAdditions** → reboot

If it's very slow, it's probably the 🐢 Hyper-V turtle mode (see your earlier notes: `bcdedit /set hypervisorlaunchtype off` on the laptop, then restart the laptop).

✅ **Done when:** you're on the Server desktop, and Guest Additions are installed.

### 2.3 Name and network (10 min)
Open **PowerShell as Administrator** in the VM:
```powershell
Get-NetAdapter                      # note the Name, usually "Ethernet"
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.0.2.15 -PrefixLength 24 -DefaultGateway 10.0.2.2
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.0.2.3
Rename-Computer -NewName DC01 -Restart
```
(Why: a domain controller needs a fixed IP. These values match VirtualBox's built-in NAT network.)

✅ **Done when:** after the restart, `hostname` shows `DC01` and `ping microsoft.com` gets replies (or at least resolves the name).

### 2.4 Install Active Directory (20 min)
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName 'lab.internal' -DomainNetbiosName 'LAB' -InstallDns `
    -SafeModeAdministratorPassword (Read-Host -AsSecureString 'DSRM recovery password') -Force
```
- The DSRM password is a recovery password, so save it in your password manager.
- The VM restarts by itself, and the first login takes a few minutes.
- [ ] Log in as **LAB\Administrator**

📸 `screenshots/05-ad-server-manager.png`: Server Manager showing AD DS

✅ **Done when:** **Server Manager → Tools → Active Directory Users and Computers** opens and shows `lab.internal`.

### 2.5 Copy the project into the VM (10 min)
- [ ] VirtualBox: **Devices → Shared Folders → Shared Folders Settings → +** → **Folder Path:** your `access-management-lab` folder · ✅ **Auto-mount** → OK
- [ ] In the VM, open File Explorer → the shared drive (e.g. `Z:` or `\\VBoxSvr\access-management-lab`) → copy the **whole folder** to `C:\Lab`
- [ ] PowerShell (Admin):
```powershell
cd C:\Lab\scripts
Get-ChildItem C:\Lab -Recurse | Unblock-File
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```
(`-Scope Process` only affects this PowerShell window. Open a new window = protections back on.)

✅ **Done when:** `dir C:\Lab\scripts` lists the 3 `.ps1` files.

### 2.6 Create the OU structure and groups (5 min)
```powershell
.\00-Setup-LabStructure.ps1 -WhatIf     # preview, changes nothing
.\00-Setup-LabStructure.ps1             # do it
```
- [ ] Open **AD Users and Computers** → `lab.internal` → **LAB** → check `Users`, `Groups`, `Disabled` and the 7 groups

📸 `screenshots/06-ad-ou-structure.png`

✅ **Done when:** OUs and groups are visible. Run the script again, and it should say **Exists** for everything (it's safe to re-run).

### 2.7 Onboarding: create users from the CSV (20 min)
- [ ] Open `C:\Lab\data\new-hires.csv` in Notepad → **Edit → Replace** `RITM0010001` with your **real** approved onboarding RITM number from Phase 1 → Save
- [ ] Preview first:
```powershell
.\01-New-UsersFromCsv.ps1 -CsvPath ..\data\new-hires.csv -WhatIf
```
- [ ] Real run (enter a temporary password when asked, e.g. `Welcome-2026!Lab`):
```powershell
.\01-New-UsersFromCsv.ps1 -CsvPath ..\data\new-hires.csv
```
**Expected:** 4 × `Created`, 1 × `Created with warnings` (Sarah Thompson: group `ACCESS-Payroll` doesn't exist). That's an **intentional exception** to test.

- [ ] Check in ADUC: 5 users in `LAB\Users`, and Daniel Okafor's **Organization** tab shows manager Priya Shah
- [ ] Find the log and results CSV in `C:\Lab\scripts\logs\`

📸 `screenshots/07-onboarding-script-output.png` · `08-ad-new-users.png`

✅ **Done when:** 5 users exist, and the log + results CSV exist.

### 2.8 Onboarding exceptions test (10 min)
- [ ] In `C:\Lab\data\test-exceptions.csv`, replace `RITM0010003` with your **Aisha Khan** RITM number
```powershell
.\01-New-UsersFromCsv.ps1 -CsvPath ..\data\test-exceptions.csv
```
**Expected:**
| Row | Expected result | Why |
|---|---|---|
| Priya Shah | `Skipped: Username already exists` | Duplicate: a human must decide (rehire? different person?) |
| Jordan (no last name) | `Skipped: Missing or invalid name` | Bad request data |
| Aisha Khan | `Created with warnings: Manager 'nosuchmanager' not found` | Account created, follow-up needed |

📸 `screenshots/09-onboarding-exceptions.png`

✅ **Done when:** results match the table.

### 2.9 Offboarding (15 min)
- [ ] Preview:
```powershell
.\02-Disable-UserAccount.ps1 -SamAccountName dokafor -TicketNumber <your offboarding RITM> -WhatIf
```
- [ ] Real run (answer **Y** to the confirmation):
```powershell
.\02-Disable-UserAccount.ps1 -SamAccountName dokafor -TicketNumber <your offboarding RITM>
```
**Expected:** all 3 verify checks `PASS`, then a block of text "Paste into the ServiceNow work notes". **Copy that text** into Notepad for Phase 4.
- [ ] ADUC: Daniel Okafor is in `LAB\Disabled` with a ⬇ (disabled) icon, and **Member Of** shows only *Domain Users*

📸 `screenshots/10-offboarding-output.png` · `11-ad-disabled-user.png`

### 2.10 Offboarding exceptions test (5 min)
```powershell
.\02-Disable-UserAccount.ps1 -SamAccountName dokafor -TicketNumber TEST       # already offboarded → "Nothing to do"
.\02-Disable-UserAccount.ps1 -SamAccountName Administrator -TicketNumber TEST # protected → refused
.\02-Disable-UserAccount.ps1 -SamAccountName nobody -TicketNumber TEST        # not found → error, nothing changed
```
📸 `screenshots/12-offboarding-exceptions.png`

✅ **Done when:** all three are refused safely, and nothing changed.

- [ ] Copy `C:\Lab\scripts\logs\` back to your laptop's project folder (through the shared folder) → `evidence/logs/`

🛑 **End of session 3.** Commit: `git commit -am "Phase 2: AD lab, onboarding/offboarding scripts tested"`

---

## Phase 3: Microsoft Forms + Power Automate (session 4, ~90 min)

### 3.1 Test users (10 min)
**admin.microsoft.com → Users → Active users → Add a user**, twice:
- [ ] `Riley Requester` (riley@…): the HR person who submits requests
- [ ] `Morgan Manager` (morgan@…): the hiring manager who approves
- [ ] Give both a **license** and save their passwords in your password manager

✅ **Done when:** both users show a license assigned.

### 3.2 Build the form (15 min)
As the admin, go to **forms.office.com → New Form** → title `New Employee Access Request`:

| # | Question | Type | Required |
|---|---|---|---|
| 1 | Employee full name | Text | ✅ |
| 2 | Department | Choice: IT, HR, Sales, Finance | ✅ |
| 3 | Job title | Text | ✅ |
| 4 | Start date | Date | ✅ |
| 5 | Access needed | Choice, **multiple answers**: VPN, Shared drive, CRM | ✅ |
| 6 | Hiring manager's email | Text | ✅ |
| 7 | Business justification | Text, **long answer** | ✅ |

- [ ] **⋯ → Settings:** **Only people in my organization can respond** + ✅ **Record name**. This gives the flow the requester's email.

✅ **Done when:** the preview shows all 7 questions.

### 3.3 Build the flow (40 min)
**make.powerautomate.com → Create → Automated cloud flow** → name `New Employee Access Approval` → trigger **When a new response is submitted** (Microsoft Forms) → **Create**

- [ ] **Trigger:** Form Id = your form
- [ ] **+ → Get response details:** Form Id = your form · Response Id = *Response Id* (dynamic content)
- [ ] **+ → Start and wait for an approval**
  - **Approval type:** Approve/Reject – First to respond
  - **Title:** `Access request: ` + *Employee full name* + ` (` + *Department* + `)`
  - **Assigned to:** *Hiring manager's email*
  - **Details:**
    ```
    Employee: <Employee full name>
    Department / title: <Department> / <Job title>
    Start date: <Start date>
    Access needed: <Access needed>
    Justification: <Business justification>
    Requested by: <Responders' Email>
    ```
    (insert each `<…>` from dynamic content)
- [ ] **+ → Condition:** *Outcome* `is equal to` `Approve`
- [ ] **True branch → Send an email (V2)** (Office 365 Outlook)
  - **To:** *Responders' Email*
  - **Subject:** `Approved: access request for ` + *Employee full name*
  - **Body:** `Your request was approved by the hiring manager. IT will create the account before the start date. Comments: ` + *Responses Comments*
  - (Power Automate may wrap this in **Apply to each**. That's normal, because approvals can have several responses.)
- [ ] **True branch → another Send an email (V2):** **To:** your admin email · **Subject:** `ACTION: create account for ` + *Employee full name* (this notifies IT)
- [ ] **False branch → Send an email (V2):** **To:** *Responders' Email* · **Subject:** `Rejected: access request for ` + *Employee full name* · **Body:** `The hiring manager rejected this request. Comments: ` + *Responses Comments*
- [ ] **Save**

📸 `screenshots/13-power-automate-flow.png`: the whole flow, expanded

✅ **Done when:** the flow saves without errors.

### 3.4 Test it (20 min)
**Approve path**
- [ ] Open a **private/InPrivate browser window** → sign in as **Riley** → open the form link → submit (*Mei Chen, Finance…*, manager email = **Morgan's** address)
- [ ] Private window → sign in as **Morgan** → **Outlook** (or make.powerautomate.com → **Approvals**) → **Approve** with a comment
- [ ] As **Riley** → Outlook → the **Approved** email arrived ✅

**Reject path**
- [ ] Submit again as Riley → **Reject** as Morgan with comment `Start date not confirmed` → Riley gets the **Rejected** email ✅

- [ ] Power Automate → your flow → **28-day run history** → both runs **Succeeded**

📸 `14-forms-request.png` · `15-approval-email.png` · `16-requester-notified.png` · `17-flow-run-history.png`

Note: the very first approval in a new tenant can take a few extra minutes to arrive (Power Automate sets up its approvals storage the first time).

✅ **Done when:** both paths work and both runs show **Succeeded**.

**Optional, only if you're ahead of time (15 min): manager never answers**
- [ ] On **Start and wait for an approval** → **Settings** → **Timeout** = `PT10M` (10 min for testing, use `P3D` = 3 days in real life)
- [ ] Add a **parallel branch** after it → **Send an email (V2)** to Responders' Email "No decision yet, escalated to IT" → **Settings → Run after** → tick **has timed out** only

🛑 **End of session 4.** Commit: `git commit -am "Phase 3: Microsoft Forms + Power Automate approval flow"`

---

## Phase 4: Tickets + knowledge base in ServiceNow (session 5, ~60 min)

### 4.1 Work the catalog tasks (25 min)
For each **SCTASK** from Phase 1 (as admin, **Service Desk → My Groups Work**):

- [ ] **Onboarding task (Priya Shah batch):**
  - **Assigned to:** yourself → **State:** Work in Progress
  - **Work notes:** paste the onboarding results (from the results CSV), and mention the `ACCESS-Payroll` exception
  - **Attach** (📎 paperclip): the onboarding log + results CSV
  - **State:** Closed Complete → the RITM closes automatically (that's the flow's Update Record step)
- [ ] **Aisha Khan task:** same, with the exceptions run's log. Note the "manager not found" follow-up.
- [ ] **Offboarding task (dokafor):** paste the "work notes" text from the offboarding script + attach the log and groups-backup CSV → Close
- [ ] Check that each **RITM** is now **Closed Complete**

### 4.2 Raise an incident for the missing group (5 min)
Real help desks track follow-ups:
- [ ] **All → Incident → Create New**
  - **Caller:** Beth Anglin · **Short description:** `Onboarding: AD group ACCESS-Payroll does not exist (Sarah Thompson not added)`
  - **Assignment group:** IT Access Management · **Work notes:** link to the RITM
  - Leave it **open** (or resolve it by creating the group and adding Sarah, if you want)

### 4.3 Log the Power Automate test runs (10 min)
- [ ] Create **two incidents** (or one each for approve and reject), category *Inquiry / Help*:
  - `TEST: M365 access approval flow, approve path, Succeeded`
  - `TEST: M365 access approval flow, reject path, Succeeded`
  - Work notes: run date/time, approver, outcome. Attach the screenshots. **Resolve** them.
- [ ] Fill in every ticket number in `docs/ticket-log.md`

### 4.4 Knowledge base articles (20 min)
- [ ] **All → Knowledge → Articles → Create New** → Knowledge base: **IT**
  - **Short description:** `How to: Onboard a new user (AD account + access)`
  - **Article body:** copy from `docs/kb-onboard-new-user.md` (paste as plain text, then fix headings with the editor toolbar)
  - **Publish**. If your instance sends it for review, approve it via **My Approvals**.
- [ ] Same for `docs/kb-offboard-user.md` → `How to: Offboard a user (disable + remove access)`
- [ ] Note the **KB numbers** in `docs/ticket-log.md`

📸 `18-servicenow-closed-ritm.png` · `19-servicenow-kb-articles.png`

✅ **Done when:** all RITMs closed, 1+ incidents logged, 2 KB articles published.

---

## Phase 5: Workflow document + GitHub (session 5, ~60 min)

### 5.1 One-page workflow document (35 min)
- [ ] Open `docs/workflow-one-pager.md` and **replace every `[ ]` placeholder** with your real values (ticket numbers, times, what actually happened)
- [ ] Read it out loud once. Anything that doesn't match what you built → fix it.
- [ ] (Optional) Paste it into Word or Google Docs → export as **PDF** → `docs/workflow-one-pager.pdf` (keep it to **one page**)

### 5.2 Publish (25 min)
- [ ] Make sure all 📸 screenshots are in `screenshots/`
- [ ] Update `README.md`: tick the checklist, add your name and links
- [ ] Check for secrets: `git diff` → no passwords, no keys
- [ ] `git add . && git commit -m "Phase 4-5: tickets, KB articles, workflow doc" && git push`
- [ ] Pin the repo on your GitHub profile
- [ ] Add the resume bullets from `README.md` to your resume

✅ **Done when:** the repo is public, pinned, and the README shows screenshots.

🎉 **Project complete.** Now (and only now) open `PARKING-LOT.md` and pick one extra idea, if you want.
