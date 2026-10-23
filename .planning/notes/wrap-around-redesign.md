# Wrap-around: hop without edge walls (built 2026-10-23, keypress gate PENDING)

Goal (author): cross at BOTH side edges with the mouse (Mac linked left and
right of Linux, and vice versa) while ALT+C still always lands.

Branch `wrap-hop` (b1fa53b, 24c5ce9). Installed on ryuk (--link); server.conf
on ryuk is wrap-around, Mac listed on the right first. Rollback:
`server.conf.pre-wrap` on ryuk + `git checkout main` in ~/Projects/ilhop.

## Why the old hop broke under wrap
It shoved 10 x 800px at the Mac and relied on the far edge being a wall. With
wrap the burst ran off the far edge and ping-ponged (44 switches / 6 hops).

## Findings (all measured on ryuk + MacBook Air, 1470 wide, LAN)
- libinput's adaptive profile scales ydotool deltas 1x-2x by event timing
  (396 -> 735 / 954 / 977). With `accel_profile = "flat"` on
  ydotoold-virtual-device-1: exactly 1:1 (3 x 300 -> 900).
- Warp to 1px inside the Mac-facing edge + 5px push: crosses every time.
  input-leap logs the entry 4px in from the Mac's edge pixel on both sides
  (`at 4,y` / `at 1465,y`).
- The first relative motion after a crossing is dropped (8/8 without a
  throwaway). The compositor pointer freezes at once, so the gap cannot be
  seen locally. throwaway + modifier flush + throwaway + nudge: 15/15.
- Safety net: detached check reads the Mac x over ssh (~140ms warm) and
  re-nudges a pointer still parked at the entry edge (tested by removing the
  nudge: x=4 -> 900).
- Return: 3 x 800 (> Mac width, < Mac + Linux width); overshoot carries into
  Linux, then the compositor warp.
- Hazard found and fixed: a late side file triggered the retry shove on a
  pointer that had already landed -> crossed over the far edge. The retry
  now asks the compositor pointer first (1px probe; retry-skipped tested).

## Results
- Mac right, wrap: 30 switches / 15 round trips, 15/15 both ways; 12/15
  within 1px of target, 3 off by 17-102px (still on the Mac).
- Mac left (order swapped), wrap: 16 switches / 8 trips, all exact.
  Two earlier Mac-left runs had failures with stray pointer motion in the
  log (Mac x 567/340, an entry at 345) - looked like a hand on a mouse;
  capture probes and reruns were clean.
- doctor 27/0, doctor --test: to Mac 33-47ms, back 48-55ms; repro --all 206/0.

## Still open
- Author gate: hold Alt + repeated C (>= 6 presses, both ways), physical mouse
  crossing at all four side edges, two-window landing.
- Then merge `wrap-hop` into main and reinstall the Mac copy (unchanged
  Mac scripts, so optional).
