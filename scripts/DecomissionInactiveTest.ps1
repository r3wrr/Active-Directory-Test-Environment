Import-Module ActiveDirectory

$daysInactive = -1
$timeSpan = (Get-Date).AddDays(-$daysInactive)
$disabledOU = "OU=DisabledUsers,DC=twoja,DC=domena"

# Zdefiniowanie OU, które ma być przeszukiwane
$targetOU = "OU=TestCompany,DC=homelab,DC=local"

# Pobranie użytkowników nieaktywnych tylko z wybranego OU
$inactiveUsers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $targetOU -Properties LastLogonDate, Created | Where-Object {
    ($_.LastLogonDate -and $_.LastLogonDate -lt $timeSpan) -or 
    (-not $_.LastLogonDate -and $_.Created -lt $timeSpan)
}

$inactiveUsers | Format-Table Name, SamAccountName, LastLogonDate, Created -AutoSize