---
phase: 01-regression-recovery
reviewed: 2026-09-11T18:30:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - /home/nastralis/.local/bin/il-jump
  - /home/nastralis/.local/bin/il-side-watch
  - /home/nastralis/.local/bin/il-repro
  - /home/nastralis/.local/bin/il-doctor
  - /home/nastralis/.local/bin/il-cursortrace
  - /home/nastralis/.config/systemd/user/il-side-watch.service
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-09-11T18:30:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the six files named in scope, with priority on the double-press override
in `il-jump` (:141-159), `il-side-watch`'s `--cursor-file` reattach, quoting/
injection safety across all five scripts, and silent-failure paths. `il-doctor`
and `il-cursortrace` were read for cross-file context only, per the prompt's
framing as prior-plan instrumentation; nothing new is filed against them beyond
what was already flagged as known.

None of the findings below touch the key/pointer injection path itself (no
`ydotool key`/`ydotool mousemove` call sites were changed by anything I'm
flagging), so none of them are gated by the human-at-the-keyboard constraint —
they are all independently testable by script, and I ran several of them live
against this machine's actual `journalctl`/`systemd` (not just read cold) to
keep the theoretical/reachable distinction honest. Where I could not establish
reachability, I say so explicitly rather than inflating severity.

**Headline finding:** `il-side-watch`'s new `--cursor-file` reattach
(`il-side-watch:69-74`) has no error handling at all for `journalctl`'s own
documented hard-failure mode on an unreadable cursor. I verified against this
machine's real `journalctl` (systemd 261) that a malformed cursor file makes
`journalctl` exit 1 immediately with zero lines of output, that the bad cursor
file is never repaired, and that the pipe's `2>/dev/null` discards the one
diagnostic line `journalctl` does print — so if this is ever triggered, the
watcher enters a `Restart=always`/`RestartSec=3` crash loop that never updates
`$STATE` again, with literally nothing written anywhere (not `$DBGLOG`, not the
unit's own journal) to explain why. This is the same class of failure — a
silent, permanent, unrecoverable no-op — that this entire phase exists to kill,
now reachable through a brand-new code path this phase itself introduced. I
was not able to identify a concrete trigger for *byte-level* corruption of the
cursor file given that `journalctl` saves it via atomic temp-file+rename (also
verified live); the closer-to-reachable sibling case (a well-formed cursor
`journalctl` can no longer locate, e.g. after ordinary journal rotation) does
NOT hard-fail — it silently replays the full retained backlog instead, which
is a separate, lower-severity finding below.

Everything else is a warning or an info-level polish/traceability item; I did
not find a shell-injection vector in any of the five scripts (see WR/IN write-
ups for the specific things I checked and ruled out).

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: `il-side-watch`'s cursor-file reattach has no defense against `journalctl`'s own hard-failure mode, and the one diagnostic line it emits is discarded

**File:** `/home/nastralis/.local/bin/il-side-watch:69-74`
**Issue:**

```sh
CURSOR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/il-side-watch.cursor"

journalctl --user -u input-leap-server.service -f -n 0 --cursor-file="$CURSOR" --no-pager 2>/dev/null |
while IFS= read -r line; do
    handle_line "$line"
done
```

I tested this directly against this machine's real `journalctl` (systemd 261,
`261.2-1-arch`) with a scratch cursor file, not just reasoned about it:

- A syntactically invalid cursor (`echo "garbage-not-a-cursor" > cursor`) makes
  `journalctl -f -n 0 --cursor-file=...` print `Failed to seek to cursor:
  Invalid argument` to its own stderr and **exit 1 immediately, with zero
  lines of stdout output** — verified with a bare invocation (no `2>/dev/null`)
  to see the real exit code and message. The cursor file itself is **not**
  rewritten or repaired after this failure — it stays garbage.
- When `journalctl` exits, the `while IFS= read -r line` loop it feeds hits
  EOF immediately and the whole script reaches end-of-file and exits.
- Under this unit's actual config (`il-side-watch.service:4,9-10`:
  `StartLimitIntervalSec=0`, `Restart=always`, `RestartSec=3`), systemd will
  restart it forever at a 3-second cadence, and every restart reads the same
  still-garbage cursor file and fails the same way — **a permanent, fast
  crash loop with no self-heal**, during which `$STATE` (`il-side-watch:16`)
  is never written again because `handle_line()` never runs.
- `il-side-watch:71` pipes `journalctl`'s stderr to `/dev/null` on the
  `journalctl` command itself, *before* the pipe. That discards the one
  diagnostic line (`Failed to seek to cursor: ...`) before systemd's own
  per-unit journal capture would ever see it. So this failure produces **no
  trace anywhere** — not in `$DBGLOG` (`il-side-watch` never writes there at
  all — see WR-03/IN note below), not in `journalctl --user -u
  il-side-watch.service`, nothing. The only externally visible symptom is the
  unit's restart counter climbing.
- I also verified, with a throwaway unit configured identically
  (`Type=simple`, `Restart=always`, `RestartSec=3`, `StartLimitIntervalSec=0`,
  `ExecStart=/bin/false`), that `systemctl --user is-active --quiet` reports
  `active` for a brief instant on **some** restart cycles and `activating` on
  most others — polling every 200ms across a 4s crash loop showed `active`
  roughly 1 time in 10. This means the exact health checks `il-doctor:66` and
  `il-repro:343,350,394` (`--watcher-gap`) use to decide "the watcher is
  running" are not reliable during this specific failure mode: a check that
  happens to land in that brief window reports healthy while the service is
  actually permanently crash-looping and `$STATE` is frozen.

**What I could NOT establish (stated plainly, not inflated):** a concrete
real-world path to the cursor file actually containing *garbage bytes*. I
verified `journalctl` persists the cursor via an atomic write (temp file +
`rename()`, confirmed with `inotifywait` watching the real `.#<name><random>`
→ `MOVED_TO` sequence on `SIGTERM`), which protects against partial-write
corruption from an ordinary crash or OOM-kill mid-save (this machine runs
`oomd`, per the system memory notes, so that was worth checking specifically).
A 0-byte cursor file (another plausible corruption shape) is handled
gracefully — `journalctl` treats it the same as "no cursor," the documented
`-n 0` cold-start fallback, not an error. The one class of unlocatable cursor
I *could* trigger (a well-formed cursor pointing at a timestamp/position
`journalctl` can no longer resolve, simulating rotation past the referenced
entry) did **not** hit this hard-fail path — it fell back to replaying from
the oldest retained entry instead (see WR-01). So the exact trigger for
literal cursor corruption remains open; what's proven is that *if* it ever
happens, by any means, there is currently zero handling for it and the result
is a silent, permanent regression to exactly the class of bug this phase
exists to close.

**Fix:** Check `journalctl`'s exit status and, on nonzero, delete `$CURSOR`
before letting `Restart=always` retry it, so the very next restart falls back
to the documented `-n 0` cold-start path instead of looping on the same
unreadable cursor forever. Something like:

```sh
journalctl --user -u input-leap-server.service -f -n 0 --cursor-file="$CURSOR" --no-pager |
while IFS= read -r line; do
    handle_line "$line"
done
rc=$?
[ "$rc" -ne 0 ] && rm -f "$CURSOR"   # do not loop on an unreadable cursor forever
exit "$rc"
```

(Exact exit-status plumbing through the pipe needs care — `$?` after a `while`
fed by a pipeline reflects the loop's own status in `sh`/`bash` without
`pipefail`; use `PIPESTATUS`/`set -o pipefail`-equivalent, matching whatever
this phase already does elsewhere.) Also stop discarding `journalctl`'s
stderr unconditionally — route it through the same `dbg()`-style sink `il-jump`
already has, or at minimum let it reach the unit's own journal, so a future
occurrence of this exact failure is discoverable without a code reviewer
manually removing `2>/dev/null` by hand, as I had to.

### Warnings

#### WR-01: A well-formed-but-unresolvable cursor silently replays the full retained journal backlog instead of a bounded catch-up

**File:** `/home/nastralis/.local/bin/il-side-watch:69-74`
**Issue:** I tested a syntactically valid cursor pointing at an unreachable
position (`s=...;i=1;b=<real boot id>;m=1;t=1;x=...`, i.e. "the beginning of
time" for this boot) against the real `journalctl`. It did **not** error — it
silently started emitting entries from the oldest entry currently retained in
the journal, then continued following live as normal. Every one of those
historical `switch from`/`jump from`/`has connected`/`has disconnected` lines
gets replayed through `handle_line()` exactly as if it just happened.

The final value `$STATE` converges to after the replay is correct (this is
the same code path as normal operation, just compressed in time), so this is
not a data-loss bug the way CR-01 is. But it is a real, reachable event —
ordinary `journalctl` rotation/vacuuming (`SystemMaxUse`, time-based
retention, or a manual `--vacuum-size`) will eventually evict the entry a
long-idle watcher's stored cursor points at on any system that doesn't keep
the journal forever — and it directly contradicts this phase's own stated
design property (01-ROOTCAUSE.md property 2: "must not have an unbounded
blind spot... closing it (bounded backlog on reattach...)"). What ships is
bounded by whatever the journal currently retains, not by "since this
process's own last exit" as intended, and nothing observes or logs when this
fallback happens — `il-side-watch` doesn't write to `$DBGLOG` at all (only
`il-jump` does), so `il-repro --report`'s tally can never surface it.
**Untested** — `il-repro --watcher-parser` exercises `handle_line()` directly
and `il-repro --watcher-gap` exercises a normal restart with a *valid,
current* cursor; neither exercises an unresolvable cursor.

**Fix:** At minimum, log (even to stderr, captured by the unit's own journal)
when `journalctl` starts emitting entries with a timestamp far older than the
cursor file's own mtime, so a large unexpected replay is at least visible
after the fact. Consider capping how far back a reattach is allowed to trust
(e.g., discard `$CURSOR` and fall back to `-n 0` if its mtime is more than
some bound in the past) so "bounded" is actually enforced rather than
inherited from journald's retention policy.

#### WR-02: `il-repro --retry-forced` (and `--all`) writes into the real production `il-jump.retry` file with no `trap`-based cleanup

**File:** `/home/nastralis/.local/bin/il-repro:102-107, 413-478`
**Issue:** `il-repro` snapshots and restores `$STATE` via a trap:

```sh
ORIG=""
restore_side() {
    [ -n "$ORIG" ] || return 0
    printf '%s\n' "$ORIG" > "$STATE" 2>/dev/null
}
trap restore_side EXIT INT TERM
```

but `mode_retry_forced()` (`il-repro:415-478`) writes real, un-sandboxed
content into `$RUN/il-jump.retry` — **the same path `il-jump` itself reads
and writes** (`il-jump:48`) — and only cleans it up with a plain `rm -f
"$RETRY"` at the very end of the function (`il-repro:476`), outside any trap.
If `il-repro --retry-forced` or `--all` is interrupted (Ctrl-C, killed,
session drop) partway through the five `retry_case` calls, whatever the last
completed `retry_case` left behind — a marker naming the test's own `$dir`
and a real millisecond timestamp taken at that moment (`il-jump`'s own refuse
branch, `il-jump:155`, overwrites the marker with the real "now" on every
refused call, so the leftover shape is often indistinguishable from a genuine
refusal) — persists in the live file for up to `RETRY_MAX_MS` (5000ms,
`il-jump:63`). In the specific case where the interrupt lands between the
`inside-window` case's fabricated-marker write (`il-repro:427`, deliberately
~300ms old — inside the live window) and `il-jump`'s own subsequent overwrite,
a real press from the user in the same direction shortly after the
interruption can be force-fired by the override on the strength of a test
artifact, not a real prior press.

This can't wedge input or corrupt `$STATE` permanently (worst case is one
extra or one fewer hop, self-correcting on the next press), so it's a
hygiene/isolation gap rather than a safety bug — but it's a live-system
contamination path, not merely a test-flakiness issue, so it clears the bar
for reporting despite touching a file only used by tests.
**Fix:** Add `$RETRY` to the same trap that protects `$STATE`:
```sh
restore_side() {
    [ -n "$ORIG" ] || return 0
    printf '%s\n' "$ORIG" > "$STATE" 2>/dev/null
    rm -f "$RETRY" 2>/dev/null
}
```

#### WR-03: The detached self-check's actual rescue branch is invisible to the debug log and never verifies its own success

**File:** `/home/nastralis/.local/bin/il-jump:232-250`
**Issue:** Every other named exit path in the detached self-check calls
`dbg()` (`superseded` at :237, `watcher-unknown` at :238), but the branch that
matters most — the one that actually fires when the crossing never gets
confirmed —does not:

```sh
    # The other screen never took it: Mac asleep, client disconnected, network
    # gone. Do not leave the pointer buried against the edge.
    centre_nastralis
    note "the other screen didn't take the pointer (asleep or disconnected?)"
) >/dev/null 2>&1 &
```

`note()` is a `notify-send` toast, and D-12 (01-CONTEXT.md) explicitly
rejected toasts as the log sink "because toasts are useless for after-the-fact
forensics" — yet the single most diagnostically important event in this whole
file (the rescue actually firing) is recorded *only* as a toast, with nothing
written to `$DBGLOG`. `il-repro --report`'s tally (`il-repro:326`) enumerates
`already-on-side stale-lock superseded watcher-unknown usage die dispatch` —
there is no `rescue` bucket, because nothing ever logs one. Given the whole
apparatus this phase built exists to turn "an impression" into "a tally," this
is the one place that reverted to an impression. Separately, `centre_nastralis`
here is never checked for success — if its own `hyprctl` dispatch silently
fails (e.g. a stale `HYPRLAND_INSTANCE_SIGNATURE` resolution), the user gets
told "the other screen didn't take the pointer" while the local recentre
*also* silently failed, and nothing distinguishes that from the recentre
having worked.

Note: this gap is not something the double-press override or the
`--cursor-file` reattach introduced — the self-check's exit-path logging was
added in phase 01-01 (D-11) and named "at least four silent `exit 0` paths"
that did not include this one; it has been present unchanged since, and is
still present in the file as it stands after this phase's edits.
**Fix:** `dbg "rescue: dir=$dir want=$want — far side never confirmed, recentred locally"` before the final `centre_nastralis`/`note` pair, and consider re-sampling `hyprctl cursorpos` after `centre_nastralis` to confirm the recentre actually landed before claiming it did.

#### WR-04: The 200ms floor's own justification cites a test mode that structurally cannot produce the measurement it describes

**File:** `/home/nastralis/.local/bin/il-jump:49-56` (cites `/home/nastralis/.local/bin/il-repro:246-256`)
**Issue:**

```sh
# Window bounds for the double-press override below - both measured on this
# machine, not guessed (01-ROOTCAUSE.md, 01-06-SUMMARY.md):
#  - floor 200ms: a tight back-to-back loop of the SAME direction (il-repro
#    --stress's own alternating pattern) costs 12.9-22.3ms between repeats,
#    measured over 19 samples. ...
```

`il-repro --stress` (`mode_stress`, `il-repro:246-256`) is:

```sh
while [ "$i" -le "$n" ]; do
    stress_iter left  mac        "$i/left"
    stress_iter right nastralis  "$i/right"
    i=$((i + 1))
done
```

This alternates `left`/`right` on every call — it never repeats the same
direction back-to-back. A "tight back-to-back loop of the SAME direction"
timing figure could not have been produced by literally running `--stress` as
written; either the 12.9-22.3ms figure came from a different, unrecorded
invocation (e.g. a manual loop of only `stress_iter left mac`), or the
comment's description of what `--stress` does is wrong. Either way, a reader
trying to verify the floor's stated "9x margin" claim by running `il-repro
--stress` as the comment directs would observe alternating-direction timing,
not the same-direction timing the safety margin is actually about. This is a
safety-relevant constant (`RETRY_MIN_MS`, `il-jump:62`) — its whole job is to
keep a genuinely-correct rapid refusal from being force-fired — so an
unreproducible citation for it is worth fixing even though I found no
evidence the 200ms value itself is wrong, only that its documented
methodology doesn't match the code it cites. The ceiling's citation (organic
Route 2 logging, not `--stress`) is unaffected by this.
**Fix:** Either correct the comment to name where the same-direction figure
actually came from, or add a same-direction-repeat mode to `il-repro --stress`
so the cited command genuinely reproduces the claim.

#### WR-05: `il-side-watch`'s "has connected"/"has disconnected" match is an unanchored substring test

**File:** `/home/nastralis/.local/bin/il-side-watch:44-46`
**Issue:**

```sh
*'has connected'*|*'has disconnected'*)
    printf 'nastralis\n' > "$STATE"
    ;;
```

Unlike the switch/jump branch (`il-side-watch:34`), which requires the
`" to "` shape, this branch matches the bare substring anywhere in the line.
Journald lines from `input-leap-server.service` are not, from this script's
point of view, fully trusted — they can embed content that ultimately derives
from a connecting client's own advertised name. I did not attempt to fire an
actual crafted client name against this server (out of scope for a read-only
review and this project's own testability constraints don't cover the
input-leap client-negotiation layer), so I'm stating this as a plausible,
low-confidence robustness gap rather than a demonstrated exploit: a client
name, or any future log message, that happens to contain the literal
substring "has connected"/"has disconnected" without being an actual
connect/disconnect event would reset `$STATE` to `nastralis` regardless.
Worst case is a wrong toggle direction on the next press, self-correcting on
the next real transition — not a wedge, not data loss.
**Fix:** Anchor the match closer to input-leap's actual log shape (e.g.
`*'client "'*'" has connected'*` / `*'has disconnected'*`) the same way the
switch/jump branch above it already anchors on `" to "`.

### Info

#### IN-01: The already-on-side no-op path went from zero-cost to a forked `date` call plus a conditional file read

**File:** `/home/nastralis/.local/bin/il-jump:143-159`
**Issue:** Before this phase, `[ "$CUR" = "$want" ] && exit 0` was a single
`test` and an `exit` — no fork at all. The same guard now unconditionally
forks `date +%s%3N` (`il-jump:144`) and conditionally reads/writes
`$RETRY` on every no-op press, whether or not the override ever fires. This
does not touch the ~50ms hop-latency budget (PROJECT.md) because it's not on
the dispatch path — it only affects the no-op path, which the organic log
(01-ROOTCAUSE.md) shows firing far less often than real dispatches (4 vs 47 in
~4h). Noted for completeness since the guard is what the double-press override
sits inside, not because it's a meaningful regression.
**Fix:** None needed; informational only.

#### IN-02: No shell-injection vector found — noted for the record

**File:** all five reviewed scripts
**Issue:** I specifically checked every place untrusted-ish input (journald
lines in `handle_line()`, the side file's content, the retry marker's
content) flows into the scripts, looking for `eval`, unquoted expansions
passed to a command's argument list, or command substitution of attacker-
influenced content. I found none — `$line`/`$dest` are only ever compared via
`case`/parameter-expansion or interpolated into `echo`/`printf` messages
(never as a format string; `echo` here is bash's builtin with `xpg_echo` off,
verified live, so no backslash-escape interpretation either), and every value
that reaches an actually-executed command (`$geom` in `centre_nastralis`,
`$w`/mac width in `mac_width`) is validated against a digits-only pattern
before use, with a hardcoded fallback on validation failure. This is a
positive finding, recorded because the prompt specifically asked for this
check.
**Fix:** None needed; informational only.

#### IN-03: "jump from" semantic equivalence to "switch from" remains an open, unverified assumption (carried over, not new)

**File:** `/home/nastralis/.local/bin/il-side-watch:28-41`
**Issue:** 01-ROOTCAUSE.md's own "Not established" section already records
that whether `forceLeaveClient()`'s `jump from` line represents a real
pointer-ownership transition the same way `switchScreen()`'s `switch from`
does — versus firing for some unrelated administrative event — was not
settled before this phase shipped matching it. I re-checked this during
review (it's directly relevant to the "can the backlog replay write a wrong
side value" question I was asked to prioritize) and found nothing new to add;
the code treats both line shapes identically (`il-side-watch:34`), and that
treatment's correctness still rests on the same unverified assumption
ROOTCAUSE.md already named. Restated here only so it isn't lost between "out
of scope, already known" and "in scope, worth flagging" — it is genuinely the
latter, just not a *new* finding.
**Fix:** None from this review; tracked already as an open question for
whoever extends Route 2 or reads input-leap's `forceLeaveClient()` call sites
next (per 01-ROOTCAUSE.md).

---

_Reviewed: 2026-09-11T18:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
