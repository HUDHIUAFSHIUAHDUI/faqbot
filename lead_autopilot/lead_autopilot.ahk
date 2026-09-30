#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
InstallMouseHook                  ; lets the script tell YOUR mouse moves from its own
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
SetDefaultMouseSpeed 0
SetMouseDelay -1
SetKeyDelay -1
; Use real screen pixels for both mouse and colors (avoids tablet scaling mix-ups)
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; Close any other copy of this script that is still running (e.g. "lead_autopilot (1).ahk")
DetectHiddenWindows true
for hwnd in WinGetList("ahk_class AutoHotkey") {
    try {
        if (hwnd != A_ScriptHwnd && InStr(WinGetTitle(hwnd), "lead_autopilot"))
            WinClose hwnd
    }
}
DetectHiddenWindows false

; ===================== HOW TO USE =====================
; CAPS LOCK: click the red hang-up button, wait for the page to reload, click No Contact.
;   Shift+Caps Lock still turns caps on/off.
; F12: click the green phone icon next to the lead's number (call them).
; Caps Lock and F12 each have their own quick setup, done the first time the key is tapped.
; Esc = stop a run or cancel setup.      Ctrl+Alt+X = quit the script.
; ======================================================

global Settle         := 40     ; ms pause after a button appears, before clicking
global Timeout        := 5000   ; ms to wait for a button before giving up
global ColorTolerance := 40     ; raise if it stalls on a button that IS showing
global SpotSlack      := 4      ; px around a saved spot where its color may show
global AmbiguousCap   := 800    ; ms max extra wait when a spot looked "ready" before the page changed
global RetryNear      := 20     ; during setup, a click this close to the last step's spot = retry of that step

; Second automation (Caps Lock): hang up, then No Contact.
; A 4th item of true = the page reloads before this button can be clicked, so wait
; for it to go away and come back (it's already showing before the reload).
global HangupSteps := [
    ["hangup",    "Click the RED hang-up button in the softphone.", "red hang-up button"],
    ["nocontact", "Wait for the page to reload.`nThen click 'No Contact' (bottom of the blue list).", "No Contact button", true]
]
global ReloadWait := 3000       ; ms max to wait for the page to reload after hanging up

; Third automation (F12): call the lead
global CallSteps := [
    ["call", "Click the GREEN phone icon next to the lead's number.", "green phone icon"]
]

; Which key runs each automation (shown in messages)
global KeyNames := Map("hangup2", "Caps Lock", "call", "F12")

global IniFile   := A_ScriptDir "\lead_points.ini"
global LogFile   := A_ScriptDir "\lead_autopilot_log.txt"   ; what each run saw and did (for fixing misses)
global Abort     := false
global SetupStep := 0          ; 0 = not in setup, otherwise the step being recorded
global SetupTemp := Map()
global SetupSteps := HangupSteps    ; which automation setup is recording
global SetupSection := "hangup2"
global StartupLnk := A_Startup "\Lead Autopilot.lnk"

; ---------- TRAY MENU ----------
A_TrayMenu.Insert("1&", "Run Setup (Caps Lock: hang up + No Contact)", (*) => StartSetup(HangupSteps, "hangup2"))
A_TrayMenu.Insert("2&", "Run Setup (F12: call)", (*) => StartSetup(CallSteps, "call"))
A_TrayMenu.Insert("3&", "Start with Windows", ToggleStartup)
A_TrayMenu.Insert("4&")
if FileExist(StartupLnk)
    A_TrayMenu.Check("Start with Windows")

ToggleStartup(name, *) {
    if FileExist(StartupLnk) {
        FileDelete StartupLnk
        A_TrayMenu.Uncheck(name)
    } else {
        FileCreateShortcut A_ScriptFullPath, StartupLnk, A_ScriptDir
        A_TrayMenu.Check(name)
    }
}

; ---------- SETUP ----------
; While setup is on, every left click is remembered (spot + color) and then
; passed through to the page, so the user just does the workflow once.
StartSetup(steps, section) {
    global SetupSteps := steps
    global SetupSection := section
    global SetupStep := 1
    global SetupTemp := Map()
    ShowSetupTip()
}

ShowSetupTip() {
    ToolTip "SETUP for the " KeyNames[SetupSection] " key  (step " SetupStep " of " SetupSteps.Length ")`n`n" SetupSteps[SetupStep][2]
        . "`n`n(Esc = cancel)", 10, 10
}

#HotIf SetupStep
LButton::RecordClick()
#HotIf

RecordClick() {
    global SetupStep
    MouseGetPos &x, &y
    Sleep 250                   ; let the hover highlight finish fading in
    c := PixelGetColor(x, y)
    key := SetupSteps[SetupStep][1]
    if (SetupStep > 1) {        ; clicked the last step's spot again (it didn't take)? retry it, don't move on
        prev := StrSplit(SetupTemp[SetupSteps[SetupStep - 1][1]], ",")
        if (Abs(x - prev[1]) <= RetryNear && Abs(y - prev[2]) <= RetryNear) {
            ClickAt(x, y, true)
            return
        }
    }
    ; Also save the color with the mouse OFF the button: hover colors can differ
    ; a little from moment to moment, and a run matches either one.
    MouseMove 1, 1
    Sleep 150
    idle := PixelGetColor(x, y)
    MouseMove x, y
    Sleep 150
    SetupTemp[key] := x "," y "," c "," idle
    Log("SETUP " SetupSection "/" key " at " x "," y " hover=" c " idle=" idle)
    ClickAt(x, y, true)         ; now do the real click
    SoundBeep 1200, 60
    if (SetupStep >= SetupSteps.Length) {
        SetupStep := 0
        for k, v in SetupTemp
            IniWrite v, IniFile, SetupSection, k
        Flash("Setup saved!`nNext time just tap the " KeyNames[SetupSection] " key.", 4000)
        return
    }
    SetupStep += 1
    ShowSetupTip()
}

; ---------- RUN ----------
; Caps Lock (tapped alone) = hang up, then No Contact. The hotkey swallows the
; key, so caps doesn't toggle; Shift+Caps Lock still turns caps on/off.
*CapsLock::TriggerRun(DoHangup)
+CapsLock::SetCapsLockState(!GetKeyState("CapsLock", "T"))

; F12 = call the lead (also stops F12 opening Chrome's developer tools)
*F12::TriggerRun(DoCall)

; Run in its own thread so the trigger hotkeys stay free while a run is going
global Running := false
global RunStart := 0
global UserMoved := false
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

; If Windows thinks Win/Ctrl/Alt/Shift is still held but it isn't physically,
; let it go, so clicks and other keys don't turn into Win+click etc.
ReleaseStuckKeys() {
    for k in ["LWin", "RWin", "LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift"]
        if GetKeyState(k) && !GetKeyState(k, "P")
            Send "{Blind}{" k " up}"
}

DoHangup() => DoClicks(HangupSteps, "hangup2")
DoCall() => DoClicks(CallSteps, "call")

; Click each saved button in order, as soon as it shows up
DoClicks(steps, section) {
    global Abort := false
    global UserMoved := false
    if SetupStep
        return
    pts := LoadPoints(steps, section)
    if !pts {                   ; first time: go straight into setup for this key
        StartSetup(steps, section)
        return
    }
    KeyWait "Shift"             ; don't Shift-click by accident
    Log("RUN " KeyNames[section])
    for step in steps {
        p := pts[step[1]]
        waitReload := step.Length >= 4 && step[4]
        Log(" " step[1] ": looking")
        if !WaitForSpot(p, waitReload, waitReload ? ReloadWait : AmbiguousCap)
            return Fail(step[3])
        Sleep Settle
        ClickAt(p[1], p[2], true)
        Log(" " step[1] ": clicked")
        if (step[1] = "hangup") {
            ; Make sure the call really ended: the red button goes away. If it's
            ; still there, the click didn't take - click it again.
            Loop 3 {
                if WaitGone(p, 700)
                    break
                Log(" hangup: still showing, clicking again")
                ClickAt(p[1], p[2], true)
            }
        }
    }
    Log("RUN done")
    Flash("Done ✔")
}

; Click a spot. With activate: first bring the window under it to the front,
; because some programs (like the softphone) ignore a click that only
; activates their window. Also makes sure Windows will let us click it at all.
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

; Windows silently blocks clicks into programs running as administrator unless
; this script runs as administrator too. If that's the case, restart as admin.
RestartAsAdminIfNeeded(hwnd) {
    if A_IsAdmin
        return
    try pid := WinGetPID(hwnd)
    catch
        return
    if !IsProcessElevated(pid)
        return
    Flash("The softphone runs as administrator.`nRestarting Lead Autopilot as administrator - click Yes.", 4000)
    try {
        Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        ExitApp
    }
}

IsProcessElevated(pid) {
    h := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr")   ; QUERY_LIMITED_INFORMATION
    if !h
        return false
    elev := 0, tok := 0
    if DllCall("advapi32\OpenProcessToken", "ptr", h, "uint", 0x8, "ptr*", &tok) {  ; TOKEN_QUERY
        DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 20, "uint*", &elev, "uint", 4, "uint*", &len := 0)  ; TokenElevation
        DllCall("CloseHandle", "ptr", tok)
    }
    DllCall("CloseHandle", "ptr", h)
    return elev != 0
}

~Esc:: {
    global Abort := true
    global SetupStep
    if SetupStep {
        SetupStep := 0
        Flash("Setup cancelled. Nothing was changed.")
    }
}

^!x::ExitApp

; ---------- HELPERS ----------
LoadPoints(steps, section) {
    pts := Map()
    for step in steps {
        a := StrSplit(IniRead(IniFile, section, step[1], ""), ",")
        if (a.Length < 3)
            return 0
        ; [x, y, hover color, idle color] (older setups only saved the hover color).
        ; A plain white/gray idle color is ignored: a blank or loading page could
        ; match it and look like the button is there.
        hover := Integer(a[3])
        idle := a.Length >= 4 ? Integer(a[4]) : hover
        pts[step[1]] := [Integer(a[1]), Integer(a[2]), hover, Distinct(idle) ? idle : hover]
    }
    return pts
}

; The button is showing if its hover OR its normal color is at the saved spot
SpotVisible(p) => ColorNear(p, p[3]) || (p.Length >= 4 && p[4] != p[3] && ColorNear(p, p[4]))
ColorNear(p, c) => PixelSearch(&fx, &fy, p[1]-SpotSlack, p[2]-SpotSlack, p[1]+SpotSlack, p[2]+SpotSlack, c, ColorTolerance)

Hex(c) => Format("0x{:06X}", c)

; A real button color (colorful or dark), not page background white/gray
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

; For the log: what color is actually at the spot right now
SeenAt(p) {
    try return Hex(PixelGetColor(p[1], p[2]))
    return "?"
}

; Put the mouse on the spot (setup saved the hovered color) and wait for the color.
; ambiguous = the spot looked ready before the page changed, so first wait to see
; it change (at most AmbiguousCap ms).
WaitForSpot(p, ambiguous := false, cap := AmbiguousCap) {
    start := A_TickCount
    limit := Max(Timeout, cap + Timeout)
    seenGone := !ambiguous
    nudge := 0
    MouseMove p[1], p[2]
    while (A_TickCount - start < limit) {
        if Stopped()
            return false
        if SpotVisible(p) {
            if (seenGone || A_TickCount - start > cap) {
                Log("  found " p[1] "," p[2] " after " (A_TickCount - start) "ms"
                    . (ambiguous ? (seenGone ? " (saw the page change)" : " (page never changed, waited " cap "ms)") : ""))
                return true
            }
        } else
            seenGone := true
        if (Mod(A_Index, 6) = 0)    ; wiggle 1px so Chrome refreshes the hover color
            MouseMove p[1] + (nudge := !nudge), p[2]
        Sleep 10
    }
    Log("  NOT FOUND at " p[1] "," p[2] ": saw " SeenAt(p) ", wanted " Hex(p[3]) " or " Hex(p.Length >= 4 ? p[4] : p[3]))
    return false
}

; Stop the run if Esc was pressed or YOU moved/clicked the mouse since the run
; started (A_TimeIdleMouse only counts real mouse use, not the script's moves).
Stopped() {
    global Abort, UserMoved
    if Abort
        return true
    if (Running && A_TimeIdleMouse < A_TickCount - RunStart - 50) {
        UserMoved := true
        Abort := true
        return true
    }
    return false
}

; True once the spot stops showing the button (within ms)
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

Fail(name) {
    Log("STOPPED: " (UserMoved ? "you moved the mouse" : Abort ? "Esc pressed" : name = "" ? "stopped" : "couldn't find " name))
    if UserMoved
        Flash("Stopped - you moved the mouse.")
    else if Abort || name = ""
        Flash("Stopped.")
    else
        Flash("Couldn't find: " name "`nIf this keeps happening, run setup again.", 3000)
}

Flash(msg, ms := 1500) {
    ToolTip msg, 10, 10
    SetTimer () => ToolTip(), -ms
}

; ---------- ON LAUNCH ----------
if (hw := WinExist("VS Connect"))
    RestartAsAdminIfNeeded(hw)
Flash("Lead Autopilot is ON ✔`nCaps Lock = hang up + No Contact   F12 = call"
    . "`n(The first tap of each key sets it up.)", 5000)
