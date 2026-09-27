#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <UIA>   ; UI Automation (Lib\UIA.ahk, Descolada/UIA-v2, MIT) — clic sur « Télécharger » pour Ctrl+D

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
;                 Dans la VISIONNEUSE LGPI (historique des délivrances →
;                 ancienne ordonnance DÉJÀ scannée) : clique la disquette de
;                 sa barre d'outils et range le PDF qui en sort.
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
JOURNAL := A_ScriptDir "\ordo-mutuelle.log"           ; trace horodatée de chaque appui ; "" = désactivé
EXT_IMPORT := "i)^(png|jpe?g|gif|bmp|webp|heic|pdf)$"   ; seuls ces types sont proposés par Ctrl+I
; Filet de sécurité : si le dernier fichier de CaptOrdo n'est pas tout frais, c'est qu'un Ctrl+D
; vient d'échouer sans qu'on s'en aperçoive — Ctrl+I demande alors confirmation, au lieu d'insérer
; en silence le document du patient PRÉCÉDENT.
FRAICHEUR_MIN := 10                              ; minutes ; 0 = désactivé
; Visionneuse de scans de LGPI (« Visualisation/Numérisation … », historique des délivrances) : Ctrl+D
; y sort le document par le bouton DISQUETTE de sa barre d'outils, repéré à l'image (la fenêtre bouge,
; des coordonnées fixes ne tiendraient pas). Le gabarit est une capture 18×18 de cette icône.
TITRE_VISIONNEUSE_LGPI := "i)(visualisation|num[ée]risation)"
ICONE_ENREGISTRER := A_ScriptDir "\img\lgpi-enregistrer.png"
; Étiquette « Nom du fichier : » des boîtes Java de LGPI. Repérée à l'image, elle donne la seule chose
; qui manquait : un point où CLIQUER pour être sûr du focus avant de coller (voir InsererCheminSwing).
ETIQUETTE_NOM_FICHIER := A_ScriptDir "\img\lgpi-nom-fichier.png"
DECALAGE_CHAMP := 124                            ; px à droite du COIN GAUCHE de l'étiquette = dans le champ

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
    J("--- Ctrl+D sur : " FenetreActive())
    ; La visionneuse de LGPI n'est pas un navigateur et ne télécharge rien : elle a sa propre route.
    if (exe ~= "i)^javaw?\.exe$" && WinGetTitle(hwnd) ~= TITRE_VISIONNEUSE_LGPI) {
        SortirScanLGPI(hwnd, exe)
        return
    }
    if !(exe ~= "i)^(chrome|msedge|firefox|brave)\.exe$") {
        Erreur("Ctrl+D se lance depuis le navigateur (Chrome, Edge, Firefox) ou depuis la visionneuse LGPI. Sinon : Ctrl+O.", 7000)
        return
    }
    SetTimer(DevantNommer, -50)
    ib := InputBox("Le document affiché va être téléchargé dans CaptOrdo.`n`nNom du patient (vide = horodatage seul) :"
        , "Télécharger vers CaptOrdo", "w460 h160")
    if (ib.Result != "OK") {
        J("    abandonné : nom du patient non saisi")   ; sans cette ligne, un Ctrl+D annulé ressemblait dans le journal à un Ctrl+D resté sans réponse
        return
    }
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
        ; Contrôle sur le CONTENU, pas sur l'extension : un « Enregistrer la page » parti sans qu'on
        ; le voie donnerait un .html, et CaptOrdo ne doit contenir que des documents exploitables.
        ; Le fichier refusé reste dans le dossier de téléchargement — rien n'est supprimé.
        if !DocumentValide(src) {
            J("Ctrl+D : REJET — " NomFichier(src) " n'est ni une image ni un PDF")
            Erreur("Le fichier téléchargé n'est ni une image ni un PDF (page web ?) — rien n'a été ajouté à CaptOrdo → Ctrl+O (capture).", 8000)
            return
        }
        SplitPath src, , , &ext
        ext := ExtensionReelle(src, ext)
        dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") (ext != "" ? "." ext : "")
        try {
            FileMove src, dest, 1
            J("Ctrl+D : OK -> " dest)
            Notif("Rangé dans CaptOrdo : " NomFichier(dest), 5000)
        } catch {
            J("Ctrl+D : ÉCHEC du déplacement de " src)
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
    if !AttendreFichier(dest, 30000) {
        Erreur("Rien n'est arrivé dans CaptOrdo (30 s) → Ctrl+O (capture).", 8000)
        return
    }
    ; Ici le fichier est DÉJÀ dans CaptOrdo : l'y laisser piégerait le prochain Ctrl+I, qui le
    ; prendrait pour le document du patient. Corbeille (récupérable), jamais suppression sèche.
    if !DocumentValide(dest) {
        try FileRecycle dest
        J("Ctrl+D : REJET — " NomFichier(dest) " n'est ni une image ni un PDF")
        Erreur("Ce n'est pas un document (page web ?) — rien n'a été ajouté à CaptOrdo → Ctrl+O (capture).", 8000)
        return
    }
    J("Ctrl+D : OK -> " dest)
    Notif("Enregistré dans CaptOrdo : " NomFichier(dest), 5000)
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

; ---------- Ctrl+D dans la visionneuse LGPI : ordonnance DÉJÀ scannée ----------
; Historique des délivrances → une ancienne ordonnance → LGPI ouvre « Visualisation/Numérisation … » et y
; affiche le scan. Il n'y a ni page web ni téléchargement à guetter : le seul moyen d'en ressortir le
; document est le bouton DISQUETTE de sa barre d'outils. Ctrl+D le clique, remplit la boîte
; « Enregistrer » vers CaptOrdo, puis range le fichier qui en sort — même si la boîte a dû être finie à
; la main : LGPI dessine ses boîtes en Java, rien ne garantit qu'on puisse y écrire (InsererCheminSwing).
SortirScanLGPI(hwnd, exe) {
    SetTimer(DevantNommer, -50)
    ib := InputBox("Le scan affiché va être enregistré dans CaptOrdo.`n`nNom du patient (vide = horodatage seul) :"
        , "Télécharger vers CaptOrdo", "w460 h160")
    if (ib.Result != "OK") {
        J("    abandonné : nom du patient non saisi")
        return
    }
    nom := NettoyerNom(ib.Value)
    dest := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") ".pdf"
    WinActivate hwnd
    WinWaitActive hwnd, , 2
    KeyWait "Ctrl"
    dossiers := DossiersSortieLGPI()
    avant := FichiersActuels(dossiers)
    if CliquerDisquetteLGPI(hwnd)
        Notif("Enregistrement du scan…", 30000)
    else
        Notif("Bouton disquette introuvable : cliquez-le vous-même dans la visionneuse — je range le fichier.", 20000)
    dlg := AttendreBoiteFichierLGPI(exe, 8000)
    if dlg {
        J("    boîte « " WinGetTitle(dlg) " » | classe " WinGetClass(dlg))
        if !RemplirBoiteFichier(dlg, dest)
            Notif("Choisissez le dossier et validez : je range le document dans CaptOrdo.", 20000)
    } else {
        J("    aucune boîte « Enregistrer » repérée — on guette quand même le fichier")
    }
    src := AttendreDocumentLGPI(avant, dossiers, dest, dlg, 90000)
    if (src = "") {
        Erreur("Rien n'est sorti de la visionneuse LGPI (enregistrement annulé ?) → réessayez, ou Ctrl+O (capture).", 8000)
        return
    }
    ; Contrôle sur le CONTENU : ce qui entre dans CaptOrdo doit être un document exploitable.
    if !DocumentValide(src) {
        J("Ctrl+D LGPI : REJET — " NomFichier(src) " n'est ni une image ni un PDF")
        Erreur("Le fichier enregistré n'est ni une image ni un PDF — rien n'a été ajouté à CaptOrdo → Ctrl+O (capture).", 8000)
        return
    }
    SplitPath src, , , &ext
    vrai := ExtensionReelle(src, ext)
    if (src = dest && vrai = ext) {           ; LGPI a écrit droit dans CaptOrdo, au nom demandé
        J("Ctrl+D LGPI : OK -> " src)
        Notif("Rangé dans CaptOrdo : " NomFichier(src), 5000)
        return
    }
    final := DOSSIER "\" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") (nom != "" ? "_" nom : "") (vrai != "" ? "." vrai : "")
    try {
        FileMove src, final, 1
        J("Ctrl+D LGPI : OK -> " final (src != dest ? " (repris de " src ")" : ""))
        Notif("Rangé dans CaptOrdo : " NomFichier(final), 5000)
    } catch {
        J("Ctrl+D LGPI : ÉCHEC du déplacement de " src)
        Erreur("Enregistré mais impossible à déplacer (fichier verrouillé ?) : " src, 8000)
    }
}

; Clique la disquette de la barre d'outils, repérée à l'IMAGE dans la fenêtre : la visionneuse se
; déplace et se redimensionne, des coordonnées fixes viseraient à côté — au pire l'imprimante, juste à
; côté. Le curseur est remis où il était. false = icône non trouvée (l'utilisateur cliquera lui-même).
CliquerDisquetteLGPI(hwnd) {
    if !FileExist(ICONE_ENREGISTRER) {
        J("    gabarit d'icône absent : " ICONE_ENREGISTRER)
        return false
    }
    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    try
        WinGetPos &wx, &wy, &ww, &wh, hwnd
    catch
        return false
    for tolerance in ["*25", "*50"] {        ; tolérance de couleur croissante (thème, anticrénelage)
        try {
            if ImageSearch(&ix, &iy, wx, wy, wx + ww, wy + wh, tolerance " " ICONE_ENREGISTRER) {
                CliquerEcran(ix + 9, iy + 9)     ; centre du gabarit 18×18
                J("    disquette cliquée en " (ix + 9) "," (iy + 9) " (tolérance " tolerance ")")
                return true
            }
        }
    }
    J("    disquette introuvable dans la fenêtre (" wx "," wy " " ww "×" wh ")")
    return false
}

; La boîte « Enregistrer » qui suit le clic : LGPI en ouvre tantôt une vraie (Windows, classe #32770 avec
; un champ Edit1), tantôt une dessinée en Java (SunAwtDialog, aucun contrôle Windows). On ne retient une
; #32770 que si elle a bien un champ de saisie — sinon c'est un simple message de LGPI.
AttendreBoiteFichierLGPI(exe, ms) {
    debut := A_TickCount
    while (A_TickCount - debut < ms) {
        for h in WinGetList("ahk_exe " exe) {
            cls := "", titre := ""
            try cls := WinGetClass(h)
            try titre := WinGetTitle(h)
            if (titre = "")
                continue
            if (cls = "#32770") {
                try {
                    ControlGetText("Edit1", h)
                    return h
                }
                continue
            }
            ; radicaux, pas mots entiers : « Enregistrer sous », « Sauvegarde du document », « Exporter »…
            if (cls = "SunAwtDialog" && titre ~= "i)(enregistr|sauvegard|\bsave\b|export|choisir|s[ée]lectionn|parcourir)")
                return h
        }
        Sleep 200
    }
    return 0
}

RemplirBoiteFichier(dlg, dest) {
    cls := ""
    try cls := WinGetClass(dlg)
    if (cls = "#32770" && RemplirBoiteEnregistrer(dlg, dest)) {
        J("    chemin inséré dans la boîte Windows « Enregistrer »")
        return true
    }
    return InsererCheminSwing(dlg, dest, true)   ; boîte « Enregistrer » : on valide, rien ne peut être écrasé
}

; Où LGPI peut déposer le PDF : il propose le dossier de la DERNIÈRE sauvegarde (« Ordo du jour », le
; Bureau, Téléchargements…) — impossible à connaître d'avance, on guette donc large, CaptOrdo compris
; (l'utilisateur peut y enregistrer à la main, sous le nom VisuScan_… proposé par LGPI).
DossiersSortieLGPI() {
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
    for d in DOSSIERS_TELECHARGEMENT
        Ajouter(d)
    Ajouter(A_Desktop "\Ordo du jour")
    Ajouter(EnvGet("USERPROFILE") "\Desktop\Ordo du jour")
    Ajouter(EnvGet("USERPROFILE") "\Documents")
    Ajouter(DOSSIER)
    return liste
}

; Attend le document : soit il arrive pile à l'adresse demandée (le chemin a été inséré), soit ailleurs
; (boîte finie à la main) — on prend alors le fichier APPARU depuis le clic. Taille inchangée d'un
; passage à l'autre = écriture terminée. Si la boîte s'est refermée sans rien produire (Annuler), inutile
; d'attendre la fin du délai : on abrège au bout de 12 s.
AttendreDocumentLGPI(avant, dossiers, dest, dlg, ms) {
    debut := A_TickCount, vus := Map(), fermee := 0
    while (A_TickCount - debut < ms) {
        if Stabilise(dest, vus)
            return dest
        for dossier in dossiers {
            Loop Files dossier "\*.*" {
                if (A_LoopFileExt ~= "i)^(tmp|part|partial|crdownload|ini|lnk|db)$")
                    continue
                if (avant.Has(A_LoopFileFullPath) || A_LoopFileFullPath = dest)
                    continue
                if Stabilise(A_LoopFileFullPath, vus)
                    return A_LoopFileFullPath
            }
        }
        if (dlg && !WinExist("ahk_id " dlg)) {
            if !fermee
                fermee := A_TickCount
            else if (A_TickCount - fermee > 12000)
                return ""
        }
        Sleep 400
    }
    return ""
}

; Le fichier existe et sa taille n'a pas bougé depuis le passage précédent = écriture terminée
Stabilise(chemin, vus) {
    if !FileExist(chemin)
        return false
    taille := -1
    try taille := FileGetSize(chemin)
    if (taille < 0)
        return false
    if (vus.Has(chemin) && vus[chemin] = taille && taille > 0)
        return true
    vus[chemin] := taille
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
    ; La boîte « Ouvrir » est repérée AVANT le contrôle de fraîcheur : sa MsgBox prend le focus, et
    ; « la fenêtre active » ne serait alors plus la boîte de dialogue du logiciel officine.
    hDlg := WinActive("ahk_class #32770")   ; 0 = aucune boîte Ouvrir/Enregistrer au premier plan
    ; La classe est journalisée : c'est ELLE qui dit comment le chemin sera inséré — #32770 = vraie
    ; boîte Windows (ControlSetText), SunAwtDialog = boîte dessinée par Java/LGPI (collage clavier).
    J("--- Ctrl+I sur : " FenetreActive() " | classe " ClasseActive() " | boîte standard : " (hDlg ? "oui" : "non"))
    J("    fichier retenu : " NomFichier(dernier) " (" AgeTexte(AgeMinutes(dernier)) ")")
    dernier := ConfirmerSiVieux(dernier, "Insérer")
    if (dernier = "") {   ; chaîne vide = l'utilisateur a refusé
        J("    abandonné : document jugé trop ancien")
        return
    }
    KeyWait "Ctrl"
    if (hDlg && WinExist("ahk_id " hDlg)) {  ; boîte de dialogue Ouvrir/Enregistrer standard
        try {
            WinActivate hDlg
            ControlFocus "Edit1", hDlg
            ControlSetText dernier, "Edit1", hDlg
            Sleep 120
            ControlSend "{Enter}", "Edit1", hDlg
            J("    inséré dans la boîte « Ouvrir »")
            return
        }
        ; contrôle introuvable → repli presse-papiers ci-dessous
    }
    ; Boîte « Ouvrir » NON standard : LGPI dessine la sienne en Java (Swing). Elle n'a aucun contrôle
    ; Windows à remplir, et surtout elle ne comprend PAS le presse-papiers « fichier » (CF_HDROP) : le
    ; Ctrl+V du repli ci-dessous n'y collait rien — d'où les « collé dans java.exe | Ouvrir » sans effet.
    ; On y insère donc le CHEMIN EN TEXTE, comme si on le tapait dans « Nom du fichier ».
    hJava := BoiteFichierJava()
    if (hJava && InsererCheminJava(hJava, dernier))
        return
    ; copie le FICHIER dans le presse-papiers (comme Ctrl+C dans l'Explorateur) — pour une capture
    ; (PNG/JPG) l'IMAGE elle-même est ajoutée aussi — puis le colle (Ctrl+V) dans la fenêtre active :
    ; pièce jointe dans Gmail / Doctolib / WhatsApp Web, image dans un mail, un chat ou Word
    CopierFichierPressePapiers(dernier)
    Send "^v"
    J("    collé dans " FenetreActive())
    Notif("Collé : " NomFichier(dernier) "  (reste dans le presse-papiers → Ctrl+V ailleurs si besoin)", 6000)
}

; La boîte de fichiers de LGPI est-elle au premier plan ? Elle est dessinée par Java (Swing) : classe
; SunAwtDialog et non #32770 — ni Edit1 à remplir, ni presse-papiers « fichier » compris. On la
; reconnaît au couple processus Java + titre de boîte de fichiers ; la fenêtre PRINCIPALE de LGPI
; (« … Portail Pharmagest … ») ne matche pas — elle héberge un navigateur, où coller un FICHIER marche.
BoiteFichierJava() {
    try {
        if !(WinGetProcessName("A") ~= "i)^javaw?\.exe$")
            return 0
        if !(WinGetTitle("A") ~= "i)^\s*(ouvrir|open|importer|import|enregistrer|save|charger|parcourir|s[ée]lectionner|choisir)\b")
            return 0
        return WinActive("A")
    }
    return 0
}

; Boîte « Ouvrir » de LGPI : insertion prudente (voir InsererCheminSwing, enregistrement = false) — sans
; certitude sur le focus, aucune Entrée n'est envoyée, car elle ouvrirait le fichier sélectionné dans la
; LISTE : le document d'un AUTRE patient. Échec → message + chemin dans le presse-papiers, et l'appel
; est tout de même considéré comme TRAITÉ. Renvoie false seulement si la boîte a disparu entre-temps
; (→ repli presse-papiers du côté de ImporterDernierFichier).
InsererCheminJava(hwnd, chemin) {
    if InsererCheminSwing(hwnd, chemin)
        return true
    if !WinExist("ahk_id " hwnd)
        return false         ; la boîte a disparu → repli presse-papiers
    Erreur("LGPI n'a pas pris le chemin : cliquez dans « Nom du fichier », puis Ctrl+V et Entrée (le chemin est dans le presse-papiers).", 10000)
    return true              ; traité : surtout ne pas coller un fichier par-dessus
}

; Écrit un chemin dans une boîte de fichiers dessinée par Java/Swing, et valide.
;
; Le collage, lui, a toujours marché : la capture du 07/09 montre le chemin bel et bien écrit dans
; « Nom du fichier ». Ce qui échouait, c'était la RELECTURE de contrôle — Ctrl+Inser ne rend rien en
; Swing, le script en concluait « je n'ai rien écrit », refusait d'appuyer sur Entrée et laissait la
; boîte plantée à demander où enregistrer (et, côté Ctrl+I, sept « champ lu : «  » » le 05/09).
;
; On ne se fie donc plus à la relecture mais au FOCUS : un clic dans le champ, repéré par son étiquette
; (CliquerChampNomFichier), et l'Entrée peut partir. Sans ce clic, repli au clavier — tel quel, la
; mnémonique du libellé, puis Tab après Tab — avec relecture, qui vaut confirmation quand elle répond.
;
; enregistrement = true (boîte « Enregistrer ») : on valide même sans certitude. Rien ne peut être
; écrasé, le pire est un fichier écrit sous le nom proposé par LGPI — que SortirScanLGPI rattrape et
; range. Dans une boîte « Ouvrir » (false), au contraire, une Entrée mal placée chargerait le document
; d'un AUTRE patient : sans clic ni relecture concluante, on n'envoie rien.
; Le presse-papiers garde le chemin en sortie, pour un Ctrl+V manuel.
InsererCheminSwing(hwnd, chemin, enregistrement := false) {
    titre := ""
    try titre := WinGetTitle("ahk_id " hwnd)
    WinActivate hwnd
    if !WinWaitActive("ahk_id " hwnd, , 2)
        return false
    ; Focus certain : on clique dans « Nom du fichier », au lieu d'espérer que Swing l'ait donné au champ
    clique := CliquerChampNomFichier(hwnd)
    essais := clique ? [""] : ["", "!n"]     ; sans clic : tel quel, puis la mnémonique « &Nom du fichier »
    if !clique
        Loop 8
            essais.Push("{Tab}")
    for touche in essais {
        if !WinExist("ahk_id " hwnd)
            return false
        if (touche != "")
            Send touche
        Sleep 80
        lu := CollerEtRelire(chemin)
        if (lu != chemin && lu != "") {
            ; le champ répond mais le collage n'a pas pris : on tape le chemin caractère par caractère
            Send "{Home}+{End}"
            SendText chemin
            Sleep 150
            lu := ChampRelu(600)
        }
        sur := (lu = chemin) || (clique || enregistrement)
        if sur {
            Send "{End}{Enter}"
            A_Clipboard := chemin
            J("    chemin inséré dans la boîte Java « " titre " » ("
                . (lu = chemin ? "champ relu" : clique ? "clic dans le champ" : "validé d'office") ")")
            Notif("Inséré : " NomFichier(chemin), 5000)
            return true
        }
    }
    A_Clipboard := chemin
    J("    boîte Java « " titre " » : le chemin n'a pu être écrit dans aucun champ — Entrée non envoyée")
    return false
}

; Clique dans le champ « Nom du fichier » d'une boîte Java, repéré par son ÉTIQUETTE : Swing n'expose
; aucun contrôle Windows, mais l'étiquette est toujours dessinée pareil et le champ commence juste à sa
; droite. false = étiquette introuvable (autre thème, boîte d'un autre logiciel) → repli au clavier.
CliquerChampNomFichier(hwnd) {
    if !FileExist(ETIQUETTE_NOM_FICHIER)
        return false
    CoordMode "Pixel", "Screen"
    try
        WinGetPos &wx, &wy, &ww, &wh, hwnd
    catch
        return false
    for tolerance in ["*25", "*50"] {
        try {
            if ImageSearch(&ix, &iy, wx, wy, wx + ww, wy + wh, tolerance " " ETIQUETTE_NOM_FICHIER) {
                CliquerEcran(ix + DECALAGE_CHAMP, iy + 8)
                J("    clic dans « Nom du fichier » en " (ix + DECALAGE_CHAMP) "," (iy + 8))
                return true
            }
        }
    }
    J("    étiquette « Nom du fichier » introuvable dans la boîte")
    return false
}

; Clic à un point de l'ÉCRAN, curseur remis où il était (on travaille par-dessus l'épaule de quelqu'un)
CliquerEcran(x, y) {
    CoordMode "Mouse", "Screen"
    MouseGetPos &ox, &oy
    MouseMove x, y, 0
    Sleep 80
    Click
    Sleep 80
    MouseMove ox, oy, 0
}

; Colle le chemin par-dessus ce que la boîte propose déjà, puis relit ce que le champ contient
CollerEtRelire(chemin) {
    A_Clipboard := chemin
    if !ClipWait(2, 0)
        return ""
    Send "{Home}+{End}"      ; remplace ce que la boîte propose déjà, au lieu de coller à la suite
    Send "^v"
    Sleep 180
    return ChampRelu(600)
}

; Relit le champ qui vient d'être collé : sélection de la ligne, puis copie. La copie passe par
; Ctrl+Inser (équivalent Swing de Ctrl+C) — un Ctrl+C simulé déclencherait le ~^c de
; recherche-selection.ahk. La sentinelle distingue « champ vide » de « rien n'a été copié » (clavier
; hors du champ de saisie).
; ATTENTION : dans les boîtes Swing de LGPI cette relecture revient TOUJOURS vide, même quand le champ
; est correctement rempli — elle ne vaut donc que comme confirmation POSITIVE, jamais comme preuve
; d'échec. C'est le clic dans le champ qui fait foi (voir InsererCheminSwing).
ChampRelu(msMax := 1200) {
    static SENTINELLE := "«?»"
    A_Clipboard := SENTINELLE
    Send "{Home}+{End}^{Insert}"
    debut := A_TickCount
    while (A_TickCount - debut < msMax) {
        Sleep 100
        if (A_Clipboard != SENTINELLE)
            return Trim(A_Clipboard)
    }
    return ""
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

; Fichier le plus récent d'un ou plusieurs dossiers. Liste BLANCHE d'extensions (EXT_IMPORT) : seuls
; une image ou un PDF ont un sens dans une boîte « Ouvrir » ; cela écarte du même coup les
; téléchargements en cours (.crdownload, .part) et les fichiers système (.ini, desktop.ini).
DernierFichier(dossiers) {
    if !(dossiers is Array)
        dossiers := [dossiers]
    meilleur := "", meilleurTime := 0
    for dossier in dossiers {
        Loop Files dossier "\*.*" {
            if !(A_LoopFileExt ~= EXT_IMPORT)
                continue
            t := DateArrivee(A_LoopFileFullPath, A_LoopFileName, A_LoopFileTimeModified)
            if (t > meilleurTime) {
                meilleurTime := t
                meilleur := A_LoopFileFullPath
            }
        }
    }
    return meilleur
}

; Date d'ARRIVÉE d'un fichier : l'horodatage du nom (yyyy-MM-dd_HHmmss, posé par Ctrl+O / Ctrl+D)
; prime sur la date de modification, que FileMove conserve — sinon un fichier rapatrié restait
; derrière un plus ancien et Ctrl+I reprenait toujours le mauvais. Règle unique, partagée par
; DernierFichier et le contrôle de fraîcheur : les deux désignent forcément le même fichier.
DateArrivee(chemin, nom := "", modif := "") {
    if (nom = "")
        nom := NomFichier(chemin)
    if RegExMatch(nom, "^(\d{4})-(\d{2})-(\d{2})_(\d{6})", &m)
        return m[1] m[2] m[3] m[4]
    return (modif != "") ? modif : FileGetTime(chemin, "M")
}

AgeMinutes(chemin) {
    return DateDiff(A_Now, DateArrivee(chemin), "Minutes")
}

AgeTexte(min) {
    if (min < 1)
        return "à l'instant"
    if (min < 60)
        return min " min"
    if (min < 1440)
        return Round(min / 60) " h"
    return Round(min / 1440) " j"
}

; Garde-fou anti « mauvais patient ». Un Ctrl+D qui échoue sans qu'on le remarque laisse le document
; du patient PRÉCÉDENT en tête de CaptOrdo ; sans ce contrôle, Ctrl+I l'enverrait dans le dossier du
; patient suivant. Au-delà de FRAICHEUR_MIN minutes, plus rien n'est donc pris en silence.
; Renvoie le chemin si l'on peut continuer, "" si l'utilisateur refuse.
ConfirmerSiVieux(chemin, action) {
    if (FRAICHEUR_MIN <= 0 || chemin = "")
        return chemin
    age := AgeMinutes(chemin)
    if (age <= FRAICHEUR_MIN)
        return chemin
    txt := "Aucun document récent (moins de " FRAICHEUR_MIN " min) dans CaptOrdo.`n`n"
        . "Le plus récent est :`n" NomFichier(chemin) "`n"
        . "du " FormatTime(DateArrivee(chemin), "dd/MM/yyyy à HH:mm") "  (il y a " AgeTexte(age) ")`n`n"
        . action " ce fichier quand même ?"
    ; Default2 = « Non » présélectionné : un appui réflexe sur Entrée ne prend pas un vieux document.
    return (MsgBox(txt, "Vérifier le fichier", "YesNo Icon! Default2") = "Yes") ? chemin : ""
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

; Type réel d'après les premiers octets : "png", "jpg", "pdf", "gif", "bmp", "webp", ou "" si le
; fichier n'est ni une image ni un PDF — une page web enregistrée par erreur, par exemple.
SignatureFichier(chemin) {
    hex := ""
    try {
        f := FileOpen(chemin, "r")
        buf := Buffer(12, 0)
        n := f.RawRead(buf, 12)
        f.Close()
        Loop n
            hex .= Format("{:02X}", NumGet(buf, A_Index - 1, "UChar"))
    }
    if (InStr(hex, "89504E47") = 1)
        return "png"
    if (InStr(hex, "FFD8FF") = 1)
        return "jpg"
    if (InStr(hex, "25504446") = 1)               ; %PDF
        return "pdf"
    if (InStr(hex, "47494638") = 1)               ; GIF8
        return "gif"
    if (InStr(hex, "424D") = 1)                   ; BM
        return "bmp"
    if (InStr(hex, "52494646") = 1 && SubStr(hex, 17, 8) = "57454250")   ; RIFF….WEBP
        return "webp"
    return ""
}

; Document exploitable = image ou PDF reconnu à ses OCTETS, pas à son extension : une page web
; enregistrée en « .pdf » commence par « <!DOCTYPE » et n'a rien à faire dans CaptOrdo.
DocumentValide(chemin) {
    return SignatureFichier(chemin) != ""
}

; Extension d'après le CONTENU du fichier quand le téléchargement n'en a pas ou qu'elle ment ;
; sinon l'extension d'origine est gardée
ExtensionReelle(chemin, ext) {
    sig := SignatureFichier(chemin)
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

; Trace horodatée : permet de savoir APRÈS COUP quel fichier a été pris, et d'où. Le journal reste
; local — il peut contenir des noms de patients, et *.log est exclu par .gitignore.
J(txt) {
    if (JOURNAL = "")
        return
    try FileAppend FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "  " txt "`n", JOURNAL, "UTF-8"
}

; Fenêtre active (processus + titre), pour le journal
FenetreActive() {
    try
        return WinGetProcessName("A") " | " WinGetTitle("A")
    catch
        return "(inconnue)"
}

; Classe de la fenêtre active, pour le journal : #32770 = boîte Windows standard (remplie par
; ControlSetText), SunAwtDialog = boîte dessinée par Java (remplie au clavier, voir InsererCheminJava)
ClasseActive() {
    try
        return WinGetClass("A")
    catch
        return "(inconnue)"
}

; Message d'ERREUR bien visible : bandeau rouge, gros texte blanc, en haut de l'écran, toujours devant ;
; se ferme seul après ms millisecondes ou au clic ; ne prend pas le clavier (on peut enchaîner Ctrl+O)
Erreur(txt, ms := 8000) {
    static courant := 0
    J("  ERREUR : " txt)
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
