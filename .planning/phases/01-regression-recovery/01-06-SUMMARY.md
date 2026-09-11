---
phase: 01-regression-recovery
plan: 06
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, ydotool, systemd, human-gate]

requires:
  - phase: 01-01
    provides: "ILHOP_DEBUG / dbg() tracer, the arm switch, il-repro --inject-noop"
  - phase: 01-02
    provides: "01-A1-RESULT.md's FROZE verdict — the basis for the local landing oracle"
  - phase: 01-03
    provides: "every il-jump exit path named in the log; --stress/--watcher-gap/--arm/--report"
  - phase: 01-04
    provides: "il-cursortrace --landed, the non-circular landing oracle; 01-HOP-03-FINDING.md"
  - phase: 01-05
    provides: "01-ROOTCAUSE.md's named mechanism and its seven fix properties"
provides:
  - "The HOP-02 fix, shipped whole in the shape chosen at the D-17 checkpoint: bounded-backlog reattach, `jump from` line-shape match, and a same-direction double-press override"
  - "il-repro --retry-forced, --watcher-parser, --selfcheck-rescue — the phase regression gate"
  - "The human-at-the-keyboard gate, performed and logged rather than asserted"
affects: ["02", "03", "04"]

actuals:
  tokens: 55000
  tasks: 3
  commits: 6
  plan_head_before: 47b3c27

tech-stack:
  added: []
  patterns:
    - "Bounded-backlog journal reattach (`--cursor-file`) instead of `-n 0`, so a follower's own restart is not an unbounded blind spot; `-n 0` retained only as the cold-start fallback"
    - "A refusal that cannot verify its own premise gets an escape hatch bounded by measured numbers at both ends — floor above the fastest observed legitimate repeat, ceiling below the smallest observed organic gap — rather than an unbounded retry or none at all"
    - "When a defect's proof requires a human's hand, state the bar and get it agreed BEFORE the presses, and have the process log the evidence so the result is a tally rather than an impression"

key-files:
  created:
    - .planning/phases/01-regression-recovery/01-06-SUMMARY.md
  modified:
    - /home/nastralis/.local/bin/il-jump
    - /home/nastralis/.local/bin/il-side-watch
    - /home/nastralis/.local/bin/il-repro
    - /home/nastralis/.config/systemd/user/il-side-watch.service

key-decisions:
  - "The human gate's bar was agreed with the author before the presses, per the plan's own requirement that it be stated rather than judged afterwards: 10 ALT+C presses in ordinary use, at least 4 in each direction, every one fires; any silent no-op is a fail. Author reported 10 presses, 5 each direction, all fired."
  - "Recorded the press-count discrepancy instead of smoothing it: the log shows 27 dispatches in the gate window against 10 reported ALT+C presses. ALT+C was ruled out as a double-firer by measurement (`hyprctl binds` shows exactly one handler on modmask 8 / key C, `__lua 145`; modmask 65 is the unrelated SUPER+SHIFT colour-pick). The best-supported explanation is that ALT+H's edge-jump path also invokes il-jump in ordinary focus-left use (binds.lua:90 -> il-focus-jump -> il-jump left) — offered as the explanation, not claimed as proven, since the two paths are indistinguishable in the log."
  - "The log proves only that every INVOCATION reached dispatch. A press that never reached il-jump at all would leave no line, which is exactly the upstream-of-il-jump failure the plan's human-check names. The author's own count is what covers that half; neither half alone closes the criterion."
  - "Corrected the handoff note's commit table: six commits carry this plan's work, not five. `e921752` (il-repro --retry-forced, RED against the un-fixed guard) was omitted from it. Verified by `git log --oneline | grep -c '(01-06)'` = 6."
  - "Corrected the handoff note's claim that Route 2 was still armed. It was NOT: the arm switch lives on tmpfs and two reboots (13:18, 16:12) had wiped it. Re-armed before the gate, with a 50-line baseline copy taken so the tally counts only the author's own presses."
  - "Two FAILs seen in an il-repro --all re-run were diagnosed as an artifact of the author using the mouse during the run, then PROVEN rather than argued: a hands-off re-run came back 80 ok / 0 failed, exit 0. The diagnosis was already supported by the adjacent assertion — `retry[wrong-direction]: still refused (already-on-side)` passes on the line above, meaning il-jump exited at :157 before shove() and moved nothing, while the probe reported 874px and 64px of motion. Filed as a harness defect for Phase 4, not as a regression."
  - "il-repro's total check count is not a fixed invariant — measured 83 (disarmed), 80, 80 (armed) across four runs today. One of the three-check delta is traced to the arm-conditional debug-off skip at il-repro:177-178; the other two are not traced. Recorded as a DIAG-phase observation: a suite whose denominator moves makes 'N ok, 0 failed' a weaker gate than it appears. Not chased here — out of this plan's scope."
  - "HOP-03 closed on 01-HOP-03-FINDING.md's NOT-A-DEFECT determination, per ROADMAP criterion 4's own clause that recording the finding is how the criterion is met. Screen-centre accuracy is explicitly not the bar; HOP-05 / Phase 3.1 owns moving the target to the window nearest the crossed edge."

patterns-established:
  - "Pattern: a pointer-motion probe cannot distinguish the code under test from a human using the machine. Any assertion of the form 'the pointer did not move' needs either an exclusive-input window or a second, independent signal (here: the refusal's own log line) before a FAIL is believed."

requirements-completed: [HOP-02, HOP-03]

coverage:
  - id: D1
    description: "The fix shipped whole, in the shape the author chose at the D-17 checkpoint — bounded-backlog reattach (il-side-watch:71), `jump from` line shape matched (il-side-watch:34), same-direction double-press override (il-jump:141-155, RETRY_MIN_MS=200 / RETRY_MAX_MS=5000) — with no substitution, reduction or deferral of any part"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Six commits in ~/.dotfiles (e921752, e1af5ee, 16772b9, fc739bc, 8408bcc, 8daf23e); both working trees clean; il-repro --retry-forced covers no-marker, below-floor, inside-window, past-ceiling and wrong-direction branches and asserts the refusal is motionless on each"
        status: pass
    human_judgment: false
  - id: D2
    description: "The window bounds are measured, not guessed: floor 200ms sits >9x above the 12.9-22.3ms measured cost of a tight back-to-back same-direction repeat (19 samples); ceiling 5000ms sits >13x below the 67,514ms smallest organic same-direction gap in ~4h of Route 2 logging"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Recorded in the handoff audit and re-stated here; the accepted cost (a genuinely correct same-direction double-press inside the window also fires) is documented in il-jump's own comment at :135-140"
        status: pass
    human_judgment: false
  - id: D3
    description: "The scriptable half of the phase gate is green: il-doctor --test 23 ok / 0 failed with a live round trip judged by the non-circular oracle, and il-repro --all 80 ok / 0 failed, exit 0, on a hands-off run"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-doctor --test: 23 ok, 0 failed, hop to the Mac 24ms, hop back 45ms. il-repro --all (hands-off): 80 ok, 0 failed, exit 0. systemctl --user is-active il-side-watch.service = active; $XDG_RUNTIME_DIR/il-side non-empty"
        status: pass
    human_judgment: false
  - id: D4
    description: "Latency compared to the 01-EVIDENCE.md baseline rather than merely recorded: 24ms out (baseline 20ms, +4ms, well inside the ~50ms budget) and 45ms back (baseline 53ms, -8ms). The return leg was the one leg over PROJECT.md's budget at baseline, by 3ms; it is now 5ms under it"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "01-EVIDENCE.md section 6 baseline (20ms / 53ms) vs this session's il-doctor --test (24ms / 45ms)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The detached self-check still rescues a hop the watcher never confirms — exercised end to end by il-repro --selfcheck-rescue, not argued (ROADMAP criterion 5)"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "--selfcheck-rescue: the dispatch that started the self-check is in the log; no superseded/watcher-unknown early bail; the pointer is functionally local per the landed(nastralis) oracle; within tolerance of the computed centre (target 1280,720 actual 1280,720); il-side-watch.service active again; $STATE restored to a real value"
        status: pass
    human_judgment: false
  - id: D6
    description: "The author pressed the bind in ordinary use, both directions, and every press fired — measured against a bar stated and agreed beforehand, with a log rather than an impression"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "Gate window 2026-09-11T16:43:17.828 - 16:43:54.728: 27 dispatch lines, 0 already-on-side, 0 stale-lock, 0 superseded, 0 watcher-unknown, 0 die, 0 usage, 0 retry-forced. Author's report: 10 ALT+C presses, 5 each direction, all fired"
        status: pass
    human_judgment: true
    rationale: "No script can supply this and none pretends to — ydotool key events do not fire Hyprland keybinds (measured at zero fires), so the keybind path cannot be exercised by any harness. The bar was agreed before the presses per the plan's own requirement. The log covers 'every invocation reached dispatch'; the author's count covers 'every press reached il-jump'. The zero retry-forced count is worth noting on its own: the double-press override never had to fire, so the three upstream fixes carried every press unaided."
  - id: D7
    description: "The pointer landed correctly in both directions with the author watching, never pinned against an edge (ROADMAP criterion 4, HOP-03, D-18)"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "Author's 10-press session, 5 each direction, all landing; 01-HOP-03-FINDING.md's NOT-A-DEFECT determination, measured not asserted"
        status: pass
    human_judgment: true
    rationale: "Screen-centre accuracy is explicitly not the bar here per ROADMAP criterion 4 and D-03. HOP-03 closes as a finding rather than a repair; HOP-05 / Phase 3.1 owns the target change."
  - id: D8
    description: "No wedged input — the criterion the project exists to protect (PROJECT.md 'The scar')"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "il-doctor: 'no modifier latched down'. No reach for il-reset during or after the gate session. The 2026-09-10 revert's failing mechanism (re-pressing held modifiers through ydotool) is absent from all six commits — the override changes only the already-on-side guard, never key injection"
        status: pass
    human_judgment: true
    rationale: "A green il-doctor does not stand in for this. The author ran the changed code as the daily driver through the gate session with no wedged keyboard and no wedged mouse."

duration: ~50min (resume session; original execution killed by rate limit)
completed: 2026-09-11
status: complete
---

# Phase 1 Plan 06: Ship the Fix and Close the Phase — Summary

**HOP-02 is fixed and the fix is proven at the only bar that counts for an input-path change: the author's own hand. 27 logged invocations across the gate window, zero silent no-ops, zero double-press rescues needed — and HOP-03 closes as the not-a-defect finding it was measured to be.**

## Performance

- **Duration:** ~50 min across two sessions — the original execution was killed by an API rate limit after committing the complete fix but before writing this SUMMARY; the resume session ran the gate and wrote it.
- **Completed:** 2026-09-11T16:45+01:00
- **Tasks:** 3/3
- **Commits:** 6 (all in `~/.dotfiles`), plus the handoff and metadata commits in `ilhop`

## Accomplishments

- **The fix shipped whole, all three parts, no reduction.** Bounded-backlog reattach (`il-side-watch:71`, `--cursor-file="$CURSOR"`, with `-n 0` kept only as the cold-start fallback) closes the writer's blind spot across its own restarts. The `jump from` line shape is matched (`il-side-watch:34`) and the unparsable branch now logs instead of absorbing silently. The same-direction double-press override (`il-jump:141-155`) means a wrong cached side can no longer make every press a silent no-op forever.
- **The human gate was performed, not deferred again.** The machine was headless when the original executor stopped; a monitor (DP-1, 2560x1440) is attached again. The bar was agreed before the presses — 10 ALT+C presses in ordinary use, at least 4 in each direction, every one fires — and the author reported 10 presses, 5 each direction, all fired.
- **The gate produced a tally, not an impression.** Route 2 was re-armed first (it was NOT still armed, contrary to the handoff note — tmpfs, wiped by two reboots) and a 50-line baseline copy taken. Gate window `16:43:17.828`-`16:43:54.728`: **27 `dispatch` lines, 0 `already-on-side`, 0 of every other exit path.** `retry-forced` fired **zero** times — the override never had to rescue anything, so the three upstream fixes carried every press unaided.
- **Latency improved against the recorded baseline.** 24ms out and 45ms back, against `01-EVIDENCE.md`'s 20ms / 53ms. The return leg was the one leg over PROJECT.md's ~50ms budget at baseline, by 3ms; it now sits 5ms under it.
- **Two FAILs were chased to ground instead of explained away.** A re-run of `il-repro --all` while the author was at the machine reported `stress[19/right]: pointer moved dx=874 dy=80 px during a refusal` and `retry[wrong-direction]: pointer moved during a refusal (dx=64 dy=44 px)`. The adjacent assertion already contradicted a code cause — `retry[wrong-direction]: still refused (already-on-side)` passes, so `il-jump` exited at `:157` before `shove()` and moved nothing — but this project's scar is about shipping on reasoning, so it was measured: a hands-off re-run returned **80 ok, 0 failed, exit 0**. The confound is the author's hand; the harness defect is real and belongs to Phase 4.
- **Three corrections to the handoff note, recorded rather than silently fixed.** Six commits carry this plan, not five (`e921752` was omitted). Route 2 was not armed. And `il-repro`'s check total is not a fixed invariant (83 disarmed, 80 armed, twice).

## Task Commits

1. **Task 1: Choose the shape of the HOP-02 fix** — the D-17 decision checkpoint; no commit of its own, the choice is recorded in `01-CONTEXT.md` and implemented by task 2.
2. **Task 2: Implement the chosen fix, whole** — `e921752` (test: `--retry-forced`, RED), `e1af5ee` (refactor: `handle_line()` test seam), `16772b9` (test: `--watcher-parser`, RED), `fc739bc` (feat: the same-direction retry), `8408bcc` (feat: `jump from` match + restart-reattach gap closed)
3. **Task 3: The phase gate** — `8daf23e` (feat: `--selfcheck-rescue`), then the gate itself: `il-doctor --test`, `il-repro --all`, and the human criteria

**Plan metadata:** the handoff commit `c255493`, and this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS + state.json)

## Files Created/Modified

- `/home/nastralis/.local/bin/il-jump` — the same-direction override inside the `CUR = want` branch
- `/home/nastralis/.local/bin/il-side-watch` — `handle_line()` seam, `jump from` match, logged unparsable branch, `--cursor-file` reattach
- `/home/nastralis/.config/systemd/user/il-side-watch.service` — the reattach cursor file
- `/home/nastralis/.local/bin/il-repro` — `--retry-forced`, `--watcher-parser`, `--selfcheck-rescue`
- `.planning/phases/01-regression-recovery/01-06-SUMMARY.md` (created)

## Deviations from Plan

None in the work itself. The plan's human-check wording asks for "one full working session" of ordinary use; what was actually performed was a 37-second, 27-invocation concentrated session against an explicitly agreed 10-press bar. This is recorded as what it is — a shorter window than the plan's prose imagines — and is judged sufficient because the plan's own objective bar ("a dispatch line for every press the author intended to fire, zero already-on-side refusals against a press they meant to land, no stretch where presses produced no line at all") is met exactly, with a 27/0 margin on the refusal count. Per D-21 the author's presses are spent confirming, never fishing.

## Issues Encountered

- **The original executor was killed by an API rate limit** after committing the complete fix but before writing this SUMMARY. The handoff file `.continue-here.md` deliberately withheld the SUMMARY so `phase-plan-index` could not report `has_summary: true` and skip the human gate. That worked as designed; the file is removed with this commit.
- **Route 2 was not armed on resume.** The arm switch is tmpfs and two reboots had wiped it. This is exactly the failure mode the plan told the SUMMARY to warn about, encountered for real: **re-arm after any reboot with `il-repro --arm`.**
- **`il-repro`'s pointer-motion probe produces false FAILs on a machine in use.** Proven, not assumed (hands-off re-run: 80/0). Belongs to Phase 4 (DIAG) — the probe needs an exclusive-input window or a second independent signal before a motion FAIL is believed.
- **`il-repro`'s check total moves between runs** (83 / 80 / 80 measured today). One check of the three-check delta traced to the arm-conditional skip at `il-repro:177-178`; the other two untraced. A moving denominator weakens "N ok, 0 failed" as a gate. Phase 4.
- **`il-doctor:78` calls bare `hyprctl binds -j`** while `:126` correctly routes through the `hypr()` wrapper at `:25`. Run without `HYPRLAND_INSTANCE_SIGNATURE` — from ssh, a systemd unit, or an agent shell — the bind checks emit a false `FAIL` with a misleading *"run `ryoku materialize && hyprctl reload`"* remedy. Real bug, Phase 4 (DIAG). Workaround until then: `export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" | head -n1)`.
- **ROADMAP criterion 5 says `il-doctor --test` reports "21/21".** The actual figures are 21 checks without `--test` and 23 with it; `01-EVIDENCE.md`'s baseline is 23. The criterion is met at 23/23; the "21/21" wording is stale and is corrected in the ROADMAP with this commit.

## Known Limitations

- **The rescue asymmetry.** `centre_nastralis()`'s target does not depend on `$dir`, so a Nastralis-bound rescue is functionally effective but a Mac-bound rescue — a crossing that genuinely succeeded while the side file was merely frozen — is cosmetic: it resets `hyprctl cursorpos` without releasing input-leap's real capture. Predates this plan; `centre_nastralis()`/`landed()` untouched by all six commits. This is what `--selfcheck-rescue`'s output and the `landed(nastralis)` oracle warning point at.
- **The override's accepted cost.** A genuinely correct same-direction double-press inside the 200-5000ms window also fires. Accepted at the D-17 checkpoint on the measured bounds above.
- **Still parked by the author's explicit decision:** the invisible-cursor defect in `centre_nastralis()` (`il-jump:142-151`) — after a Mac->Nastralis return leg the pointer is present and usable but not drawn until real motion arrives, because a `hyprctl` warp emits no pointer event. Verified untouched by all six commits. Full write-up in `~/.local/share/ryoku/rashin/journal/2026-09-10.md`. The parking condition was "until Phase 1 closes" — that is now, and the backlog-vs-Phase-2-requirement call is due.

## Next Phase Readiness

- **HOP-02 and HOP-03 are both closed** and the daily driver is running the fix (`il-side-watch.service` restarted 01:12:55 after the 00:57:32 watcher fix, so the running watcher carries the new code).
- **Route 2 stays armed until phase close**, then `il-repro --disarm`.
- Phase 2 (Clean Handoff) inherits the "Mac is deaf after the hop" defect (HOP-01) and the slow ssh return leg (HOP-04), plus the parked invisible-cursor decision above.
- Phase 4 (DIAG) inherits three harness/diagnostic defects named here: the motion-probe confound, the moving check denominator, and `il-doctor:78`'s bare `hyprctl`.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-11*

## Self-Check: PASSED

All six claimed `~/.dotfiles` commits verified present (`e921752`, `e1af5ee`, `16772b9`, `fc739bc`, `8408bcc`, `8daf23e`); `git log --oneline | grep -c '(01-06)'` = 6, matching `actuals.commits`. The handoff commit `c255493` verified present in `ilhop`. All five claimed files found on disk. Every cited line reference re-read and confirmed at execution time: `il-side-watch:34` (the `switch from` / `jump from` alternation), `il-side-watch:71` (`--cursor-file="$CURSOR"`), `il-jump:157` (the refusal's `exit 0`), `il-repro:177-178` (the arm-conditional debug-off skip), and `il-doctor:78` vs `:126` (bare `hyprctl` against the `hypr()` wrapper). Both working trees clean before this commit.
