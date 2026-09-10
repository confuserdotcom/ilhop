# Phase 1 Plan 02 — A1 Falsification Result

Falsifies RESEARCH.md Q6 / Assumptions Log A1: does `hyprctl cursorpos`,
sampled locally on Nastralis, freeze once input-leap's server-side capture
takes the pointer over, or does it keep tracking every local synthetic delta
regardless (meaning D-14's landing oracle is wrong)?

## Marker selection — why 19:29:13, not "whatever `--verdict` finds last"

The trace recorded more than one screen crossing, and picking the wrong one
would silently misattribute someone else's pointer motion to the author's
press. Full inventory, with provenance, of every `switch from` line inside
the trace's recording window (`2026-09-10T19:23:17.794+0100` ..
`2026-09-10T19:32:10.928+0100`):

| Time | Transition | Source |
|---|---|---|
| 19:28:51 | Nastralis → Mac | author, ALT+C |
| 19:28:52 | Mac → Nastralis | author, ALT+C |
| 19:28:52 | Nastralis → Mac | author, ALT+C |
| 19:28:53 | Mac → Nastralis | author, ALT+C |
| 19:28:55 | Nastralis → Mac | author, ALT+C |
| 19:28:57 | Mac → Nastralis | author, ALT+C |
| **19:29:13** | **Nastralis → Mac** | **author, ALT+C — the scored marker** |
| 19:31:25 | Mac → Nastralis | orchestrator-requested mouse jiggle, unrelated to this plan — **not scored** |
| 19:32:11 | Nastralis → Mac | same jiggle — **not scored**; this is what an unbounded "most recent" search would have picked |

The 19:31:25/19:32:11 pair was real pointer motion the orchestrator asked
the author to make while diagnosing a separate, unrelated cursor-visibility
symptom (see below), after the author had already reported the checkpoint's
round trip done. It is genuine data, not a tool bug, but it is not the
event this plan asked the author to produce, so it must not be scored as
such.

**19:29:13 (Nastralis → Mac) is the marker scored below.** Reasons, all
independently checked against the raw trace rather than taken on report:

- Its own ±2s window (`19:29:11.781`–`19:29:15.781`) is free of every other
  marker — the previous one is at `19:28:57` (nearly 16s earlier) and the
  next is at `19:31:25` (over 2 minutes later, excluded via the `--before`
  bound added below).
- It is a genuine keybind-driven hop, not raw pointer motion: the pre-marker
  samples show a monotonic leftward sweep — `1347,707 → 1230,705 →
  1124,734 → 1000,836 → 850,896 → 598,960 → 328,976 → 8,940` — matching
  `il-jump`'s `shove()` (ten `ydotool mousemove -- -800 0` steps for
  `dir=left`, `il-jump:123-126`), not a single edge-crossing motion.
- The earlier 19:28:51–19:28:57 cluster is also the author's presses, but
  each pair is only 1–2s apart, so their ±2s windows overlap each other and
  each other's crossings — unscorable individually. A spot check (below)
  shows it is at least qualitatively consistent with the scored marker, and
  is cited only as corroboration.

### Tool fix required to make this reproducible (Rule 1/3)

`il-cursortrace --verdict` only exposed `--since`, which bounds the *lower*
edge of the marker search window; there was no way to cap the *upper* edge,
so an unbounded search always finds whatever is chronologically last —
which by the time this was scored was the unrelated 19:32:11 marker, not
19:29:13. Added `--before ISO` (same shape as `--since`, same
`to_jctl_ts()` conversion) so the exact window used here is re-runnable by
anyone, not just describable in prose. Committed to `~/.dotfiles` alongside
two other fixes found while building and scoring this: `head()` (the
`pass`/`fail`/`warn`/`head` reporting idiom, copied verbatim from
`il-doctor` per PATTERNS.md) shadowed the coreutils `head` command used
inside the verbatim-copied `hypr()` wrapper and in the script's own trace
reads; and `journalctl --since`/`--until` rejects the script's own `%z`
timestamp shape (`+0100`) with "Failed to parse timestamp" on stderr,
silently swallowed by the `2>/dev/null` redirect already in place for
tolerant-failure handling — so `--verdict` was reporting a false
"no marker found" on every run until this was found and fixed. Both are
documented as deviations in `01-02-SUMMARY.md`.

## Raw verdict output (verbatim)

```
$ il-cursortrace --verdict --before "2026-09-10T19:30:00+0100"
Marker: 2026-09-10T19:29:13+0100 [2026-09-10T19:29:13] INFO: switch from "Nastralis" to "Macbook-Air.local" at 1698,724
Search bound: --before 2026-09-10T19:30:00+0100 applied (marker search window capped at this instant)
Window: pre=[2026-09-10T19:29:11.781+0100 .. 2026-09-10T19:29:13.781+0100]  post=[2026-09-10T19:29:13.781+0100 .. 2026-09-10T19:29:15.781+0100]
Pre-marker samples: 51 (distinct positions: 7)  range x[328,1347] y[705,976]
Post-marker samples: 54 (distinct positions: 1)  range x[8,8] y[940,940]
**Verdict:** FROZE (post-marker samples are all identical while pre-marker samples were not)
```

## Marker journal line (verbatim)

```
Sep 10 19:29:13 Nastralis input-leaps[2360]: [2026-09-10T19:29:13] INFO: switch from "Nastralis" to "Macbook-Air.local" at 1698,724
Sep 10 19:29:13 Nastralis input-leaps[2360]: [2026-09-10T19:29:13] INFO: leaving screen
```

## Trace excerpt, ±2s either side of the marker (consecutive duplicates collapsed, count shown)

```
=== PRE-MARKER  2026-09-10T19:29:11.781+0100 .. 2026-09-10T19:29:13.781+0100 ===
2026-09-10T19:29:11.808+0100  1347 707  (x45)
2026-09-10T19:29:13.536+0100  1230 705  (x1)
2026-09-10T19:29:13.582+0100  1124 734  (x1)
2026-09-10T19:29:13.621+0100  1000 836  (x1)
2026-09-10T19:29:13.663+0100  850 896  (x1)
2026-09-10T19:29:13.705+0100  598 960  (x1)
2026-09-10T19:29:13.742+0100  328 976  (x1)

=== POST-MARKER  2026-09-10T19:29:13.781+0100 .. 2026-09-10T19:29:15.781+0100 ===
2026-09-10T19:29:13.786+0100  8 940  (x54)
```

## Discriminating "genuinely frozen" from "just walked into the screen edge"

A pointer parked at `x=8` after a leftward `shove()` has two possible
readings, and they are not the same finding:

1. Input-leap's capture took over partway through the shove, so `cursorpos`
   genuinely stopped tracking further local synthetic events — A1 confirmed,
   D-14's oracle survives.
2. The shove simply drove the local Hyprland cursor into its own screen-edge
   clamp at `x≈8` and it had nowhere further left to go — a constant reading
   that would occur regardless of capture, proving nothing about it.

These are distinguished by what happens next, not by the frozen value
itself. After the crossing, `il-jump` immediately issues `centre_mac()` —
one *rightward* relative move (`il-jump:167`, `mac_width/4`, roughly
430–860px after acceleration) intended to walk the far side's pointer off
the pinned edge toward its centre. An edge clamp does not resist rightward
motion — only further leftward motion is blocked at `x=0`. So if reading 2
were correct (no capture), this rightward nudge should have moved the local
cursor visibly away from `x=8` within the next sample or two (~25–50ms).

It did not. The trace was independently re-checked past the strict ±2s
verdict window, all the way to the next marker: **3,481 consecutive samples
spanning `19:29:13.786` to `19:31:24.999` — roughly two minutes twelve
seconds — read exactly `8 940`, with zero deviation.** `centre_mac()`'s
rightward nudge, which fires within tens of milliseconds of the crossing
and which an edge clamp alone would not have blocked, never reached
Nastralis's local `cursorpos` at all. That rules out reading 2. The frozen
reading is genuine capture, not a clamp artifact.

## The reported vanished-cursor symptom — related but not the same measurement

The author separately reported, and the orchestrator independently
confirmed is not a Hyprland cursor-visibility setting (`cursor:*` options in
`~/.config/hypr/*.conf` are unset), that the local cursor visibly disappears
after a hop and stays gone on the return leg until real mouse motion occurs.
That is a rendering/visibility observation; `hyprctl cursorpos` is a
position query, not a visibility query, and the two are logically
separable — a hidden-but-still-tracked cursor would show `cursorpos`
continuing to move, while a positionally frozen one would not, regardless of
whether it is rendered at all. The discriminator above shows the latter:
the value itself is demonstrably stuck, independent of whatever the
compositor chose to draw. This plan does not attempt to explain *why* the
cursor is invisible — that is out of scope here and is being handled
separately — but the data available to this plan supports "genuinely
frozen," not merely "invisible so it looked frozen."

## Corroboration from the earlier press cluster (context only, not scored)

A spot check of `19:28:50.5`–`19:28:53.5` (inside the unscorable overlapping
cluster) shows positions actively changing between presses (`1280,720` →
`2343,720` → `1280,720` → `2294,720` → `1280,720`) rather than being stuck
at one value throughout — qualitatively consistent with real, repeated
crossings firing rather than a single stuck reading being reported
seven times. Not decomposed further: the ±2s windows around these markers
overlap each other, so no individual marker in this cluster can be
cleanly attributed.

## Did the author's press fire the hop?

Yes, unambiguously — both by the shove-signature match in the pre-marker
trace and by the journal's own `leaving screen` / `entering screen`
companion lines at every transition timestamp above. Per RESEARCH.md Q4,
an absent fire would itself be diagnostic; that question does not arise
here because the fire is directly evidenced.

## Verdict

**Verdict:** FROZE

A1 holds: `hyprctl cursorpos`, sampled locally on Nastralis, freezes once
input-leap's server-side capture takes the pointer over, and the freeze is
demonstrated to be genuine (not an edge-clamp artifact) by the absence of
`centre_mac()`'s own rightward nudge from the local trace for over two
minutes following the crossing. D-14's local-oracle claim stands. Plan
01-04 builds `il-doctor`'s replacement landing check on the local freeze
test described in D-14/Q6: issue a small known local probe delta after a
hop and see whether the local pointer moves — if it stays put, capture is
active and the hop landed; if it moves, capture never took hold. This is
local, free, and — unlike `il-doctor:105-113`'s current check — never reads
`$RUN/il-side`, so it cannot repeat D-16's circularity. No repair for
HOP-03 is proposed in this document; HOP-03's own status (is there a defect
to fix at all, per D-03's correction that landing already lands at screen
centre) is plan 01-03/01-05's determination, not this plan's.
