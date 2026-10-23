# Wrap-around: hop without edge walls (in progress, paused 2026-10-23)

Goal (author): keep crossing at BOTH side edges with the mouse (Mac linked
left and right of Linux, and vice versa) while ALT+C still always lands.

## Why today's hop breaks under wrap

il-jump shoves 10 x 800px toward the Mac and relies on the Mac's far edge
being a wall (pinned overshoot = known start x for centre_mac). With wrap the
far edge is linked, so the burst exits it and ping-pongs. Tried live: 44
screen switches for 6 hops, one hop to the Mac did not land. Reverted
(af00c12); server.conf on ryuk is back to `right`/`left` single links.

## Measured so far (Mac on the right, Linux 2560x1440, Mac 1470 wide)

Linux -> Mac, new approach: warp the Linux cursor with
`hl.dsp.cursor.move({ x = 2558, y = <y> })`, then `ydotool mousemove -- 5 0`.
- Crosses every time (15-29ms), enters the Mac at x ~= 2 (near edge).
- The FIRST relative move after the crossing is often swallowed.
- With a 1px throwaway move, then one move N (no sleeps): 5/5 trials,
  crossing confirmed by `il-cursortrace --landed mac`, landed at 680-681 for
  N=366 -> gain ~1.85 (not the old 2x). Wider sample at other targets was
  the next step (interrupted).
- Unverified earlier loops showed "lost" nudges and outliers (1031, 1189)
  but did not confirm the crossing; treat them as measurement noise until
  the crossing-verified sample says otherwise.
- Spaced moves (0.5s apart) land 1:1; accel depends on event timing.

Mac -> Linux: not yet redesigned. Plan: one or two shoves whose total
(after accel) is >= Mac width (1470) and < Mac width + Linux width (4030),
then the existing exact compositor warp (arrive_nastralis). Note the old
measurement: the crossing lands after the FIRST step even from the far edge.
The self-check's `shove 14` retry must shrink the same way.

## Next steps

1. Crossing-verified sample: targets 200/400/735/1000/1200, 3 each, with
   throwaway + N = (tx - 2) / 1.85. Accept if every trial lands within
   ~60px and none is lost.
2. Same for Mac on the left (warp to x=1, push -5, mirror the nudge).
3. Size the Mac -> Linux shove under wrap; verify no bounce.
4. Rewrite il-jump shove/centre_mac/self-check retry; one code path for
   single links and wrap. Re-enable wrap parsing (see c6963e3 for the
   parser/doctor/side-conf changes that were reverted).
5. il-repro + live round trips + author keypress gate (hold Alt + repeated C).

Test scripts used (scratch, Mac side): warp + push via ssh to ryuk,
Mac x read with `NSEvent.mouseLocation` through osascript.
