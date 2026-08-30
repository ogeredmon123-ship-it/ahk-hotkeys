#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <UIA>   ; UI Automation (Lib\UIA.ahk, Descolada/UIA-v2, MIT) — clic sur « Télécharger » pour Ctrl+D

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
; Aucun chemin en dur (A_MyDocuments / EnvGet("USERPROFILE")). Données patients
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
; Double Ctrl+D → télécharge le document AFFICHÉ (aperçu Gmail,
;                 WhatsApp Web, Doctolib, image/PDF dans un onglet) dans
;                 CaptOrdo, nommé pareil — en cliquant lui-même Télécharger
;                 (UI Automation) ou par Ctrl+S. Échec → message → Ctrl+O.
; Double Ctrl+I → boîte « Ouvrir » active (LGO, upload site) : insère le
;                 chemin du fichier le plus récent de CaptOrdo + Entrée.
;                 Sinon : copie ce fichier (et l'image, si c'est une capture)
;                 dans le presse-papiers et le colle dans la fenêtre active.
; Un seul appui = comportement natif, renvoyé après 350 ms.
; ============================================================

DOSSIER := EnvGet("USERPROFILE") "\Documents\CaptOrdo"   ; Documents LOCAL du compte, jamais OneDrive (données patients)
; Dossiers où le navigateur dépose ses téléchargements, résolus au lancement (voir DossiersTelechargement) :
; « Téléchargements » réel de Windows, Downloads, « Google Downloads », dossiers de téléchargement et
; d'« Enregistrer sous » de Chrome / Edge / Firefox, Bureau — rien en dur, valable sur un poste inconnu.
; Ctrl+D y guette le fichier qui ARRIVE après son clic (jamais un fichier déjà présent).
DOSSIERS_TELECHARGEMENT := DossiersTelechargement()
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
        Erreur("Capture non détectée — rien d'enregistré")
        return
    }
    if !DllCall("IsClipboardFormatAvailable", "UInt", 8) {  ; 8 = CF_DIB
        Erreur("Le presse-papiers ne contient pas d'image")
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
        Erreur("Échec de l'enregistrement")
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

; ---------- Double Ctrl+D : télécharger le document AFFICHÉ → CaptOrdo ----------
; Le document du patient est à l'écran dans le navigateur (aperçu Gmail, WhatsApp Web, Doctolib, image ou
; PDF ouvert dans un onglet…). Ctrl+D demande le nom du patient, déclenche LUI-MÊME le téléchargement — clic sur
; le bouton « Télécharger » / « Download » de la page (UI Automation), sinon Ctrl+S avec la boîte
; « Enregistrer sous » remplie vers CaptOrdo — attrape le fichier qui arrive et le range nommé dans CaptOrdo.
; S'il n'y arrive pas : message d'erreur → Ctrl+O (capture).
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
        TelechargerVersCaptOrdo()
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

TelechargerVersCaptOrdo() {
    hwnd := WinExist("A")
    exe := ""
    try exe := WinGetProcessName(hwnd)
    if !(exe ~= "i)^(chrome|msedge|firefox|brave)\.exe$") {
        Erreur("Ctrl+D se lance depuis le navigateur (Chrome, Edge, Firefox) : affiche le document du patient, puis Ctrl+D. Sinon : Ctrl+O.", 7000)
        return
    }
    SetTimer(DevantNommer, -50)
    ib := InputBox("Le document affiché va être téléchargé dans CaptOrdo.`n`nNom du patient (vide = horodatage seul) :"
        , "Télécharger vers CaptOrdo", "w460 h160")
    if (ib.Result != "OK")
        return
    nom := NettoyerNom(ib.Value)
    WinActivate hwnd
    WinWaitActive hwnd, , 2
    avant := FichiersActuels(DOSSIERS_TELECHARGEMENT)
    Notif("Téléchargement…", 30000)
    dest := ""
    if CliquerTelecharger(hwnd) {
        src := AttendreNouveauTelechargement(avant, exe, nom, 30000, &dest)
        if (src = "sauvegarde") {
            FinirEnregistrement(dest)
            return
        }
        if (src = "") {
            Erreur("Le bouton Télécharger a été cliqué mais rien n'est arrivé (30 s) → Ctrl+O (capture).", 8000)
            return
        }
        SplitPath src, , , &ext
        ext := ExtensionReelle(src, ext)
        dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") (ext != "" ? "." ext : "")
        try {
            FileMove src, dest, 1
            Notif("Rangé dans CaptOrdo : " NomFichier(dest), 5000)
        } catch {
            Erreur("Téléchargé mais impossible à déplacer (fichier verrouillé ?) : " src, 8000)
        }
        return
    }
    if LancerEnregistrerSous(hwnd, exe, nom, &dest) {
        FinirEnregistrement(dest)
        return
    }
    Erreur("Ctrl+D n'a trouvé ni bouton Télécharger ni fichier à enregistrer sur cet écran → Ctrl+O (capture).", 8000)
}

DevantNommer() {
    if WinWait("Télécharger vers CaptOrdo ahk_class #32770", , 2) {
        WinSetAlwaysOnTop 1
        WinActivate
    }
}

FinirEnregistrement(dest) {
    if AttendreFichier(dest, 30000)
        Notif("Enregistré dans CaptOrdo : " NomFichier(dest), 5000)
    else
        Erreur("Rien n'est arrivé dans CaptOrdo (30 s) → Ctrl+O (capture).", 8000)
}

; Clique le bouton « Télécharger » / « Download » de la PAGE affichée (UI Automation, dans le contenu web
; seulement — jamais la barre d'outils ni les extensions). false si introuvable ou ambigu.
CliquerTelecharger(hwnd) {
    try {
        racine := UIA.ElementFromHandle(hwnd)
        docs := []
        Loop 4 {   ; le navigateur expose parfois le contenu de la page avec un léger retard
            docs := racine.FindElements({Type:"Document"})
            if (docs.Length)
                break
            Sleep 250
        }
        candidats := []
        for doc in docs {
            for e in doc.FindElements({Name:"^(Télécharger|Download)", mm:"RegEx"}) {
                try {
                    if (e.IsOffscreen || !(e.Type = UIA.Type.Button || e.Type = UIA.Type.Link || e.Type = UIA.Type.MenuItem))
                        continue
                    loc := e.Location
                    if (loc.w < 2 || loc.h < 2)
                        continue
                    candidats.Push(e)
                }
            }
        }
        if (candidats.Length = 0)
            return false
        for e in candidats                       ; priorité au bouton nu = celui de l'aperçu ouvert
            if (e.Name ~= "i)^(Télécharger|Download)$")
                return Activer(e)
        if (candidats.Length = 1)                ; une seule pièce jointe visible
            return Activer(candidats[1])
        return false                             ; plusieurs pièces jointes : ouvrir l'aperçu de la bonne, puis Ctrl+D
    } catch {
        return false
    }
}

Activer(e) {
    try {
        e.Click()          ; motif Invoke / action par défaut
        return true
    }
    try {
        e.ControlClick()   ; sinon clic souris sans bouger le curseur
        return true
    }
    return false
}

; Ctrl+S dans le navigateur (image ou PDF ouvert dans un onglet) → boîte « Enregistrer sous » ; si elle propose
; un vrai fichier (pas une page web), on la remplit avec le chemin CaptOrdo nommé et on valide.
LancerEnregistrerSous(hwnd, exe, nom, &dest) {
    dest := ""
    KeyWait "Ctrl"
    Send "^s"
    dlg := WinWait("ahk_class #32770 ahk_exe " exe, , 3)
    if !dlg
        return false
    propose := ""
    try propose := ControlGetText("Edit1", dlg)
    SplitPath propose, , , &ext
    if (propose = "" || ext ~= "i)^(html?|mhtml|webarchive|txt)$") {   ; « Enregistrer la page » = pas un document patient
        WinClose dlg
        return false
    }
    dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") "." ext
    return RemplirBoiteEnregistrer(dlg, dest)
}

RemplirBoiteEnregistrer(dlg, dest) {
    try {
        ControlFocus "Edit1", dlg
        ControlSetText dest, "Edit1", dlg
        Sleep 150
        ControlSend "{Enter}", "Edit1", dlg
        return true
    } catch {
        return false
    }
}

; Attend qu'un NOUVEAU fichier complet apparaisse dans les dossiers de téléchargement (marque du web posée par
; le navigateur à la fin, ou taille stable), ou qu'une boîte « Enregistrer sous » du navigateur s'ouvre (alors
; remplie vers CaptOrdo → renvoie "sauvegarde", dest rempli). "" si rien en ms millisecondes.
AttendreNouveauTelechargement(avant, exe, nom, ms, &dest) {
    dest := ""
    debut := A_TickCount
    vus := Map()
    while (A_TickCount - debut < ms) {
        dlg := WinExist("ahk_class #32770 ahk_exe " exe)
        if dlg {
            propose := ""
            try propose := ControlGetText("Edit1", dlg)
            SplitPath propose, , , &ext
            dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") (ext != "" ? "." ext : "")
            if RemplirBoiteEnregistrer(dlg, dest)
                return "sauvegarde"
        }
        for dossier in DOSSIERS_TELECHARGEMENT {
            Loop Files dossier "\*.*" {
                if (A_LoopFileExt ~= "i)^(crdownload|tmp|partial|part|download|ini)$")
                    continue
                if avant.Has(A_LoopFileFullPath)
                    continue
                if EstTelecharge(A_LoopFileFullPath)
                    return A_LoopFileFullPath
                taille := A_LoopFileSize
                if (vus.Has(A_LoopFileFullPath) && vus[A_LoopFileFullPath] = taille && taille > 0)
                    return A_LoopFileFullPath
                vus[A_LoopFileFullPath] := taille
            }
        }
        Sleep 500
    }
    return ""
}

FichiersActuels(dossiers) {
    m := Map()
    for dossier in dossiers
        Loop Files dossier "\*.*"
            m[A_LoopFileFullPath] := true
    return m
}

AttendreFichier(chemin, ms) {
    debut := A_TickCount, derniere := -1
    while (A_TickCount - debut < ms) {
        if FileExist(chemin) {
            taille := FileGetSize(chemin)
            if (taille = derniere && taille > 0)
                return true
            derniere := taille
        }
        Sleep 500
    }
    return false
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
        Erreur("Dossier CaptOrdo vide — rien à importer")
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
    ; copie le FICHIER dans le presse-papiers (comme Ctrl+C dans l'Explorateur) — pour une capture
    ; (PNG/JPG) l'IMAGE elle-même est ajoutée aussi — puis le colle (Ctrl+V) dans la fenêtre active :
    ; pièce jointe dans Gmail / Doctolib / WhatsApp Web, image dans un mail, un chat ou Word
    CopierFichierPressePapiers(dernier)
    Send "^v"
    Notif("Collé : " NomFichier(dernier) "  (reste dans le presse-papiers → Ctrl+V ailleurs si besoin)", 6000)
}

; Met un fichier dans le presse-papiers (CF_HDROP) ; si c'est une image, ajoute aussi l'image (bitmap + PNG)
CopierFichierPressePapiers(chemin) {
    SplitPath chemin, , , &ext
    extra := ""
    if (ext ~= "i)^(png|jpe?g|bmp|gif)$")
        extra := "$img = [System.Drawing.Image]::FromFile('" chemin "'); $do.SetImage($img); "
            . "$ms = New-Object System.IO.MemoryStream; $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); "
            . "$ms.Position = 0; $do.SetData('PNG', $ms); "
    psCmd := "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
        . "$sc = New-Object System.Collections.Specialized.StringCollection; [void]$sc.Add('" chemin "'); "
        . "$do = New-Object System.Windows.Forms.DataObject; $do.SetFileDropList($sc); "
        . extra
        . "[System.Windows.Forms.Clipboard]::SetDataObject($do, $true)"
    RunWait('powershell.exe -NoProfile -STA -Command "' psCmd '"', , "Hide")
}

; ---------- Utilitaires ----------

; Fichier le plus récent d'un ou plusieurs dossiers (ignore téléchargements en cours et fichiers système).
; « Récent » = date d'ARRIVÉE : l'horodatage du nom (yyyy-MM-dd_HHmmss, posé par Ctrl+O / Ctrl+D) prime
; sur la date de modification, que FileMove conserve — sinon un fichier rapatrié pouvait rester derrière
; un plus ancien et Ctrl+I reprenait toujours le mauvais.
DernierFichier(dossiers) {
    if !(dossiers is Array)
        dossiers := [dossiers]
    meilleur := "", meilleurTime := 0
    for dossier in dossiers {
        Loop Files dossier "\*.*" {
            if (A_LoopFileExt ~= "i)^(crdownload|tmp|partial|ini)$")
                continue
            t := A_LoopFileTimeModified
            if RegExMatch(A_LoopFileName, "^(\d{4})-(\d{2})-(\d{2})_(\d{6})", &m)
                t := m[1] m[2] m[3] m[4]
            if (t > meilleurTime) {
                meilleurTime := t
                meilleur := A_LoopFileFullPath
            }
        }
    }
    return meilleur
}

; Dossiers où chercher le dernier téléchargement — résolus au lancement, existants, dédoublonnés :
; 1) « Téléchargements » réel de Windows (suit une redirection réseau/OneDrive éventuelle),
; 2) Downloads et « Google Downloads » du profil, 3) dossier personnalisé de Chrome et Edge (tous
; profils) et de Firefox. Rien en dur → marche tel quel sur un poste inconnu.
DossiersTelechargement() {
    liste := []
    Ajouter(d) {
        d := RTrim(Trim(d), "\")
        if (d = "" || !DirExist(d))
            return
        for x in liste
            if (x = d)
                return
        liste.Push(d)
    }
    Ajouter(DossierConnu("{374DE290-123F-4565-9164-39C4925E467B}"))   ; FOLDERID_Downloads
    Ajouter(EnvGet("USERPROFILE") "\Downloads")
    Ajouter(EnvGet("USERPROFILE") "\OneDrive\Desktop\Google Downloads")
    Ajouter(A_Desktop)                                                  ; cible fréquente d'« Enregistrer sous »
    for base in [EnvGet("LOCALAPPDATA") "\Google\Chrome\User Data", EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data"] {
        Loop Files base "\*", "D" {
            txt := ""
            try txt := FileRead(A_LoopFileFullPath "\Preferences", "UTF-8")
            if RegExMatch(txt, '"download":\s*\{[^{}]*?"default_directory":\s*"((?:[^"\\]|\\.)*)"', &m)
                Ajouter(StrReplace(m[1], "\\", "\"))
            if RegExMatch(txt, '"savefile":\s*\{[^{}]*?"default_directory":\s*"((?:[^"\\]|\\.)*)"', &m)   ; « Enregistrer sous »
                Ajouter(StrReplace(m[1], "\\", "\"))
        }
    }
    Loop Files EnvGet("APPDATA") "\Mozilla\Firefox\Profiles\*", "D" {
        txt := ""
        try txt := FileRead(A_LoopFileFullPath "\prefs.js", "UTF-8")
        if RegExMatch(txt, 'user_pref\("browser\.download\.dir",\s*"((?:[^"\\]|\\.)*)"', &m)
            Ajouter(StrReplace(m[1], "\\", "\"))
    }
    return liste
}

; Chemin d'un dossier connu de Windows (SHGetKnownFolderPath), "" si indisponible
DossierConnu(guid) {
    g := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "WStr", guid, "Ptr", g) != 0
        return ""
    p := 0
    if DllCall("shell32\SHGetKnownFolderPath", "Ptr", g, "UInt", 0, "Ptr", 0, "Ptr*", &p) != 0
        return ""
    d := StrGet(p, "UTF-16")
    DllCall("ole32\CoTaskMemFree", "Ptr", p)
    return d
}

; Extension d'après le CONTENU du fichier (signature des premiers octets) quand le téléchargement
; n'en a pas ou qu'elle ment ; sinon l'extension d'origine est gardée
ExtensionReelle(chemin, ext) {
    hex := ""
    try {
        f := FileOpen(chemin, "r")
        buf := Buffer(12, 0)
        n := f.RawRead(buf, 12)
        f.Close()
        Loop n
            hex .= Format("{:02X}", NumGet(buf, A_Index - 1, "UChar"))
    }
    sig := ""
    if (InStr(hex, "89504E47") = 1)
        sig := "png"
    else if (InStr(hex, "FFD8FF") = 1)
        sig := "jpg"
    else if (InStr(hex, "25504446") = 1)          ; %PDF
        sig := "pdf"
    else if (InStr(hex, "47494638") = 1)          ; GIF8
        sig := "gif"
    else if (InStr(hex, "424D") = 1)              ; BM
        sig := "bmp"
    else if (InStr(hex, "52494646") = 1 && SubStr(hex, 17, 8) = "57454250")   ; RIFF….WEBP
        sig := "webp"
    if (sig = "")
        return ext
    if (ext = "")
        return sig
    if (ext ~= "i)^(png|jpe?g|gif|bmp|webp|pdf)$" && !(ext ~= "i)^" sig "$") && !(sig = "jpg" && ext ~= "i)^jpe?g$"))
        return sig
    return ext
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

; Le fichier a-t-il été téléchargé ? = flux NTFS « Zone.Identifier » (marque du web) posé par Chrome, Edge,
; Firefox, Outlook… ; une capture d'écran, un document créé sur place ou un raccourci n'en ont pas
EstTelecharge(chemin) {
    return FileExist(chemin ":Zone.Identifier") != ""
}

Notif(txt, ms := 3500) {
    ToolTip txt
    SetTimer () => ToolTip(), -ms
}

; Message d'ERREUR bien visible : bandeau rouge, gros texte blanc, en haut de l'écran, toujours devant ;
; se ferme seul après ms millisecondes ou au clic ; ne prend pas le clavier (on peut enchaîner Ctrl+O)
Erreur(txt, ms := 8000) {
    static courant := 0
    if courant
        try courant.Destroy()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "Erreur")
    g.BackColor := "C62828"
    g.MarginX := 28, g.MarginY := 18
    g.SetFont("s15 bold cWhite", "Segoe UI")
    t := g.Add("Text", "w640 Center", "✖  " txt)
    t.OnEvent("Click", (*) => g.Destroy())
    g.Show("NoActivate xCenter y60")
    courant := g
    SetTimer(FermerErreur.Bind(g), -ms)
}

FermerErreur(g) {
    try g.Destroy()
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
