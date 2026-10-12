#Requires AutoHotkey v2.0
; Tests lead_autopilot's Caps Lock (voicemail drop) on a fake screen.
; Run from lead_autopilot\harness:  SCEN=<ok|fail|failup|nosetup> wine AutoHotkey64.exe main_harness.ahk
OnError((e, *) => (FileAppend("ERROR: " e.Message " @ line " e.Line " " e.What "`n", "*"), ExitApp(3)))
Out(s) => FileAppend(s "`n", "*")
global RED := 0xDD0000, NOC := 0x3366CC, VDGRAY := 0x555A60, CLOSEC := 0x6B6B6B, OFF := 0xC0C0C0
global Scenario := EnvGet("SCEN")
try FileDelete A_ScriptDir "\lead_points.ini"
try FileDelete A_ScriptDir "\lead_autopilot_log.txt"
ini := A_ScriptDir "\lead_points.ini"
for k in ["ext","upload","email","tmpl","next","scrollbar","send"]
    IniWrite "5,5,0,0", ini, "points", k
IniWrite "300,100," RED "," RED, ini, "hangup2", "hangup"
IniWrite "100,300," NOC "," NOC, ini, "hangup2", "nocontact"
if (Scenario != "nosetup") {
    IniWrite "40,360," VDGRAY "," VDGRAY, ini, "vdrop", "drop"
    IniWrite "180,360," CLOSEC "," CLOSEC, ini, "vdrop", "close"
}
g := Gui("-Caption +AlwaysOnTop")
g.BackColor := "FFFFFF"
SetC(c, col) => (c.Opt("Background" Format("{:06X}", col)), c.Redraw())
global cRed   := g.Add("Text", "x280 y80 w40 h40 Background" Format("{:06X}", RED))
global cNoc   := g.Add("Text", "x80 y280 w40 h40 Background" Format("{:06X}", NOC))
global cDrop  := g.Add("Text", "x20 y340 w40 h40 Background" Format("{:06X}", VDGRAY))
global cClose := g.Add("Text", "x160 y340 w40 h40 Background" Format("{:06X}", OFF))
cRed.OnEvent("Click", (*) => (Out("  [fake] hung up"), SetC(cRed, OFF), SetC(cNoc, OFF), SetTimer(() => SetC(cNoc, NOC), -400)))
cNoc.OnEvent("Click", (*) => Out("  [fake] No Contact clicked"))
cClose.OnEvent("Click", (*) => (Out("  [fake] red box closed"), SetC(cClose, OFF)))
cDrop.OnEvent("Click", DropClick)
DropClick(*) {
    if (Scenario = "ok")
        return Out("  [fake] voicemail DROPPED")
    Out("  [fake] voicemail drop FAILED (red box)")
    if (Scenario = "fail")              ; the call already ended
        SetC(cRed, OFF)
    SetTimer () => SetC(cClose, CLOSEC), -600
}
g.Show("x0 y0 w500 h400 NoActivate")
#Include ..\lead_autopilot.ahk
Sleep 1500
Out("scenario " Scenario)
DoHangup()
Sleep 300
Out(FileRead(A_ScriptDir "\lead_autopilot_log.txt"))
ExitApp
