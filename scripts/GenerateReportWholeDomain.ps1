Import-Module ActiveDirectory

$reportPath = "C:\Users\rawrr\Desktop\scripts\AD_Audit_Report.html"
$daysToExpiration = 14
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days

# 1. Wygasające hasła
$users = Get-ADUser -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false} -Properties PasswordLastSet, DisplayName
$expiringUsers = @()

foreach ($user in $users) {
    if ($user.PasswordLastSet) {
        $expiresOn = $user.PasswordLastSet.AddDays($maxPasswordAge)
        $daysLeft = ($expiresOn - (Get-Date)).Days
        
        if ($daysLeft -le $daysToExpiration -and $daysLeft -ge 0) {
            $expiringUsers += [PSCustomObject]@{
                "Użytkownik"     = $user.DisplayName
                "sAMAccountName" = $user.SamAccountName
                "Data wygaśnięcia" = $expiresOn.ToString("yyyy-MM-dd")
                "Dni do wygaśnięcia" = $daysLeft
            }
        }
    }
}

# 2. Członkowie grupy Domain Admins
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" | Select-Object Name, SamAccountName, objectClass

# 3. Budowanie stylu CSS i struktury HTML
$style = @"
<style>
    body { font-family: Arial, sans-serif; margin: 20px; background-color: #f4f4f9; }
    h2 { color: #333; border-bottom: 2px solid #0056b3; padding-bottom: 5px; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 30px; background: white; }
    th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
    th { background-color: #0056b3; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@

$htmlHeader = "<h1>Raport Audytowy Active Directory - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</h1>"
$htmlExpiring = "<h2>1. Hasła wygasające w ciągu $daysToExpiration dni</h2>" + ($expiringUsers | ConvertTo-Html -Fragment)
$htmlAdmins = "<h2>2. Aktualny skład grupy Domain Admins</h2>" + ($domainAdmins | ConvertTo-Html -Fragment)

# Złożenie i zapis raportu
$finalHtml = ConvertTo-Html -Head $style -Body "$htmlHeader $htmlExpiring $htmlAdmins"
$finalHtml | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "[REPORT] Raport wygenerowany w: $reportPath" -ForegroundColor Green