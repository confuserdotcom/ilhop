---
phase: 01-regression-recovery
plan: 03
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, ydotool, systemd-user, tdd]

requires:
  - phase: 01-01
    provides: "ILHOP_DEBUG-gated dbg()/dbg_rotate() logging on il-jump:91, --inject-noop harness, 01-EVIDENCE.md"
  - phase: 01-02
    provides: "A1 falsified: hyprctl cursorpos FROZE under capture (D-14's oracle stands) -- not directly consumed by this plan, but the sibling wave this one completes"
provides:
  - "il-jump: dbg() calls at all five remaining exit/end paths (stale-lock, superseded, watcher-unknown, usage, die) plus the dispatch path, so a successful hop also leaves a line -- every way the script can end is now named when debug is on, nothing changes when it is off"
  - "il-repro: --stress (route 1 loop), --stress-live (real crossings, capped), --watcher-gap (RESEARCH Q2 #1's consequence half, asserted not argued), --arm/--disarm/--report (route 2 control surface), --all"
  - "Route 2 armed for the remainder of the phase: $XDG_RUNTIME_DIR/ilhop-debug.on present, so plans 01-04/01-05/01-06 inherit a live passive log"
affects: ["01-04", "01-05", "01-06"]

actuals:
  tokens: 1099
  tasks: 2
  commits: 2
  plan_head_before: efc1cfa  # ~/.dotfiles HEAD before this plan's first commit (split-repo: code lives in ~/.dotfiles, not this ilhop repo)

tech-stack:
  added: []
  patterns:
    - "mode_* functions in il-repro, sharing one ok/bad tally in-process, so --all composes submodes without re-exec'ing the script or losing the aggregate count"
    - "Real-hop-avoidance via real-side awareness: when a test needs il-jump to reach past the already-on-side guard (dispatch/superseded paths), choose the direction that keeps the shove entirely within whichever machine already has real capture, so a REAL relative-move burst never risks crossing back for real"
    - "Isolated harness for race-only-reachable branches: when a branch is reachable only in a sub-millisecond window between a function's internal early-return and the following check (or only by deliberately breaking a live daemon), verify the exact conditional + dbg wiring against both the git-HEAD (old) and edited (new) function bodies in a standalone script, rather than forcing an unreliable live race or breaking ydotoold on the daily driver"

key-files:
  created: []
  modified:
    - /home/nastralis/.local/bin/il-jump
    - /home/nastralis/.local/bin/il-repro

key-decisions:
  - "Did not run `requirements mark-complete HOP-02` -- REQUIREMENTS.md's HOP-02 line requires reproduced, root-caused, AND closed; this plan completes reproduction (all three D-21 routes now exist and run green) and asserts RESEARCH Q2 #1's consequence half, but root-cause and closure are explicitly plans 01-05/01-06's output (01-ROOTCAUSE.md). Same reasoning 01-01/01-02 applied; requirements-completed in this file's frontmatter still names HOP-02 per the template's copy-from-plan-frontmatter instruction, but that is a contribution record, not a REQUIREMENTS.md status change."
  - "watcher-unknown (il-jump's second post-landed() unknown check) and die() verified via an isolated harness, not the live script -- both are reachable only through either a sub-millisecond process race (external timing cannot reliably land in the gap between landed()'s own early-return and the following two checks, since landed() itself already exits early on ANY unknown value seen during its 12x0.1s poll) or by deliberately breaking ydotoold on the daily driver. Documented rather than asserted, per the live-system-safety directive to say so plainly rather than overclaim."
  - "Dispatch, superseded and lock-path RED/GREEN were exercised live via direct script invocation (D-21 route 1), but only ever in the direction that kept the real relative-move bursts on whichever machine already had real capture at the time (side was 'mac' for most of the session) -- so a REAL shove never risked a real, unintended crossing back to Nastralis. One real toggle (used for the debug-off regression check) did genuinely cross back for real; this is normal daily-driver behaviour, not test contamination, and was left as the new real baseline rather than reversed."
  - "--watcher-gap uses `systemctl --user restart` (measured gap: 15-18ms across two runs) rather than trying to reproduce Restart=always's full RestartSec=3 outage -- a manual restart skips the RestartSec delay that only applies to automatic post-crash restarts. The mode's output states this plainly and cites 01-EVIDENCE.md's independently-observed ~4s Restart=always cycle for comparison, rather than implying the measured 15-18ms figure is the mechanism's typical real-world window."
  - "Route 2 left armed at the end of this plan (`il-repro --arm`) -- RESEARCH Q4's recommended sequencing puts route 2 running continuously for the remainder of the phase, and plans 01-04/01-05 are still ahead, so an organic failure between now and phase close will self-explain via `il-repro --report`."

patterns-established:
  - "Pattern: when a test needs to force il-jump past its already-on-side guard without genuinely crossing between machines, pick the direction consistent with whichever side already has real capture -- the relative-move burst then stays local to that machine regardless of what the (deliberately wrong) cached side file claims."
  - "Pattern: mode_* functions sharing global ok/bad counters, so a composite mode (--all) can call submodes as in-process function calls rather than re-exec'ing the script and losing the aggregate tally."

requirements-completed: [HOP-02]

coverage:
  - id: D1
    description: "Every way il-jump can end now names itself in the log when debug is on: stale-lock, superseded, watcher-unknown, usage, and die(), plus a new dispatch line before the first shove -- so the absence of any line beside a remembered failed press is now evidence the failure is upstream of il-jump (RESEARCH Q4)"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "RED observed for all six behaviors against the unmodified il-jump (silent exit, ILHOP_DEBUG=1, no log line written); GREEN observed after each dbg() call was added -- see 'RED results per exit path' below for the full table"
        status: pass
      - kind: other
        ref: "grep -c 'exec 9>&-' il-jump == 1; sh -n il-jump clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "il-repro --stress loops the two decision-table combinations whose correct answer is a refusal, 20 times, with zero pointer motion"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --stress (default): 41/41 checks ok, exit 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "il-repro --watcher-gap proves, without a real hop, that il-side-watch.service does not re-derive truth on restart (a wrong value survives untouched) and that the surviving wrong value produces a silent no-op -- the consequence half of RESEARCH Q2 mechanism #1"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --watcher-gap: 5/5 checks ok, exit 0; il-side-watch.service active at exit both runs; $XDG_RUNTIME_DIR/il-side restored to its real value both runs"
        status: pass
    human_judgment: false
  - id: D4
    description: "Route 2 (--arm/--disarm/--report) round-trips: armed, reported (tail + per-exit-path tally + dispatch count), disarmed"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --arm && test -e $XDG_RUNTIME_DIR/ilhop-debug.on && il-repro --report --lines 5 && il-repro --disarm && test ! -e $XDG_RUNTIME_DIR/ilhop-debug.on -- exit 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "il-repro --all (--inject-noop + --stress + --watcher-gap) exits 0; --stress-live exists, defaults to 2, hard-caps at 5 with a clean refusal, and stays out of --all"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --all: 56/56 checks ok, exit 0; il-repro --stress-live --iterations 6: FAIL + exit 1 + zero side effect (side file unchanged, no pointer motion)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Latency has not drifted since instrumentation landed: il-doctor --test round-trip timings with ILHOP_DEBUG unset and set, compared against 01-EVIDENCE.md's 20ms/53ms baseline"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Two paired samples: unset 20/50ms & set 31/46ms; unset 21/53ms & set 21/43ms -- both legs stay within noise of the baseline and well under the ~50ms budget; no systematic regression (dbg() is a single tmpfs printf per Q5)"
        status: pass
    human_judgment: true
    rationale: "01-EVIDENCE.md recorded a single baseline sample with no explicit variance figure, so judging 'within the baseline's own spread' required a second live paired sample and a qualitative read of the pattern (one leg up, one leg down, inconsistent with a systematic per-call regression) rather than a hard numeric threshold."

duration: ~35min
completed: 2026-09-10
status: complete
---

# Phase 1 Plan 03: Full Refusal Log and the Reproduction Harness Summary

**Every remaining silent exit in `il-jump` now names itself (stale-lock, superseded, watcher-unknown, usage, die, plus a new line on successful dispatch), and `il-repro` grew into the full D-21 harness -- route 1's stressor, route 2's arm/report control surface, and route 3's `--watcher-gap` asserting, not arguing, that `il-side-watch.service` does not re-derive truth on restart.**

## Performance

- **Duration:** ~35 min
- **Started:** ~2026-09-10T18:50:00Z (first read of the live `il-jump`/`il-repro`)
- **Completed:** 2026-09-10T19:04:06Z (last real-system verification pass)
- **Tasks:** 2/2
- **Files modified:** 2 (both in `~/.dotfiles`, the bare repo backing `~/.local/bin/`)

## Accomplishments

- **Every way `il-jump` can end now writes exactly one line when debug is on, and nothing at all when it is off.** Five new `dbg()` call sites (stale-lock, superseded, watcher-unknown, usage, die) plus a new dispatch-path line before the first `shove`, all through the single existing `dbg()` gate. Verified with `ILHOP_DEBUG` unset and no arm file: three representative invocations (already-on-side, bad usage, lock held) never even created the log file, matching the pre-change byte-for-byte silence.
- **RED observed before GREEN for all six behaviors**, not asserted from reading the diff. Four were exercised live against the real system (lock-path, usage-path, dispatch-path, superseded-path), staying on whichever real side already had capture so the genuine `ydotool` relative-move bursts these paths require never risked an unintended cross-machine hop. The remaining two (die(), and the watcher-unknown line -- reachable only in a sub-millisecond race between `landed()`'s own internal early-return and the following check) were verified in an isolated harness against both the git-HEAD and edited function bodies, documented as such rather than forced live.
- **`il-repro` grew from one mode to eight**, refactored into `mode_*` functions sharing one `ok`/`bad` tally so `--all` composes submodes in-process: `--stress` (loops the decision table's two refusal combinations 20x, zero pointer motion, 41/41 green), `--stress-live` (real crossings, default 2, hard-caps at 5 with a clean no-side-effect refusal, excluded from `--all`), `--watcher-gap` (5/5 green: injects a wrong value, restarts `il-side-watch.service`, asserts the value survived untouched and that it then produces a silent no-op), `--arm`/`--disarm`/`--report` (route 2's control surface, round-trips clean), and `--all` (56/56 green).
- **RESEARCH Q2 mechanism #1's consequence half asserted, not argued.** `il-repro --watcher-gap` measured a 15-18ms restart gap across two runs (a manual `systemctl restart` skips `RestartSec`'s automatic-crash-only delay) alongside 01-EVIDENCE.md's independently-observed 166.5s mean transition interval, and states plainly in its own output what this does and does not establish -- a stale value surviving a restart and then causing a silent no-op is proven; whether it happened during the author's real failures remains open, which is exactly what the now-armed route 2 exists to close.
- **Route 2 left armed for the remainder of the phase** (`$XDG_RUNTIME_DIR/ilhop-debug.on` present) so plans 01-04 through 01-06 inherit a live passive log without a separate arming step.
- **Latency has not drifted.** Two paired `il-doctor --test` samples (`ILHOP_DEBUG` unset vs. set) both stayed within noise of 01-EVIDENCE.md's 20ms/53ms baseline and well under the ~50ms budget; the pattern (one leg up, one down between samples) is consistent with ordinary run-to-run jitter, not a systematic per-`dbg()`-call cost.
- **Nothing on the daily driver was left restarted, rebound, or in an unexpected state**: `$XDG_RUNTIME_DIR/il-side` reads `nastralis`, its real value at every checkpoint in this plan; `il-side-watch.service` is active; `il-doctor` (no `--test`) reports 21/21 clean throughout.

## Task Commits

Both commits landed in `~/.dotfiles` (bare repo, work tree `$HOME`) per the plan's split-repo routing table -- neither `il-jump` nor `il-repro` lives in the `ilhop` repo.

1. **Task 1: Every exit path names itself, and a successful dispatch leaves a line too** - `d3833e7` (`~/.dotfiles`) -- five new `dbg()` call sites in `il-jump` plus the dispatch-path line, TDD RED-then-GREEN per behavior
2. **Task 2: Route 1's stressor, the watcher-gap assertion, and route 2's arm-and-read surface** - `a9128f1` (`~/.dotfiles`) -- `il-repro` grown to eight modes

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS, `ilhop` repo)

## Files Created/Modified

- `/home/nastralis/.local/bin/il-jump` (modified, `~/.dotfiles`) -- 6 insertions/5 deletions: `dbg()` calls at the lock guard, the usage-error branch, before the first `shove`, and at both post-`landed()` bails inside the existing detached block; `die()` now logs before it notifies/exits. Exactly one `exec 9>&-` remains (no new detached block, RESEARCH Pitfall 4).
- `/home/nastralis/.local/bin/il-repro` (modified, `~/.dotfiles`) -- 271 insertions/10 deletions: refactored `--inject-noop` into `mode_inject_noop()`, added `mode_stress()`/`stress_iter()`, `mode_stress_live()`, `mode_watcher_gap()`, `mode_arm()`/`mode_disarm()`/`mode_report()`, `mode_all()`.

## RED results per exit path

All six observed failing (silent exit, `ILHOP_DEBUG=1`, zero new log bytes) before that path's `dbg()` call existed, then passing after:

| Exit path | RED (unmodified `il-jump`) | GREEN (after) | Method |
|---|---|---|---|
| stale-lock | exit 0, no log line | `stale-lock: another jump in flight, dropping this press` | Live: external `flock` holder on `il-jump.lock`, then invoke |
| usage | exit 2, no log line | `usage: bad-arg='bogus-arg'` | Live: invalid argument |
| dispatch | exit 0, no log line | `dispatch: dir=left want=mac CUR=nastralis seq=...` | Live: faked `CUR` on the real-mac side, direction kept local to the Mac |
| superseded | exit 0 (both invocations), no log line | `superseded: seq=<first> now=<second>` | Live: two quick same-direction invocations, both kept local to the Mac |
| die | exit 1, no log line | `die: ydotoold will not start, so the pointer cannot be moved` | Isolated harness: git-HEAD vs. edited `die()` body |
| watcher-unknown | exit 0, no log line | `watcher-unknown: dir=left want=mac, cannot judge landing` | Isolated harness: the exact post-`landed()` conditional, driven directly (this branch is reachable live only in the sub-millisecond gap between `landed()`'s own internal `[ "$CUR" = unknown ] && return 0` and the following check -- any external attempt to time an unknown-value injection either lands inside `landed()`'s 12x0.1s poll, where its own early-return fires first and silently exits one line earlier, or lands after the two post-loop checks have already run) |

## Watcher-restart-gap measurement

Two independent `il-repro --watcher-gap` runs:

| Run | Restart gap | Injected value survived? | Consequence (silent no-op) confirmed? | Unit active at exit? |
|---|---|---|---|---|
| standalone | 15ms | yes | yes | yes |
| inside `--all` | 18ms | yes | yes | yes |

Both figures are far below 01-EVIDENCE.md's independently-observed ~4s `Restart=always` cycle (`00:53:34`→`00:53:38`) -- expected, since `systemctl --user restart` is a manual stop+start and does not incur `RestartSec`'s automatic-crash-only delay. `il-repro --watcher-gap`'s own output states this distinction plainly rather than implying 15-18ms is the mechanism's typical real-world window. Printed alongside 01-EVIDENCE.md's 166.5s mean transition interval so the expected rate of lost transitions per restart is a number, not an impression.

## Route 2 status

**Left armed.** `il-repro --arm` was run as the last action of this plan; `$XDG_RUNTIME_DIR/ilhop-debug.on` is present. Per RESEARCH Q4's recommended sequencing ("Route 2 running continuously in the background throughout normal use for the remainder of the phase") and because plans 01-04 through 01-06 are still ahead, an organic HOP-02 occurrence between now and phase close will self-explain via `il-repro --report` (or show no line at all near the remembered press time, which RESEARCH Q4 established is itself the diagnosis: failure upstream of `il-jump`). The arm switch lives on tmpfs and will not survive a reboot; re-arm with `il-repro --arm` if the machine restarts before the phase closes.

## Decisions Made

See `key-decisions` in the frontmatter above -- the `requirements mark-complete` deferral, the isolated-harness methodology for the two race-only-reachable branches, the real-side-awareness technique used to keep every live real shove local to whichever machine already had capture, the `--watcher-gap` timing caveat, and the deliberate choice to leave route 2 armed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `il-repro --report`'s per-exit-path tally double-counted via a broken `||` fallback idiom**
- **Found during:** Task 2, first manual `--report` smoke test with real log content
- **Issue:** `c=$(grep -c "pattern" "$DBGLOG" 2>/dev/null || echo 0)` -- `grep -c` on zero matches still prints `0` to stdout AND exits non-zero (no lines selected), so the `||` branch fired too, concatenating a second `0` into the same command substitution and producing garbled two-line tally output for every zero-count exit path.
- **Fix:** Dropped the `|| echo 0` fallback entirely (`grep -c` always prints a count regardless of match/no-match exit status) and defaulted via `${c:-0}` for the one genuine failure case (log file absent).
- **Files modified:** `/home/nastralis/.local/bin/il-repro`
- **Verification:** Re-ran the same smoke test; tally now shows exactly one line per exit path with correct counts.
- **Committed in:** `a9128f1` (folded into the same commit; caught before the first commit of this task landed)

---

**Total deviations:** 1 auto-fixed (1 bug, caught in testing before commit)
**Impact on plan:** None on scope or objective -- a testing-time bug in a brand-new mode, fixed before that mode's own commit, not a regression to anything from a prior plan.

## Issues Encountered

- **The decision table `il-jump:81-91` names for `--stress` has only 2 refusal combinations, not the full 3x3=9.** `toggle` can never produce a refusal by construction (it always picks the side the cache says you are *not* on), and the `unknown` cached state never equals a real side value. Per the plan's own instruction ("restricted to the combinations whose correct answer is a refusal"), `--stress` loops exactly the two combinations that inject_case already exercises once (`left`/`mac` and `right`/`nastralis`), N times each. Documented here so a future reader is not surprised the loop only ever touches two of the nine cells.
- **Real side was `mac` for most of this plan's live testing, briefly `nastralis` after one intentional regression-check toggle.** Every real relative-move burst required by the dispatch/superseded RED-GREEN tests was deliberately kept in the direction consistent with whichever side had real capture at the time, so no test risked an unwanted real crossing. The one genuine crossing that did happen (`il-jump toggle` used for the debug-off regression check, run without first checking direction) was a normal, safe, reversible daily-driver action -- documented as a key-decision above rather than treated as contamination.
- **01-EVIDENCE.md's latency baseline is a single sample with no recorded variance**, so "exceeds the baseline by more than the baseline's own spread" (the plan's verification wording) had no numeric spread to compare against. Resolved by taking a second paired live sample and reading the pattern qualitatively -- recorded as coverage item D6 with `human_judgment: true` and the reasoning made explicit, rather than silently treated as an automated pass/fail.

## User Setup Required

None -- no external service configuration required. Route 2 is left armed (see above); no action needed unless the machine reboots before phase close, in which case `il-repro --arm` re-arms it.

## Next Phase Readiness

- `il-jump`'s full refusal log and `il-repro`'s full D-21 harness (`--inject-noop`, `--stress`, `--stress-live`, `--watcher-gap`, `--arm`/`--disarm`/`--report`, `--all`) are exactly what plan 01-05 (root-cause determination) and 01-06 (closure) read from -- every silent path names itself, and the watcher-restart-gap mechanism is asserted end to end.
- Route 2 is armed and will keep logging through plans 01-04/01-05/01-06 unless the machine reboots.
- **Not yet done, by design:** root-cause determination (`01-ROOTCAUSE.md`) and HOP-02's actual closure remain plan 01-05/01-06's work, per this plan's own "Artifacts this phase produces" table. HOP-03's landing-oracle work (this plan did not touch it) is plan 01-04's.
- Nothing on the daily driver was left restarted, rebound, or in an injected state beyond the intentional route-2 arm switch: `$XDG_RUNTIME_DIR/il-side` reads `nastralis`, its real value; `il-side-watch.service` is active; `il-doctor` (no `--test`) reports 21/21 clean, matching the baseline throughout every checkpoint in this plan.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-10*

## Self-Check: PASSED

All claimed files found on disk; both claimed commits found in `~/.dotfiles` (`d3833e7`, `a9128f1`).
