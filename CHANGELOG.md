# Changelog

## Unreleased

- App icon: a 24-hour dial whose rim is coloured by the New York sessions,
  with its hand on 09:30, the open. It is drawn in code by
  `icon/make-icon.swift`, and `make icon` regenerates `Resources/AppIcon.icns`
  and `docs/icon.png`.

## 0.1.0 — 2026-09-23

First release.

- Floating New York clock that stays above every window and Space, including
  full-screen apps, never takes focus, and resizes from any edge or corner.
- Session colours: slate blue pre-market, warm white regular hours, amber
  after-hours, dim grey closed. A session line underneath names the phase and
  flags holidays and 13:00 early closes.
- Four soft bells at 04:00, 09:30, the close and 20:00, each a different contour.
- Opening-range bar from 09:30 through 5, 10, 15 and 30 minutes, each stage its
  own colour with a countdown, a tick and a short spoken phrase.
- NYSE holidays and early closes computed from the exchange rules; optional
  Polygon.io check for unscheduled closures; manual overrides file.
- Menu bar menu with mute, click-through, per-event chime and speech settings,
  test sounds, simulation of any event, a two-minute tour of the day, and
  Launch at Login.
