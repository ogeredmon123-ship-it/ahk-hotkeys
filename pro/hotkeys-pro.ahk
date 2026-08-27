#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; HOTKEYS OFFICINE — version PRO (poste de travail en pharmacie)
; Un seul fichier, 8 raccourcis, tous en DOUBLE APPUI RAPIDE
; (deux Ctrl+X en < 0,5 s). Un seul appui = comportement natif.
;
;   Double Ctrl+C → recherche Google du texte copié
;   Double Ctrl+G → boîte de saisie → Google (vide = google.com)
;   Double Ctrl+U → boîte de saisie → YouTube
;   Double Ctrl+T → ouvre Theriaque (page recherche simple)
;   Double Ctrl+M → ouvre Meddispar
;   Double Ctrl+O → capture d'écran → PNG horodaté + nom patient (CaptOrdo)
;   Double Ctrl+D → rapatrie le dernier téléchargement dans CaptOrdo
;   Double Ctrl+I → injecte le dernier fichier CaptOrdo dans la boîte « Ouvrir »
;
; Aucun chemin en dur (A_MyDocuments / A_UserProfile). Données patients
; dans Documents\CaptOrdo, local, purgées après PURGE_JOURS jours.
; ============================================================


; ============================================================
; PARTIE 1 — Flux ordonnances / mutuelles → logiciel officine (O, D, I)
; ============================================================

; ============================================================
; Flux ordonnances / cartes mutuelle → logiciel officine
;
; Double Ctrl+O → capture une zone de l'écran (ordo/mutuelle affichée
;                 dans Doctolib, la messagerie…), demande le nom du
;                 patient, enregistre en PNG dans le dossier CaptOrdo.
; Double Ctrl+D → rapatrie le DERNIER fichier téléchargé (PDF/JPG reçu
;                 par mail ou Doctolib) dans CaptOrdo, renommé pareil.
; Double Ctrl+I → boîte « Ouvrir » active (LGO, upload site) : insère le
;                 chemin du fichier le plus récent de CaptOrdo + Entrée.
;                 Sinon : copie ce chemin et ouvre l'Explorateur dessus
;                 (pour glisser-déposer).
; Un seul appui = comportement natif, renvoyé après 350 ms.
; ============================================================

DOSSIER := A_MyDocuments "\CaptOrdo"             ; local, hors OneDrive (données patients)
; Chrome télécharge dans « Google Downloads » (réglage Chrome), les autres apps dans Downloads
DOSSIERS_TELECHARGEMENT := [A_UserProfile "\OneDrive\Desktop\Google Downloads"
    , A_UserProfile "\Downloads"]
PURGE_JOURS := 30                                ; au-delà → corbeille au lancement ; 0 = désactivé

DirCreate DOSSIER

if (PURGE_JOURS > 0) {
    seuil := DateAdd(A_Now, -PURGE_JOURS, "Days")
    Loop Files DOSSIER "\*.*" {
        if (A_LoopFileTimeModified < seuil)
            try FileRecycle A_LoopFileFullPath
    }
}

; ---------- Double Ctrl+O : capture → PNG nommé ----------
oPending := false

$^o:: {
    global oPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (oPending) {
        SetTimer(SendNativeCtrlO, 0)
        oPending := false
        CaptureOrdo()
    } else {
        oPending := true
        SetTimer(SendNativeCtrlO, -350)
    }
}

SendNativeCtrlO() {
    global oPending
    oPending := false
    Send "^o"
}

CaptureOrdo() {
    KeyWait "Ctrl"
    A_Clipboard := ""          ; vide le presse-papiers pour détecter la nouvelle image
    Send "#+s"                 ; outil Capture d'écran Windows (sélection de zone)
    if !ClipWait(45, 1) {
        Notif("Capture non détectée — rien d'enregistré")
        return
    }
    if !DllCall("IsClipboardFormatAvailable", "UInt", 8) {  ; 8 = CF_DIB
        Notif("Le presse-papiers ne contient pas d'image")
        return
    }
    ib := InputBox("Nom du patient (vide = horodatage seul) :", "Enregistrer la capture", "w380 h130")
    if (ib.Result != "OK")
        return
    nom := NettoyerNom(ib.Value)
    chemin := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") ".png"
    if SauverPngPressePapiers(chemin)
        Notif("Enregistré : " NomFichier(chemin))
    else
        Notif("Échec de l'enregistrement")
}

; Sauvegarde l'image du presse-papiers en PNG (GDI+ via PowerShell, pas de lib externe)
SauverPngPressePapiers(chemin) {
    psCmd := "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
        . "$img = [System.Windows.Forms.Clipboard]::GetImage(); "
        . "if ($img -eq $null) { exit 1 }; "
        . "$img.Save('" chemin "', [System.Drawing.Imaging.ImageFormat]::Png); exit 0"
    code := RunWait('powershell.exe -NoProfile -STA -Command "' psCmd '"', , "Hide")
    return (code = 0) && FileExist(chemin)
}

; ---------- Double Ctrl+D : dernier téléchargement → CaptOrdo ----------
dPending := false

$^d:: {
    global dPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {
        last := now
        return
    }
    last := now
    if (dPending) {
        SetTimer(SendNativeCtrlD, 0)
        dPending := false
        RapatrierDernierTelechargement()
    } else {
        dPending := true
        SetTimer(SendNativeCtrlD, -350)
    }
}

SendNativeCtrlD() {
    global dPending
    dPending := false
    Send "^d"
}

RapatrierDernierTelechargement() {
    src := DernierFichier(DOSSIERS_TELECHARGEMENT)
    if (src = "") {
        Notif("Aucun fichier dans les dossiers de téléchargement")
        return
    }
    ib := InputBox("Fichier : " NomFichier(src) "`n`nNom du patient (vide = horodatage seul) :"
        , "Rapatrier le dernier téléchargement", "w420 h160")
    if (ib.Result != "OK")
        return
    nom := NettoyerNom(ib.Value)
    SplitPath src, , , &ext
    dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") "." ext
    try {
        FileMove src, dest
        Notif("Rapatrié : " NomFichier(dest))
    } catch {
        Notif("Échec — fichier verrouillé ou déjà déplacé")
    }
}

; ---------- Double Ctrl+I : import dans la boîte « Ouvrir » active ----------
iPending := false

$^i:: {
    global iPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {
        last := now
        return
    }
    last := now
    if (iPending) {
        SetTimer(SendNativeCtrlI, 0)
        iPending := false
        ImporterDernierFichier()
    } else {
        iPending := true
        SetTimer(SendNativeCtrlI, -350)
    }
}

SendNativeCtrlI() {
    global iPending
    iPending := false
    Send "^i"
}

ImporterDernierFichier() {
    dernier := DernierFichier(DOSSIER)
    if (dernier = "") {
        Run 'explorer.exe "' DOSSIER '"'
        Notif("Dossier CaptOrdo vide — rien à importer")
        return
    }
    KeyWait "Ctrl"
    if WinActive("ahk_class #32770") {  ; boîte de dialogue Ouvrir/Enregistrer standard
        try {
            ControlFocus "Edit1", "A"
            ControlSetText dernier, "Edit1", "A"
            Sleep 120
            ControlSend "{Enter}", "Edit1", "A"
            return
        }
        ; contrôle introuvable → repli presse-papiers ci-dessous
    }
    ; copie le FICHIER (comme Ctrl+C dans l'Explorateur) → Ctrl+V le joint dans
    ; Gmail, Doctolib, WhatsApp Web… ; l'Explorateur s'ouvre en plus pour le glisser-déposer
    RunWait('powershell.exe -NoProfile -STA -Command "Set-Clipboard -LiteralPath ' "'" dernier "'" '"', , "Hide")
    Run 'explorer.exe /select,"' dernier '"'
    Notif("Fichier copié — Ctrl+V pour le joindre (ou glisser depuis l'Explorateur)")
}

; ---------- Utilitaires ----------

; Fichier le plus récent d'un ou plusieurs dossiers (ignore téléchargements en cours et fichiers système)
DernierFichier(dossiers) {
    if !(dossiers is Array)
        dossiers := [dossiers]
    meilleur := "", meilleurTime := 0
    for dossier in dossiers {
        Loop Files dossier "\*.*" {
            if (A_LoopFileExt ~= "i)^(crdownload|tmp|partial|ini)$")
                continue
            if (A_LoopFileTimeModified > meilleurTime) {
                meilleurTime := A_LoopFileTimeModified
                meilleur := A_LoopFileFullPath
            }
        }
    }
    return meilleur
}

; Nom compatible chemin de fichier : caractères interdits retirés, espaces → tirets
NettoyerNom(s) {
    s := Trim(s)
    s := RegExReplace(s, '[\\/:*?"<>|]', "")
    s := RegExReplace(s, "['’]", " ")
    s := RegExReplace(s, "\s+", "-")
    return s
}

NomFichier(chemin) {
    SplitPath chemin, &n
    return n
}

Notif(txt) {
    ToolTip txt
    SetTimer () => ToolTip(), -3500
}

; ============================================================
; PARTIE 2 — Recherche (C, G, U, T, M)
; ============================================================

; Double appui rapide sur Ctrl+C → recherche Google du texte copié.
; Un seul Ctrl+C = copie normale, comportement inchangé.
~^c:: {
    static last := 0
    now := A_TickCount
    gap := now - last
    last := now
    if (gap > 120 && gap < 500) {
        last := 0
        Sleep 100
        q := Trim(A_Clipboard)
        if (q = "")
            return
        Run "https://www.google.com/search?q=" . UrlEncode(q)
    }
}

; Double appui rapide sur Ctrl+G → boîte de saisie flottante :
;   Entrée avec du texte  → recherche Google dans le navigateur
;   Entrée champ vide     → ouvre Google Chrome sur google.com
;   Échap                 → annuler
; Un seul Ctrl+G = comportement natif, renvoyé après 350 ms.
gPending := false

$^g:: {
    global gPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (gPending) {
        SetTimer(SendNativeCtrlG, 0)
        gPending := false
        ShowGoogleBox()
    } else {
        gPending := true
        SetTimer(SendNativeCtrlG, -350)
    }
}

SendNativeCtrlG() {
    global gPending
    gPending := false
    Send "^g"
}

ShowGoogleBox() {
    static box := 0, champ := 0
    if !box {
        box := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Recherche Google")
        box.SetFont("s11")
        champ := box.Add("Edit", "w420")
        box.Add("Button", "Default Hidden", "OK").OnEvent("Click", (*) => GoogleBoxSubmit(box, champ))
        box.OnEvent("Escape", (*) => box.Hide())
        box.OnEvent("Close", (*) => box.Hide())
    }
    champ.Value := ""
    box.Show("AutoSize Center")
    champ.Focus()
}

GoogleBoxSubmit(box, champ) {
    q := Trim(champ.Value)
    box.Hide()
    if (q = "")
        Run "https://www.google.com/"  ; champ vide = ouvre Google dans le navigateur par défaut
    else
        Run "https://www.google.com/search?q=" . UrlEncode(q)
}

; Double appui rapide sur Ctrl+U → boîte de saisie flottante : tape ta requête,
; Entrée = recherche YouTube dans le navigateur, Échap = annuler.
; Un seul Ctrl+U = comportement natif (souligner…), renvoyé après 350 ms.
uPending := false

$^u:: {
    global uPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (uPending) {
        SetTimer(SendNativeCtrlU, 0)
        uPending := false
        ShowYoutubeBox()
    } else {
        uPending := true
        SetTimer(SendNativeCtrlU, -350)
    }
}

SendNativeCtrlU() {
    global uPending
    uPending := false
    Send "^u"
}

ShowYoutubeBox() {
    static box := 0, champ := 0
    if !box {
        box := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Recherche YouTube")
        box.SetFont("s11")
        champ := box.Add("Edit", "w420")
        box.Add("Button", "Default Hidden", "OK").OnEvent("Click", (*) => YoutubeBoxSubmit(box, champ))
        box.OnEvent("Escape", (*) => box.Hide())
        box.OnEvent("Close", (*) => box.Hide())
    }
    champ.Value := ""
    box.Show("AutoSize Center")
    champ.Focus()
}

YoutubeBoxSubmit(box, champ) {
    q := Trim(champ.Value)
    box.Hide()
    if (q != "")
        Run "https://www.youtube.com/results?search_query=" . UrlEncode(q)
}

; Double appui rapide sur Ctrl+T → ouvre THERIAQUE sur la page de recherche simple.
; Pas de boîte de saisie, pas de saisie automatisée : Theriaque est sous authentification
; et n'expose AUCUNE URL de recherche en GET (le serveur répond « Vous n'êtes pas
; autorisé… » hors session). Le collage automatique dans la page a été tenté puis
; abandonné (2026-07-22) — n'atterrissait pas dans le champ, avec ou sans {Tab}.
; On ouvre la page, le terme se tape à la main.
; Un seul Ctrl+T = nouvel onglet natif, renvoyé après DELAI ms.
$^t:: TheriaqueTap()

TheriaqueTap(natif := false) {
    static DELAI := 300  ; ms d'attente avant de rendre Ctrl+T natif
    static last := 0, pending := false
    if (natif) {
        pending := false
        Send "^t"
        return
    }
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (pending) {
        SetTimer(TheriaqueTapNatif, 0)
        pending := false
        Run "https://www.theriaque.org/apps/recherche/rch_simple.php"
    } else {
        pending := true
        SetTimer(TheriaqueTapNatif, -DELAI)
    }
}

TheriaqueTapNatif() => TheriaqueTap(true)

; Double appui rapide sur Ctrl+M → ouvre MEDDISPAR (médicaments à dispensation
; particulière, Ordre des pharmaciens) dans un onglet du navigateur.
; Pas de boîte de saisie : ouverture directe, comme Theriaque.
; Un seul Ctrl+M = comportement natif, renvoyé après DELAI ms.
$^m:: MeddisparTap()

MeddisparTap(natif := false) {
    static DELAI := 300  ; ms d'attente avant de rendre Ctrl+M natif
    static last := 0, pending := false
    if (natif) {
        pending := false
        Send "^m"
        return
    }
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (pending) {
        SetTimer(MeddisparTapNatif, 0)
        pending := false
        Run "https://www.meddispar.fr/"
    } else {
        pending := true
        SetTimer(MeddisparTapNatif, -DELAI)
    }
}

MeddisparTapNatif() => MeddisparTap(true)

; ---------- Utilitaire ----------

UrlEncode(str) {
    buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, buf, "UTF-8")
    out := ""
    Loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        c := Chr(b)
        out .= (c ~= "[0-9A-Za-z\-_.~]") ? c : Format("%{:02X}", b)
    }
    return out
}
