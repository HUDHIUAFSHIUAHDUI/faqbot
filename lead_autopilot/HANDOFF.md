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
| **Win** (tap) | Email flow: Lead Scraper → Upload to SuperSalesSMS → envelope → NCCTeam template → Next → scroll → Send |
| **Caps Lock** | Red hang-up in VS Connect → wait for reload → No Contact |
| F12 | Exists in the code (green phone), but Brendan says he doesn't have or use it. F12 needs Fn on his keyboard. |
| Esc / mouse move | Stop a run. Ctrl+Alt+X quits. |

Saved spots are in `lead_points.ini` under `points` (email flow), `hangup2` (Caps Lock) and `call` (F12, probably never set up). See the original handoff for design details: click-to-record setup, the hover and idle colors, and the Win-key masking trick.

## Owlman Dials: `owlman_dials.ahk`
**One key: Right Alt** (no Fn).
- **Tap Right Alt**: ON. Starts watching or dialing, and a small always-on-top "OWLMAN DIALS is ON" box shows.
- **Tap Right Alt again**: OFF. Stops, turns the sound back on, and hides the box. Esc, any other physical key, a mouse move, or the box's Turn OFF button also stops it.
- Right Alt is held back and re-sent, using the same vkE8 masking trick the main script uses for Win. A tap never opens a menu, and Right Alt combos still work. Whether Owlman was busy is captured on key **down**, because the key press itself already stops a run, so the up event must mean OFF, not "start again".
- The script file must be running (double-click once per day). While OFF it does nothing but listen for Right Alt.

**Loop (never clicks the phone):**
1. Wait for the dialer's call: the red hang-up spot appears within `NextCallWait` (15 s). After No Contact, also wait for the new lead's page to load: the envelope goes away and comes back, or `ReloadWait` passes. **The call is watched the whole time.** A pickup or decline during this wait is handled at once.
2. **Special lead:** no email envelope, checked by hovering the envelope spot from the Win setup. It stops and unmutes; the call is Brendan's.
3. Watch the **ringing sign**, the one spot Owlman records itself.
   - The ringing sign disappears while the red button stays for `AnsweredConfirmMs`: **answered**. It unmutes immediately, beeps, and stops.
   - The red button disappears: the lead **declined**. It clicks No Contact and moves on.
   - Still ringing after the ring limit: **no answer**. It hangs up (last-moment pickup re-check first), waits, clicks No Contact, and the dialer calls the next lead.
4. **Muting:** speakers and headset are muted while ringing, using both the default playback device and the default communications device, never the mic. They are unmuted on pickup, stop, error, or exit. Only devices Owlman itself muted are unmuted.
5. **Timing is random every call:** it rings 18–23 s before hanging up and waits 2–5 s before No Contact. **Every 10–15 dials** (random) one dial is long: it rings 28–30 s and waits 5–7 s. There is no wait before the next call, because the dialer calls instantly.
6. Hang-up skip: if the red button isn't found within 3 s, the call is already over, so it goes straight to No Contact.

**Safety checks:**
- The ringing spot showing with no call, or staying on after the call ends, means a bad setup. Owlman forgets only that spot and asks for setup on the next tap.
- It won't start while the main script is mid-run. It reads `lead_autopilot_log.txt` read-only: a line from the last 10 s that isn't `RUN done` or `STOPPED` means busy.
- Any physical key or mouse input stops a run, so a run never overlaps a main-script key.
- The box moves itself off any saved button before a run.
- Errors unmute, write to the log, and stop quietly with no error dialog.
- If VS Connect runs elevated, Owlman restarts itself as admin and comes back ON.

**Files and what Owlman reads:**
- Reads `lead_points.ini` **read-only**:
  - `points/email` (the envelope)
  - `hangup2/hangup` (the red button)
  - `hangup2/nocontact` (No Contact)
- Writes only `owlman_points.ini` (`[autodial] ringing=x,y,hover,idle`) and `owlman_log.txt`.

**Setup (first Right Alt tap):** while the dialer's call is ringing, click the ringing sign on VS Connect, for example the word "Ringing". The click is not passed on. Plain white or gray spots are refused, and clicks on the Owlman box pass through.

## Status
- **Nothing in Owlman has been run on his tablet yet.** He was about to do the first setup. Right Alt, the real mute, and the timing against his real dialer are all unverified.
- Earlier attempts with F9/F11 failed on his tablet because those keys need Fn.
- Next steps:
  1. Walk him through setup one step at a time. The first Right Alt tap should happen while a call is ringing.
  2. Get `owlman_log.txt` after the first real runs.
  3. Tune `ReloadWait`, `NextCallWait` and `EnvelopeWait` from the log.
- Open offers: a smaller or secret-looking box (a tiny owl, no words), and making Owlman start with Windows.

## Testing (you can't run it on his machine)
Setup: Wine and Xvfb, plus AutoHotkey v2.0.18 from `github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.18/AutoHotkey_2.0.18.zip`. Install with `apt-get install wine64 wine xdotool`; autohotkey.com is blocked.
- **Syntax check:** `xvfb-run -a wine AutoHotkey64.exe /ErrorStdOut /validate owlman_dials.ahk`
- **Behavior:** `harness/owlman_harness.ahk` draws a fake VanillaSoft and softphone (colored squares at fixed spots), and its fake dialer calls by itself after No Contact. Run it with `SCEN=<name> xvfb-run -a -s "-screen 0 1280x1024x24" wine AutoHotkey64.exe /ErrorStdOut 'harness\owlman_harness.ahk'`. The scenarios:
  - `setup`, `setupoff`: first-time setup, and stopping during setup
  - `toggle`: turning Owlman off mid-call
  - `answer1`, `answer2`: pickups
  - `special`: a lead with no email button
  - `decline`: the lead declines
  - `noauto`: the dialer never calls
  - `lastmoment`: pickup right at the ring limit
  - `badspot`, `stuck`: a bad ringing-sign setup
  - `nohang`: the red button is missing
  - `busy`: the main script is mid-run
  - `timing`: random timing and long dials
- **Wine gotchas:**
  - Wine counts the script's own clicks as physical mouse input, so the harness calls `DoAutoDial()` directly instead of `RunAutomation`, to keep the mouse-stop check off.
  - `xdotool` key presses don't reach AHK hotkeys, so Right Alt can't be pressed in tests.
  - There is no real sound card, so muting is only exercised through the code path.
  - A `#Warn` popup, such as a harness calling a function that no longer exists, hangs a test silently. Read popup text with a small `WinGetText` script.
- AHK v2 reminders: names are case-insensitive, `InstallMouseHook` and `InstallKeybdHook` are functions, and `A_TimeIdleMouse` and `A_TimeIdleKeyboard` only count physical input once the hooks are installed.
