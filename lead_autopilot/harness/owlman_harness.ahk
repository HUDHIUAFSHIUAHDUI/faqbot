#Requires AutoHotkey v2.0
OnError((e, *) => (FileAppend("ERROR: " e.Message " @ line " e.Line " " e.What "`n", "*"), ExitApp(3)))
Out(s) => FileAppend(s "`n", "*")

; Fake softphone + VanillaSoft: 4 colored squares on a borderless window at 0,0
global PHONE := 0x00AA00, RED := 0xDD0000, RING := 0x0000DD, NOC := 0x3366CC, ENV := 0x2266EE, OFF := 0xC0C0C0
global Scenario := EnvGet("SCEN")   ; which call gets answered etc.
global CallNo := 0
try FileDelete A_ScriptDir "\lead_points.ini"
try FileDelete A_ScriptDir "\owlman_log.txt"
try FileDelete A_ScriptDir "\owlman_points.ini"
ini := A_ScriptDir "\lead_points.ini"
IniWrite "100,100," PHONE "," PHONE, ini, "call", "call"
IniWrite "300,100," RED "," RED, ini, "hangup2", "hangup"
IniWrite "100,300," NOC "," NOC, ini, "hangup2", "nocontact"
IniWrite "300,300," RING "," RING, A_ScriptDir "\owlman_points.ini", "autodial", "ringing"
IniWrite "100,100," PHONE "," PHONE, A_ScriptDir "\owlman_points.ini", "autodial", "phone"
IniDelete ini, "call"   ; no F12 setup in lead_autopilot
for k in ["ext","upload","email","tmpl","next","scrollbar","send"]
    IniWrite "5,5,0,0", ini, "points", k   ; email flow unused
IniWrite "100,200," ENV "," ENV, ini, "points", "email"

g := Gui("-Caption +AlwaysOnTop")
g.BackColor := "FFFFFF"
global cPhone := g.Add("Text", "x80 y80 w40 h40 Background" Format("{:06X}", PHONE))
global cRed   := g.Add("Text", "x280 y80 w40 h40 Background" Format("{:06X}", OFF))
global cNoc   := g.Add("Text", "x80 y280 w40 h40 Background" Format("{:06X}", NOC))
global cEnv   := g.Add("Text", "x80 y180 w40 h40 Background" Format("{:06X}", ENV))
global cRing  := g.Add("Text", "x280 y280 w40 h40 Background" Format("{:06X}", OFF))
cPhone.OnEvent("Click", PhoneClick)
cRed.OnEvent("Click", RedClick)
cNoc.OnEvent("Click", NocClick)
g.Show("x0 y0 w500 h400 NoActivate")

SetC(c, col) {
    if (c = cRing && col = OFF && (Scenario = "badspot" || Scenario = "stuck"))
        return   ; broken setup: the "ringing" spot never goes away
    c.Opt("Background" Format("{:06X}", col)), c.Redraw()
}

PhoneClick(*) => StartFakeCall("!!! OWLMAN CLICKED THE PHONE (bug)")
StartFakeCall(how) {
    global CallNo += 1
    Out("  [fake] " how " -> call " CallNo)
    SetC(cRed, RED)
    SetTimer () => SetC(cRing, RING), -700          ; starts ringing
    ; scenario: which call gets answered, which one the lead declines
    if (Scenario = "answer2" && CallNo = 2) || (Scenario = "answer1" && CallNo = 1)
        SetTimer () => SetC(cRing, OFF), -2500      ; picked up: ringing stops, red stays
    if (Scenario = "answer2" && CallNo = 1) || (Scenario = "decline" || Scenario = "noauto") || (Scenario = "stuck")
        ; call 1 rings out (script hangs up); in "decline" every call is declined
        (Scenario = "decline" || Scenario = "stuck") ? SetTimer(EndCall, -2000) : 0
}
EndCall() {
    Out("  [fake] lead declined, call ended")
    SetC(cRing, OFF), SetC(cRed, OFF), Reload_()
}
RedClick(*) {
    Out("  [fake] hung up")
    SetC(cRing, OFF), SetC(cRed, OFF)
    Reload_()
}
Reload_() {      ; page reloads: both page buttons blink off for a moment
    SetC(cNoc, OFF), SetC(cPhone, OFF)
    SetTimer () => (SetC(cNoc, NOC), SetC(cPhone, PHONE)), -400
}
NocClick(*) {
    Out("  [fake] No Contact clicked -> next lead")
    Reload_()
    if (Scenario != "noauto")           ; like the real dialer: calls the next lead by itself
        SetTimer () => StartFakeCall("DIALER called the next lead"), -900
    if (Scenario = "special" && CallNo = 1)        ; lead 2 is a special lead: no email button
        SetTimer () => SetC(cEnv, OFF), -300
    if (Scenario = "decline" && CallNo >= 3)
        SetTimer () => (Out("  [fake] pressing Esc"), Abort := true), -600
}

WriteMainLog(line) {
    try FileDelete f
    FileAppend(FormatTime(, "MM/dd HH:mm:ss") ".123  " line "`n", f)
}
#Include ..\owlman_dials.ahk   ; run from lead_autopilot\harness
if (Scenario = "busy") {
    global f := A_ScriptDir "\lead_autopilot_log.txt"
    try FileDelete f
    Out("no main log        -> busy=" MainBusy())
    WriteMainLog(" send: clicked (try 1)"), Out("main mid-run       -> busy=" MainBusy())
    WriteMainLog("RUN done (sent)"),       Out("main finished      -> busy=" MainBusy())
    WriteMainLog("STOPPED: couldn't find Send button"), Out("main stopped       -> busy=" MainBusy())
    WriteMainLog("  hangup: looking"),     FileSetTime(DateAdd(A_Now, -30, "Seconds"), f), Out("old unfinished run -> busy=" MainBusy())
    WriteMainLog(" nocontact: looking"),   DoAutoDial(), Out("F11 while main busy made calls: " CallNo)
    FileDelete f
    ExitApp
}
if (Scenario = "toggle") {
    Sleep 500
    Out("box visible at start: " DllCall("IsWindowVisible", "ptr", Panel.Hwnd))
    SetTimer () => Out("box visible while dialing: " DllCall("IsWindowVisible", "ptr", Panel.Hwnd)), -1500
    SetTimer () => (Out("  [test] tapping Right Alt to turn OFF mid-call"), OwlOff()), -2500
    SetTimer () => StartFakeCall("DIALER called the lead"), -500
    DoAutoDial()
    Out("after stop: box visible=" DllCall("IsWindowVisible", "ptr", Panel.Hwnd) "  calls made: " CallNo)
    Out(FileRead(A_ScriptDir "\owlman_log.txt"))
    ExitApp
}

if (Scenario = "timing") {
    longs := [], rMin := 99999, rMax := 0, pMin := 99999, pMax := 0
    Loop 60 {
        t := PickTiming()
        if t.long {
            longs.Push(A_Index)
            if (t.ring < 28000 || t.ring > 30000 || t.noContactPause < 5000 || t.noContactPause > 7000 || t.dialPause < 5000 || t.dialPause > 7000)
                Out("BAD long timing on dial " A_Index)
        } else {
            rMin := Min(rMin, t.ring), rMax := Max(rMax, t.ring)
            pMin := Min(pMin, t.noContactPause, t.dialPause), pMax := Max(pMax, t.noContactPause, t.dialPause)
        }
    }
    s := "" 
    for i in longs
        s .= i " "
    Out("long dials at: " s)
    Out("normal ring: " rMin "-" rMax "ms   normal waits: " pMin "-" pMax "ms")
    ExitApp
}
RingMin := 2500, RingMax := 3000, PauseMin := 300, PauseMax := 600, NextCallWait := 4000   ; short, so tests run fast
global LastMute := -1
WatchMute() {
    global LastMute
    try {
        ComCall(15, SpeakerVolume(0), "int*", &m := 0)
        if (m != LastMute)
            Out("  [speaker] " (m ? "MUTED" : "sound on")), LastMute := m
    } catch as e
        Out("  [speaker] can't read: " e.Message)
}
SetTimer WatchMute, 50
if (Scenario = "lastmoment") {
    Sleep 500
    SetC(cRed, RED)                 ; call is up, ringing sign OFF = they just picked up
    Out("ring off, red on -> " HangUpAndNoContact([300,100,RED,RED], [100,300,NOC,NOC], true, [300,300,RING,RING]))
    SetC(cRing, RING), Sleep(200)   ; still ringing -> must hang up
    Out("ring on,  red on -> " HangUpAndNoContact([300,100,RED,RED], [100,300,NOC,NOC], true, [300,300,RING,RING]))
    Panel.GetPos(&x1, &y1)
    KeepPanelClear([[x1 + 20, y1 + 20]])   ; a saved button under the box
    Panel.GetPos(&x2, &y2)
    Out("box was at " x1 "," y1 " -> now " x2 "," y2)
    Out(FileRead(A_ScriptDir "\owlman_log.txt"))
    ExitApp
}
if (Scenario = "setupoff") {
    Sleep 500
    IniDelete A_ScriptDir "\owlman_points.ini", "autodial", "ringing"
    StartRingingSetup()   ; in setup, box showing
    Sleep 800
    Panel.GetPos(&x, &y, &w, &h)
    MouseMove x + w // 2, y + h - 25 ; over the Stop button
    Out("clicking Stop during setup")
    RecordRinging()
    Sleep 800
    Out("setup now: '" SetupOn "'  box visible=" DllCall("IsWindowVisible", "ptr", Panel.Hwnd) "  ringing saved: " IniRead(A_ScriptDir "\owlman_points.ini", "autodial", "ringing", "(none)"))
    ExitApp
}
if (Scenario = "setup") {
    IniDelete A_ScriptDir "\owlman_points.ini", "autodial"
    Sleep 500
    StartFakeCall("DIALER called the lead")
    DoAutoDial()                 ; first Right Alt tap -> setup
    Out("setup on: " SetupOn "  box visible=" DllCall("IsWindowVisible", "ptr", Panel.Hwnd) "  Owlman clicked the phone? " (CallNo > 1 ? "YES - bug" : "no"))
    Sleep 1200
    MouseMove 450, 350
    RecordRinging()
    Out("after white click, setup on: " SetupOn)
    MouseMove 300, 300
    RecordRinging()
    Out("after ringing click, setup on: " SetupOn "  box visible=" DllCall("IsWindowVisible", "ptr", Panel.Hwnd) "  saved: " IniRead(A_ScriptDir "\owlman_points.ini", "autodial", "ringing", "(none)"))
    ExitApp
}
if (Scenario = "nohang") {
    Sleep 500
    Out("result: " HangUpAndNoContact([300,100,RED,RED], [100,300,NOC,NOC], true))
    Out(FileRead(A_ScriptDir "\owlman_log.txt"))
    ExitApp
}
Sleep 500
Out("scenario " Scenario)
if (Scenario = "badspot") {
    SetC(cRing, RING)       ; "ringing" sign shows with no call = bad setup
    Sleep 300
}
SetTimer () => StartFakeCall("DIALER called the lead"), -1000
DoAutoDial()   ; not via RunAutomation: Wine counts the script's own clicks as "you moved the mouse"
Sleep 300
Out("calls made: " CallNo)
Out("ini autodial: " IniRead(A_ScriptDir "\owlman_points.ini", "autodial", "ringing", "(deleted)"))
Out("--- log ---")
Out(FileRead(A_ScriptDir "\owlman_log.txt"))
ExitApp
