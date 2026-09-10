# Phase 1 Plan 01 — Evidence

Zero-keypress, read-only evidence sweep (Task 1), followed by the tracer's
reach and limits (Task 3, appended after Task 2's harness runs).

No live component was restarted, reconfigured, or written to during this
task. The only pointer motion in this document is the `il-doctor --test`
round trip in measurement 6, which the plan explicitly licenses and which
returns the pointer to its starting side.

## 1. Restart history

Commands run:

```
systemctl --user show il-side-watch.service -p NRestarts -p Restart -p RestartUSec -p ActiveEnterTimestamp -p ExecMainStartTimestamp
journalctl --user -u il-side-watch.service --since "-7 days" --no-pager
```

Verbatim output:

```
ActiveEnterTimestamp=Thu 2026-09-10 13:29:58 +01
Restart=always
RestartUSec=3s
NRestarts=0
ExecMainStartTimestamp=Thu 2026-09-10 13:29:58 +01
```

```
Sep 10 00:46:51 Nastralis systemd[707]: Started Track which machine currently owns the input-leap pointer.
Sep 10 00:53:34 Nastralis systemd[707]: Stopping Track which machine currently owns the input-leap pointer...
Sep 10 00:53:35 Nastralis systemd[707]: Stopped Track which machine currently owns the input-leap pointer.
Sep 10 00:53:38 Nastralis systemd[707]: Started Track which machine currently owns the input-leap pointer.
Sep 10 04:32:27 Nastralis systemd[707]: Stopping Track which machine currently owns the input-leap pointer...
Sep 10 04:32:27 Nastralis systemd[707]: Stopped Track which machine currently owns the input-leap pointer.
-- Boot 85ecab7660894b94b2cfff49eca27061 --
Sep 10 13:29:58 Nastralis systemd[711]: Started Track which machine currently owns the input-leap pointer.
```

`NRestarts=0` is the counter's **current** value only — `ActiveEnterTimestamp`
shows it was last reset at `13:29:58` today, which is a fresh boot (see the
`-- Boot ... --` marker immediately above it), not a manager reload mid-session.
The counter is corroboration, not the record; the journal above is the durable
evidence, and it shows one genuine same-boot restart cycle:

- **00:46:51** — watcher started (this boot's first start, itself following an
  earlier boot not shown because it falls outside the union of boots retained
  in the `--since "-7 days"` window's active journal).
- **00:53:34 → 00:53:38** — a real `Restart=always` cycle: `Stopping` at
  `00:53:34`, `Stopped` at `00:53:35`, `Started` at `00:53:38`. Gap: ~4 seconds,
  consistent with `RestartSec=3s` plus systemd's own stop/start overhead.
- **04:32:27** — `Stopping`/`Stopped` immediately followed by a full system
  reboot (`-- Boot ... --`), not a same-session `Restart=always` cycle. The
  watcher did not restart on its own here; the whole machine went down and
  came back up at `13:29:58`.

**Restart count in the 7-day window: 1** same-boot `Restart=always` cycle
(`00:53:34`→`00:53:38`). The `04:32:27` stop is a session teardown, counted
separately below (Overlap, Gap 2) because it has the same shape (watcher not
listening) even though it is not the mechanism Q2 #1 describes.

## 2. Transition rate

Commands run:

```
journalctl --user -u input-leap-server.service --since "-7 days" --no-pager > /tmp/ils-7d.log
wc -l /tmp/ils-7d.log
grep -c 'switch from' /tmp/ils-7d.log
grep -c 'jump from' /tmp/ils-7d.log
grep -c 'has connected' /tmp/ils-7d.log
grep -c 'has disconnected' /tmp/ils-7d.log
grep -c 'disconnecting client' /tmp/ils-7d.log
```

Verbatim counts:

```
1016881 /tmp/ils-7d.log
switch from: 1005
jump from:   7
has connected: 20
has disconnected: 5
disconnecting client: 9
```

`jump from` present and non-zero (7 occurrences) confirms RESEARCH Q1's point
directly: these are `forceLeaveClient()` lines that `il-side-watch:24`'s case
statement (`*'switch from "'*'" to "'*`) does not match at all — 7 transitions
the watcher provably never had a chance to observe, independent of any restart
gap.

First and last transition in the window:

```
Sep 08 18:43:22 Nastralis input-leaps[2141]: [2026-09-08T18:43:22] INFO: switch from "Macbook-Air.local" to "Nastralis" at 1,778
Sep 10 17:31:45 Nastralis input-leaps[2360]: [2026-09-10T17:31:45] INFO: switch from "Macbook-Air.local" to "Nastralis" at 5,1180
```

Span: 168503s (46.81 hours) actual logged activity (the machine was not up
for the full nominal 7-day window — `journalctl --list-boots` shows the
retained journal starts at boot `-4`, Sep 08 18:40:50). Transition count over
that span: 1005 `switch from` + 7 `jump from` = 1012. Mean interval between
transitions: **166.5 seconds (~2.8 minutes)**. In practice usage is bursty —
several switches land in the same wall-clock second during active use — not
evenly spaced.

**Side note, not part of the six measurements but observed while building
this file and recorded for completeness:** the vast majority of the
1,016,881 lines in the window (1,013,212 of them) are `DEBUG:`-level
`on_motion_event` spam, all timestamped before `2026-09-10 00:45:28`. The
unit's current config is `--debug INFO` (confirmed via `il-doctor` below and
`grep -o -- '--debug [A-Z]*' ~/.config/systemd/user/input-leap-server.service`
→ `INFO`), and no `DEBUG:` line appears anywhere after `00:45:28` in the
window — so the flood is historical, ended before this session, and the
live unit is not in violation of PROJECT.md's log-level constraint right now.
Flagged only because it explains the line count; not a Task 1 measurement and
not chased further.

## 3. Overlap

For the one same-boot restart (Gap 1) and the reboot-spanning stop (Gap 2),
every transition line landing between the watcher's last `Stopping`/`Stopped`
and its next `Started` is listed below.

**Gap 1 — `00:53:34` → `00:53:38` (real `Restart=always` cycle):**

```
Sep 10 00:53:35 Nastralis input-leaps[285580]: [2026-09-10T00:53:35] INFO: switch from "Nastralis" to "Macbook-Air.local" at 1464,556
Sep 10 00:53:36 Nastralis input-leaps[285580]: [2026-09-10T00:53:36] INFO: switch from "Macbook-Air.local" to "Nastralis" at 668,720
```

**2 transitions, provably lost.** Both fall strictly inside the watcher's
down window. The nearest transitions immediately outside the window (`00:53:30`
switch-to-mac, `00:53:32` switch-to-nastralis) were captured normally; the pair
inside the gap was not delayed, it was skipped — `journalctl -f -n 0`
reattaches with zero backlog, exactly as RESEARCH Q2 #1 describes.

In this specific instance the two lost transitions cancel out (mac→nastralis
then nastralis→mac→nastralis nets back to `nastralis`, which is also what the
last-observed-before-the-gap line already said), so the side file was not
*visibly* wrong immediately afterward — this is coincidence, not
correctness: an odd count, or a differently-ordered pair, would have left
`il-side` stale in exactly the shape D-02 reports, and there was no code path
here that could have told the difference.

**Gap 2 — `04:32:27` → `13:29:58` (session teardown, spans a reboot):**

```
Sep 10 04:32:27 Nastralis input-leaps[309137]: [2026-09-10T04:32:27] NOTE: disconnecting client "Macbook-Air.local"
Sep 10 04:32:27 Nastralis input-leaps[309137]: [2026-09-10T04:32:27] INFO: jump from "Macbook-Air.local" to "Nastralis" at -1,-1
```

Both lines share the same one-second timestamp as the watcher's own
`Stopping`/`Stopped` pair, so second-resolution journald timestamps cannot
settle whether the watcher captured them before dying. Moot either way: this
is `input-leap-server.service` itself shutting down as the machine goes down
(`systemd[707]: Stopping Input Leap Server (User)...` at the same second),
not a live session where a stale `il-side` would mislead a press — the whole
machine restarted immediately after, and `il-side-watch:19`'s own
`[ -s "$STATE" ] || printf 'nastralis\n' > "$STATE"` plus the optimistic
"nastralis" default on every `has connected`/`has disconnected` line means the
file lands on the correct value again as soon as the Mac client next connects
at the following boot regardless.

**Total provable overlap count: 2** (both in Gap 1; Gap 2 contributes 0 to the
"stale during ordinary use" count because it is a reboot boundary, not a
mid-session gap a press could land in).

## 4. A3 — EIS lock-file count

Commands run:

```
ls "$XDG_RUNTIME_DIR"/eis-*.lock 2>/dev/null | wc -l
uptime
```

Verbatim output:

```
1
```

```
 18:46:47 up  5:16,  2 users,  load average: 0.69, 0.87, 0.54
```

One EIS lock file, current boot up 5h16m. No accumulation visible — this is
consistent with input-leap holding one long-lived InputCapture session rather
than creating/closing one per hop, as RESEARCH Assumptions Log A3 presumed.
Settles A3 cheaply: nothing here supports the portal fd-leak issue
(hyprwm/xdg-desktop-portal-hyprland#419) as a live secondary hypothesis on
this machine right now.

## 5. Ground truth right now

Commands run:

```
cat "$XDG_RUNTIME_DIR/il-side"
cat "$XDG_RUNTIME_DIR/il-mac-width"
git --git-dir=$HOME/.dotfiles --work-tree=$HOME status --porcelain
git --git-dir=$HOME/.dotfiles --work-tree=$HOME log --oneline -1
```

Verbatim output:

```
nastralis
```

```
1710
```

```
(empty — clean)
```

```
9d1f129 Revert the modifier re-press; add il-reset
```

D-10's clean-tree claim holds at execution time: the `~/.dotfiles` work tree
is clean and `HEAD` is exactly `9d1f129`, the same commit CONTEXT.md recorded.

## 6. Latency baseline

**This step moves the pointer twice and returns it**, per the plan. Command:

```
/home/nastralis/.local/bin/il-doctor --test
```

Relevant verbatim output (full 23-check run, all passed):

```
[1mlive round trip[0m
  [32mok[0m    hop to the Mac: 20ms
  [32mok[0m    hop back: 53ms

23 check(s) ok, 0 failed
```

**Baseline round-trip timings: 20ms to the Mac, 53ms back.** Both are inside
PROJECT.md's ~50ms latency budget for a single hop (the 53ms return leg is the
one over budget, by 3ms — flagged for plan 01-06's baseline comparison, not
acted on here). `il-side` read `nastralis` both before and after the full
`--test` run — the round trip returned the pointer to its starting side, so
this measurement leaves no injected or shifted state behind.

**The landing pass/fail those two lines report is circular per D-16**: both
assertions are `[ "$(cat "$RUN/il-side")" = <want> ]` — reading the exact
file under suspicion, not an independent oracle. A green result here means
"the cache agrees with itself," not "the pointer demonstrably moved." Only
the millisecond timings are being taken as the baseline; the pass/fail
verdict is not trusted as proof of landing.

## Verdict

Stated as a measurement, not a conclusion, per the plan's requirement:

**RESEARCH Q2 mechanism #1 (watcher-restart-gap losing transitions) has
firing evidence on this machine.** In the one same-boot `Restart=always`
cycle captured in this 7-day window, two real transitions landed inside the
watcher's ~4-second blind spot and were provably never observed by
`il-side-watch`. This is not a theoretical construction from reading the
code — it is measured, with exact timestamps, from `journalctl` alone,
without a single keypress. The sample size is small (one restart cycle
observed; NRestarts resets on reboot so the true lifetime count is unknown —
see measurement 1's caveat), and in this one instance the lost pair happened
to net back to the correct value, so it did not visibly corrupt `il-side`
this time. The mechanism is real and has fired at least once; whether it
fires often enough, and lands on an odd (state-corrupting) count often
enough, to be *the* explanation for the user's reported HOP-02 failures
remains open and is exactly what plan 01-03's watcher-gap assertion and the
continuing Route 2 passive log are for. This evidence supports rather than
deflates the leading hypothesis — it does not close it.

## What the tracer proved

Executed, not inferred — every claim below was observed running, not reasoned
from reading the code:

- With `il-jump`'s current code (`849b6ac..9d1f129`, unchanged since
  `92f64bc`), forcing `$XDG_RUNTIME_DIR/il-side` to the value `il-jump`'s
  guard at `:91` computes as `$want` for a given direction produces a
  silent, motionless `exit 0` on every press, in both directions (`left`
  with the file forced to `mac`; `right` with the file forced to
  `nastralis`). This was demonstrated by `il-repro --inject-noop`, with no
  keypress and no pointer motion — `hyprctl cursorpos` sampled immediately
  before and after each invocation differed by `dx=0 dy=0` in both cases.
- Before this task's instrumentation existed, the same injection produced
  the identical silent exit 0 with zero explanation anywhere — confirmed by
  running `il-repro --inject-noop` against the unmodified `il-jump` and
  observing it FAIL (`4 checks failed`, `exit 1`) specifically on the "a
  refusal line appeared in the log" assertions, while the exit-code and
  pointer-stillness assertions already passed. This isolates precisely what
  changed: the guard already produced D-02's *symptom* before this task; the
  task made the guard *explain itself*.
- The guard now writes exactly one line per refusal, carrying a
  human-readable wall-clock timestamp with milliseconds, the direction, and
  both compared values (`CUR` and `want`) — verified by byte-offset
  inspection of `$XDG_RUNTIME_DIR/ilhop-debug.log` before and after each
  invocation, not by eyeballing the tail of the file.
- With `ILHOP_DEBUG` unset and no arm file present, the same two injected
  invocations leave the log's byte count unchanged (verified: `72` bytes
  before and after the first case's debug-off run, `157` before and after
  the second) — confirming the logging is genuinely off by default, not
  merely quiet.
- The repeated no-op is exactly D-02's reported shape: it persists across
  presses (every one of `il-repro`'s repeated injected invocations produced
  the identical refusal, not a one-shot transient), it is direction-symmetric
  (`left` and `right` both refuse under the matching injected value, matching
  D-01), and nothing about the invocation itself clears it — only a change to
  the side file would. This demonstrates, rather than merely restates, the
  mechanism D-05 accused.

## What it did not prove

Evidenced but not proven — task 1's restart-and-overlap counts speak to this,
and plan 01-03's watcher-gap assertion sharpens it further:

- **Whether this wrong value actually occurs during ordinary use.** Task 1
  measured one confirmed instance of the watcher-restart-gap mechanism firing
  (2 real transitions lost inside a ~4-second blackout), but in that instance
  the lost pair happened to net back to the correct value, so it did not
  visibly corrupt `il-side` that time. Route 3 proves the guard behaves
  exactly as suspected *when* the file is wrong; it says nothing about how
  often, in practice, the file actually ends up wrong on this machine. That
  is an open frequency question, not a mechanism question, and this document
  does not close it.

Not established at all — outside what any of the three sanctioned routes can
reach:

- **Whether the Hyprland keybind (ALT+C / ALT+H) ever fails to invoke
  `il-jump` in the first place.** That dispatch lives in Hyprland's own
  keybind layer, entirely outside this script, and — per PROJECT.md's
  Testability constraint and this session's own measurement — `ydotool` key
  events do not fire Hyprland keybinds at all (0 fires), so no route
  available to this phase can simulate a press and observe whether the
  dispatch itself succeeds. Route 1 (a scripted stressor) calls `il-jump`
  directly and so cannot see a keybind-dispatch failure either; Route 3
  (this task) starts even further downstream, at a specific already-inside-
  the-script guard. This is precisely why route 2's passive `ILHOP_DEBUG=1`
  logging is armed for the rest of the phase in plan 01-03: with the log
  instrumented and running continuously, the *absence* of any new log line
  beside a real, remembered failed press is itself a finding — it would mean
  the failure happened upstream of `il-jump`, in territory none of the three
  routes can directly observe.

No fix, cause, or recommendation is recorded in this document. Plan 01-05
owns the determination and consumes this file as input.

