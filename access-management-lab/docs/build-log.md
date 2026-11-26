# Build Log

Problems I hit while building this, and how I sorted them out.

## Switched from VirtualBox to VMware
**Problem:** My VirtualBox VMs were slow, and some broke after I moved them to an external SSD.
**Investigation:** Hashed the same VM disk file twice with `certutil -hashfile` and got different results each time, while files on the internal drive matched every time.
**Root cause:** The external SSD's USB enclosure was returning corrupted data.
**Fix:** Built this lab in VMware Workstation on internal storage instead.
**Lesson:** "Windows can see the drive" doesn't mean the drive is reliable. Check with hashes, and use a control test.

## New DC couldn't resolve internet names
**Problem:** `ping 8.8.8.8` worked but `ping microsoft.com` said it couldn't find the host.
**Root cause:** The DNS setting didn't take when I set the static IP.
**Fix:** Set DNS to VMware's NAT DNS (`.2`) plus `8.8.8.8`, cleared the cache, and after promoting the DC added `8.8.8.8` as a forwarder.

## Manager field missing on the user form
**Problem:** Couldn't set Beth Anglin's manager, because the field wasn't on the form.
**Fix:** Added it with Configure → Form Layout.

## Catalog item didn't show in the portal
**Problem:** *New Employee Access Request* didn't show up in the catalog.
**Root cause:** The item had no catalog/category set.
**Fix:** Set Catalog = Service Catalog and Category = Software.

## Approval rule picked the wrong person
**Problem:** The approver pill ended with "Manager > Manager", which is the manager's manager.
**Fix:** In the pill picker, the arrow goes one level deeper and clicking the name selects it. I re-picked *Requested for → Manager*.

## A request closed itself straight away (RITM0010002)
**Problem:** The request went to Closed Incomplete with no approval.
**Root cause:** I'd submitted it as the admin account, and admin has no manager, so the approval had nobody to go to.
**Lesson:** Every requester needs a manager, or the flow needs a fallback approver.

## Wrong ticket number on the exceptions run
**Problem:** Ran the exceptions test before updating the ticket number in the CSV, so `akhan` was stamped with RITM0010003 instead of RITM0010004.
**Fix:** Corrected the description with `Set-ADUser` and noted it in the ServiceNow task.
**Lesson:** Check the ticket number in the `-WhatIf` preview before the real run.

## Offboarding script wouldn't load
**Problem:** `Variable reference is not valid. ':' was not followed by a valid variable name character.`
**Root cause:** `$TicketNumber:` inside a string is read as a drive-qualified variable.
**Fix:** Changed it to `${TicketNumber}:`.
