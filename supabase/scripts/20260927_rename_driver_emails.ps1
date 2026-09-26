# =============================================================================
# CMANDILI -- Basculer les comptes livreurs de test sur des alias Gmail
#
# Remplace l'email de chaque livreur par ademcherif209+<nom>@gmail.com, le
# marque confirme, et pose le meme mot de passe partout. Aucune suppression :
# les comptes gardent leur id, donc leurs commandes, leur portefeuille et leur
# historique (drive@gmail.com a 11 commandes, driver@test.com en a 19,
# adem@gmail.com 31).
#
# Les alias "+" de Gmail arrivent tous dans la meme boite, donc les emails de
# reinitialisation vous parviendront desormais.
#
# EXCLU VOLONTAIREMENT : ademcherif209@gmail.com. Ce compte a AUSSI une ligne
# drivers (profil "rafik2"), il apparaitrait donc naturellement dans cette
# liste -- c'est votre compte admin, il n'y figure pas.
#
# Le mot de passe n'est pas dans ce fichier : il est demande a l'execution.
#
#   .\20260927_rename_driver_emails.ps1
#
# Ajoutez -WhatIf pour voir ce qui serait fait sans rien modifier.
# =============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot n'est pas encore renseigne dans le bloc param() sous
# PowerShell 5.1 : on resout le chemin ici.
if (-not $EnvFile) {
    $racine = $PSScriptRoot
    if (-not $racine) { $racine = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $EnvFile = Join-Path $racine '..\..\cmandili_admin\.env.local'
}

# -- Correspondance figee, relue depuis la base le 27/09 ----------------------
# Le compte qui porte le plus de commandes garde l'alias simple ; les homonymes
# recoivent un numero (adem2, firas2).
$mapping = @(
    @{ id = 'b3bf7e4b-307d-4892-8883-586605eb5222'; ancien = 'amin2212@gmail.co';  nouveau = 'ademcherif209+aamin@gmail.com' }
    @{ id = '57640370-a641-469c-aeb9-3193a25d3859'; ancien = 'adam@gmail.com';     nouveau = 'ademcherif209+adam@gmail.com' }
    @{ id = '59b8262a-06d6-4bbd-9d66-dc10942188e7'; ancien = 'adem@gmail.com';     nouveau = 'ademcherif209+adem@gmail.com' }
    @{ id = 'e24c65e6-3022-4765-81dd-62f5c801623f'; ancien = 'adem1@gmail.com';    nouveau = 'ademcherif209+adem2@gmail.com' }
    @{ id = '8fbe55e5-11d8-47aa-a3da-884803a8c8c6'; ancien = 'akil1@gmail.com';    nouveau = 'ademcherif209+akil@gmail.com' }
    @{ id = 'a562a94f-8a91-4d12-9d04-ab0d848e88d3'; ancien = 'aymen@gmail.com';    nouveau = 'ademcherif209+aymen@gmail.com' }
    @{ id = 'fe291537-4377-41da-a9a3-2065eaca1912'; ancien = 'drive@gmail.com';    nouveau = 'ademcherif209+drive@gmail.com' }
    @{ id = 'c3d0baf0-9d49-47ef-b3b0-79073873ae6d'; ancien = 'driver@test.com';    nouveau = 'ademcherif209+driver@gmail.com' }
    @{ id = '06cef32c-511e-48e1-804e-458882a077a7'; ancien = 'firas1@gmail.com';   nouveau = 'ademcherif209+firas@gmail.com' }
    @{ id = '6cee3137-dc78-41ed-b974-88df3466ade8'; ancien = 'firas123@gmail.com'; nouveau = 'ademcherif209+firas2@gmail.com' }
    @{ id = '938a6dd4-fd90-4bc0-bddd-76bb5830d09f'; ancien = 'moetez2@gmail.com';  nouveau = 'ademcherif209+moetzzz@gmail.com' }
    @{ id = '673a54da-de3c-4989-ba32-7797b16a364a'; ancien = 'rafik2@gmail.co';    nouveau = 'ademcherif209+rafik@gmail.com' }
)

# Filet : aucun id de cette liste ne doit etre le compte admin.
$adminGuard = $mapping | Where-Object { $_.ancien -eq 'ademcherif209@gmail.com' }
if ($adminGuard) { throw "Le compte admin figure dans la liste. Arret." }

# -- Lecture des secrets depuis .env.local (rien a coller) --------------------
if (-not (Test-Path $EnvFile)) { throw "Fichier introuvable : $EnvFile" }

$conf = @{}
foreach ($line in Get-Content $EnvFile) {
    if ($line -match '^\s*#') { continue }
    if ($line -notmatch '=') { continue }
    $i = $line.IndexOf('=')
    $conf[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
}

$url = $conf['NEXT_PUBLIC_SUPABASE_URL']
$key = $conf['SUPABASE_SERVICE_ROLE_KEY']
if (-not $url -or -not $key) { throw "SUPABASE_URL ou SERVICE_ROLE_KEY absent de $EnvFile" }

# -- Le mot de passe, saisi ici et nulle part ailleurs ------------------------
# En -WhatIf on ne demande rien : la simulation n'ecrit pas, elle n'a pas
# besoin du mot de passe.
$password = $null
if (-not $WhatIfPreference) {
    $secure = Read-Host -AsSecureString "Mot de passe a poser sur les $($mapping.Count) comptes (min. 8 caracteres)"
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    if ($password.Length -lt 8) { throw "Mot de passe trop court : Supabase en exige 8 au minimum." }
}

$headers = @{
    apikey        = $key
    Authorization = "Bearer $key"
    'Content-Type' = 'application/json'
}

$ok = 0
$ko = 0

foreach ($m in $mapping) {
    $cible = "$($m.ancien)  ->  $($m.nouveau)"

    if (-not $PSCmdlet.ShouldProcess($cible, 'Changer email + mot de passe')) { continue }

    # email_confirm = true : l'adresse est marquee verifiee, aucun mail de
    # confirmation n'est envoye et le compte reste utilisable immediatement.
    $body = @{
        email         = $m.nouveau
        email_confirm = $true
        password      = $password
    } | ConvertTo-Json -Compress

    try {
        $null = Invoke-RestMethod -Method Put `
            -Uri "$url/auth/v1/admin/users/$($m.id)" `
            -Headers $headers -Body $body
        Write-Host ("  OK    " + $cible) -ForegroundColor Green
        $ok++
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        Write-Host ("  ECHEC " + $cible + "  --  " + $detail) -ForegroundColor Red
        $ko++
    }
}

$password = $null
Write-Host ""
Write-Host "$ok compte(s) modifie(s), $ko echec(s)."
Write-Host "Connectez-vous ensuite avec le nouvel email et ce mot de passe."
