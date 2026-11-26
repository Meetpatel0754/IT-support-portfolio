<#
.SYNOPSIS
    Offboarding: disables an AD account, removes its group memberships and moves it to the Disabled OU.

.DESCRIPTION
    Steps, in this order (security first):
      1. Safety checks (account exists, not a protected/admin account, not already offboarded)
      2. Saves the user's current group memberships to a CSV (audit trail + rollback if needed)
      3. Disables the account                                  <- access is cut immediately
      4. Resets the password to a long random value            <- in case it is re-enabled by mistake
      5. Removes the user from every group (except the primary group, Domain Users)
      6. Updates the description with the date and ticket number
      7. Moves the account to OU=Disabled,OU=LAB
      8. Verifies the result and prints a summary to paste into the ticket

    The account is NOT deleted: it is kept disabled for the retention period, as most companies require.

.PARAMETER SamAccountName
    Username to offboard, e.g. dokafor

.PARAMETER TicketNumber
    The ServiceNow request number authorising the change, e.g. RITM0010005

.EXAMPLE
    .\02-Disable-UserAccount.ps1 -SamAccountName dokafor -TicketNumber RITM0010005 -WhatIf   # preview only
    .\02-Disable-UserAccount.ps1 -SamAccountName dokafor -TicketNumber RITM0010005           # asks to confirm once

.NOTES
    Run on the domain controller as a Domain Admin.
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$SamAccountName,

    [Parameter(Mandatory)]
    [string]$TicketNumber,

    [string]$DisabledOU,

    [string]$LogFolder = (Join-Path $PSScriptRoot 'logs')
)

Import-Module ActiveDirectory -ErrorAction Stop

# --- Setup ----------------------------------------------------------------------
$domain = Get-ADDomain
if (-not $DisabledOU) { $DisabledOU = "OU=Disabled,OU=LAB,$($domain.DistinguishedName)" }

New-Item -ItemType Directory -Path $LogFolder -Force -WhatIf:$false | Out-Null
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile    = Join-Path $LogFolder "offboarding-$SamAccountName-$stamp.log"
$groupsFile = Join-Path $LogFolder "offboarding-$SamAccountName-$stamp-groups-removed.csv"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $line -WhatIf:$false
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}

Write-Log "=== Offboarding run started by $env:USERDOMAIN\$env:USERNAME | User: $SamAccountName | Ticket: $TicketNumber | WhatIf: $WhatIfPreference ==="

# --- 1. Safety checks ----------------------------------------------------------------
$user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties MemberOf, Description, Enabled
if (-not $user) {
    Write-Log "User '$SamAccountName' not found. Nothing changed. Check the username in the ticket." 'ERROR'
    exit 1
}

$protectedNames = 'Administrator', 'krbtgt', 'Guest', $env:USERNAME
if ($user.SamAccountName -in $protectedNames) {
    Write-Log "Refusing to offboard protected/current account '$($user.SamAccountName)'. Nothing changed." 'ERROR'
    exit 1
}

$adminGroups = 'Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators'
$memberGroupNames = @($user.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })
$privileged = $memberGroupNames | Where-Object { $_ -in $adminGroups }
if ($privileged) {
    Write-Log "User is in privileged group(s): $($privileged -join ', '). Privileged accounts need senior admin approval. Nothing changed." 'ERROR'
    exit 1
}

if (-not $user.Enabled -and $user.DistinguishedName -like "*$DisabledOU") {
    Write-Log "User '$SamAccountName' is already disabled and in the Disabled OU. Nothing to do." 'WARN'
    exit 0
}

# --- Show the plan ------------------------------------------------------------------
Write-Host "`nPlanned changes for $($user.Name) ($SamAccountName):" -ForegroundColor Cyan
Write-Host "  - Disable account"
Write-Host "  - Reset password to a random value"
Write-Host "  - Remove from $($memberGroupNames.Count) group(s): $($memberGroupNames -join ', ')"
Write-Host "  - Move to $DisabledOU`n"

if (-not $PSCmdlet.ShouldProcess("$SamAccountName ($($user.Name))", "Offboard per $TicketNumber")) {
    Write-Log 'Preview only (WhatIf) or cancelled by operator. Nothing changed.' 'WARN'
    exit 0
}

# --- 2. Save current group memberships (audit / rollback) -------------------------------
$memberGroupNames | ForEach-Object { [pscustomobject]@{ User = $SamAccountName; Group = $_; Ticket = $TicketNumber } } |
    Export-Csv -Path $groupsFile -NoTypeInformation -WhatIf:$false
Write-Log "Saved $($memberGroupNames.Count) group membership(s) to $groupsFile"

$errors = 0

# --- 3. Disable ------------------------------------------------------------------------
try {
    Disable-ADAccount -Identity $user -Confirm:$false -ErrorAction Stop
    Write-Log 'Account disabled'
}
catch {
    Write-Log "FAILED to disable account: $($_.Exception.Message). Stopping, no further changes made." 'ERROR'
    exit 1
}

# --- 4. Reset password to a random value -----------------------------------------------
try {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $randomPassword = ConvertTo-SecureString ([Convert]::ToBase64String($bytes) + 'aA1!') -AsPlainText -Force
    Set-ADAccountPassword -Identity $user -Reset -NewPassword $randomPassword -Confirm:$false -ErrorAction Stop
    Write-Log 'Password reset to a random value (not recorded)'
}
catch {
    Write-Log "FAILED to reset password: $($_.Exception.Message)" 'ERROR'
    $errors++
}

# --- 5. Remove group memberships -----------------------------------------------------------
foreach ($groupDN in $user.MemberOf) {
    $groupName = (Get-ADGroup -Identity $groupDN).Name
    try {
        Remove-ADGroupMember -Identity $groupDN -Members $user -Confirm:$false -ErrorAction Stop
        Write-Log "Removed from group $groupName"
    }
    catch {
        Write-Log "FAILED to remove from $groupName : $($_.Exception.Message)" 'ERROR'
        $errors++
    }
}

# --- 6. Update description ------------------------------------------------------------------
try {
    $oldDescription = "$($user.Description)"
    $newDescription = "DISABLED $(Get-Date -Format 'yyyy-MM-dd') per $TicketNumber"
    if ($oldDescription) { $newDescription += " | was: $oldDescription" }
    if ($newDescription.Length -gt 1024) { $newDescription = $newDescription.Substring(0, 1024) }
    Set-ADUser -Identity $user -Description $newDescription -Confirm:$false -ErrorAction Stop
    Write-Log "Description set to: $newDescription"
}
catch {
    Write-Log "FAILED to update description: $($_.Exception.Message)" 'ERROR'
    $errors++
}

# --- 7. Move to Disabled OU (last, because it changes the object's DN) ---------------------------
try {
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU -Confirm:$false -ErrorAction Stop
    Write-Log "Moved to $DisabledOU"
}
catch {
    Write-Log "FAILED to move account: $($_.Exception.Message)" 'ERROR'
    $errors++
}

# --- 8. Verify ---------------------------------------------------------------------------------
$after = Get-ADUser -Identity $user.ObjectGUID -Properties MemberOf, Description
$checks = [ordered]@{
    'Account disabled'      = (-not $after.Enabled)
    'No group memberships'  = (@($after.MemberOf).Count -eq 0)
    'In Disabled OU'        = ($after.DistinguishedName -like "*$DisabledOU")
}
foreach ($check in $checks.GetEnumerator()) {
    $level = if ($check.Value) { 'INFO' } else { 'ERROR' }
    Write-Log ("Verify - {0}: {1}" -f $check.Key, $(if ($check.Value) { 'PASS' } else { 'FAIL' })) $level
}

$overall = if ($errors -eq 0 -and ($checks.Values -notcontains $false)) { 'SUCCESS' } else { 'COMPLETED WITH ERRORS - review log' }
Write-Log "=== Offboarding $overall ==="

# --- Ticket work note -------------------------------------------------------------------------
Write-Host "`n----- Paste into the ServiceNow work notes -----" -ForegroundColor Cyan
Write-Host "Offboarding for $($user.Name) ($SamAccountName) per ${TicketNumber}: $overall"
Write-Host "- Account disabled: $(-not $after.Enabled)"
Write-Host "- Password reset to random value"
Write-Host "- Groups removed ($($memberGroupNames.Count)): $($memberGroupNames -join ', ')"
Write-Host "- Moved to: $DisabledOU"
Write-Host "- Log: $(Split-Path $logFile -Leaf) | Groups backup: $(Split-Path $groupsFile -Leaf)"
Write-Host "------------------------------------------------`n" -ForegroundColor Cyan
