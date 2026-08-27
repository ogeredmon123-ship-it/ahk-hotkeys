#Requires AutoHotkey v2.0
#SingleInstance Force

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
DOSSIERS_TELECHARGEMENT := [EnvGet("USERPROFILE") "\OneDrive\Desktop\Google Downloads"
    , EnvGet("USERPROFILE") "\Downloads"]
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
