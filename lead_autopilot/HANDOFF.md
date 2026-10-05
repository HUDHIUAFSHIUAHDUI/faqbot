# Handoff: Lead Autopilot + Owlman Dials (AutoHotkey v2)

_Last updated: 2026-09-30. Code lives in `hudhiuafshiuahdui/faqbot`, branch `claude/auto-silence-phone-answer-f46l30`, folder `lead_autopilot/`._

## Who / goal
Brendan sells health and life insurance. He works on a **Windows 11 tablet** with a Bluetooth keyboard, touchpad and USB mouse. There are two separate scripts:

1. **`lead_autopilot.ahk`** is the **main script**. He uses it daily and it is **the more important one**. It is the exact version from the original handoff, and **it must not be changed** unless he explicitly asks.
2. **`owlman_dials.ahk`** is **Owlman Dials**, a separate add-on. Brendan picked the code name. It auto-dials until someone picks up. Brendan wants it easy to turn on and off, secret-ish, and it must never interfere with the main script.

## How to work with Brendan (read this first)
- He is **not a programmer**. Use short, plain language, **one or two steps at a time**, and confirm before moving on.
- **Do only what he asks.** Things that went wrong this session:
  - Removing the email flow when he floated the idea. He reversed it seconds later, loudly. **The email flow stays.**
  - Mapping Owlman to Win or Caps Lock. **Never do this. Those keys belong to the main script.**
  - Assuming his main script has an **F12 "call" key**. He says it doesn't, so don't rely on an F12 setup existing.
  - Clicking the green phone. **His dialer calls automatically**, both on its own and right after No Contact. Owlman must **never click the phone**.
- When unsure, ask one short question (AskUserQuestion works well) instead of guessing.
- **His keyboard's F-keys need Fn.** He will not use Fn combos, so any Owlman key must be a single key with no Fn. It is currently **Right Alt**.
- He can't edit code. Every change ships as a new `.ahk` file he downloads into **Downloads**, replacing the old one, and **keeps `lead_points.ini`**.
- You can't see his tablet. Be honest about what was and wasn't tested. When something misbehaves, ask for **`owlman_log.txt`** (Owlman) or **`lead_autopilot_log.txt`** (main).
- He sometimes asks unrelated side questions (for example "Who is Olive Branch administration?"). Answer briefly, or ask where he saw it.

## His setup
- Chrome, VanillaSoft CRM, the Lead Scraper extension (uploads to SuperSalesSMS), and the **VS Connect** softphone in its own window to the right of Chrome. The layout must stay fixed.
- **The dialer auto-calls:** it calls a lead by itself and calls the next lead right after No Contact.
- AutoHotkey v2 is installed. Files in **Downloads**:
  - `lead_autopilot.ahk`, `lead_points.ini`, `lead_autopilot_log.txt` (main)
  - `owlman_dials.ahk`, `owlman_points.ini`, `owlman_log.txt` (Owlman)
- He also has an ASUS Chromebook. AutoHotkey can't run there, so it would need a Chrome extension. That was explored and parked: we were waiting on a photo of VanillaSoft and VS Connect on the Chromebook. The catch is that one extension can't click another extension's popup, so the Lead Scraper "Upload" click would stay manual.

## Main script: `lead_autopilot.ahk` (unchanged from the original handoff)
| Key | Does |
|---|---|
| **Win** (tap) | Email flow: Lead Scraper → Upload to SuperSalesSMS → envelope → **_Request Quote** template (was NCCTeam until 10/05; the spot is re-recorded with the Win setup) → Next → scroll → Send |
| **Caps Lock** | Red hang-up in VS Connect → wait for reload → No Contact |
| F12 | Exists in the code (green phone), but Brendan says he doesn't have or use it. F12 needs Fn on his keyboard. |
| Esc / mouse move | Stop a run. Ctrl+Alt+X quits. |

Saved spots are in `lead_points.ini` under `points` (email flow), `hangup2` (Caps Lock) and `call` (F12, probably never set up). See the original handoff for design details: click-to-record setup, the hover and idle colors, and the Win-key masking trick.

## Owlman Dials: `owlman_dials.ahk` (SIMPLE MODE, since 2026-09-30)
Brendan asked for it simple: **it is just his Win + Caps Lock, done automatically on a timer, for every lead.** No setup of its own, no ringing-sign detection, no muting.

**One key: Right Alt** (no Fn).
- **Tap Right Alt**: ON. A small always-on-top "OWLMAN DIALS is ON" box shows.
- **Tap Right Alt again**: OFF. Esc, any other physical key, a mouse move, or the box's Turn OFF button also stops it. **This is how a pickup is handled: he hears the person and taps any key.**
- Right Alt is held back and re-sent with the vkE8 masking trick (same as the main script's Win). Whether Owlman was busy is captured on key **down**.
- The script file must be running (double-click once per day).

**His real setup (learned this session):**
- He starts the first call by tapping the **blue phone** next to the number in VanillaSoft (not the green one in VS Connect). After hang-up + No Contact, VanillaSoft moves to the next lead and calls it by itself.
- VS Connect shows **"Call established"** with a timer; the call box turns green on voicemail or pickup. So there is no reliable on-screen "ringing" sign to watch. This is why the ringing-sign version was dropped.

**Loop (never clicks a phone):**
1. Wait for the call: the red hang-up spot (`hangup2/hangup`) shows within `NextCallWait` (15 s). After No Contact, also wait for the new lead's page (envelope gone and back, or `ReloadWait`). If the call is already up when he taps Right Alt, it starts right away.
2. **Special lead** (no email envelope): stops and beeps; the call is his.
3. **While it rings, do his Win email flow** (a copy of the main script's `DoRun`: Lead Scraper → Upload → close popup → envelope → NCCTeam → Next → scroll → Send). A failure stops the run.
4. Let it ring **10–25 s** total, counted from when the red button appeared (he asked for 10–25). Every 10–15 dials one is long: 23–25 s. If the red button goes away first (declined), skip to No Contact.
5. Hang up, wait 2–5 s (long dial 5–7 s), click No Contact. The dialer calls the next lead. Repeat.

**Known trade-off (Brendan agreed):** it cannot see a pickup. Sound stays on; he must tap a key when someone answers, or it will hang up on them when the timer runs out. Voicemail also isn't detected.

**Safety checks:** won't start while the main script is mid-run (reads `lead_autopilot_log.txt`); the box moves off saved buttons; errors log and stop quietly; restarts as admin if VS Connect is elevated.

**Files:** reads `lead_points.ini` **read-only** (all of `points` for the email flow, plus `hangup2/hangup`, `hangup2/nocontact`). Writes only `owlman_log.txt`. `owlman_points.ini` is no longer used (safe to delete).

## Status
- Ran on his tablet 09/30 (first real log). Dialing, hang-up and No Contact work. Email fixes from that log:
  - **Send was clicked twice on every email** (a good click takes ~2 s to clear on the tablet; `SendStuckMs` was 1 s). Now 4 s, max 3 tries. The main script has the same 1 s value; it was left unchanged.
  - Upload popup sometimes didn't open: if Upload doesn't show in 4 s, click the Lead Scraper icon once more.
  - **Blank email bug (10/03, both files):** after the envelope click, NCCTeam (and Next) were clicked after a fixed 0.8 s (`AmbiguousCap`) because their spots look the same before and after the page changes (log: always "found after ~813ms"). On a slow load NCCTeam was clicked before the template list existed, so Next opened a BLANK email and Send raised VanillaSoft's "The Subject is blank. Send anyway?" box. Fix (he wanted it quicker than a flat 3 s): `WaitPageChange` waits for the button just clicked (envelope, then NCCTeam) to go away and stay away 300 ms, then `TemplateSettle` 600 ms; if nothing visibly changes it waits `TemplateWait` 3 s. The log says "page changed after Xms" or "page never looked different" (tune from that). In **both** `owlman_dials.ahk` and `lead_autopilot.ahk` (Brendan asked for both files to be fixed; this is the only change to the main script). Neither script ever clicks Confirm. Harness scenario `slowtmpl` reproduces it.
  - Email steps get 8 s each (`EmailStepWait`); No Contact gets 15 s (`NoContactWait`), since it was sometimes gray (0xCBCBCB) for over 8 s after hanging up.
- Next: get `owlman_log.txt` after his first runs; tune `NextCallWait`, `ReloadWait`, `EnvelopeWait`.
- Open offers: a smaller or secret-looking box, and starting Owlman with Windows.
- Possible later upgrade (only if he asks): detect pickup from the call box turning green, which would allow muting again.

## Testing (you can't run it on his machine)
Setup: Wine and Xvfb, plus AutoHotkey v2.0.18 from `github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.18/AutoHotkey_2.0.18.zip`. Install with `apt-get install wine64 wine xdotool`; autohotkey.com is blocked.
- **Syntax check:** `xvfb-run -a wine AutoHotkey64.exe /ErrorStdOut /validate owlman_dials.ahk`
- **Behavior:** `harness/owlman_harness.ahk` draws a fake VanillaSoft and softphone (colored squares at fixed spots), and its fake dialer calls by itself after No Contact. Run it with `SCEN=<name> xvfb-run -a -s "-screen 0 1280x1024x24" wine AutoHotkey64.exe /ErrorStdOut 'harness\owlman_harness.ahk'`. The scenarios:
  - `basic`: rings out three times, then "someone answers" and a key stops it
  - `already`: the call was already going when Owlman was turned on
  - `decline`: the lead declines call 2
  - `special`: a lead with no email button
  - `noauto`: the dialer never calls
  - `nohang`: the red button is missing
  - `toggle`: turning Owlman off mid-call
  - `busy`: the main script is mid-run
  - `timing`: random timing and long dials
  - `slowsend`, `popupmiss`, `slowtmpl`, `fastpage`: Send slow to clear, Lead Scraper popup not opening, slow template list with no visible change, quick email window
- **Wine gotchas:**
  - Wine counts the script's own clicks as physical mouse input, so the harness calls `DoAutoDial()` directly instead of `RunAutomation`, to keep the mouse-stop check off.
  - `xdotool` key presses don't reach AHK hotkeys, so Right Alt can't be pressed in tests.
  - There is no real sound card, so muting is only exercised through the code path.
  - A `#Warn` popup, such as a harness calling a function that no longer exists, hangs a test silently. Read popup text with a small `WinGetText` script.
- AHK v2 reminders: names are case-insensitive, `InstallMouseHook` and `InstallKeybdHook` are functions, and `A_TimeIdleMouse` and `A_TimeIdleKeyboard` only count physical input once the hooks are installed.
