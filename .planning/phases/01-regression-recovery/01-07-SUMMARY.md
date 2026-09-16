---
phase: 01-regression-recovery
plan: 07
subsystem: infra
tags: [shell, posix-sh, input-leap, systemd, journald, gap-closure, human-gate-not-required]

requires:
  - phase: 01-06
    provides: "The HOP-02 fix (bounded-backlog --cursor-file reattach, jump-from line match, same-direction double-press override) and the phase regression gate il-repro --all/--watcher-gap/--watcher-parser/--selfcheck-rescue"
provides:
  - "CR-01 closed: il-side-watch's --cursor-file reattach now bounds journalctl's own hard-failure mode on an unreadable cursor to exactly one Restart=always cycle instead of an unbounded silent crash loop, and the diagnostic is discoverable in the unit's own journal"
  - "il-doctor's crash-loop-aware health check, using a journal-history mechanism (systemd's own 'Scheduled restart job' line) verified live on this box's systemd (261), not assumed"
  - "il-repro --cursor-crash-loop, folded into --all — a permanent regression-suite proof of both halves (self-heal bounded, detector accurate) rather than a one-off finding"
affects: ["04"]

actuals:
  tokens: 3850
  tasks: 3
  commits: 3
  plan_head_before: 78123648ea49e78966cda79831f57b1e56dbbb35

tech-stack:
  added: []
  patterns:
    - "Portable exit-status capture from a journalctl-fed pipeline: a brace-group whose only unredirected stdout feeds the while-read loop, with the exit code sidecar'd to a small file (CURSOR_RC) and read back after the loop finishes — chosen over set -o pipefail/PIPESTATUS specifically for portability discipline (this file declares #!/bin/sh and has no bashism today), not because those features are unavailable on this box (they are; /bin/sh here is bash 5.3.15, verified live)"
    - "Journal-history health checks (grep-count systemd's own restart-scheduling log line over a trailing --since window) instead of point-in-time systemctl is-active polling, when a service's Restart=always/RestartSec config can make a genuinely unhealthy service report 'active' most of the time it is checked"
    - "A reproduction mode's own glob-match assertion on a health check's pass/fail text is only as strong as the two messages' actual wording — a pass message that happens to contain the fail message's key substring as a false-negation ('is NOT crash-looping' contains 'crash-loop') defeats a *crash-loop* style match; the fix is to keep the positive-state wording lexically disjoint from the flagged term, not to make the match pattern cleverer"

key-files:
  created:
    - .planning/phases/01-regression-recovery/01-07-SUMMARY.md
  modified:
    - /home/nastralis/.local/bin/il-side-watch
    - /home/nastralis/.local/bin/il-doctor
    - /home/nastralis/.local/bin/il-repro

key-decisions:
  - "WR-01 (a well-formed-but-unresolvable cursor silently replaying the full retained backlog) is explicitly deferred, not fixed — recorded as a comment in il-side-watch and restated here. It does not hit CR-01's hard-fail path at all; it converges to the correct final value rather than freezing anything, a materially lower-severity failure shape. Fixing it well needs this journal's actual retention/vacuum policy (a research question) and a place to log a large unexpected replay (does not exist in this file today) — both fit Phase 4 (DIAG)'s structured-health-reporting remit, not this minimal-change gap-closure plan."
  - "Self-heal window's bounded data-loss cost is stated, not hidden: any transitions between the failed attempt and the successful cold-start restart moments later (bounded to ~one RestartSec cycle, ~3s) are not replayed — the same class of cost the pre-existing first-run -n 0 fallback already accepts, reached through a different door, self-correcting on the next real transition exactly as the first-run case already is. This is not a reintroduction of the unbounded blind spot --cursor-file was added to close (01-06) — it is bounded to one restart cycle, not indefinite."
  - "Auto-fixed (Rule 1, same task as the writer fix): il-doctor's crash-loop check's PASS message originally read 'il-side-watch.service is not crash-looping (...)'. Discovered live while re-running il-repro --cursor-crash-loop against the fixed writer: that wording still contains the substring 'crash-loop', so the mode's *crash-loop* glob match (required by the plan to distinguish doctor's positive/negative branches) could not tell PASS from FAIL — every doctor run 'false-positived' as crash-looping regardless of actual state. Reworded to 'restart history looks healthy', which is lexically disjoint from the flagged term. Not a plan deviation in scope, but the exact kind of self-referential bug the plan's own dual-branch assertion (Task 1's 'this same induction... proves the detector's positive case' language) was designed to catch, and did catch, live, on the first post-fix run."
  - "The mechanism cited by the plan for il-doctor's new check ('systemd's own Scheduled restart job, restart counter is at N line') is exactly what is grepped — confirmed live this session at ~3s cadence per restart, matching 01-REVIEW.md's own citation. The earlier NRestarts-based wording the plan itself flagged as a leftover was never implemented — this task's acceptance criteria already corrected it before execution."
  - "il-doctor --test (the real round-trip mode) was deliberately NOT run, per the plan's own instruction: this plan touches il-side-watch's failure handling and il-doctor's diagnostic output only, nothing on il-jump's own path, the landing oracle, or key/pointer injection, so a real cross-machine hop proves nothing this plan's scope needs proven."

patterns-established:
  - "Pattern: a reproduction mode that asserts on a health check's freeform pass/fail text must treat the health check's own wording as part of what it is testing, not just the boolean pass/fail count — a substring collision between the positive and negative message is a false-negative/false-positive risk that only shows up when the mode is actually run against both states, which is exactly what happened here."

requirements-completed: [HOP-02]

coverage:
  - id: D1
    description: "CR-01 reproduced end to end against the real journalctl/systemd on this machine (unfixed code): the restart-count bound, cursor repair, and diagnostic discoverability all fail as CR-01/01-VERIFICATION.md described, while il-doctor's new crash-loop check correctly names the genuine, currently-ongoing loop — the one point in this plan's own timeline where that positive case is safely provable"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --cursor-crash-loop against unfixed il-side-watch: 3 ok / 3 failed. FAILs: 'expected exactly 1 restart, got 2', 'cursor file still literally garbage-not-a-cursor - not repaired', 'no discoverable diagnostic'. PASS: 'il-doctor correctly names the ongoing crash-loop'. Committed 33299f7."
        status: pass
    human_judgment: false
  - id: D2
    description: "A malformed or unseekable $CURSOR no longer sustains a permanent crash loop — il-side-watch.service self-heals within exactly one Restart=always cycle via the documented -n 0 cold-start fallback, and journalctl's own diagnostic is discoverable in the unit's own journal afterward, proven by the same harness that reproduced the unbounded loop against the unfixed code"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --cursor-crash-loop against fixed il-side-watch: 6 ok / 0 failed, exit 0. Journal confirmed live: single 'Scheduled restart job, restart counter is at 1' line, journalctl's 'Failed to seek to cursor: Invalid argument' now reaches the unit's own journal (previously discarded by 2>/dev/null), il-side-watch's own new diagnostic line also present. Committed 1b236c9."
        status: pass
    human_judgment: false
  - id: D3
    description: "A crash-looping-but-active-reporting il-side-watch.service is caught by an automated il-doctor check (journal-history mechanism, verified live on this box's systemd 261), and the same check does not false-positive on the single, legitimate restart the fixed self-heal itself causes"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Both branches proven live in the same session against genuinely different states: catches a real loop (il-repro --cursor-crash-loop against unfixed code, restarts=2, doctor reports crash-loop) and does not false-positive on one bounded restart (against fixed code, restarts=1, doctor reports healthy) — the latter only after the Rule-1 wording fix described in key-decisions. Committed 33299f7 (detector) + 1b236c9 (wording fix)."
        status: pass
    human_judgment: false
  - id: D4
    description: "The permanent regression-suite proof is folded into il-repro --all rather than left a one-off finding; the full closing gate (il-repro --all, non-invasive il-doctor, sh -n, debt-marker scan, Route 2 arm switch, daily-driver health) is green"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-repro --all run 4 times this session: 87/0, 86/0, 79/8, 86/0 (check(s) ok / failed). --cursor-crash-loop's own 6 assertions were green in all 4 runs, verified by direct inspection of each run's --cursor-crash-loop section. The 79/8 run's 8 FAILs were all pointer-motion-probe lines inside --stress/--retry-forced/--selfcheck-rescue (stale pointer captured via hyprctl cursorpos during a refusal or the rescue's centre-tolerance check) -- the exact pre-existing, already-documented Phase 4 harness defect from 01-06-SUMMARY.md ('a pointer-motion probe cannot distinguish the code under test from a human using the machine'), not a regression from this plan; none of the 8 FAILs were in --cursor-crash-loop. il-doctor (non-invasive) run 3 times: 22 ok / 0 failed every time, including the new crash-loop check reporting healthy. sh -n clean on all three files. grep -nE 'TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER' across all three files: no matches. $XDG_RUNTIME_DIR/ilhop-debug.on present throughout. il-side-watch.service active, $XDG_RUNTIME_DIR/il-side holds a real value. Committed ba97a0b."
        status: pass
    human_judgment: false
  - id: D5
    description: "No task in this plan required a human at the keyboard — it does not touch the key/pointer injection path, il-jump's hot-path budget, the double-press override, or the non-circular landing oracle"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-jump not in files_modified and not edited; grep confirms zero ydotool/hyprctl-dispatch call sites touched by any of the three diffs. Every assertion above is script-testable and was run non-interactively this session."
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 07: Close CR-01 (Gap Closure) Summary

**Bounded the `il-side-watch` `--cursor-file` reattach's unhandled `journalctl` hard-failure to exactly one `Restart=always` cycle, added a journal-history crash-loop detector to `il-doctor`, and folded a permanent `il-repro --cursor-crash-loop` regression gate into `--all` — all three fully autonomous, no human at the keyboard.**

## Performance

- **Duration:** ~35 min (context/reading, three tasks, full closing gate including repeated post-fix verification runs)
- **Completed:** 2026-09-16T16:57:33Z
- **Tasks:** 3/3
- **Commits:** 3 (all in `~/.dotfiles`)

## Accomplishments

- **CR-01 reproduced end to end against the unfixed code, live, before any fix.** `il-repro --cursor-crash-loop` (Task 1) induced `journalctl`'s real hard-failure mode by writing `garbage-not-a-cursor` into `il-side-watch`'s own cursor file: 2 restarts in the trailing 10s (not bounded), cursor never repaired, diagnostic undiscoverable — matching 01-REVIEW.md CR-01 and 01-VERIFICATION.md's own independent reproduction exactly. In the same run, `il-doctor`'s new crash-loop check correctly named the genuine, currently-ongoing loop — the one point in this plan's timeline that positive case can safely be proven, since fixing the writer removes the ability to safely reproduce a genuine ongoing loop again.
- **The writer is fixed: bounded self-heal, discoverable diagnostic.** `il-side-watch`'s `--cursor-file` reattach now captures `journalctl`'s own exit status via a portable brace-group + side-file (`CURSOR_RC`) — not `set -o pipefail`/`PIPESTATUS` (both DO work on this box, `/bin/sh` → bash 5.3.15, verified live; avoided for portability discipline, since the file declares `#!/bin/sh` and has no bashism today). On a nonzero exit it deletes `$CURSOR` so the next `Restart=always` cycle cold-starts via the documented `-n 0` fallback — exactly one restart, not an unbounded series — and removes the unconditional `2>/dev/null` on the `journalctl` invocation so the diagnostic reaches the unit's own journal. Re-running the identical Task 1 harness against the fixed code: 6 ok / 0 failed.
- **A live bug in the detector itself was found and fixed in the same task, by the plan's own dual-branch design.** `il-doctor`'s crash-loop check's PASS message ("... is not crash-looping ...") still contained the substring `crash-loop`, so `il-repro --cursor-crash-loop`'s glob match couldn't distinguish PASS from FAIL — every post-fix run "false-positived" as still looping. Caught live on the very first re-run against the fixed writer (not theorized), fixed by rewording the PASS path to "restart history looks healthy" (lexically disjoint from the flagged term), verified by re-running the same mode to 6/6 green.
- **CR-01's proof is now a permanent regression-suite member, not a one-off finding.** `mode_cursor_crash_loop` folded into `mode_all`, in its logical position alongside `mode_watcher_gap` and before `mode_selfcheck_rescue`. `il-repro --all` run 4 times this session: `--cursor-crash-loop`'s own 6 assertions were green every single time. One of the four runs (79 ok / 8 failed) hit the pre-existing, already-documented Phase 4 pointer-motion-probe confound in the older `--stress`/`--retry-forced`/`--selfcheck-rescue` modes (01-06-SUMMARY.md: "a pointer-motion probe cannot distinguish the code under test from a human using the machine") — none of the 8 FAILs were in `--cursor-crash-loop`, and a hands-off re-run returned clean (86 ok / 0 failed), matching 01-06's own resolution of the identical confound. Non-invasive `il-doctor` 22 ok / 0 failed on every run, including the new check reporting healthy; `sh -n` clean on all three touched files; zero debt markers; Route 2's arm switch untouched and still armed; `il-side-watch.service` active with `$XDG_RUNTIME_DIR/il-side` holding a real value throughout.
- **WR-01 and the self-heal window's bounded cost are both explicitly decided and recorded, not left unmentioned** — as code comments in `il-side-watch` and restated in this SUMMARY's `key-decisions`.
- **No task required a human at the keyboard.** `il-jump` was never edited (not in `files_modified`), no key/pointer injection call site was touched by any of the three diffs, and every assertion above ran non-interactively.

## Task Commits

1. **Task 1: Reproduce CR-01 end to end, and prove the new crash-loop detector while a genuine loop still exists** — `33299f7` (test) — `il-doctor`'s journal-history crash-loop check + `il-repro --cursor-crash-loop` (wired into CLI/header, not yet folded into `--all`), run against the unfixed writer: 3 ok / 3 failed, RED as expected, detector's positive case proven live.
2. **Task 2: Fix the writer — bound the crash loop and stop discarding the diagnostic** — `1b236c9` (fix) — the brace-group + `CURSOR_RC` side-file exit-status capture, cursor deletion on nonzero exit, `2>/dev/null` removed; plus the Rule-1 wording fix to `il-doctor`'s PASS message found live in the same task. `il-repro --cursor-crash-loop` (Task 1, unmodified): 6 ok / 0 failed. `--watcher-gap` and `--watcher-parser` unaffected.
3. **Task 3: Fold into the regression gate and close it** — `ba97a0b` (feat) — `mode_cursor_crash_loop` folded into `mode_all` and the `--all`/header docs; full closing gate run and recorded.

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS), in the `ilhop` repo.

## Files Created/Modified

- `/home/nastralis/.local/bin/il-side-watch` (`~/.dotfiles`) — the exit-status-checked, self-cleaning `--cursor-file` reattach; `2>/dev/null` removed
- `/home/nastralis/.local/bin/il-doctor` (`~/.dotfiles`) — the journal-history crash-loop check in the "side tracking" section
- `/home/nastralis/.local/bin/il-repro` (`~/.dotfiles`) — `mode_cursor_crash_loop` / `--cursor-crash-loop`, folded into `--all`
- `.planning/phases/01-regression-recovery/01-07-SUMMARY.md` (created, `ilhop` repo)

## Decisions Made

See `key-decisions` in the frontmatter: WR-01's explicit deferral to Phase 4, the self-heal window's bounded data-loss cost stated not hidden, the Rule-1 auto-fix to `il-doctor`'s PASS wording (a substring collision that defeated the plan's own dual-branch assertion), confirmation that the plan's cited detection mechanism (`Scheduled restart job` journal line) was implemented as specified (not the earlier `NRestarts`-based wording the plan itself flagged as a stale leftover), and the deliberate decision not to run `il-doctor --test`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `il-doctor`'s crash-loop check PASS message defeated its own detector's dual-branch assertion**
- **Found during:** Task 2, re-running Task 1's unmodified harness against the freshly-fixed `il-side-watch`
- **Issue:** The PASS-path message read `"il-side-watch.service is not crash-looping (...)"`. `il-repro --cursor-crash-loop`'s bounded-case assertion checks that `il-doctor`'s output does NOT contain the substring `crash-loop` — but "is **not** crash-looping" contains that exact substring, so the assertion always saw a "positive" match regardless of actual state, producing a false FAIL on a correct self-heal (confirmed by direct comparison: manual reproduction of the identical sequence outside the harness showed the underlying restart-counting logic was correct; only the assertion's own text match was fooled).
- **Fix:** Reworded the PASS message to `"il-side-watch.service restart history looks healthy (...)"` — lexically disjoint from `crash-loop` — while leaving the FAIL message (`"... is crash-looping ..."`) untouched, since it must contain that literal hyphenated word per the plan's acceptance criteria.
- **Files modified:** `/home/nastralis/.local/bin/il-doctor`
- **Verification:** Re-ran `il-repro --cursor-crash-loop` against the fixed writer: 6 ok / 0 failed (previously 5 ok / 1 failed with the un-reworded message). Re-ran `il-repro --all`: the fold-in still shows the detector correctly not-crash-looping on a settled service.
- **Committed in:** `1b236c9` (Task 2 commit, same task as the writer fix)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix was necessary for the crash-loop detector's own bounded-case assertion — required by the plan's Task 1 acceptance criteria — to actually hold. No scope creep: only the check's own PASS-path string changed, not its underlying `journalctl --since` grep-count mechanism, which matched the plan's own cited `Scheduled restart job` line exactly on first implementation.

## Issues Encountered

- **The plan-cited detection mechanism worked exactly as measured in 01-REVIEW.md** — `Scheduled restart job, restart counter is at N` lines land roughly 3 seconds apart under `RestartSec=3`, confirmed live again this session across five separate induced-failure cycles. No surprises there.
- **The one real surprise was the detector's own PASS-message wording bug** (see Deviations above) — caught live by the plan's own design (re-running the same unmodified harness against both the unfixed and fixed writer, in that specific order) rather than by code review alone. This is exactly the kind of self-referential bug a dual-branch live assertion is built to catch.
- **`mac`-vs-`nastralis` state at the end of `il-repro --all`'s `--selfcheck-rescue` sub-mode landed the daily driver on `mac` at one point, `nastralis` at another** (both real, valid values, not stale ones — the mode's own force-back logic ran each time and the final reported state is genuine). No action needed; `il-doctor` confirms `$RUN/il-side` holds a real value either way.
- **One of four `il-repro --all` re-runs this session hit the pre-existing pointer-motion-probe confound** 01-06-SUMMARY.md already filed as a Phase 4 harness defect (79 ok / 8 failed, all 8 in `--stress`/`--retry-forced`/`--selfcheck-rescue`'s pointer-stillness/centre-tolerance checks, none in `--cursor-crash-loop`). Not chased or fixed here — out of this plan's scope (the plan touches only `il-side-watch`'s failure handling, `il-doctor`'s diagnostic, and `il-repro`'s new mode, none of which own the pointer-motion probe). A hands-off re-run immediately after returned clean, matching the exact pattern 01-06-SUMMARY.md already documented and attributed to the probe's own reliability, not to code under test.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **HOP-02's reopening is satisfied.** The gap 01-VERIFICATION.md found (`gaps_found`, 5/6 must-haves) is closed: the fix this phase shipped no longer reintroduces the silent-no-op defect class through the mechanism it modified. Phase 1 can now be re-verified against its stated goal.
- **WR-01 (the well-formed-but-unresolvable cursor's unbounded backlog replay) is filed as a Phase 4 (DIAG) inheritance**, alongside the three items 01-06-SUMMARY.md already filed (the pointer-motion probe confound, `il-repro`'s moving check-count denominator, `il-doctor:78`'s bare `hyprctl`). Doing WR-01 well needs this journal's actual retention/vacuum policy (a research question) and a place to log a large unexpected replay — both fit DIAG-01's structured-health-reporting remit.
- **Route 2 (`$XDG_RUNTIME_DIR/ilhop-debug.on`) is still armed**, exactly as this plan's instructions required — disarming it is the phase-close action, not this plan's, and was deliberately not performed here.
- **Phase tail is still owed by the orchestrator**, per this plan's own instructions: this SUMMARY does not mark the phase complete and does not update STATE.md/ROADMAP.md — aggregate_results → code review gate → re-verifier → ROADMAP update remain outstanding.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-16*

## Self-Check: PASSED

All three claimed `~/.dotfiles` commits verified present and in order: `git --git-dir=$HOME/.dotfiles --work-tree=$HOME log --oneline -3` shows `ba97a0b`, `1b236c9`, `33299f7`, parented on `8daf23e` (01-06's last commit) — `git log --oneline | grep -c '(01-07)'` = 3, matching `actuals.commits`. All three claimed files found on disk and re-read after editing: `/home/nastralis/.local/bin/il-side-watch` contains `CURSOR_RC` (grep confirmed), `/home/nastralis/.local/bin/il-doctor` contains the crash-loop check with the reworded PASS message (grep confirmed, no `crash-loop` substring in the pass path), `/home/nastralis/.local/bin/il-repro` contains `mode_cursor_crash_loop` wired into both the CLI case dispatch and `mode_all`. `sh -n` re-run clean on all three at commit time. `il-repro --all` re-run 4 times while writing this SUMMARY: 87/0, 86/0, 79/8, 86/0 (ok/failed) — `--cursor-crash-loop`'s own 6 assertions green in every run, the 8 FAILs in the one flaky run confirmed by name to be the pre-existing pointer-motion-probe confound in `--stress`/`--retry-forced`/`--selfcheck-rescue`, not in any file this plan touched. `il-doctor` re-run 3 times: 22 ok / 0 failed every time, exit 0. `~/.dotfiles` working tree clean before this commit (`git status --porcelain` empty). `il-side-watch.service` active, `$XDG_RUNTIME_DIR/il-side` = `mac` (a real value, updated by the last `--all` re-run's own sub-modes). `$XDG_RUNTIME_DIR/ilhop-debug.on` present.
