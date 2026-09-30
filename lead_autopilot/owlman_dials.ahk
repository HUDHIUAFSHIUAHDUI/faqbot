#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
InstallMouseHook                  ; lets the script tell YOUR mouse moves from its own
InstallKeybdHook                  ; ...and YOUR key presses from any script's
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
SetDefaultMouseSpeed 0
SetMouseDelay -1
SetKeyDelay -1
; Use real screen pixels for both mouse and colors (same as lead_autopilot)
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; ===================== OWLMAN DIALS =====================
; A SEPARATE add-on to lead_autopilot. One key, no Fn: RIGHT ALT.
;   Tap Right Alt       = ON. A small "OWLMAN DIALS is ON" box shows.
;   Tap Right Alt again = OFF.
;   Right Alt + another key still works like a normal Alt key.
;   (Win and Caps Lock belong to lead_autopilot - Owlman never uses them.)
; While ON, for every lead it does your Win and your Caps Lock by itself:
;   the call rings -> your Win (Lead Scraper upload + email) while it rings ->
;   ring time's up -> hang up -> No Contact -> your dialer calls the next lead
;   by itself -> again. Owlman never clicks a phone.
; It can't tell when someone picks up, so your sound stays on:
;   when you hear someone answer, tap ANY key (or move the mouse) and it stops.
; A lead with NO email button is a special lead: it stops and leaves that call to you.
; No setup of its own: it uses the spots from your Win and Caps Lock setups.
;
; It never changes lead_autopilot or its saved spots: it only READS them
; from lead_points.ini.
; =====================================================

; Timing changes a little every call (random within these ranges, in ms), and
; every 10-15 dials one call is a "long" one where everything takes longer.
global RingMin := 10000, RingMax := 25000         ; let it ring this long, then hang up
global PauseMin := 2000, PauseMax := 5000         ; wait before No Contact
global LongRingMin := 23000, LongRingMax := 25000 ; the same, on a long dial
global LongPauseMin := 5000, LongPauseMax := 7000
global LongEveryMin := 10, LongEveryMax := 15     ; a long dial happens every 10-15 dials
global DialsUntilLong := Random(LongEveryMin, LongEveryMax)
global NextCallWait  := 15000   ; ms to wait for your dialer to start a call
global EnvelopeWait  := 1500    ; ms to wait for the email button before calling it a special lead
global HangupSkipMs  := 3000    ; red hang-up button not found in this long = call's already over
global ReloadWait    := 3000    ; ms max to wait for the page to reload after hanging up
global Settle        := 40      ; ms pause after a button appears, before clicking
global Timeout       := 5000    ; ms to wait for a button before giving up
global ColorTolerance := 40
global SpotSlack     := 4
global AmbiguousCap  := 800
global UploadWait    := 1200    ; the email flow's timings, same as lead_autopilot's
global SendGoneMs    := 500
global SendStuckMs   := 1000
global HoldScrollMs  := 700

global MainIni := A_ScriptDir "\lead_points.ini"        ; lead_autopilot's spots (read only)
global LogFile := A_ScriptDir "\owlman_log.txt"
global Abort := false, UserMoved := false, Running := false, RunStart := 0
global UserStopped := false
global CallStart := 0

; ---------- ON/OFF BOX ----------
global Panel := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Owlman Dials")
Panel.SetFont("s10 bold", "Segoe UI")
Panel.Add("Text", "c008800", "OWLMAN DIALS is ON")
Panel.SetFont("s9 norm")
global PanelStatus := Panel.Add("Text", "w230 r3", "")
Panel.Add("Button", "w230 h32", "Turn OFF  (Right Alt)").OnEvent("Click", (*) => OwlOff())
Panel.OnEvent("Close", (*) => OwlOff())
Panel.Show("Hide x10 y" (A_ScreenHeight - 230))    ; placed, but hidden while OFF
if (A_Args.Length && A_Args[1] = "on")   ; restarted as administrator while ON
    SetTimer () => TriggerRun(DoAutoDial), -300
else
    Flash("Owlman Dials is ready.`nTap Right Alt to turn it on.", 4000)

; ---------- ON / OFF: RIGHT ALT ----------
; Right Alt is held back and re-sent, so a tap alone never opens a menu
; (Alt alone would) but Right Alt + another key still works.
; Whether Owlman was ON is decided when the key goes DOWN: pressing any key
; already stops a run, so by the time it comes up the run may be over, and that
; tap must mean OFF, not "start again".
global AltHeld := false, AltDownBusy := false
*RAlt:: {
    global AltHeld, AltDownBusy
    if !AltHeld {               ; first press, not the auto-repeat while held
        AltHeld := true
        AltDownBusy := Running
    }
    Send "{Blind}{RAlt down}"
}
*RAlt Up:: {
    global AltHeld := false
    alone := (A_PriorKey = "RAlt")
    if alone
        Send "{Blind}{vkE8}"    ; tells Windows "Alt was used", so no menu opens
    Send "{Blind}{RAlt up}"
    if !alone
        return
    if AltDownBusy
        OwlOff()
    else
        TriggerRun(DoAutoDial)
}

OwlOff() {
    global Abort := true, UserStopped := true
    Panel.Hide()
    Log("OFF")
    Flash("Owlman Dials OFF", 1500)
}

SetStatus(msg) {
    try PanelStatus.Value := msg
}

; The box stays on top of everything, so it must never sit over a saved button
; (it would hide it, or a click meant for the button would hit the box).
; Move it to the first corner that's clear of all of them.
KeepPanelClear(spots) {
    Panel.GetPos(&px, &py, &pw, &ph)
    W := A_ScreenWidth, H := A_ScreenHeight, m := 10 + SpotSlack
    covers(x, y) {
        for p in spots
            if (p[1] >= x - m && p[1] <= x + pw + m && p[2] >= y - m && p[2] <= y + ph + m)
                return true
        return false
    }
    if !covers(px, py)
        return
    for xy in [[10, H - ph - 80], [W - pw - 10, H - ph - 80], [W - pw - 10, 80], [(W - pw) // 2, H - ph - 80], [(W - pw) // 2, 80]] {
        if !covers(xy[1], xy[2]) {
            Panel.Move(xy[1], xy[2])
            Log("moved the Owlman box to " xy[1] "," xy[2] " so it doesn't cover a button")
            return
        }
    }
    Log("couldn't find a spot for the Owlman box that covers no button")
}

; Anything unexpected: write it down for fixing
OnError(OwlmanError)
OwlmanError(e, *) {
    Log("ERROR: " e.Message " (line " e.Line ")")
    Flash("Owlman Dials hit a problem and stopped.`nSend owlman_log.txt to get it fixed.", 5000)
    try Panel.Hide()
    return 1                    ; no scary error box
}

; ---------- KEYS ----------
#HotIf Running
~Esc::OwlOff()
#HotIf

TriggerRun(fn) {
    if !Running
        SetTimer () => RunAutomation(fn), -1
}

RunAutomation(fn) {
    global Running := true
    global RunStart := A_TickCount
    ReleaseStuckKeys()
    try
        fn()
    finally {
        ReleaseStuckKeys()
        Running := false
        Panel.Hide()            ; OFF again: the box only shows while ON
    }
}

ReleaseStuckKeys() {
    for k in ["LWin", "RWin", "LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift"]
        if GetKeyState(k) && !GetKeyState(k, "P")
            Send "{Blind}{" k " up}"
}

; ---------- OWLMAN DIALS ----------
; Wait for the dialer's call -> let it ring -> hang up + No Contact (your
; Caps Lock) -> the dialer calls the next lead -> again, until you stop it.
DoAutoDial() {
    global Abort := false, UserMoved := false, UserStopped := false
    if MainBusy() {
        Log("not starting: lead_autopilot is in the middle of something")
        return Flash("Your main hotkey is still working.`nWait for it to finish, then tap Right Alt again.", 3000)
    }
    hang := LoadPts(MainIni, "hangup2", ["hangup", "nocontact"])
    mail := LoadPts(MainIni, "points", EmailKeys)
    if !hang || !mail
        return Flash("Owlman Dials needs your lead_autopilot setups first`n(Win and Caps Lock). Put owlman_dials in the same`nfolder as lead_autopilot (Downloads).", 6000)
    red := hang["hangup"], noc := hang["nocontact"], env := mail["email"]
    if (hw := WinExist("VS Connect"))
        RestartAsAdminIfNeeded(hw)
    Panel.Show("NoActivate")
    SetStatus("Starting...`nTap Right Alt (or any key) = OFF.")
    spots := [red, noc]
    for k, p in mail
        spots.Push(p)
    KeepPanelClear(spots)
    Log("RUN Owlman Dials")
    return AutoDialLoop(red, noc, env, mail)
}

AutoDialLoop(red, noc, env, mail) {
    n := 0
    afterNoContact := false
    Loop {
        n += 1
        t := PickTiming()
        Log(" call " n (t.long ? " (LONG dial)" : "") ": ring " t.ring "ms, wait before No Contact " t.noContactPause "ms")
        ; 1. Your dialer does the calling - Owlman never clicks a phone.
        Status(n, "waiting for the dialer's call...")
        r := WaitForCall(red, env, afterNoContact)
        Log(" call " n ": " r)
        if (r = "")
            return Fail("")
        if (r = "none")
            return Fail("a call (your dialer didn't call the lead)")
        if (r = "call") {
            if !EmailShowing(env)       ; special lead: already dialing, it's yours
                return Stopped() ? Fail("") : SpecialLead()
            ; 2. Your Win: upload the lead + send the email, while it rings
            Status(n, "sending the email...")
            if !SendEmail(mail)
                return
            ; 3. Let it ring. You hear it; someone answers -> you tap a key.
            r := RingFor(red, n, t.ring)
            Log(" call " n ": " r)
            if (r = "")
                return Fail("")
        }
        ; 4. Your Caps Lock: hang up (if it's still going), then No Contact
        if !HangUpAndNoContact(red, noc, r = "noanswer", t.noContactPause)
            return
        afterNoContact := true
    }
}

; Hang up (if asked and the red button is there within HangupSkipMs), then No Contact.
HangUpAndNoContact(red, noc, hangUp, pauseMs := 0) {
    waitReload := true          ; the page reloads after a call ends
    if hangUp {
        Log(" hangup: looking")
        if WaitForSpot(red, false, AmbiguousCap, HangupSkipMs) {
            Sleep Settle
            if !SpotVisible(red) {  ; the call ended by itself meanwhile
                Log(" hangup: call already over")
            } else {
                ClickAt(red[1], red[2], true)
                Log(" hangup: clicked")
                ; Make sure the call really ended: the red button goes away.
                Loop 3 {
                    if WaitGone(red, 700)
                        break
                    Log(" hangup: still showing, clicking again")
                    ClickAt(red[1], red[2], true)
                }
            }
        } else {
            if Stopped()
                return Fail("")
            Log(" hangup: not there, skipping to No Contact")
            waitReload := false     ; nothing was hung up, so no reload to wait for
        }
    }
    Log(" nocontact: looking")
    if !WaitForSpot(noc, waitReload, waitReload ? ReloadWait : AmbiguousCap)
        return Fail("No Contact button")
    if pauseMs {
        if !Pause(pauseMs, "No Contact in")
            return Fail("")
        if !SpotVisible(noc) && !WaitForSpot(noc)   ; make sure it's still there after the wait
            return Fail("No Contact button")
    }
    Sleep Settle
    ClickAt(noc[1], noc[2], true)
    Log(" nocontact: clicked")
    return true
}

; Wait for your dialer's call (the red hang-up button shows). After No Contact
; the page also reloads to the next lead: wait for that too (the envelope goes
; away and comes back), so the special-lead check looks at the NEW lead.
; Returns "call", "ended" (the call was over right away), "none" (no call came),
; or "" (stopped).
WaitForCall(red, env, afterNoContact) {
    global CallStart := 0
    start := A_TickCount, envGone := false
    Loop {
        if Stopped()
            return ""
        if !SpotVisible(env)
            envGone := true
        if (!CallStart && SpotVisible(red)) {
            CallStart := A_TickCount
            Log("  call going after " (CallStart - start) "ms")
        }
        if CallStart {
            if !SpotVisible(red) && StaysGone(red, 300)
                return "ended"          ; declined / busy already
            if (!afterNoContact || (envGone && SpotVisible(env)) || A_TickCount - CallStart > ReloadWait)
                return "call"
        } else if (A_TickCount - start > NextCallWait) {
            Log("  no call after " NextCallWait "ms: saw " SeenAt(red) " at the hang-up spot")
            return "none"
        }
        Sleep 20
    }
}

; Let the call ring for ringMs (counted from when the call started).
; Returns "noanswer" (time's up), "ended" (the call ended by itself), or "" (stopped).
RingFor(red, n, ringMs) {
    lastSec := -1
    Loop {
        if Stopped()
            return ""
        el := A_TickCount - CallStart
        if (el >= ringMs)
            return "noanswer"
        secs := (ringMs - el + 999) // 1000
        if (secs != lastSec) {
            lastSec := secs
            Status(n, "hanging up in " secs "s")
        }
        if !SpotVisible(red) && StaysGone(red, 300)
            return "ended"
        Sleep 20
    }
}

; Is the lead's email envelope there? Hovers it like the Win run does and gives
; the page up to EnvelopeWait ms to finish drawing it.
EmailShowing(env) {
    stopAt := A_TickCount + EnvelopeWait
    nudge := 0
    MouseMove env[1], env[2]
    Loop {
        if SpotVisible(env)
            return true
        if Stopped() || A_TickCount > stopAt
            break
        if (Mod(A_Index, 6) = 0)
            MouseMove env[1] + (nudge := !nudge), env[2]
        Sleep 10
    }
    Log("  no email button at " env[1] "," env[2] ": saw " SeenAt(env) ", wanted " Hex(env[3]) " or " Hex(env[4]))
    return false
}

SpecialLead() => Alert("SPECIAL LEAD (no email button)`nIt's already dialing - this one's yours.", "special lead, a call was already going")

; This dial's timing: random every time, and a long dial every 10-15 dials
PickTiming() {
    global DialsUntilLong -= 1
    long := DialsUntilLong <= 0
    if long
        DialsUntilLong := Random(LongEveryMin, LongEveryMax)
    return {long: long
        , ring: long ? Random(LongRingMin, LongRingMax) : Random(RingMin, RingMax)
        , noContactPause: long ? Random(LongPauseMin, LongPauseMax) : Random(PauseMin, PauseMax)}
}

; Wait ms (stops early on Esc / key / mouse), showing a countdown in the box
Pause(ms, label) {
    stopAt := A_TickCount + ms
    lastSec := -1
    while (A_TickCount < stopAt) {
        if Stopped()
            return false
        secs := Ceil((stopAt - A_TickCount) / 1000)
        if (secs != lastSec)
            lastSec := secs, SetStatus(label " " secs "s`nTap Right Alt (or any key) = OFF.")
        Sleep 20
    }
    return true
}

Status(n, what) => SetStatus("Call " n ": " what "`nSomeone answers? Tap any key = STOP.")

Alert(msg, why) {
    Log("STOPPED: " why)
    Flash(msg, 6000)
    SoundBeep 1500, 120
}

; ---------- EMAIL (a copy of lead_autopilot's Win key) ----------
global EmailKeys := ["ext", "upload", "email", "tmpl", "next", "scrollbar", "send"]
global EmailNames := Map("ext", "Lead Scraper icon", "upload", "Upload button", "email", "email envelope icon"
    , "tmpl", "NCCTeam template", "next", "Next button", "scrollbar", "scrollbar", "send", "Send button")

; Lead Scraper -> Upload -> envelope -> NCCTeam -> Next -> scroll -> Send.
; True once the email is sent (false = stopped, and it already said why).
SendEmail(pts) {
    Log(" email: start")
    ambiguous := false
    for i, key in EmailKeys {
        p := pts[key]
        if (key = "scrollbar")
            continue
        if (key = "send")
            return ClickSend(p, pts["scrollbar"], pts["next"])
        if (key = "ext" && SpotVisible(pts["upload"])) {
            ; The Lead Scraper popup is still open from last time. Clicking the
            ; icon now would CLOSE it, so go straight to Upload instead.
            Log(" ext: popup already open, not clicking the icon")
            continue
        }
        Log(" " key ": looking")
        if !WaitForSpot(p, ambiguous)
            return Fail(EmailNames[key])
        Sleep Settle
        ; If the next button's spot ALREADY looks ready before we click, don't
        ; trust it until the page has changed (same as lead_autopilot).
        ambiguous := (key != "upload" && key != "next") && SpotVisible(pts[EmailKeys[i + 1]])
        Click p[1], p[2]
        Log(" " key ": clicked")
        if (key = "upload") {
            if !WaitMs(UploadWait)
                return Fail("")
            if !ClosePopup(pts)
                return Fail("a way to close the Lead Scraper popup")
        }
    }
}

; Close the Lead Scraper popup and make sure it's really gone
ClosePopup(pts) {
    up := pts["upload"], ext := pts["ext"]
    Send "{Esc}"
    if WaitGone(up, 500)
        return true
    Log(" popup: Esc didn't close it, clicking the icon to close it")
    Click ext[1], ext[2]        ; the icon toggles the popup closed
    if WaitGone(up, 700)
        return true
    Log(" popup: still open")
    return false
}

; Click Send once it is steadily showing, then make sure the email actually went.
; Clicks again only if the button came back or nothing happened for SendStuckMs,
; so an email is not sent twice.
ClickSend(p, sb, nxt) {
    Loop 6 {
        tryNo := A_Index
        if !ScrollUntilSend(p, sb, nxt)
            return Fail("Send button")
        Click p[1], p[2]
        Log(" send: clicked (try " tryNo ")")
        start := A_TickCount
        goneSince := 0
        Loop {
            if Stopped()
                return Fail("")
            if SpotVisible(p) {
                if goneSince            ; it came back: the click didn't take
                    break
                if (A_TickCount - start > SendStuckMs)
                    break
            } else {
                if !goneSince
                    goneSince := A_TickCount
                if (A_TickCount - goneSince >= SendGoneMs) {
                    Log(" email: sent")
                    return true
                }
            }
            Sleep 10
        }
    }
    return Fail("Send didn't go through")
}

; Scroll the email page (by the scrollbar spot from setup) until Send sits still
ScrollUntilSend(p, sb, nxt) {
    stopAt := A_TickCount + 4000             ; wait for the Next page to go away
    while (A_TickCount < stopAt && SpotVisible(nxt)) {
        if Stopped()
            return false
        Sleep 10
    }
    tried := false
    stopAt := A_TickCount + Timeout + 4000
    while (A_TickCount < stopAt) {
        if Stopped()
            return false
        MouseMove p[1], p[2]
        Sleep 20
        MouseMove p[1] + 1, p[2]
        if StaysVisible(p, 150)
            return true
        MouseMove sb[1], sb[2]
        Sleep 20
        if SpotVisible(sb) {
            if !tried {
                Send("+{Click " sb[1] " " sb[2] "}")   ; Shift+click jumps to the bottom
                tried := true
            } else {
                Click sb[1], sb[2], "Down"            ; hold: Chrome pages down by itself
                Sleep HoldScrollMs
                Click sb[1], sb[2], "Up"
            }
            if !WaitMs(80)
                return false
        }
    }
    return false
}

StaysVisible(p, ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if Stopped() || !SpotVisible(p)
            return false
        Sleep 10
    }
    return true
}

WaitMs(ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if Stopped()
            return false
        Sleep 10
    }
    return true
}

; Is lead_autopilot in the middle of a run or a setup right now? Its log (read
; only) says so: a recent last line that isn't "RUN done" or "STOPPED".
MainBusy() {
    f := A_ScriptDir "\lead_autopilot_log.txt"
    try {
        if (DateDiff(A_Now, FileGetTime(f), "Seconds") > 10)
            return false        ; nothing written lately: idle
        lines := StrSplit(Trim(FileRead(f), "`r`n"), "`n")
        last := Trim(SubStr(lines[lines.Length], 20))  ; drop the time stamp
        return !(InStr(last, "RUN done") = 1 || InStr(last, "STOPPED") = 1)
    }
    return false                ; no log yet
}

; ---------- HELPERS (same as lead_autopilot's) ----------
; Read saved spots: [x, y, hover color, idle color]. 0 if any is missing.
LoadPts(ini, section, keys) {
    pts := Map()
    for k in keys {
        a := StrSplit(IniRead(ini, section, k, ""), ",")
        if (a.Length < 3)
            return 0
        hover := Integer(a[3])
        idle := a.Length >= 4 ? Integer(a[4]) : hover
        pts[k] := [Integer(a[1]), Integer(a[2]), hover, Distinct(idle) ? idle : hover]
    }
    return pts
}

SpotVisible(p) => ColorNear(p, p[3]) || (p.Length >= 4 && p[4] != p[3] && ColorNear(p, p[4]))
ColorNear(p, c) => PixelSearch(&fx, &fy, p[1]-SpotSlack, p[2]-SpotSlack, p[1]+SpotSlack, p[2]+SpotSlack, c, ColorTolerance)

Hex(c) => Format("0x{:06X}", c)

Distinct(c) {
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    hi := Max(r, g, b), lo := Min(r, g, b)
    return (hi - lo >= 40) || (hi < 150)
}

Log(msg) {
    try {
        if (FileExist(LogFile) && FileGetSize(LogFile) > 300000)
            FileDelete LogFile
        FileAppend FormatTime(, "MM/dd HH:mm:ss") "." A_MSec "  " msg "`n", LogFile
    }
}

SeenAt(p) {
    try return Hex(PixelGetColor(p[1], p[2]))
    return "?"
}

WaitForSpot(p, ambiguous := false, cap := AmbiguousCap, limit := 0) {
    start := A_TickCount
    if !limit
        limit := Max(Timeout, cap + Timeout)
    seenGone := !ambiguous
    nudge := 0
    MouseMove p[1], p[2]
    while (A_TickCount - start < limit) {
        if Stopped()
            return false
        if SpotVisible(p) {
            if (seenGone || A_TickCount - start > cap) {
                Log("  found " p[1] "," p[2] " after " (A_TickCount - start) "ms")
                return true
            }
        } else
            seenGone := true
        if (Mod(A_Index, 6) = 0)
            MouseMove p[1] + (nudge := !nudge), p[2]
        Sleep 10
    }
    Log("  NOT FOUND at " p[1] "," p[2] ": saw " SeenAt(p) ", wanted " Hex(p[3]) " or " Hex(p[4]))
    return false
}

Stopped() {
    global Abort, UserMoved
    if Abort
        return true
    if (Running && Min(A_TimeIdleMouse, A_TimeIdleKeyboard) < A_TickCount - RunStart - 50) {
        UserMoved := true
        Abort := true
        return true
    }
    return false
}

WaitGone(p, ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if Stopped()
            return false
        if !SpotVisible(p)
            return true
        Sleep 10
    }
    return false
}

; True if the spot stays NOT showing for ms
StaysGone(p, ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if Stopped() || SpotVisible(p)
            return false
        Sleep 10
    }
    return true
}

ClickAt(x, y, activate := false) {
    MouseMove x, y
    if activate {
        MouseGetPos ,, &hwnd
        if hwnd {
            RestartAsAdminIfNeeded(hwnd)
            if !WinActive(hwnd) {
                try WinActivate hwnd
                try WinWaitActive hwnd,, 0.3
            }
        }
    }
    Click x, y
}

; Windows blocks clicks into programs running as administrator unless this
; script runs as administrator too. If that's the case, restart as admin.
RestartAsAdminIfNeeded(hwnd) {
    if A_IsAdmin
        return
    try pid := WinGetPID(hwnd)
    catch
        return
    if !IsProcessElevated(pid)
        return
    Flash("The softphone runs as administrator.`nRestarting Owlman Dials as administrator - click Yes.", 4000)
    try {
        Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '" on'   ; come back ON
        ExitApp
    }
}

IsProcessElevated(pid) {
    h := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr")
    if !h
        return false
    elev := 0, tok := 0
    if DllCall("advapi32\OpenProcessToken", "ptr", h, "uint", 0x8, "ptr*", &tok) {
        DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 20, "uint*", &elev, "uint", 4, "uint*", &len := 0)
        DllCall("CloseHandle", "ptr", tok)
    }
    DllCall("CloseHandle", "ptr", h)
    return elev != 0
}

Fail(name) {
    Log("STOPPED: " (UserStopped ? "turned OFF" : UserMoved ? "you used the mouse or keyboard" : Abort ? "Esc pressed" : name = "" ? "stopped" : "couldn't find " name))
    if UserMoved
        msg := "Stopped - you used the mouse or keyboard."
    else if Abort || name = ""
        msg := "Stopped."
    else
        msg := "Couldn't find: " name
    if !UserStopped             ; turned OFF: "OFF" already showed
        Flash(msg, 3000)
}

Flash(msg, ms := 1500) {
    ToolTip msg, 10, 10
    SetTimer () => ToolTip(), -ms
}
