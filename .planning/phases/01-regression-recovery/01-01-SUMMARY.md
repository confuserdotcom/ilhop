---
phase: 01-regression-recovery
plan: 01
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, ydotool, systemd-user, tdd]

requires: []
provides:
  - "01-EVIDENCE.md: measured watcher-restart history, transition rate, overlap count, A3 EIS-lock check, ground truth, and latency baseline for HOP-02/HOP-03"
  - "il-jump: ILHOP_DEBUG-gated dbg()/dbg_rotate() logging at the accused guard (il-jump:91), off by default, capped at 64 KiB"
  - "il-repro: new reproduction harness, --inject-noop mode (Route 3 state injection, both directions)"
affects: ["01-02", "01-03", "01-04", "01-05", "01-06"]

actuals:
  tokens: 6179
  tasks: 3
  commits: 3
  plan_head_before: 49cb1cbfce140ae7dba2addeda3892b3b9079acc

tech-stack:
  added: []
  patterns:
    - "dbg() one-liner beside note()/die(): single `[ -n ... ] || [ -e ... ] || return 0` gate, one printf per line, >> never >"
    - "dbg_rotate(): tail -c + mv trailing-half rotation at startup, no lock, accepted lossy-on-rename cost"
    - "il-repro snapshot+trap(EXIT INT TERM)+restore idiom for any harness that deliberately injects wrong state into a live tmpfs file"

key-files:
  created:
    - /home/nastralis/.local/bin/il-repro
    - .planning/phases/01-regression-recovery/01-EVIDENCE.md
  modified:
    - /home/nastralis/.local/bin/il-jump

key-decisions:
  - "Restart-history evidence SUPPORTS RESEARCH Q2 mechanism #1, not deflates it: 2 real transitions measured lost inside the one watcher-restart gap captured in the 7-day window (journalctl alone, zero keypresses)"
  - "Did not run `requirements mark-complete HOP-02` — REQUIREMENTS.md's HOP-02 line requires reproduced, root-caused, AND closed; this plan only reproduces the guard mechanism via Route 3. Marking it complete now would misrepresent status on the exact project that already shipped once on unverified confidence. Plans 01-05/01-06 own root-cause and closure."
  - "dbg()'s timestamp uses date +%Y-%m-%dT%H:%M:%S.%3N%z (human-readable, per the plan's explicit D-11 rationale) rather than PATTERNS.md's epoch-only suggestion, so an absent line can be correlated against a human's memory of when a press failed"

patterns-established:
  - "Pattern: gated debug logging that costs a daily driver nothing when off (single shell `test`, no fork, no printf call reached)"
  - "Pattern: state-injection harnesses that snapshot + trap-restore before writing a deliberate lie into shared tmpfs state"

requirements-completed: [HOP-02]

coverage:
  - id: D1
    description: "Zero-keypress journald evidence sweep: watcher restart history, input-leap transition rate, restart-gap overlap, A3 EIS-lock count, ground truth, and il-doctor --test latency baseline, all recorded in 01-EVIDENCE.md"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Task 1 automated verify: grep -Eq 'NRestarts=[0-9]+' and grep -Eq 'switch from' against 01-EVIDENCE.md"
        status: pass
    human_judgment: false
  - id: D2
    description: "il-repro --inject-noop demonstrates the guard at il-jump:91 producing D-02's silent, motionless, self-explaining no-op on command, in both directions, via Route 3 state injection — RED observed against unmodified il-jump before the fix, GREEN after"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "/home/nastralis/.local/bin/il-repro --inject-noop (10/10 checks, exit 0)"
        status: pass
      - kind: other
        ref: "sh -n il-jump && sh -n il-repro && test -x il-repro"
        status: pass
    human_judgment: false
  - id: D3
    description: "The tracer's reach and limits recorded separately in 01-EVIDENCE.md, so Route 3's success is not mistaken for closing HOP-02 (RESEARCH Pitfall 1)"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "grep -Eq '^## What the tracer proved' and grep -Eq '^## What it did not prove' against 01-EVIDENCE.md"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-09-10
status: complete
---

# Phase 1 Plan 01: Evidence Sweep and Tracer Summary

**Watcher-restart-gap mechanism (RESEARCH Q2 #1) confirmed firing with measured journald evidence (2 lost transitions), and the accused guard at `il-jump:91` proven end to end via `il-repro --inject-noop` — zero keypresses, zero pointer motion, RED observed before GREEN.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-10T17:40:00Z (approx, first read-only probe)
- **Completed:** 2026-09-10T17:55:17Z (final `ilhop` commit)
- **Tasks:** 3/3
- **Files modified:** 3 (1 created harness, 1 modified live script, 1 created/extended evidence doc)

## Accomplishments

- **The evidence sweep did not deflate the leading hypothesis — it measured it firing.** In the one same-boot `il-side-watch.service` restart cycle captured in the 7-day journald window (`00:53:34`→`00:53:38`, a real `Restart=always RestartSec=3` cycle), two genuine `switch from` transitions landed inside the watcher's blind spot and were provably never observed. In this instance the pair happened to cancel out, so `il-side` was not visibly corrupted that time — but the mechanism is real, not theoretical, on this machine.
- Also measured: `jump from` (7 occurrences) confirms `il-side-watch:24`'s case statement never matches `forceLeaveClient()`'s line shape at all — a second, independent source of missed transitions beyond the restart-gap mechanism.
- `il-jump` now writes exactly one human-readable, wall-clock-timestamped line to `$XDG_RUNTIME_DIR/ilhop-debug.log` at the accused guard (`:91`), gated behind `ILHOP_DEBUG` or an arm file, off by default (verified: zero bytes written, log file not even created, across repeated invocations with debug off).
- `il-repro --inject-noop` demonstrates the guard end to end: forcing the side file to the guard's `$want` in both directions produces exit 0, exactly one new log line naming the refusal/direction/values, and pointer stillness (`dx=0 dy=0`/`dx=0 dy=1`px, both well under the 50px margin) — with the side file always restored to its original value afterward, including under a simulated `SIGTERM` mid-run.
- Latency baseline recorded for plan 01-06 to measure against: 20ms to the Mac, 53ms back (the return leg is 3ms over PROJECT.md's ~50ms budget — flagged, not acted on here).

## Task Commits

1. **Task 1: Spend the free evidence** - `a9dde01` (docs, `ilhop` repo) — watcher restart history, transition rate, overlap, A3, ground truth, latency baseline
2. **Task 2: Tracer — the accused refusal, wired end to end** - `926abb7` (feat, `~/.dotfiles` bare repo) — `il-jump` instrumentation + new `il-repro` harness. TDD: RED observed (4 FAIL assertions, exit 1) against unmodified `il-jump` before this commit's `il-jump` changes existed; GREEN after (10/10, exit 0).
3. **Task 3: Record the tracer's reach and its limits** - `a2f2c52` (docs, `ilhop` repo) — appended `## What the tracer proved` / `## What it did not prove` to `01-EVIDENCE.md`

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS)

_Split-repo routing followed exactly per the plan's table: code (`il-jump`, `il-repro`) → `~/.dotfiles` bare repo; `.planning/**` → `ilhop` repo._

## Files Created/Modified

- `/home/nastralis/.local/bin/il-jump` (modified, `~/.dotfiles`) — added `DBGLOG`/`DBGARM`/`DBGCAP`, `dbg()`, `dbg_rotate()`, and instrumented the `:91` guard; no new detached subshell
- `/home/nastralis/.local/bin/il-repro` (created, `~/.dotfiles`) — `--inject-noop` Route 3 reproduction harness, `il-doctor`-style tolerant shell (no `set -u`/`set -e`)
- `.planning/phases/01-regression-recovery/01-EVIDENCE.md` (created, `ilhop`) — six Task 1 measurements plus the Task 3 proved/not-proved split

## Decisions Made

- Restart-history evidence **supports** RESEARCH Q2 mechanism #1 rather than deflating it — see key-decisions above and `01-EVIDENCE.md`'s Verdict section.
- Deliberately did **not** run `requirements mark-complete HOP-02` — see key-decisions above. HOP-02 remains `- [ ]` in `REQUIREMENTS.md` until root-cause and closure land in a later plan.
- `dbg()`'s timestamp format follows the plan's explicit human-readable spec, not PATTERNS.md's epoch-only suggestion (the plan's wording supersedes the pattern map here, and the plan is the more specific, later-considered source).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `git add` with a relative pathspec silently failed in the `~/.dotfiles` bare repo**
- **Found during:** Task 2, first commit attempt
- **Issue:** `git --git-dir=$HOME/.dotfiles --work-tree=$HOME add .local/bin/il-jump` returned `fatal: pathspec '.local/bin/il-jump' did not match any files` because the shell's cwd was `/home/nastralis/Projects/ilhop`, not `$HOME` — RESEARCH.md's Sources section had already flagged this exact sandbox quirk (pathspec-filtered `git diff`/`git show` silently returning empty) for read commands; it turns out `git add` with a relative pathspec hits the same issue.
- **Fix:** Staged with absolute paths (`git add "$HOME/.local/bin/il-jump" "$HOME/.local/bin/il-repro"`) instead of paths relative to the bare repo's work tree.
- **Files modified:** none (staging mechanics only, no script content affected)
- **Verification:** `git status --porcelain` showed both files staged correctly before committing.
- **Committed in:** `926abb7`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Staging-mechanics only; no effect on script content, verification results, or scope.

## Issues Encountered

- The `input-leap-server.service` journal in the 7-day window contains ~1M lines, 1,013,212 of them `DEBUG:`-level `on_motion_event` spam, all timestamped before `2026-09-10 00:45:28` — historical, ended before this session, and the live unit is confirmed `--debug INFO` right now (via `il-doctor`). Recorded as a side note in `01-EVIDENCE.md`'s Transition Rate section for context; not chased further, as it predates and is unrelated to this task's scope.
- Gap 2 (`04:32:27`→`13:29:58`) initially looked like a second lost-transition window, but on inspection it is `input-leap-server.service` itself shutting down as the machine goes down for a reboot, not a live mid-session gap a press could land in — documented separately from Gap 1 in `01-EVIDENCE.md` so it is not miscounted as a second confirmed overlap.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `01-EVIDENCE.md` and the now-instrumented `il-jump`/`il-repro` are the load-bearing inputs plan 01-02 (A1 falsification), 01-03 (watcher-gap stressor + Route 2 arming), and 01-05 (root-cause determination) all read from.
- The `ILHOP_DEBUG`/`DBGARM`/`DBGCAP`/`dbg()`/`dbg_rotate()` surface is exactly what D-13 requires to survive into Phase 4's `ilhop doctor` — nothing here needs revisiting for that migration, only extending (D-11's remaining three exit paths are explicitly plan 01-03's work, not redone here).
- **Not yet done, by design:** HOP-02's other three silent exits (`:54` stale lock, `:168` superseded sequence, `:169` watcher unknown) are uninstrumented — this task's acceptance criteria named exactly one exit path (`:91`) as in scope. HOP-03's landing oracle (D-14/D-16, blocked on the A1 falsification) is untouched. Neither is a blocker for plan 01-02, which is next.
- Nothing on the daily driver was left restarted, rebound, or in an injected state: `$XDG_RUNTIME_DIR/il-side` reads `nastralis`, matching its value before this plan began; no debug log file exists (debug was left off); `il-doctor` (no `--test`) reports 21/21 clean, matching Task 1's pre-change baseline of 0 failures.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-10*

## Self-Check: PASSED

All claimed files found on disk; all claimed commits found in their respective repos (`a9dde01`, `a2f2c52` in `ilhop`; `926abb7` in `~/.dotfiles`).
