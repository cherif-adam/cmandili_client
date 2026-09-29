# =============================================================================
# CMANDILI -- Sortir la boutique "cadeau" / Charlot du compte admin
#
# Cree charlot@gmail.com (adresse marquee confirmee, aucun mail envoye) et
# lui transfere la boutique, son portefeuille et son releve.
#
# LE COMPTE ADMIN N'EST NI RENOMME NI REMOT-DE-PASSE. ademcherif209@gmail.com
# garde son email, son mot de passe, son id, ses droits d'administration, ses
# 2 commandes client et sa ligne livreur "rafik2".
#
# -- CE QUI EST ATTACHE AU COMPTE PARTAGE (releve du 30/09) -------------------
#
#   role        preuve                                   activite
#   admin       profiles.is_admin = true                 --
#   partenaire  partners -> vendors 134dd418 "cadeau"    0 commande recue
#   livreur     drivers "rafik2"                         0 course, 0 livraison
#   client      orders.user_id                           2 commandes
#   argent      wallets 50.000 DT + 1 settlement         entity_type=restaurant
#
# Le portefeuille et le releve appartiennent au PARTENAIRE : le releve porte
# entity_type = 'restaurant' et la mention "Test top-up". Ils suivent donc la
# boutique. Les laisser derriere donnerait une boutique a solde nul, et
# enforce_prepaid_block la bloquerait des la premiere commande.
#
# La ligne livreur "rafik2" N'EST PAS deplacee : elle n'a jamais servi, et
# vous n'avez pas demande de la bouger. A supprimer ou a deplacer plus tard,
# c'est votre decision.
#
# -- CE QUE LE SCRIPT FAIT ----------------------------------------------------
#
#   1. Cree charlot@gmail.com               (API admin, email_confirm = true)
#   2. partners.user_id      -> nouveau compte
#   3. vendors.owner_id      -> nouveau compte   (cette boutique est la SEULE
#                                                 des 20 a porter un owner_id,
#                                                 et il pointe sur l'admin)
#   4. wallets.user_id       -> nouveau compte
#   5. settlements.user_id   -> nouveau compte
#
# Rien n'est supprime. Si une etape echoue, les precedentes restent faites :
# le script affiche ou il s'est arrete pour que la reprise soit evidente.
#
# -- UTILISATION --------------------------------------------------------------
#
#   .\20260930_split_partner_from_admin.ps1 -WhatIf    <-- simulation, d'abord
#   .\20260930_split_partner_from_admin.ps1            <-- pour de vrai
#
# Le mot de passe n'est pas dans ce fichier : il est demande a l'execution.
# =============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$EnvFile,
    [string]$NouvelEmail = 'charlot@gmail.com'
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot n'est pas encore renseigne dans le bloc param() sous
# PowerShell 5.1 : on resout le chemin ici.
if (-not $EnvFile) {
    $racine = $PSScriptRoot
    if (-not $racine) { $racine = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $EnvFile = Join-Path $racine '..\..\cmandili_admin\.env.local'
}

# -- Valeurs figees, relues depuis la base le 30/09 --------------------------
$adminId   = 'be0f6629-0f37-4112-ab8c-d717031f5d9e'   # ademcherif209@gmail.com
$adminMail = 'ademcherif209@gmail.com'
$vendorId  = '134dd418-d329-49d9-88ad-45d33741f44d'   # boutique "cadeau" / Charlot

# Filet : ce script ne doit jamais toucher a l'adresse de l'admin.
if ($NouvelEmail -eq $adminMail) {
    throw "Le nouvel email est celui de l'admin. Arret."
}

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

$headers = @{
    apikey         = $key
    Authorization  = "Bearer $key"
    'Content-Type' = 'application/json'
}

# -- Etat avant, relu en direct ----------------------------------------------
Write-Host ""
Write-Host "Etat actuel" -ForegroundColor Cyan

function Get-Rest($chemin) {
    return Invoke-RestMethod -Method Get -Uri "$url/rest/v1/$chemin" -Headers $headers
}

$partenaire = Get-Rest "partners?user_id=eq.$adminId&select=id,business_name,entity_id,partner_type"
if (-not $partenaire) { throw "Aucune ligne partners sur le compte admin. Rien a deplacer." }
if ($partenaire.Count -gt 1) { throw "Le compte admin porte $($partenaire.Count) boutiques. Arret : ce script en deplace une seule." }
if ($partenaire[0].entity_id -ne $vendorId) {
    throw "La boutique du compte admin ($($partenaire[0].entity_id)) n'est pas celle attendue ($vendorId). Arret."
}

$portefeuille = Get-Rest "wallets?user_id=eq.$adminId&select=id,balance,status"
$releves      = Get-Rest "settlements?user_id=eq.$adminId&select=id,amount,entity_type,type"

Write-Host ("  boutique      : {0}  ({1})" -f $partenaire[0].business_name, $partenaire[0].partner_type)
Write-Host ("  portefeuille  : {0} ligne(s), solde {1}" -f $portefeuille.Count, $(if ($portefeuille) { $portefeuille[0].balance } else { '-' }))
Write-Host ("  releves       : {0} ligne(s)" -f $releves.Count)
Write-Host ""

# -- Le mot de passe, saisi ici et nulle part ailleurs ------------------------
# En -WhatIf on ne demande rien : la simulation n'ecrit pas.
$password = $null
if (-not $WhatIfPreference) {
    $secure = Read-Host -AsSecureString "Mot de passe du nouveau compte $NouvelEmail (min. 8 caracteres)"
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    if ($password.Length -lt 8) { throw "Mot de passe trop court : Supabase en exige 8 au minimum." }
}

# -- 1. Le compte ------------------------------------------------------------
$nouvelId = $null

$existant = Invoke-RestMethod -Method Get `
    -Uri "$url/auth/v1/admin/users?filter=$([uri]::EscapeDataString($NouvelEmail))" `
    -Headers $headers
if ($existant.users -and $existant.users.Count -gt 0) {
    $nouvelId = $existant.users[0].id
    Write-Host ("  Compte deja existant : {0}  ({1})" -f $NouvelEmail, $nouvelId) -ForegroundColor Yellow
}

if (-not $nouvelId) {
    if ($PSCmdlet.ShouldProcess($NouvelEmail, 'Creer le compte (email confirme, aucun mail envoye)')) {
        # email_confirm = true : l'adresse est marquee verifiee, aucun mail de
        # confirmation n'est envoye et le compte est utilisable tout de suite.
        $body = @{
            email         = $NouvelEmail
            password      = $password
            email_confirm = $true
        } | ConvertTo-Json -Compress

        $cree = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/admin/users" `
            -Headers $headers -Body $body
        $nouvelId = $cree.id
        Write-Host ("  OK    compte cree : {0}  ({1})" -f $NouvelEmail, $nouvelId) -ForegroundColor Green
    } else {
        Write-Host "  (simulation) le compte serait cree, puis les 4 transferts ci-dessous." -ForegroundColor DarkGray
    }
}

# -- 2 a 5. Les transferts ---------------------------------------------------
# Chacun est cible par la valeur ACTUELLE (user_id = admin), donc rejouer le
# script apres un transfert reussi ne fait rien : il n'y a plus de ligne a
# deplacer. C'est ce qui rend une reprise apres echec sans danger.
function Move-Ligne($table, $filtre, $corps, $libelle) {
    if (-not $PSCmdlet.ShouldProcess($libelle, "Transferer vers $NouvelEmail")) { return }
    if (-not $nouvelId) { Write-Host "  (simulation) $libelle" -ForegroundColor DarkGray; return }

    $h = $headers.Clone()
    $h['Prefer'] = 'return=representation'
    try {
        $r = Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/$table`?$filtre" `
            -Headers $h -Body $corps
        Write-Host ("  OK    {0} -- {1} ligne(s)" -f $libelle, @($r).Count) -ForegroundColor Green
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        Write-Host ("  ECHEC {0}  --  {1}" -f $libelle, $detail) -ForegroundColor Red
        throw
    }
}

$versNouveau = @{ user_id  = $nouvelId } | ConvertTo-Json -Compress
$versOwner   = @{ owner_id = $nouvelId } | ConvertTo-Json -Compress

Move-Ligne 'partners'    "user_id=eq.$adminId"  $versNouveau 'la boutique (partners)'
Move-Ligne 'vendors'     "id=eq.$vendorId"      $versOwner   'la fiche boutique (vendors.owner_id)'
Move-Ligne 'wallets'     "user_id=eq.$adminId"  $versNouveau 'le portefeuille (50.000 DT)'
Move-Ligne 'settlements' "user_id=eq.$adminId"  $versNouveau 'le releve'

# -- Verification ------------------------------------------------------------
$password = $null

if ($WhatIfPreference) {
    Write-Host ""
    Write-Host "Simulation terminee. Rien n'a ete modifie." -ForegroundColor Cyan
    return
}

Write-Host ""
Write-Host "Verification" -ForegroundColor Cyan

$resteAdmin = @(Get-Rest "partners?user_id=eq.$adminId&select=id").Count `
            + @(Get-Rest "wallets?user_id=eq.$adminId&select=id").Count `
            + @(Get-Rest "settlements?user_id=eq.$adminId&select=id").Count
$chezCharlot = @(Get-Rest "partners?user_id=eq.$nouvelId&select=id,business_name")

Write-Host ("  lignes partenaire restees sur l'admin : {0}   (attendu 0)" -f $resteAdmin)
Write-Host ("  boutique sur {0} : {1}" -f $NouvelEmail, $(if ($chezCharlot) { $chezCharlot[0].business_name } else { 'AUCUNE' }))

$admin = Invoke-RestMethod -Method Get -Uri "$url/auth/v1/admin/users/$adminId" -Headers $headers
Write-Host ("  email admin inchange : {0}   (attendu {1})" -f $admin.email, $adminMail)

Write-Host ""
Write-Host "Connectez-vous a l'app partenaire avec $NouvelEmail et le mot de passe saisi."
Write-Host "Le compte admin garde ses 2 commandes client et sa ligne livreur 'rafik2'."
