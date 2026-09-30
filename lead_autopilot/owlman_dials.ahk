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
; A SEPARATE add-on to lead_autopilot. It starts ASLEEP: while asleep it does
; nothing at all except listen for F9 (F11 works like normal).
;   F9 = turn ON.  A small "OWLMAN DIALS is ON" box shows.
;   F9 again (or "Turn OFF" in the box) = turn OFF: stops any run, sound back on,
;   box goes away, asleep again.
; While ON, F11 = call the lead; nobody answers in time -> hang up, No Contact,
;   next lead. Keeps going until someone picks up, then beeps and stops.
;   Your speakers/headset stay muted while it rings (never your microphone).
;   A lead with NO email button is a special lead: it stops without calling it.
; Esc, any other key, or moving the mouse stops a run (so it never runs at the same
;   time as a lead_autopilot key like Caps Lock).
;
; It never changes lead_autopilot or its saved spots: it only READS the spots
; from lead_points.ini (Win, Caps Lock and F12 setups) and keeps its own one
; spot (the ringing sign) in owlman_points.ini.
; =====================================================

; Timing changes a little every call (random within these ranges, in ms), and
; every LongEvery dials one call is a "long" one where everything takes longer.
global RingMin := 18000, RingMax := 23000         ; ringing with no answer before hanging up
global PauseMin := 2000, PauseMax := 5000         ; wait before No Contact, and before calling the next lead
global LongRingMin := 28000, LongRingMax := 30000 ; the same, on a long dial
global LongPauseMin := 5000, LongPauseMax := 7000
global LongEveryMin := 10, LongEveryMax := 15     ; a long dial happens every 10-15 dials
global DialsUntilLong := Random(LongEveryMin, LongEveryMax)
global DialWait      := 8000    ; ms to wait for ringing to start after clicking the green phone
global AnsweredConfirmMs := 800 ; ringing sign must stay gone this long (red button still there) = answered
global EnvelopeWait  := 1500    ; ms to wait for the email button before calling it a special lead
global HangupSkipMs  := 3000    ; red hang-up button not found in this long = call's already over
global ReloadWait    := 3000    ; ms max to wait for the page to reload after hanging up
global Settle        := 40      ; ms pause after a button appears, before clicking
global Timeout       := 5000    ; ms to wait for a button before giving up
global ColorTolerance := 40
global SpotSlack     := 4
global AmbiguousCap  := 800

global MainIni := A_ScriptDir "\lead_points.ini"        ; lead_autopilot's spots (read only)
global OwnIni  := A_ScriptDir "\owlman_points.ini"   ; the ringing sign
global LogFile := A_ScriptDir "\owlman_log.txt"
global Abort := false, UserMoved := false, Running := false, RunStart := 0
global SetupOn := false
global OwlOn := false          ; asleep until F9

; ---------- ON/OFF BOX ----------
global Panel := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Owlman Dials")
Panel.SetFont("s10 bold", "Segoe UI")
Panel.Add("Text", "c008800", "OWLMAN DIALS is ON")
Panel.SetFont("s9 norm")
global PanelStatus := Panel.Add("Text", "w230 r3", "Tap F11 to start.`nAny key or mouse move = stop.")
Panel.Add("Button", "w230 h32", "Turn OFF  (F9)").OnEvent("Click", (*) => OwlOff())
Panel.OnEvent("Close", (*) => OwlOff())
Panel.Show("Hide x10 y" (A_ScreenHeight - 230))    ; placed, but hidden while asleep
if (A_Args.Length && A_Args[1] = "on")   ; restarted as administrator while ON
    SetTimer OwlOnNow, -100
else
    Flash("Owlman Dials is ready (asleep).`nPress F9 to turn it on.", 4000)

; ---------- ON / OFF (F9) ----------
F9::(OwlOn ? OwlOff() : OwlOnNow())

OwlOnNow() {
    global OwlOn := true
    SetStatus("Tap F11 to start.`nAny key or mouse move = stop.")
    Panel.Show("NoActivate")
    Log("ON")
    Flash("Owlman Dials ON", 1500)
}

OwlOff() {
    global OwlOn := false, Abort := true, SetupOn := false
    SpeakersMuted(false)        ; a run in progress also stops and unmutes by itself
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

; Anything unexpected: never leave you muted, and write it down for fixing
OnError(OwlmanError)
OwlmanError(e, *) {
    SpeakersMuted(false)
    Log("ERROR: " e.Message " (line " e.Line ")")
    Flash("Owlman Dials hit a problem and stopped.`nSend owlman_log.txt to get it fixed.", 5000)
    SetStatus("Stopped (error). Tap F11 to try again.")
    return 1                    ; no scary error box
}

; ---------- KEYS ----------
#HotIf OwlOn                   ; asleep = F11 does its normal thing
*F11::TriggerRun(DoAutoDial)
#HotIf

#HotIf OwlOn
~Esc:: {
    global Abort := true
    global SetupOn
    if SetupOn {
        SetupOn := false
        Flash("Owlman Dials setup cancelled.")
        SetStatus("Tap F11 to start.`nAny key or mouse move = stop.")
    }
}
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
    }
}

ReleaseStuckKeys() {
    for k in ["LWin", "RWin", "LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift"]
        if GetKeyState(k) && !GetKeyState(k, "P")
            Send "{Blind}{" k " up}"
}

; ---------- SETUP (one spot: the ringing sign) ----------
#HotIf SetupOn
LButton::RecordRinging()
#HotIf

StartRingingSetup(phone) {
    global SetupOn
    Log("SETUP: calling so the ringing sign shows")
    if WaitForSpot(phone) {
        ClickAt(phone[1], phone[2], true)
        Log(" setup: phone clicked")
        Sleep 300               ; let the click land before the setup message pops up over the screen
    }
    SetupOn := true
    msg := "OWLMAN DIALS SETUP`n`nThe lead is being called (F12 calls again).`nWhile it's RINGING, click the sign on the softphone that shows it's ringing`n(like the word 'Ringing'). Pick one that doesn't blink.`nThis click does nothing to the call.`n`n(Esc = cancel)"
    ToolTip msg, 10, 10
    SetStatus("Setup: click the ringing sign.")
}

RecordRinging() {
    global SetupOn
    MouseGetPos &x, &y, &win
    if (win = Panel.Hwnd) {     ; a click on the Owlman box (like Turn OFF): let it through
        Click
        return
    }
    Sleep 250
    c := PixelGetColor(x, y)
    MouseMove 1, 1
    Sleep 150
    idle := PixelGetColor(x, y)
    MouseMove x, y
    if !Distinct(c) && !Distinct(idle) {
        ToolTip "That spot is plain white or gray.`nClick right ON the colored part or the dark text of the ringing sign.`n`n(Esc = cancel)", 10, 10
        return
    }
    IniWrite x "," y "," c "," idle, OwnIni, "autodial", "ringing"
    Log("SETUP ringing at " x "," y " hover=" c " idle=" idle)
    SetupOn := false
    SoundBeep 1200, 60
    Flash("Setup saved!`nHang up this call (Caps Lock), then tap F11 to start Owlman Dials.", 5000)
    SetStatus("Tap F11 to start.`nAny key or mouse move = stop.")
}

; ---------- OWLMAN DIALS ----------
; Call -> watch the ringing sign -> nobody answered in time? hang up + No Contact,
; then call the next lead. Stops the moment someone picks up.
; When unsure what's happening it STOPS instead of hanging up, so a real person
; is never hung up on because of a guess.
DoAutoDial() {
    global Abort := false
    global UserMoved := false
    if SetupOn || !OwlOn
        return
    if MainBusy() {
        Log("not starting: lead_autopilot is in the middle of something")
        return Flash("Your main hotkey is still working.`nWait for it to finish, then tap F11 again.", 3000)
    }
    call := LoadPts(MainIni, "call", ["call"])
    hang := LoadPts(MainIni, "hangup2", ["hangup", "nocontact"])
    env  := LoadPts(MainIni, "points", ["email"])
    if !call || !hang || !env
        return Flash("Owlman Dials needs your lead_autopilot setups first`n(Win, Caps Lock and F12). Put owlman_dials in the same`nfolder as lead_autopilot (Downloads).", 6000)
    phone := call["call"], red := hang["hangup"], noc := hang["nocontact"], env := env["email"]
    ring := LoadPts(OwnIni, "autodial", ["ringing"])
    if !ring
        return StartRingingSetup(phone)
    ring := ring["ringing"]
    KeyWait "F11"
    global RunStart := A_TickCount  ; letting go of F11 isn't a "stop" key press
    if (hw := WinExist("VS Connect"))
        RestartAsAdminIfNeeded(hw)
    KeepPanelClear([phone, red, noc, ring, env])
    Log("RUN Owlman Dials")
    SpeakersMuted(true)         ; no ringing in your ears; sound comes back when someone picks up
    try
        return AutoDialLoop(phone, red, noc, ring, env)
    finally
        SpeakersMuted(false)    ; however it stops, you always get your sound back
}

AutoDialLoop(phone, red, noc, ring, env) {
    n := 0
    afterNoContact := false
    Loop {
        n += 1
        SpeakersMuted(true)
        t := PickTiming()
        Log(" call " n (t.long ? " (LONG dial)" : "") ": ring up to " t.ring "ms, waits " t.dialPause "/" t.noContactPause "ms")
        ; 1. Start the call (unless VanillaSoft already started one by itself)
        if SpotVisible(red) {
            Log(" call " n ": a call is already going, not clicking the phone")
            if !EmailShowing(env)
                return Stopped() ? Fail("") : SpecialLead(true)
        } else {
            if StaysVisible(ring, 500)
                return BadRingingSpot("it shows even with no call going")
            r := DialLead(phone, red, env, afterNoContact, afterNoContact ? t.dialPause : 0)
            if (r = "special")
                return Stopped() ? Fail("") : SpecialLead(false)
            if (r = "auto" && !EmailShowing(env))
                return Stopped() ? Fail("") : SpecialLead(true)
            if !r
                return Fail("green phone icon")
        }
        ; 2. Wait for it to start ringing
        Status(n, "dialing...")
        if !WaitRinging(ring) {
            if Stopped()
                return Fail("")
            if SpotVisible(red)
                return Alert("Couldn't see it ringing - check the call!", "never saw the ringing sign, but the call is up")
            return Fail("a call starting (the ringing sign never showed)")
        }
        ; 3. Watch until it's answered, ends, or rings too long
        result := WatchCall(ring, red, n, t.ring)
        Log(" call " n ": " result)
        switch result {
            case "answered":
                return Alert("SOMEONE ANSWERED - go!", "answered on call " n)
            case "noanswer":
                r := HangUpAndNoContact(red, noc, true, ring, t.noContactPause)
                if (r = "answered")
                    return Alert("SOMEONE ANSWERED - go!", "answered right at the time limit, on call " n)
                if !r
                    return
            case "ended":           ; they declined / busy: the call is already over
                if !HangUpAndNoContact(red, noc, false, 0, t.noContactPause)
                    return
            case "badspot":
                return BadRingingSpot("it stayed on after the call ended")
            default:                ; Esc / mouse moved
                return Fail("")
        }
        afterNoContact := true
    }
}

; Hang up (if asked and the red button is there within HangupSkipMs), then No Contact.
HangUpAndNoContact(red, noc, hangUp, ring := 0, pauseMs := 0) {
    waitReload := true          ; the page reloads after a call ends
    if hangUp {
        Log(" hangup: looking")
        if WaitForSpot(red, false, AmbiguousCap, HangupSkipMs) {
            Sleep Settle
            ; Last look: if the ringing stopped right at the time limit and the call
            ; is still up, they just picked up - never hang up on them.
            if ring && !SpotVisible(ring) {
                gone := StaysGone(ring, AnsweredConfirmMs)
                if Stopped()
                    return Fail("")
                if gone && SpotVisible(red) {
                    SpeakersMuted(false)
                    Log(" hangup: they picked up at the last moment - NOT hanging up")
                    return "answered"
                }
            }
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

; Click the green phone once the lead's page is ready. Right after No Contact the
; old lead's phone icon is still showing, so first wait for the page to change.
; No email button on the new lead = special lead: don't call it.
; Returns "clicked", "auto" (a call started by itself), "special", or "" (failed).
DialLead(p, red, env, afterNoContact, pauseMs := 0) {
    start := A_TickCount
    seenGone := !afterNoContact
    nudge := 0
    MouseMove p[1], p[2]
    while (A_TickCount - start < ReloadWait + Timeout) {
        if Stopped()
            return ""
        if SpotVisible(red) {       ; VanillaSoft dialed the next lead by itself
            Log("  a call started by itself, not clicking the phone")
            return "auto"
        }
        if SpotVisible(p) && (seenGone || A_TickCount - start > ReloadWait) {
            if !EmailShowing(env)
                return "special"
            if pauseMs {
                if !Pause(pauseMs, "next call in")
                    return ""
                pauseMs := 0
                start := A_TickCount, seenGone := true
                if SpotVisible(red) {   ; VanillaSoft dialed it by itself meanwhile
                    Log("  a call started by itself, not clicking the phone")
                    return "auto"
                }
                MouseMove p[1], p[2]
                continue            ; look at the phone icon again, then click
            }
            Sleep Settle
            ClickAt(p[1], p[2], true)
            Log("  phone clicked after " (A_TickCount - start) "ms")
            return "clicked"
        }
        if !SpotVisible(p)
            seenGone := true
        if (Mod(A_Index, 6) = 0)    ; wiggle 1px so Chrome refreshes the hover color
            MouseMove p[1] + (nudge := !nudge), p[2]
        Sleep 10
    }
    Log("  NOT FOUND at " p[1] "," p[2] ": saw " SeenAt(p) ", wanted " Hex(p[3]) " or " Hex(p[4]))
    return ""
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

SpecialLead(calling) {
    if calling
        Alert("SPECIAL LEAD (no email button)`nIt's already dialing - this one's yours.", "special lead, a call was already going")
    else
        Alert("SPECIAL LEAD (no email button)`nNot called - dial this one yourself.", "special lead, not called")
}

WaitRinging(ring) {
    stopAt := A_TickCount + DialWait
    while (A_TickCount < stopAt) {
        if Stopped()
            return false
        if SpotVisible(ring)
            return true
        Sleep 20
    }
    Log("  ringing sign never showed: saw " SeenAt(ring) ", wanted " Hex(ring[3]) " or " Hex(ring[4]))
    return false
}

; This dial's timing: random every time, and a long dial every 10-15 dials
PickTiming() {
    global DialsUntilLong -= 1
    long := DialsUntilLong <= 0
    if long
        DialsUntilLong := Random(LongEveryMin, LongEveryMax)
    return {long: long
        , ring: long ? Random(LongRingMin, LongRingMax) : Random(RingMin, RingMax)
        , noContactPause: long ? Random(LongPauseMin, LongPauseMax) : Random(PauseMin, PauseMax)
        , dialPause: long ? Random(LongPauseMin, LongPauseMax) : Random(PauseMin, PauseMax)}
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
            lastSec := secs, SetStatus(label " " secs "s`nAny key or mouse move = stop.")
        Sleep 20
    }
    return true
}

; Returns "answered", "noanswer", "ended", "badspot", or "" (stopped)
WatchCall(ring, red, n, ringLimit) {
    start := A_TickCount
    lastSec := -1
    Loop {
        if Stopped()
            return ""
        secs := (A_TickCount - start) // 1000
        if (secs != lastSec) {
            lastSec := secs
            Status(n, "ringing " secs "s")
        }
        if SpotVisible(ring) {
            if !SpotVisible(red)        ; call over but "ringing" still showing: wrong spot
                if !WaitGoneOrBack(ring, red, 1500)
                    return "badspot"
            if (A_TickCount - start > ringLimit)
                return "noanswer"
        } else {
            ; Ringing stopped. Red button still there for a moment = picked up.
            ; Red button gone too = the call ended without an answer.
            SpeakersMuted(false)        ; right away, so you hear their "Hello?"
            confirmUntil := A_TickCount + AnsweredConfirmMs
            back := false
            while (A_TickCount < confirmUntil) {
                if Stopped()
                    return ""
                if !SpotVisible(red)
                    return "ended"
                if SpotVisible(ring) {  ; just a flicker, still ringing
                    SpeakersMuted(true)
                    back := true
                    break
                }
                Sleep 20
            }
            if !back
                return "answered"
        }
        Sleep 20
    }
}

; With no call going, the ringing sign should go away within ms (false = it didn't)
WaitGoneOrBack(ring, red, ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if !SpotVisible(ring) || SpotVisible(red)
            return true
        Sleep 20
    }
    return false
}

; The saved ringing spot can't tell ringing from not ringing: forget it, so the
; next F11 tap redoes that setup.
BadRingingSpot(why) {
    Log("STOPPED: ringing sign spot is wrong (" why ")")
    try IniDelete OwnIni, "autodial"
    Flash("Owlman Dials stopped: the ringing sign I saved doesn't work`n(" why ").`nTap F11 to set it up again.", 6000)
    SetStatus("Stopped: ringing sign needs setup again.`nTap F11.")
}

Status(n, what) => SetStatus("Call " n ": " what "`nAny key or mouse move = stop.")

Alert(msg, why) {
    Log("STOPPED: " why)
    SpeakersMuted(false)
    Flash(msg, 6000)
    SetStatus(StrReplace(msg, "`n", " ") "`nTap F11 to start again.")
    SoundBeep 1500, 120
}

; ---------- SOUND ----------
; Mute/unmute the speakers/headset only (never the microphone). Covers both the
; normal sound device and the one Windows uses for calls, in case they differ.
; Only ever unmutes what this script muted.
global MutedByUs := []
OnExit((*) => SpeakersMuted(false))     ; turning it off mid-run never leaves you muted
SpeakersMuted(mute) {
    global MutedByUs
    if !mute {
        for vol in MutedByUs
            try ComCall(14, vol, "int", 0, "ptr", 0)            ; SetMute(false)
        if MutedByUs.Length
            Log("  sound back on")
        MutedByUs := []
        return
    }
    if MutedByUs.Length
        return
    for role in [0, 2] {                                        ; 0 = normal, 2 = calls
        try {
            vol := SpeakerVolume(role)
            ComCall(15, vol, "int*", &was := 0)                 ; GetMute
            if was
                continue                                        ; already muted by you: leave it alone
            ComCall(14, vol, "int", 1, "ptr", 0)                ; SetMute(true)
            MutedByUs.Push(vol)
        } catch as e
            Log("  couldn't mute sound device (" e.Message ")")
    }
    if MutedByUs.Length
        Log("  sound muted")
}

; The volume control of the default playback device for a role (IAudioEndpointVolume)
SpeakerVolume(role) {
    enum := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    ComCall(4, enum, "int", 0, "int", role, "ptr*", &dev := 0)  ; GetDefaultAudioEndpoint(eRender, role)
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "ptr", iid)
    try ComCall(3, dev, "ptr", iid, "uint", 23, "ptr", 0, "ptr*", &vol := 0)   ; Activate(IAudioEndpointVolume)
    finally ObjRelease(dev)
    return ComValue(13, vol)
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

StaysVisible(p, ms) {
    stopAt := A_TickCount + ms
    while (A_TickCount < stopAt) {
        if Stopped() || !SpotVisible(p)
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
    Log("STOPPED: " (!OwlOn ? "turned OFF" : UserMoved ? "you used the mouse or keyboard" : Abort ? "Esc pressed" : name = "" ? "stopped" : "couldn't find " name))
    if UserMoved
        msg := "Stopped - you used the mouse or keyboard."
    else if Abort || name = ""
        msg := "Stopped."
    else
        msg := "Couldn't find: " name
    if OwlOn
        Flash(msg, 3000)
    SetStatus(msg "`nTap F11 to start again.")
}

Flash(msg, ms := 1500) {
    ToolTip msg, 10, 10
    SetTimer () => ToolTip(), -ms
}
