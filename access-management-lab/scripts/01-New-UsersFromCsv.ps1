<#
.SYNOPSIS
    Onboarding: creates Active Directory users from a CSV file and adds them to groups.

.DESCRIPTION
    For each CSV row the script:
      1. Validates the row (first and last name present)
      2. Builds the username (first initial + last name, e.g. Priya Shah -> pshah)
      3. SKIPS the row if that username already exists (a human must decide: rehire? different person?)
      4. Creates the account in OU=Users,OU=LAB (enabled, must change password at first logon)
      5. Sets title, department, manager and a description that references the ticket number
      6. Adds the user to each group in the Groups column (semicolon-separated)
    Every action is written to a log file, and a results CSV is saved so it can be
    attached to the ServiceNow ticket.

    Required CSV columns: FirstName, LastName, Department, Title, Groups, TicketNumber
    Optional CSV column : Manager  (sAMAccountName of the manager, e.g. pshah)

.PARAMETER CsvPath
    Path to the CSV file.

.PARAMETER InitialPassword
    Temporary password for all new accounts (users must change it at first logon).
    If omitted, you will be prompted. It is never written to the log.

.PARAMETER TargetOU
    OU for new users. Default: OU=Users,OU=LAB,<your domain>

.EXAMPLE
    .\01-New-UsersFromCsv.ps1 -CsvPath ..\data\new-hires.csv -WhatIf    # preview only
    .\01-New-UsersFromCsv.ps1 -CsvPath ..\data\new-hires.csv            # create users

.NOTES
    Run on the domain controller as a Domain Admin. Run 00-Setup-LabStructure.ps1 first.
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [securestring]$InitialPassword,

    [string]$TargetOU,

    [string]$LogFolder = (Join-Path $PSScriptRoot 'logs')
)

Import-Module ActiveDirectory -ErrorAction Stop

# --- Setup ----------------------------------------------------------------------
$domain = Get-ADDomain
if (-not $TargetOU) { $TargetOU = "OU=Users,OU=LAB,$($domain.DistinguishedName)" }
$upnSuffix = $domain.DNSRoot

if (-not (Test-Path -Path $CsvPath)) { throw "CSV file not found: $CsvPath" }

New-Item -ItemType Directory -Path $LogFolder -Force -WhatIf:$false | Out-Null
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile    = Join-Path $LogFolder "onboarding-$stamp.log"
$resultFile = Join-Path $LogFolder "onboarding-$stamp-results.csv"

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

function ConvertTo-UsernamePart {
    param([string]$Text)
    # keep letters only, lowercase (removes spaces, hyphens, apostrophes, accents that aren't a-z)
    return ($Text -replace '[^a-zA-Z]', '').ToLower()
}

# --- Read and validate the CSV ---------------------------------------------------
$rows = @(Import-Csv -Path $CsvPath)
if ($rows.Count -eq 0) { throw "CSV has no data rows: $CsvPath" }

$required = 'FirstName', 'LastName', 'Department', 'Title', 'Groups', 'TicketNumber'
$columns  = $rows[0].PSObject.Properties.Name
$missing  = $required | Where-Object { $_ -notin $columns }
if ($missing) { throw "CSV is missing required column(s): $($missing -join ', ')" }

if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$TargetOU'")) {
    throw "Target OU not found: $TargetOU  (run 00-Setup-LabStructure.ps1 first)"
}

if (-not $InitialPassword -and -not $WhatIfPreference) {
    $InitialPassword = Read-Host -AsSecureString -Prompt 'Temporary password for the new accounts (users must change it at first logon)'
}

Write-Log "=== Onboarding run started by $env:USERDOMAIN\$env:USERNAME | CSV: $CsvPath | Rows: $($rows.Count) | WhatIf: $WhatIfPreference ==="

# --- Process each row -------------------------------------------------------------
$results = foreach ($row in $rows) {
    $first  = "$($row.FirstName)".Trim()
    $last   = "$($row.LastName)".Trim()
    $ticket = "$($row.TicketNumber)".Trim()
    $notes  = @()

    # 1. Validate
    $firstPart = ConvertTo-UsernamePart $first
    $lastPart  = ConvertTo-UsernamePart $last
    if (-not $firstPart -or -not $lastPart) {
        Write-Log "Row skipped (ticket $ticket): first or last name missing/invalid -> '$first' '$last'" 'WARN'
        [pscustomobject]@{ Ticket = $ticket; Name = "$first $last"; SamAccountName = ''; UPN = ''
                           Status = 'Skipped'; Notes = 'Missing or invalid first/last name' }
        continue
    }

    # 2. Build username
    $sam = $firstPart.Substring(0, 1) + $lastPart
    if ($sam.Length -gt 20) { $sam = $sam.Substring(0, 20) }   # sAMAccountName max length
    $upn = "$sam@$upnSuffix"

    # 3. Duplicate check
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Log "Row skipped (ticket $ticket): username '$sam' already exists. Needs human review (rehire? different person?)" 'WARN'
        [pscustomobject]@{ Ticket = $ticket; Name = "$first $last"; SamAccountName = $sam; UPN = $upn
                           Status = 'Skipped'; Notes = 'Username already exists' }
        continue
    }

    # 4/5. Build the account properties
    $params = @{
        Name                  = "$first $last"
        GivenName             = $first
        Surname               = $last
        DisplayName           = "$first $last"
        SamAccountName        = $sam
        UserPrincipalName     = $upn
        Department            = $row.Department
        Title                 = $row.Title
        Description           = "Created $(Get-Date -Format 'yyyy-MM-dd') by onboarding script per $ticket"
        Path                  = $TargetOU
        AccountPassword       = $InitialPassword
        Enabled               = $true
        ChangePasswordAtLogon = $true
    }

    $managerSam = "$($row.Manager)".Trim()
    if ($managerSam) {
        $manager = Get-ADUser -Filter "SamAccountName -eq '$managerSam'"
        if ($manager) {
            $params.Manager = $manager.DistinguishedName
        }
        else {
            Write-Log "Manager '$managerSam' not found for $sam. Account will be created without a manager" 'WARN'
            $notes += "Manager '$managerSam' not found"
        }
    }

    $status = 'WhatIf'
    if ($PSCmdlet.ShouldProcess("$sam ($first $last) in $TargetOU", 'Create AD user')) {
        try {
            New-ADUser @params -ErrorAction Stop
            Write-Log "Created user $sam ($first $last) | $($row.Title), $($row.Department) | ticket $ticket"
            $status = 'Created'
        }
        catch {
            Write-Log "FAILED to create $sam : $($_.Exception.Message)" 'ERROR'
            [pscustomobject]@{ Ticket = $ticket; Name = "$first $last"; SamAccountName = $sam; UPN = $upn
                               Status = 'Failed'; Notes = $_.Exception.Message }
            continue
        }
    }

    # 6. Group membership
    $groupNames = "$($row.Groups)" -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($groupName in $groupNames) {
        $group = Get-ADGroup -Filter "Name -eq '$groupName'"
        if (-not $group) {
            Write-Log "Group '$groupName' does not exist. $sam NOT added (needs follow-up)" 'WARN'
            $notes += "Group '$groupName' not found"
            continue
        }
        if ($PSCmdlet.ShouldProcess("$sam -> $groupName", 'Add to group')) {
            try {
                Add-ADGroupMember -Identity $group -Members $sam -ErrorAction Stop
                Write-Log "Added $sam to $groupName"
            }
            catch {
                Write-Log "FAILED to add $sam to $groupName : $($_.Exception.Message)" 'ERROR'
                $notes += "Failed to add to '$groupName'"
            }
        }
    }

    if ($notes.Count -gt 0 -and $status -eq 'Created') { $status = 'Created with warnings' }

    [pscustomobject]@{ Ticket = $ticket; Name = "$first $last"; SamAccountName = $sam; UPN = $upn
                       Status = $status; Notes = ($notes -join '; ') }
}

# --- Summary ------------------------------------------------------------------------
$results | Export-Csv -Path $resultFile -NoTypeInformation -WhatIf:$false

Write-Log "=== Run finished. Results: $(@($results).Count) row(s) ==="
$results | Group-Object Status | ForEach-Object { Write-Log ("  {0}: {1}" -f $_.Name, $_.Count) }

Write-Host "`nResults table:" -ForegroundColor Cyan
$results | Format-Table Ticket, Name, SamAccountName, Status, Notes -AutoSize
Write-Host "Log file    : $logFile"     -ForegroundColor Cyan
Write-Host "Results CSV : $resultFile`n" -ForegroundColor Cyan
Write-Host 'Attach both files to the ServiceNow catalog task.' -ForegroundColor Cyan
