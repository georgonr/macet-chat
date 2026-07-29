# Google Play listing assets

Everything Play asks for on the store listing page, kept next to the source so it can be
regenerated rather than hand-edited in the console.

## Graphics

| file | size | notes |
|---|---|---|
| `icon-512.png` | 512×512 | app icon, opaque, square — Play rounds the corners itself |
| `feature-graphic.png` | 1024×500 | banner at the top of the listing |

Both are drawn from the geometry of `assets/macet-logo.svg` by
`scripts/macet/make-play-graphics.ps1`, the same way the desktop and iOS icons are — nothing is
resampled from a finished bitmap. Regenerate with:

```
powershell -ExecutionPolicy Bypass -File scripts/macet/make-play-graphics.ps1
```

## Text

`listing-sk.md` and `listing-en.md` hold the app name, the short description (Play caps it at 80
characters) and the full description (capped at 4000), plus notes for the Data safety form.

The wording is deliberately plain. It states what is encrypted, and it also states what the server
still sees — IP addresses, connection times, transferred volume — because the privacy policy says
so and the listing must not say otherwise.

## Screenshots

`screenshots/screenshot-1.png` … `screenshot-4.png`, 720×1280 each (9:16), 24-bit PNG:

| file | screen |
|---|---|
| `screenshot-1.png` | chat list |
| `screenshot-2.png` | open conversation |
| `screenshot-3.png` | *Network & servers*, Macet as the only operator |
| `screenshot-4.png` | *Settings* |

Captured on a physical Xiaomi (720×1600 panel, MIUI) and cropped to 9:16 without upscaling. 720×1280
is below the 1080×1920 that reads best in the store listing — recapture on a higher-resolution device
before a release that cares about it.

### Turn *Protect app screen* off before capturing, and back on afterwards

`privacyProtectScreen` defaults to `true` and `MainActivity` sets `FLAG_SECURE` from it, so **every
screenshot and screen recording of the app comes out solid black** — `adb exec-out screencap`
included. Only the system status bar survives. This is the app working as intended, not a capture
bug, and it is easy to mistake for one.

Turn it off in the app under *Settings → Privacy & security → Protect app screen*, capture, then
**turn it back on**. The toggle clears the window flag immediately, so no restart is needed.

Verify a capture is not black before trusting it — mean luma of a valid dark-theme frame here is
around 30, of a blocked one exactly 0.

### Capturing on MIUI

`adb shell input tap` and `input keyevent` fail with `SecurityException: … requires the caller to
have the INJECT_EVENTS permission`, so the screens cannot be driven from adb — navigate by hand.
`adb shell am start`, `adb exec-out screencap` and `adb shell uiautomator dump` all work, and the
`uiautomator` dump is enough to confirm which screen is showing and what is on it.

Note that `adb exec-out screencap -p > file.png` corrupts the PNG when the redirection is done by
PowerShell; use a POSIX shell, or `adb shell screencap -p /sdcard/x.png` followed by `adb pull`.

### Before capturing

Use test profiles and keep personal data out of the frames. Also dismiss the first-run
*Reachable chat toolbar* card on the chat list (and the dialog that follows it) — it otherwise sits
in the middle of the screenshot and makes the app look half-configured.
