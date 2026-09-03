Import-Module ActiveDirectory

$daysInactive = 60
$timeSpan = (Get-Date).AddDays(-$daysInactive)
$disabledOU = "OU=DisabledUsers,OU=TestCompany,DC=homelab,DC=local"

# Zdefiniowanie OU, które ma być przeszukiwane
$targetOU = "OU=TestCompany,DC=homelab,DC=local"

# Pobranie użytkowników nieaktywnych tylko z wybranego OU
$inactiveUsers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $targetOU -Properties LastLogonDate, Created | Where-Object {
    ($_.LastLogonDate -and $_.LastLogonDate -lt $timeSpan) -or 
    (-not $_.LastLogonDate -and $_.Created -lt $timeSpan)
}

foreach ($user in $inactiveUsers) {
    # Zabezpieczenie przed wyłączeniem kont systemowych/administratora
    if ($user.SamAccountName -in @("Administrator", "krbtgt", "rawrr", "rawrrGuest", "Guest")) { continue }

    try {
        # 1. Wyłączenie konta
        Get-ADUser -Identity $user.SamAccountName | Disable-ADAccount
        
        # 2. Przeniesienie do OU Disabled_Users
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU
        
        # 3. Ustawienie opisu z datą deaktywacji
        Set-ADUser -Identity $user.SamAccountName -Description "Wyłączone z powodu braku aktywności w dniu $(Get-Date -Format 'yyyy-MM-dd')"
        
        Write-Host "[OFFBOARDING] Wyłączono i przeniesiono konto: $($user.SamAccountName)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "[ERROR] Błąd przetwarzania $($user.SamAccountName): $_" -ForegroundColor Red
    }
}