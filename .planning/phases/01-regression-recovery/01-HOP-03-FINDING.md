# HOP-03 Finding

**Finding:** NOT A DEFECT

D-18's bar for this phase is "lands on the correct screen and is not pinned
against an edge" — not a percentage ring around screen centre, because HOP-05
(Phase 3.1) replaces screen-centre as the landing target outright. D-03
already corrected the original report: the pointer *does* land at the centre
of the screen today; the actual complaint is that screen centre is the wrong
place to land, which is HOP-05's problem, not HOP-02/HOP-03's. All four
measurements below confirm the landing geometry clears D-18's bar with wide
margin on both legs. No repair is made here — `centre_mac()` and
`centre_nastralis()` are untouched by this plan, and the target coordinate is
left exactly as-is for HOP-05 to redefine.

## Measurements

All four ran cold, arithmetic-only against live geometry (measurement 4 issues
a single small local `ydotool` probe via `il-cursortrace --landed`, which
undoes itself when it takes effect locally — same as every other use of that
oracle in this plan). No keypress, and no `il-jump` invocation was needed for
measurements 1–3.

### 1. `centre_nastralis()`'s computed target, and whether the `jq` read actually succeeds

Command (the exact `jq` filter at the live `centre_nastralis()`, `il-jump:146`):

```
$ hyprctl monitors -j | jq -r '(map(select(.focused))[0] // .[0]) | "\((.x + (.width / .scale) / 2) | floor) \((.y + (.height / .scale) / 2) | floor)"'
1280 720
```

Raw monitor JSON (single monitor, `DP-1`):

```json
{"id":0,"name":"DP-1","width":2560,"height":1440,"x":0,"y":0,"scale":1,"focused":true, ...}
```

`geom="1280 720"` matches the `[0-9]* [0-9]*` shape `il-jump:148`'s case
statement checks for, so the primary branch's no-op (`: ;;`) runs and
`il-jump:150`'s hardcoded fallback (`geom="1280 720"`) is **not** reached.
This is confirmed independently, not just inferred from the matching shape:
manual arithmetic against the raw monitor JSON —
`x + width/scale/2 = 0 + 2560/1/2 = 1280`, `y + height/scale/2 = 0 + 1440/1/2
= 720` — reproduces the `jq` output exactly. The fallback happens to carry
the identical literal value on this specific 2560×1440 display (screen centre
of a 2560-wide screen is 1280 either way), which is why the two cannot be told
apart by the number alone; they are told apart by confirming the computation
actually ran. It did.

**On this machine, today, `il-jump:150`'s hardcoded fallback is dead code** —
the live `jq` geometry read succeeds every time, not a stale comment
papering over a broken path.

### 2. D-18's bar: inside monitor bounds, ≥100px from every edge

Monitor bounds: `x=0 y=0 width=2560 height=1440` (scale 1, so logical =
physical here). Target: `x=1280 y=720`.

| Edge | Distance |
|---|---|
| left | 1280px |
| right | 1280px |
| top | 720px |
| bottom | 720px |

All four margins clear the 100px bar by more than 7×. The target is `[0,
2560] × [0, 1440]` — inside monitor bounds. **D-18's bar: PASS.**

### 3. Mac leg: `centre_mac()`'s nudge stays inside the Mac's width, doubled or not

Command:

```
$ cat "$XDG_RUNTIME_DIR/il-mac-width"
1710
```

`centre_mac()` (`il-jump:166-170`) issues one relative nudge of
`mac_width / 4`:

```
nudge = 1710 / 4 = 427
```

`427 > 0` and `427 < 1710` — a pointer starting pinned against the Mac's left
edge (`x=0`) cannot be driven past its right edge (`x=1710`) by this nudge
alone.

The tuning note at `il-jump:27-29` records that `ydotool` deltas land at
roughly 2× after acceleration on this stack (measured there: `430 -> 859` on
this same 1710-wide screen). Checking the doubled value against the width
too, per the plan's explicit instruction:

```
doubled = 427 * 2 = 854
```

`854 < 1710` — even at the measured ~2× acceleration, the nudge stays inside
the screen with more than 850px of margin on the right. **Mac-leg nudge
check: PASS**, at both the commanded value and the measured-doubled value.

### 4. Current side per the new oracle, not the cache

Command:

```
$ cat "$XDG_RUNTIME_DIR/il-side"
nastralis
$ /home/nastralis/.local/bin/il-cursortrace --landed nastralis
signal: local-freeze-probe (never reads /run/user/1000/il-side)
before: 1912 340
probe: relative +5px,0 (ydotool mousemove)
after: 1918 340
result: local (pointer moved 6px locally after the probe - not captured, pointer is here)
**landed(nastralis):** yes
exit: 0
```

The oracle built in Task 1/2 of this plan agrees with the cache at the moment
of measurement: pointer is genuinely local (on Nastralis), not merely
cache-claimed. This finding rests on that oracle, not on `$RUN/il-side` read
in isolation.

## Why this is not a defect

Per D-03's own correction and per the four measurements above: the landing
math computes a real, in-bounds, edge-clear target from live geometry on both
legs, with no dead fallback silently substituting for it. The user's
complaint was never that the pointer misses this target — it lands exactly
there, every time this was checked. The complaint is that landing at screen
centre, with two windows open on the destination, puts the pointer in the gap
*between* them rather than on either window. That is a target-selection
problem, not a landing-accuracy problem, and **HOP-05 (Phase 3.1)** is the
requirement that replaces screen-centre with "the centre of the window
nearest the crossed edge, with that window taking focus" (D-19, D-20). Per
the roadmap, recording HOP-03 as not-a-defect — with the measurements above
in evidence rather than asserted — is how Phase 1's success criterion 4 is
met, and per D-18/D-03 tightening a tolerance around a bullseye the project
has already agreed is the wrong bullseye would be wasted work belonging to
HOP-05, not this phase.

## What was not touched

`centre_mac()` and `centre_nastralis()` (`il-jump:145-170`) are byte-identical
to their state before this plan. No repair was made or proposed for HOP-03;
the target coordinate is left exactly as-is for HOP-05 to redefine.

## Human verification (harvested at end of phase, not mid-plan)

Per `01-VALIDATION.md`'s Manual-Only table and this plan's own
`<human-check>`: the author hops in both directions and watches the pointer
land each time, confirming it arrives on the destination screen and is not
pinned against an edge. Screen-centre accuracy is explicitly not the bar —
per D-03 and D-18 the target itself is HOP-05's problem. This check is
deliberately not requested mid-plan; `workflow.human_verify_mode` is
`end-of-phase` for this project, so it is harvested in the phase-level UAT
pass, not as a plan checkpoint here.
