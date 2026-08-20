# Wykrywanie i wyłączanie kont nieaktywnych przez ponad 90 dni w OU testowym
$TargetOU = "OU=Testing,OU=Users,DC=lab,DC=local"
$DaysInactive = 90
$TimeSpan = (Get-Date).AddDays(-$DaysInactive)

Get-ADUser -SearchBase $TargetOU -Filter {LastLogonDate -lt $TimeSpan -and Enabled -eq $true} | 
    Disable-ADUser -PassThru | 
    Set-ADUser -Description "Konto wyłączone automatycznie z powodu braku aktywności ($TimeSpan)"