Import-Module ActiveDirectory

$csvPath = ".\users.csv"
$domainOU = "OU=TestCompany,DC=homelab,DC=local"
$users = Import-Csv -Path $csvPath -Encoding UTF8

# Mapowanie działów na grupy RBAC
$rbacMapping = @{
    "IT"         = "GG_IT"
    "HR"         = "GG_HR"
    "Sales"      = "GG_Sales"
    "Helpdesk"   = "GG_Helpdesk"
    "Accounting" = "GG_Accounting"
	"Management" = "GG_Management"
}

foreach ($user in $users) {
    # Tworzenie loginu
    $baseSam = ($user.FirstName.Substring(0,1) + $user.LastName).ToLower()
    
    # Usunięcie polskich znaków (wielkie i małe litery)
    $plChars  = @('ą','ć','ę','ł','ń','ó','ś','ź','ż','Ą','Ć','Ę','Ł','Ń','Ó','Ś','Ź','Ż')
    $enChars  = @('a','c','e','l','n','o','s','z','z','a','c','e','l','n','o','s','z','z')
    
    for ($j = 0; $j -lt $plChars.Length; $j++) {
        $baseSam = $baseSam -replace $plChars[$j], $enChars[$j]
    }

    $samAccountName = $baseSam
    $baseDisplayName = "$($user.FirstName) $($user.LastName)"
    $displayName = $baseDisplayName
    $i = 1

    # Sprawdzanie unikalności loginu i nazwy wyświetlanej w AD
    while (
        (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) -or 
        (Get-ADUser -Filter "Name -eq '$displayName'" -ErrorAction SilentlyContinue)
    ) {
        $samAccountName = "$baseSam$i"
        $displayName = "$baseDisplayName $i"
        $i++
    }


    # Generowanie UPN
	$alternativeDomain = "recondrone7gmail.onmicrosoft.com"
    $userPrincipalName = "$samAccountName" 
    $forest = Get-ADForest
	$validSuffixes = @($forest.RootDomain) + $forest.UPNSuffixes

	# Sprawdzanie, czy podana domena jest na liście
	if ($validSuffixes -contains $alternativeDomain) {
		$userPrincipalName = "$samAccountName@$alternativeDomain"
		Write-Host "Sukces: Sufiks jest poprawny ($userPrincipalName)" -ForegroundColor Green
    
	
	} else {
		throw "BŁĄD: Sufiks UPN '$alternativeDomain' nie jest zarejestrowany w Active Directory!"
	}
	
    # Tymczasowe bezpieczne hasło
    $securePassword = ConvertTo-SecureString "Start1234!" -AsPlainText -Force
	
	# Sprawdzanie department - czy istnieje takie OU
	$departmentOU = "OU=$($user.Department),$domainOU"
	try {
		$ouCheck = Get-ADOrganizationalUnit -Identity $departmentOU -ErrorAction Stop
	}
	catch {
		Write-Warning "Jednostka organizacyjna dla departamentu '$($user.Department)' nie istnieje w ścieżce: $domainOU"
		return
	}
	
    # Tworzenie konta w AD
    try {
        New-ADUser `
            -SamAccountName $samAccountName `
            -UserPrincipalName $userPrincipalName `
            -Name $displayName `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -DisplayName $displayName `
            -Department $user.Department `
            -Title $user.Title `
            -Path $departmentOU `
            -AccountPassword $securePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop

        Write-Host "[SUCCESS] Utworzono konto: $samAccountName ($displayName) w jednostce organizacyjnej ($ouCheck)" -ForegroundColor Green

        # Przypisywanie do grupy RBAC
        if ($rbacMapping.ContainsKey($user.Department)) {
            $groupName = $rbacMapping[$user.Department]
            Add-ADGroupMember -Identity $groupName -Members $samAccountName -ErrorAction SilentlyContinue
            Write-Host "   -> Dodano do grupy: $groupName" -ForegroundColor Cyan
        }


    }
    catch {
        Write-Host "[ERROR] Błąd podczas tworzenia ${samAccountName}: $_" -ForegroundColor Red
    }
}