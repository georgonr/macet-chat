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

## Screenshots — still missing

Play wants at least two phone screenshots; four or more is better. **They are not in this
directory yet.** Two things blocked capturing them on this machine:

- `adb exec-out screencap` returns an all-black frame on the API 35 emulator used here. The app
  renders through Skia/GL under gfxstream and the composited output is not captured. The system
  status bar comes through, the app surface does not.
- The app itself does not currently get past "Opening database…" on that emulator. This is not
  caused by the app: a build of the exact configuration that was verified working earlier
  (compileSdk 35 / targetSdk 35) hangs the same way, so it is the emulator environment on this
  host, not a regression.

To produce them, on a machine with a working emulator or a physical device:

1. Install the release build and complete onboarding.
2. Capture at least four portrait phone screenshots, 1080×1920 or larger, PNG or JPEG:
   - the chat list with a few conversations,
   - an open conversation,
   - *Network & servers* showing the Macet servers,
   - *Settings*, or the onboarding "Network commitments" screen.
3. Drop them here as `screenshot-1.png` … `screenshot-4.png`.

Avoid personal data in the frames — use test profiles.
