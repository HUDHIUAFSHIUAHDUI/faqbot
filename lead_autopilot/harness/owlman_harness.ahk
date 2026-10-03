#Requires AutoHotkey v2.0
OnError((e, *) => (FileAppend("ERROR: " e.Message " @ line " e.Line " " e.What "`n", "*"), ExitApp(3)))
Out(s) => FileAppend(s "`n", "*")

; Fake softphone + VanillaSoft: colored squares on a borderless window at 0,0
global PHONE := 0x00AA00, RED := 0xDD0000, NOC := 0x3366CC, ENV := 0x2266EE, OFF := 0xC0C0C0
global EXT := 0x884400, UPL := 0x00AA88, TMPL := 0x6600AA, NXT := 0x0044CC, SB := 0x555555, SND := 0x22AA22
global Emails := 0
global Scenario := EnvGet("SCEN")
global CallNo := 0
try FileDelete A_ScriptDir "\lead_points.ini"
try FileDelete A_ScriptDir "\owlman_log.txt"
ini := A_ScriptDir "\lead_points.ini"
IniWrite "300,100," RED "," RED, ini, "hangup2", "hangup"
IniWrite "100,300," NOC "," NOC, ini, "hangup2", "nocontact"
IniWrite "100,200," ENV "," ENV, ini, "points", "email"
IniWrite "440,40," EXT "," EXT, ini, "points", "ext"
IniWrite "440,120," UPL "," UPL, ini, "points", "upload"
IniWrite "240,200," TMPL "," TMPL, ini, "points", "tmpl"
IniWrite "240,260," NXT "," NXT, ini, "points", "next"
IniWrite "470,300," SB "," SB, ini, "points", "scrollbar"
IniWrite "400,360," SND "," SND, ini, "points", "send"

g := Gui("-Caption +AlwaysOnTop")
g.BackColor := "FFFFFF"
global cPhone := g.Add("Text", "x80 y80 w40 h40 Background" Format("{:06X}", PHONE))   ; the blue call button
global cRed   := g.Add("Text", "x280 y80 w40 h40 Background" Format("{:06X}", OFF))
global cNoc   := g.Add("Text", "x80 y280 w40 h40 Background" Format("{:06X}", NOC))
global cEnv   := g.Add("Text", "x80 y180 w40 h40 Background" Format("{:06X}", ENV))
global cExt  := g.Add("Text", "x420 y20 w40 h40 Background" Format("{:06X}", EXT))
global cUpl  := g.Add("Text", "x420 y100 w40 h40 Background" Format("{:06X}", OFF))
global cTmpl := g.Add("Text", "x220 y180 w40 h40 Background" Format("{:06X}", OFF))
global cNxt  := g.Add("Text", "x220 y240 w40 h40 Background" Format("{:06X}", OFF))
global cSb   := g.Add("Text", "x460 y280 w20 h40 Background" Format("{:06X}", OFF))
global cSnd  := g.Add("Text", "x380 y340 w40 h40 Background" Format("{:06X}", OFF))
global PopupOpen := false, ExtClicks := 0, SendClicks := 0
ExtClick(*) {
    global ExtClicks += 1
    if (Scenario = "popupmiss" && ExtClicks = 1)
        return Out("  [fake] Lead Scraper icon click did nothing")
    global PopupOpen := !PopupOpen
    SetC(cUpl, PopupOpen ? UPL : OFF), Out("  [fake] Lead Scraper popup " (PopupOpen ? "open" : "closed"))
}
SendClick(*) {
    global SendClicks += 1
    Out("  [fake] Send clicked (" SendClicks ")")
    if (Scenario = "slowsend")          ; like the tablet: Send takes ~2 s to go away
        return SetTimer(SendDone, -2000)
    SendDone()
}
SendDone() {
    global Emails += 1
    SetC(cSnd, OFF), SetC(cSb, OFF), Out("  [fake] EMAIL SENT (" Emails ")")
}
cExt.OnEvent("Click", ExtClick)
cUpl.OnEvent("Click", (*) => Out("  [fake] lead uploaded"))
global TmplReady := false
EnvClick(*) {
    global TmplReady := false
    Out("  [fake] envelope clicked")
    if (Scenario = "slowtmpl")          ; like the log: the spot never changes color, but the
        SetTimer () => (TmplReady := true), -2000       ; template list takes ~2 s to really load
    else
        SetC(cTmpl, TMPL), TmplReady := true
}
TmplClick(*) {
    Out("  [fake] NCCTeam clicked " (TmplReady ? "(template loaded)" : "TOO EARLY -> BLANK EMAIL"))
    SetC(cTmpl, OFF), SetC(cNxt, NXT)
}
cEnv.OnEvent("Click", EnvClick)
cTmpl.OnEvent("Click", TmplClick)
if (Scenario = "slowtmpl")
    SetC(cTmpl, TMPL)
cNxt.OnEvent("Click", (*) => (SetC(cNxt, OFF), SetC(cSb, SB), SetTimer(() => SetC(cSnd, SND), -500)))
cSnd.OnEvent("Click", SendClick)
cPhone.OnEvent("Click", (*) => StartFakeCall("!!! OWLMAN CLICKED THE PHONE (bug)"))
cRed.OnEvent("Click", RedClick)
cNoc.OnEvent("Click", NocClick)
g.Show("x0 y0 w500 h400 NoActivate")

SetC(c, col) => (c.Opt("Background" Format("{:06X}", col)), c.Redraw())

StartFakeCall(how) {
    global CallNo += 1
    Out("  [fake] " how " -> call " CallNo " at " A_TickCount)
    SetC(cRed, RED)
    if (Scenario = "decline" && CallNo = 2)
        SetTimer EndCall, -1200         ; the lead declines call 2
}
EndCall() {
    Out("  [fake] lead declined, call ended")
    SetC(cRed, OFF), Reload_()
}
RedClick(*) {
    Out("  [fake] hung up at " A_TickCount)
    SetC(cRed, OFF), Reload_()
}
Reload_() {      ; page reloads: the page buttons blink off for a moment
    SetC(cNoc, OFF), SetC(cPhone, OFF), SetC(cEnv, OFF)
    SetTimer () => (SetC(cNoc, NOC), SetC(cPhone, PHONE), SetC(cEnv, ENV), (Scenario = "slowtmpl" ? SetC(cTmpl, TMPL) : 0)), -400
}
NocClick(*) {
    global Abort
    Out("  [fake] No Contact clicked -> next lead at " A_TickCount)
    Reload_()
    if (Scenario = "special" && CallNo = 1)        ; lead 2 is a special lead: no email button
        SetTimer () => SetC(cEnv, OFF), -600
    if (Scenario != "noauto")           ; like the real dialer: calls the next lead by itself
        SetTimer () => StartFakeCall("DIALER called the next lead"), -900
    if (CallNo >= 3)                    ; enough: someone "answers" and you tap a key
        SetTimer () => (Out("  [fake] someone answered, you tap a key"), Abort := true), -1500
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
    WriteMainLog(" nocontact: looking"),   DoAutoDial(), Out("while main busy, calls made: " CallNo "  hang-ups: none expected")
    FileDelete f
    ExitApp
}
if (Scenario = "timing") {
    longs := [], rMin := 99999, rMax := 0, pMin := 99999, pMax := 0
    Loop 60 {
        t := PickTiming()
        if t.long {
            longs.Push(A_Index)
            if (t.ring < 23000 || t.ring > 25000 || t.noContactPause < 5000 || t.noContactPause > 7000)
                Out("BAD long timing on dial " A_Index)
        } else {
            rMin := Min(rMin, t.ring), rMax := Max(rMax, t.ring)
            pMin := Min(pMin, t.noContactPause), pMax := Max(pMax, t.noContactPause)
        }
    }
    s := ""
    for i in longs
        s .= i " "
    Out("long dials at: " s)
    Out("normal ring: " rMin "-" rMax "ms   normal waits: " pMin "-" pMax "ms")
    ExitApp
}
RingMin := 6000, RingMax := 7000, PauseMin := 300, PauseMax := 600, NextCallWait := 4000   ; short, so tests run fast
if (Scenario = "nohang") {
    Sleep 500
    Out("result: " HangUpAndNoContact([300,100,RED,RED], [100,300,NOC,NOC], true))
    Out(FileRead(A_ScriptDir "\owlman_log.txt"))
    ExitApp
}
if (Scenario = "toggle") {
    SetTimer () => Out("box visible while dialing: " DllCall("IsWindowVisible", "ptr", Panel.Hwnd)), -1500
    SetTimer () => (Out("  [test] tapping Right Alt to turn OFF mid-call"), OwlOff()), -2000
}
Sleep 500
Out("scenario " Scenario)
if (Scenario = "already")
    StartFakeCall("you tapped the blue phone before turning Owlman on")
else
    SetTimer () => StartFakeCall("you tapped the blue phone"), -1000
DoAutoDial()   ; not via RunAutomation: Wine counts the script's own clicks as "you moved the mouse"
Sleep 300
Out("calls made: " CallNo "  emails sent: " Emails "  Send clicks: " SendClicks)
Out("--- log ---")
Out(FileRead(A_ScriptDir "\owlman_log.txt"))
ExitApp
