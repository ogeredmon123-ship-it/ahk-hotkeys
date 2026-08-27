#Requires AutoHotkey v2.0
#SingleInstance Force

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

; Double appui rapide sur Ctrl+R → lecture à voix haute du texte SÉLECTIONNÉ
; (voix Windows fr-FR Hortense, instantané, sans ouvrir d'onglet).
; Copie simulée puis presse-papiers restauré ; à défaut de sélection, lit le presse-papiers.
; Un seul Ctrl+R = comportement natif (actualiser la page…), renvoyé après 350 ms.
rPending := false
ttsVoice := ComObject("SAPI.SpVoice")
try {
    frVoices := ttsVoice.GetVoices("Language=40C")  ; 40C = français (France)
    if (frVoices.Count > 0)
        ttsVoice.Voice := frVoices.Item(0)
}

$^r:: {
    global rPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (rPending) {
        SetTimer(SendNativeCtrlR, 0)
        rPending := false
        SpeakSelection()
    } else {
        rPending := true
        SetTimer(SendNativeCtrlR, -350)
    }
}

SendNativeCtrlR() {
    global rPending
    rPending := false
    Send "^r"
}

SpeakSelection() {
    global ttsVoice
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    got := ClipWait(0.4)
    q := got ? Trim(A_Clipboard) : ""
    A_Clipboard := saved
    if (q = "") {
        Sleep 50
        q := Trim(A_Clipboard)  ; repli : contenu déjà copié
    }
    if (q = "")
        return
    ttsVoice.Speak(q, 3)  ; async + purge : un nouveau double-tap interrompt la lecture
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
        Run 'chrome.exe "https://www.google.com/"'  ; champ vide = ouvre Chrome sur Google
    else
        Run "https://www.google.com/search?q=" . UrlEncode(q)
}

; Double appui rapide sur Ctrl+K → ouvre Claude Code dans Windows Terminal.
; Un seul Ctrl+K = comportement natif (barre de recherche…), renvoyé après 350 ms.
kPending := false

$^k:: {
    global kPending
    static last := 0
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (kPending) {
        SetTimer(SendNativeCtrlK, 0)
        kPending := false
        Run 'wt.exe -d "' EnvGet("USERPROFILE") '" claude'
    } else {
        kPending := true
        SetTimer(SendNativeCtrlK, -350)
    }
}

SendNativeCtrlK() {
    global kPending
    kPending := false
    Send "^k"
}

; Double appui rapide sur Ctrl+B (B comme la Bible du médicament) → boîte de recherche
; VIDAL, toujours vide :
;   Entrée avec du texte  → page de résultats vidal.fr
;   Entrée champ vide     → page d'accueil vidal.fr (recherche sur le site)
;   Échap                 → annuler
; Ctrl+V fonctionne dans la boîte pour y coller le presse-papiers.
; Un seul Ctrl+B = comportement natif (gras…), renvoyé après DELAI ms.
; Désactivé quand la boîte elle-même a le focus, pour ne pas gêner la saisie.
#HotIf !WinActive("Recherche VIDAL ahk_class AutoHotkeyGUI")
$^b:: VidalTap()
#HotIf

VidalTap(natif := false) {
    static DELAI := 300  ; ms d'attente avant de rendre Ctrl+B natif — baisser si la latence gêne
    static last := 0, pending := false
    if (natif) {  ; timer échu : c'était un appui simple → gras normal
        pending := false
        Send "^b"
        return
    }
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (pending) {
        SetTimer(VidalTapNatif, 0)
        pending := false
        ShowVidalBox()
    } else {
        pending := true
        SetTimer(VidalTapNatif, -DELAI)
    }
}

VidalTapNatif() => VidalTap(true)

ShowVidalBox() {
    static box := 0, champ := 0
    if !box {
        box := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Recherche VIDAL")
        box.SetFont("s11")
        champ := box.Add("Edit", "w420")
        box.Add("Button", "Default Hidden", "OK").OnEvent("Click", (*) => VidalBoxSubmit(box, champ))
        box.OnEvent("Escape", (*) => box.Hide())
        box.OnEvent("Close", (*) => box.Hide())
    }
    champ.Value := ""  ; toujours vide : Ctrl+V dans la boîte si tu veux le presse-papiers
    box.Show("AutoSize Center")
    champ.Focus()
}

VidalBoxSubmit(box, champ) {
    q := Trim(champ.Value)
    box.Hide()
    if (q = "")
        Run "https://www.vidal.fr/"  ; champ vide = atterrissage sur l'accueil VIDAL
    else
        Run "https://www.vidal.fr/recherche.html?query=" . UrlEncode(q)
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

; Double appui rapide sur Ctrl+P → affiche la fenêtre PowerShell DÉJÀ ouverte
; (premier plan, restaurée si minimisée) ; n'en ouvre une nouvelle que s'il n'y en a aucune.
; Un seul Ctrl+P = comportement natif (imprimer…), renvoyé après DELAI ms.
$^p:: PowershellTap()

PowershellTap(natif := false) {
    static DELAI := 300  ; ms d'attente avant de rendre Ctrl+P natif
    static last := 0, pending := false
    if (natif) {
        pending := false
        Send "^p"
        return
    }
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (pending) {
        SetTimer(PowershellTapNatif, 0)
        pending := false
        AfficherPowershell()
    } else {
        pending := true
        SetTimer(PowershellTapNatif, -DELAI)
    }
}

PowershellTapNatif() => PowershellTap(true)

AfficherPowershell() {
    static lastRun := 0
    if (h := TrouverFenetrePowershell()) {
        WinActivate(h)
        return
    }
    ; Anti-empilement : la fenêtre lancée au double-tap précédent met ~1-2 s à
    ; recevoir son titre « PowerShell » ; pendant ce délai un nouveau double-tap
    ; ne doit pas relancer une 2e fenêtre (le timer ci-dessous la focusera).
    if (A_TickCount - lastRun < 5000)
        return
    lastRun := A_TickCount
    ; Fenêtre PowerShell DÉDIÉE : titre figé « PowerShell » (--suppressApplicationTitle)
    ; pour que le prochain double Ctrl+P la retrouve, -w new pour qu'elle ne parte
    ; jamais en onglet dans une fenêtre existante.
    Run 'wt.exe -w new new-tab -d "' EnvGet("USERPROFILE") '" --title "PowerShell" --suppressApplicationTitle'
    SetTimer(FocusPowershellNaissante, -400)
}

FocusPowershellNaissante() {
    static essais := 0
    if (h := TrouverFenetrePowershell()) {
        essais := 0
        WinActivate(h)
        return
    }
    if (++essais < 15)  ; réessaie ~6 s le temps que la fenêtre reçoive son titre
        SetTimer(FocusPowershellNaissante, -400)
    else
        essais := 0
}

TrouverFenetrePowershell() {
    ; Fenêtre Windows Terminal dont l'onglet ACTIF est PowerShell — titre exact,
    ; pas un « contient » : un onglet Claude Code peut mentionner PowerShell dans son titre.
    ; Surtout PAS de détection par ahk_exe powershell.exe : les processus d'arrière-plan
    ; exposent des consoles fantômes que WinActivate « active » sans rien afficher.
    for h in WinGetList("ahk_exe WindowsTerminal.exe")
        if RegExMatch(WinGetTitle(h), "^(Administrateur\s*:\s*)?(Windows\s)?PowerShell$")
            return h
    return 0
}

; Double appui rapide sur Ctrl+A → boîte de saisie flottante « Claude », toujours vide :
;   Entrée avec du texte  → claude.ai/new avec la question pré-remplie dans le prompt
;   Entrée champ vide     → nouvelle conversation vierge sur claude.ai
;   Échap                 → annuler
; Ctrl+V fonctionne dans la boîte pour y coller le presse-papiers.
; Un seul Ctrl+A = comportement natif (tout sélectionner), renvoyé après DELAI ms.
; Désactivé quand la boîte elle-même a le focus (sinon Ctrl+A y serait intercepté).
#HotIf !WinActive("Claude ahk_class AutoHotkeyGUI")
$^a:: ClaudeTap()
#HotIf

ClaudeTap(natif := false) {
    static DELAI := 200  ; ms d'attente avant de rendre Ctrl+A natif — baisser si la latence gêne
    static last := 0, pending := false
    if (natif) {  ; timer échu : c'était un appui simple → tout sélectionner
        pending := false
        Send "^a"
        return
    }
    now := A_TickCount
    if (now - last < 50) {  ; auto-repeat (touche maintenue) : ignorer
        last := now
        return
    }
    last := now
    if (pending) {
        SetTimer(ClaudeTapNatif, 0)
        pending := false
        ShowClaudeBox()
    } else {
        pending := true
        SetTimer(ClaudeTapNatif, -DELAI)
    }
}

ClaudeTapNatif() => ClaudeTap(true)

ShowClaudeBox() {
    static box := 0, champ := 0
    if !box {
        box := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Claude")
        box.SetFont("s11")
        champ := box.Add("Edit", "w420")
        box.Add("Button", "Default Hidden", "OK").OnEvent("Click", (*) => ClaudeBoxSubmit(box, champ))
        box.OnEvent("Escape", (*) => box.Hide())
        box.OnEvent("Close", (*) => box.Hide())
    }
    champ.Value := ""  ; toujours vide : Ctrl+V dans la boîte si tu veux le presse-papiers
    box.Show("AutoSize Center")
    champ.Focus()
}

ClaudeBoxSubmit(box, champ) {
    q := Trim(champ.Value)
    box.Hide()
    if (q = "")
        Run "https://claude.ai/new"  ; champ vide = conversation vierge
    else
        Run "https://claude.ai/new?q=" . UrlEncode(q)
}

; Double appui rapide sur Ctrl+<touche Calculatrice> (Launch_App2) → clavier arabe :
;   1er double-tap → bascule la saisie en arabe (disposition arabe 101) + affiche le
;                    clavier visuel Windows (osk.exe) pour voir/cliquer les lettres.
;   2e double-tap  → referme le clavier visuel et repasse la saisie en français.
; La touche Calculatrice seule garde son comportement natif (ouvrir la calculatrice).
$^Launch_App2:: {
    static last := 0
    now := A_TickCount
    gap := now - last
    last := now
    if (gap > 80 && gap < 500) {
        last := 0
        ToggleClavierArabe()
    }
}

ToggleClavierArabe() {
    static WM_INPUTLANGCHANGEREQUEST := 0x50
    static HKL_AR := 0x04010401  ; arabe (101) — ar-SA
    static HKL_FR := 0x040C040C  ; français AZERTY
    if WinExist("ahk_exe osk.exe") {
        PostMessage(WM_INPUTLANGCHANGEREQUEST, 0, HKL_FR, , "A")
        WinClose("ahk_exe osk.exe")
    } else {
        PostMessage(WM_INPUTLANGCHANGEREQUEST, 0, HKL_AR, , "A")
        Run "osk.exe"
    }
}

; Encodage percent UTF-8 (gère les accents : é → %C3%A9)
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
