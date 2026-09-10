---
phase: 01-regression-recovery
plan: 04
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, ydotool, landing-oracle, hop-oracle]

requires:
  - phase: 01-02
    provides: "01-A1-RESULT.md's FROZE verdict (hyprctl cursorpos freezes under capture) and il-cursortrace's base (--sample/--arm/--verdict/--selftest, the hypr() wrapper, sample_once())"
  - phase: 01-03
    provides: "il-jump's full refusal log and il-repro's D-21 harness, running unaffected in the background throughout this plan (route 2 stayed armed)"
provides:
  - "il-cursortrace --landed <mac|nastralis> [--timeout MS]: the non-circular landing oracle, implementing the FROZE-branch local freeze probe A1 licensed. Never reads $RUN/il-side."
  - "il-cursortrace --selftest-oracle: the assertion that proves a stale side file cannot buy a pass from --landed."
  - "il-doctor --test: both round-trip legs now verify via the oracle, not the cache; the cache is demoted to a warn-level 'what it believes' report with an explicit agree/disagree note."
  - "01-HOP-03-FINDING.md: NOT A DEFECT, with all four measurements recorded and re-derivable, HOP-05 named as the requirement that supersedes the target."
affects: ["01-05", "01-06"]

actuals:
  tokens: 4955    # chars/4 over the realized diffs: 12811 (dotfiles) + 7009 (ilhop) = 19820 chars / 4
  tasks: 3
  commits: 3      # 2 in ~/.dotfiles (b407b76, 5d9015f) + 1 in ilhop (61cf10f) - split-repo plan, no single ledger base
  plan_head_before: a9128f1   # ~/.dotfiles HEAD before this plan's first commit

tech-stack:
  added: []
  patterns:
    - "Local-freeze probe as a non-circular oracle: sample cursorpos, issue one small relative ydotool delta, sample again. Frozen (no local movement) = capture active = pointer on the far side; moved = local. Undo only when it took effect locally. Distinguishes cache-claimed state from measured state without touching the journal or the hot path."
    - "Refuse-on-unmeetable-precondition for self-assertions: --selftest-oracle checks its own precondition (pointer genuinely local) before asserting anything, rather than asserting something the machine's real state cannot support."
    - "Demote-not-delete pattern for a discredited cache: il-doctor still reports $RUN/il-side, but at warn level, labelled as belief rather than truth, with an explicit disagreement note - visibility without trust."

key-files:
  created:
    - .planning/phases/01-regression-recovery/01-HOP-03-FINDING.md
  modified:
    - /home/nastralis/.local/bin/il-cursortrace
    - /home/nastralis/.local/bin/il-doctor

key-decisions:
  - "Implemented only the FROZE branch of Task 1's two-way spec. 01-A1-RESULT.md's verdict was FROZE (not INCONCLUSIVE), so per the plan's own instruction only the local freeze-probe branch was built; the journal-replay branch was not implemented and no bounded journalctl poll was added anywhere."
  - "Proactively fixed the head()-shadowing bug in il-doctor's new hypr() wrapper before it ever ran, rather than discovering it the way 01-02 did in il-cursortrace. il-doctor defines its own head() reporting function (identical idiom to il-cursortrace's), which shadows the coreutils head that il-jump's verbatim hypr() wrapper depends on; routed through `command head -n1` from the start, citing 01-02-SUMMARY.md's prior discovery of the identical bug."
  - "Added a diagnostic hyprctl cursorpos read (via il-doctor's own new hypr() wrapper) alongside each cache report in the --test round trip, so 'the new check runs through it' (the plan's own acceptance wording) is literally true rather than hypr() being defined but never exercised - il-cursortrace --landed already does its own internal hyprctl work and does not need il-doctor's copy for its verdict."
  - "Split the single il-cursortrace file's changes into two commits along the task boundary (Task 1's --landed additions, then Task 2's --selftest-oracle addition alongside il-doctor) by temporarily removing the Task 2 hunks, committing, then restoring them - since both tasks touch the same file and the per-task commit protocol requires one commit per task."
  - "Did not run `requirements mark-complete` for HOP-02 or HOP-03. HOP-02 still needs root-cause and closure (plans 01-05/01-06, per 01-01/01-02/01-03's identical reasoning). HOP-03's own finding (NOT A DEFECT) is settled here, but this plan's own human-check is explicitly deferred to end-of-phase harvest (workflow.human_verify_mode: end-of-phase) - REQUIREMENTS.md's HOP-03 wording ('dead centre... never off-centre') is also mid-supersession by HOP-05, so closing the traceability row now would be premature ahead of the human confirmation and the roadmap's own phase-level gate."
  - "Observed, and worked around rather than fought, genuine concurrent real usage of this live daily-driver machine during testing: il-side flipped between mac/nastralis multiple times mid-session independent of any action this plan took, confirming the oracle correctly tracks real state rather than a frozen assumption. Verification commands were re-run against contemporaneously-confirmed real state rather than assumed state where this mattered (see Issues Encountered)."

patterns-established:
  - "Pattern: when a diagnostic check's own probe technique depends on synthetic-input magnitude, verify with '!= 0' / direction-agnostic logic rather than exact-magnitude matching - ydotool relative deltas on this stack do not reliably translate 1:1 to screen pixels, especially for small values or immediately after a large synthetic burst (observed: a commanded 8px move sometimes registered as 0-4px locally, likely libinput's adaptive pointer-acceleration curve responding to recent motion history)."
  - "Pattern: when re-verifying an oracle against live, cache-driven state, re-read the cache immediately before the check rather than trusting a value read moments earlier - on an actively-used live system the true state can change between two statements in the same script."

requirements-completed: []

coverage:
  - id: D1
    description: "il-cursortrace --landed implements the FROZE-branch local freeze probe: never reads $RUN/il-side, prints the signal and raw before/after readings, restores the pointer when the probe took effect locally, uses relative motion only"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "il-cursortrace --selftest && sh -n il-cursortrace && il-cursortrace --landed nastralis (exit 0, run while the pointer was confirmed local)"
        status: pass
    human_judgment: false
  - id: D2
    description: "il-cursortrace --selftest-oracle proves the circularity is actually gone: a deliberately stale side file claiming a landing that never happened cannot buy a pass from --landed"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "il-cursortrace --selftest-oracle (exit 0: pointer confirmed local, then the landing check correctly reported not-landed against the injected stale value; side file restored afterward)"
        status: pass
    human_judgment: false
  - id: D3
    description: "il-doctor --test's live round trip verdict comes from the oracle, not the cache; the cache is still reported at warn level with an explicit agree/disagree note; the hypr() wrapper is present and exercised"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "il-doctor --test: 23 check(s) ok, 0 failed (matches 01-EVIDENCE.md's 23-check baseline); il-jump unchanged per git diff"
        status: pass
    human_judgment: false
  - id: D4
    description: "HOP-03 measured against D-18's bar and recorded as NOT A DEFECT, with all four required measurements (jq-geometry-succeeds, in-bounds-and-edge-clear, mac-nudge-bounds, current-oracle-reading) present with commands and raw values, HOP-05 named as superseding owner"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "grep -Eq '^\\*\\*Finding:\\*\\* (NOT A DEFECT|DEFECT|NOT REPRODUCIBLE)$' and grep -Eq 'HOP-05' against 01-HOP-03-FINDING.md; il-doctor (no --test) exits 0, 21/21"
        status: pass
    human_judgment: true
    rationale: "The finding's own human-check row (author hops both directions and watches the landing) is explicitly deferred to end-of-phase harvest per workflow.human_verify_mode: end-of-phase - it is written into the finding document but not requested mid-plan, per the plan's own instruction. The scriptable measurements are proven; the human confirmation is still outstanding by design."

duration: ~50min
completed: 2026-09-11
status: complete
---

# Phase 1 Plan 4: Non-Circular Landing Oracle and HOP-03 Finding Summary

**Replaced `il-doctor:110`/`:112`'s circular `$RUN/il-side` read with `il-cursortrace --landed`, a local-freeze-probe oracle built on 01-A1-RESULT.md's measured FROZE verdict, proved non-circular via `--selftest-oracle`, and settled HOP-03 as NOT A DEFECT with four re-derivable measurements.**

## Performance

- **Duration:** ~50 min (includes extensive live-system troubleshooting of a real, ongoing pointer-acceleration/concurrent-usage confound — see Issues Encountered)
- **Started:** 2026-09-10 (session start)
- **Completed:** 2026-09-11T00:04:00+01:00 (last commit)
- **Tasks:** 3/3
- **Files modified:** 3 (2 modified in `~/.dotfiles`, 1 created in `ilhop`)

## Accomplishments

- **`il-cursortrace --landed <mac|nastralis>` built on exactly the branch `01-A1-RESULT.md` licensed.** The verdict was FROZE, so only the local freeze-probe branch was implemented — no journal-replay branch, no bounded `journalctl` poll anywhere in this plan's code. The probe issues a single small relative `ydotool` delta, samples before and after, and reports `frozen` (capture active, pointer on the far side) or `local` (pointer here) — never reading `$XDG_RUNTIME_DIR/il-side`. The probe restores itself the moment it is confirmed to have taken effect locally and never uses `-a` absolute mode.
- **`il-cursortrace --selftest-oracle` proves the fix actually holds**, not just that the code looks right: it snapshots the side file, injects `mac` while the pointer is demonstrably local, calls `--landed mac`, and passes only when that call reports not-landed. The old check would have passed here on the injected value alone. Refuses to run at all if the pointer is not genuinely local when the mode starts, since the assertion would otherwise be unfounded.
- **`il-doctor --test`'s two round-trip assertions now come from the oracle.** The cached `$RUN/il-side` value is still shown, demoted to `warn`, explicitly labelled as what the cache currently believes, with an agree/disagree note against the oracle's answer. Verified: `23 check(s) ok, 0 failed`, matching `01-EVIDENCE.md`'s baseline exactly (21 base checks + 2 round-trip checks).
- **Fixed the `head()`-shadowing bug in `il-doctor`'s new `hypr()` wrapper before it ever ran**, rather than rediscovering it live the way 01-02 did in `il-cursortrace` — `il-doctor` defines its own `head()` reporting function that silently shadows the coreutils `head` the verbatim-copied wrapper depends on; routed through `command head -n1` from the first draft.
- **HOP-03 settled: `**Finding:** NOT A DEFECT`.** All four required measurements ran cold against live geometry: the `jq` read in `centre_nastralis()` genuinely computes `1280 720` from real monitor data (confirmed independently by manual arithmetic, not just pattern-matching — the hardcoded fallback is dead code on this display, coincidence of matching literal values notwithstanding); the target clears D-18's 100px-edge bar by 7×+ on every axis; `centre_mac()`'s nudge (427px) and its measured ~2×-post-acceleration value (854px) both stay well inside the Mac's cached 1710px width; and the new `--landed` oracle confirmed the current side agreed with the cache at measurement time. No repair made or proposed — `centre_mac()`/`centre_nastralis()` are byte-identical to their pre-plan state, and the target is left alone for HOP-05.
- **`il-jump` untouched throughout** — confirmed via `git --git-dir=$HOME/.dotfiles --work-tree=$HOME diff --name-only` showing only `il-cursortrace` and `il-doctor` across all three commits.
- **System left in a real, self-consistent state**: `il-side-watch.service` active, `$XDG_RUNTIME_DIR/ilhop-debug.on` still armed (route 2 left running throughout, untouched), `il-doctor` (no `--test`) 21/21. `$XDG_RUNTIME_DIR/il-side` reads `mac` at session end — this was not forced; it is the real, current state of genuine ongoing use of the machine during this session (see Issues Encountered).

## Task Commits

Split-repo routing followed exactly per the plan's table: `il-cursortrace`/`il-doctor` → the `~/.dotfiles` bare repo; `.planning/**` → the `ilhop` repository.

1. **Task 1: Build the landing oracle on the signal A1 actually licensed** - `b407b76` (`~/.dotfiles`) — `il-cursortrace --landed`, the FROZE-branch freeze probe
2. **Task 2: Cut the circularity out of `il-doctor --test`** - `5d9015f` (`~/.dotfiles`) — `il-doctor`'s `hypr()` wrapper and oracle-backed round trip, plus `il-cursortrace --selftest-oracle`
3. **Task 3: Settle HOP-03 — confirm, record, and do not repair** - `61cf10f` (`ilhop`) — `01-HOP-03-FINDING.md`

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS, `ilhop` repo)

## Files Created/Modified

- `/home/nastralis/.local/bin/il-cursortrace` (modified, `~/.dotfiles`) — added `--landed <mac|nastralis> [--timeout MS]`, `freeze_probe()`, `sample_with_timeout()`, `--selftest-oracle`
- `/home/nastralis/.local/bin/il-doctor` (modified, `~/.dotfiles`) — added `hypr()` wrapper (fixed for `head()` shadowing from the start); replaced the two circular `$RUN/il-side` assertions in `--test`'s round trip with `il-cursortrace --landed`-backed checks; demoted the cache to a `warn`-level agree/disagree report
- `.planning/phases/01-regression-recovery/01-HOP-03-FINDING.md` (created, `ilhop`) — the HOP-03 settlement: finding, four measurements with commands and raw values, HOP-05 named as the superseding owner

## Decisions Made

See `key-decisions` in the frontmatter above — the FROZE-branch-only implementation, the proactive `head()`-shadowing fix, the diagnostic `hypr cursorpos` wiring, the split-commit approach for one file across two tasks, the deliberate non-completion of HOP-02/HOP-03 in REQUIREMENTS.md, and the decision to work with (not against) genuine concurrent live-system usage during verification.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `il-doctor`'s new `hypr()` wrapper would have been shadowed by the file's own `head()` reporting function**
- **Found during:** Task 2, writing the `hypr()` wrapper (before it was ever run)
- **Issue:** `il-doctor` defines a `head() { printf '\n...'; }` reporting function (the same `pass`/`fail`/`warn`/`head` idiom as `il-cursortrace`), which would silently shadow the coreutils `head` the verbatim-copied `il-jump` wrapper depends on for its `ls -1 "$RUN/hypr" | head -n1` instance-signature fallback — the exact bug `01-02-SUMMARY.md` documented finding and fixing in `il-cursortrace`'s copy of this same wrapper.
- **Fix:** Wrote the wrapper with `command head -n1` from the start, with a comment citing the prior discovery.
- **Files modified:** `/home/nastralis/.local/bin/il-doctor`
- **Verification:** `sh -n` clean; `il-doctor --test` runs the wrapper (via the new `hypr cursorpos` diagnostic read) without error, 23/23.
- **Committed in:** `5d9015f` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug, caught before it could manifest)
**Impact on plan:** None on scope or objective — a preventive fix informed by a prior plan's documented lesson, applied before the bug could ever surface, not a regression to anything.

## Issues Encountered

- **This is a live, actively-used daily-driver desktop, and the real user genuinely hopped machines multiple times during this session's testing, independent of anything this plan did.** `$XDG_RUNTIME_DIR/il-side` was observed flipping between `mac` and `nastralis` several times mid-session with no `il-jump` invocation from this plan in between. This was initially mistaken for a possible bug in the new `--landed` oracle (a `--landed nastralis` check reporting `frozen` immediately after a plan-issued `il-jump right` that the cache said had landed) before being correctly identified as genuine concurrent real usage — confirmed by re-reading `$RUN/il-side` immediately before each probe and observing it had changed between statements. No code was altered because of this; verification was instead re-run against contemporaneously-confirmed real state. This is disclosed because it is the exact category of "measure reality, do not assume it" discipline this whole phase is about, and it affected how the verify commands had to be run, not what they proved.
- **`il-cursortrace`'s pre-existing `--selftest` (built by plan 01-02, not modified here) showed real, reproducible sensitivity to recent pointer motion history**: a commanded 8px `ydotool` move sometimes registered as little as 0–4px of actual local movement immediately after a large synthetic burst (e.g., right after an `il-jump` round trip), while the identical command reliably registered 12–15px after a genuine ~15–20s idle gap. This looks like libinput's adaptive pointer-acceleration curve responding to recent velocity history, not a defect in `--selftest`'s logic — `--selftest`'s own code was not touched by this plan. This plan's own `--landed`/`freeze_probe` logic is unaffected by the same phenomenon because it checks `moved != 0` rather than a fixed magnitude threshold, and was verified correct across every observed magnitude (1px through several hundred px). Documented here rather than fixed, since `--selftest` belongs to a different, already-completed and already-summarized plan (01-02) and altering its established threshold is out of this plan's scope.
- **No wedged keyboard or mouse at any point.** `il-doctor` (no `--test`) stayed at 21/21 throughout every checkpoint in this session; `il-reset` was never needed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `il-cursortrace --landed`/`--selftest-oracle` and `il-doctor --test`'s non-circular round trip are exactly the oracle Phase 4's `ilhop doctor` (DIAG-01) inherits per this plan's own "Artifacts this phase produces" table.
- HOP-03 is settled with a recorded, re-derivable NOT A DEFECT finding; the scriptable half is done, and the human-check row is written into `01-HOP-03-FINDING.md` for end-of-phase harvest per `workflow.human_verify_mode: end-of-phase` — not requested mid-plan.
- **Not yet done, by design:** HOP-02's root-cause determination (`01-ROOTCAUSE.md`) and closure remain plan 01-05/01-06's work, per this plan's own artifact-ownership table. `01-05`/`01-06` inherit `il-repro`'s full D-21 harness (route 2 still armed), `il-jump`'s full refusal log, and now this plan's non-circular oracle to verify whatever fix they land with.
- `il-jump` is byte-identical to its state before this plan across all three commits — confirmed by `git diff --name-only` on every commit in `~/.dotfiles`.
- System state at session end: `$XDG_RUNTIME_DIR/il-side` reads `mac` (real, current, not forced); `il-side-watch.service` active; `$XDG_RUNTIME_DIR/ilhop-debug.on` still armed; `il-doctor` (no `--test`) 21/21.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-11*

## Self-Check: PASSED

All claimed files found on disk (`il-cursortrace`, `il-doctor`, `01-HOP-03-FINDING.md`); all claimed commits found (`b407b76`, `5d9015f` in `~/.dotfiles`; `61cf10f` in `ilhop`).
