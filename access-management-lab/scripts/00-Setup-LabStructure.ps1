<#
.SYNOPSIS
    Creates the lab OU structure and security groups used by the onboarding/offboarding scripts.

.DESCRIPTION
    Creates (only if missing):
        OU=LAB
          |- OU=Users      (active employees)
          |- OU=Groups     (security groups)
          \- OU=Disabled   (offboarded accounts)
    and the department / access groups listed in $Groups.
    Safe to run more than once: existing objects are skipped.

.EXAMPLE
    .\00-Setup-LabStructure.ps1 -WhatIf     # preview only, changes nothing
    .\00-Setup-LabStructure.ps1             # create the structure

.NOTES
    Run on the domain controller as a Domain Admin.
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess)]
param()

Import-Module ActiveDirectory -ErrorAction Stop

$domainDN = (Get-ADDomain).DistinguishedName
$rootOU   = "OU=LAB,$domainDN"

# Department groups (DEPT-*) and access groups (ACCESS-*)
$Groups = [ordered]@{
    'DEPT-IT'            = 'Department: IT'
    'DEPT-HR'            = 'Department: Human Resources'
    'DEPT-Sales'         = 'Department: Sales'
    'DEPT-Finance'       = 'Department: Finance'
    'ACCESS-VPN'         = 'Access: remote VPN'
    'ACCESS-SharedDrive' = 'Access: department shared drive'
    'ACCESS-CRM'         = 'Access: CRM application'
}
# NOTE: ACCESS-Payroll is intentionally NOT created. The sample CSV requests it
# so you can test the "requested group does not exist" exception.

function Test-OUExists {
    param([string]$DistinguishedName)
    try {
        Get-ADOrganizationalUnit -Identity $DistinguishedName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# --- 1. Root OU ---------------------------------------------------------------
if (Test-OUExists $rootOU) {
    Write-Host "Exists : $rootOU"
}
elseif ($PSCmdlet.ShouldProcess($rootOU, 'Create OU')) {
    New-ADOrganizationalUnit -Name 'LAB' -Path $domainDN -ProtectedFromAccidentalDeletion $true
    Write-Host "Created: $rootOU" -ForegroundColor Green
}

# --- 2. Child OUs -------------------------------------------------------------
foreach ($ouName in 'Users', 'Groups', 'Disabled') {
    $ouDN = "OU=$ouName,$rootOU"
    if (Test-OUExists $ouDN) {
        Write-Host "Exists : $ouDN"
    }
    elseif ($PSCmdlet.ShouldProcess($ouDN, 'Create OU')) {
        New-ADOrganizationalUnit -Name $ouName -Path $rootOU -ProtectedFromAccidentalDeletion $true
        Write-Host "Created: $ouDN" -ForegroundColor Green
    }
}

# --- 3. Security groups -------------------------------------------------------
$groupsOU = "OU=Groups,$rootOU"
foreach ($name in $Groups.Keys) {
    if (Get-ADGroup -Filter "Name -eq '$name'") {
        Write-Host "Exists : group $name"
    }
    elseif ($PSCmdlet.ShouldProcess($name, "Create security group in $groupsOU")) {
        New-ADGroup -Name $name -SamAccountName $name -GroupScope Global -GroupCategory Security `
            -Path $groupsOU -Description $Groups[$name]
        Write-Host "Created: group $name" -ForegroundColor Green
    }
}

Write-Host "`nDone. Open 'Active Directory Users and Computers' (dsa.msc) to check the LAB OU." -ForegroundColor Cyan
