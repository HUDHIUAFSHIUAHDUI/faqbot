#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
; Same screen pixels as owlman_dials, so the saved spot matches
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; ============ OWLMAN: VOICEMAIL SPOT FOR ONE-NUMBER LEADS ============
; Double-click this file once. On a lead with only ONE phone number, click
; "Default" (the voicemail right under the number). The click does NOT drop a
; voicemail. Owlman uses this spot on one-number leads from then on.
; Saves to owlman_points.ini (same folder). Esc = cancel.
; =====================================================================

global OwnIni := A_ScriptDir "\owlman_points.ini"

ToolTip "OWLMAN SETUP: voicemail on a ONE-number lead`n`nOpen a lead that has only ONE phone number.`nThen click 'Default' (the voicemail right under that number).`nThis click won't drop a voicemail.`n`n(Esc = cancel)", 10, 10

LButton::Record()
Esc:: {
    ToolTip "Setup cancelled. Nothing was changed.", 10, 10
    Sleep 2000
    ExitApp
}

Record() {
    MouseGetPos &x, &y
    ToolTip
    Sleep 250                   ; let the hover highlight finish fading in
    c := PixelGetColor(x, y)
    MouseMove 1, 1
    Sleep 150
    idle := PixelGetColor(x, y)
    MouseMove x, y
    if !Distinct(c) && !Distinct(idle) {
        ToolTip "That spot is plain white or gray.`nClick right ON the voicemail icon or the word 'Default'.`n`n(Esc = cancel)", 10, 10
        return
    }
    IniWrite x "," y "," c "," idle, OwnIni, "vdrop", "drop1"
    try FileAppend FormatTime(, "MM/dd HH:mm:ss") "  SETUP one-number voicemail at " x "," y " hover=" c " idle=" idle "`n", A_ScriptDir "\owlman_log.txt"
    SoundBeep 1200, 60
    ToolTip "Saved! Owlman will use this spot on one-number leads.", 10, 10
    Sleep 3000
    ExitApp
}

; A real button color (colorful or dark), not page background white/gray
Distinct(c) {
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    hi := Max(r, g, b), lo := Min(r, g, b)
    return (hi - lo >= 40) || (hi < 150)
}
