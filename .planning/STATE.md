---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: 01
current_phase_name: Regression Recovery
status: verification-gaps
stopped_at: Phase 01 verified — gaps_found (5/6), CR-01 gap plan owed
last_updated: "2026-09-11T16:50:00.000Z"
last_activity: 2026-09-11
last_activity_desc: Phase 01 executed and human-gated; verifier found 1 gap (CR-01) — phase stays open
state_head: c5cfeb92e62276041e4b80ed4c9c14dedff5a126
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 6
  completed_plans: 6
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Pressing the hop key always lands you on the other machine, ready to type, with no lost keystroke and no wedged input device.
**Current focus:** Phase 01 — Regression Recovery

## Current Position

Phase: 01 (Regression Recovery) — GAPS FOUND
Plan: 6 of 6 executed; 1 gap-closure plan owed
Status: Verifier returned gaps_found (5/6). Phase stays OPEN until CR-01 closes.
Last activity: 2026-09-11 — code review + verifier both ran; both land on CR-01

Progress: [█░░░░░░░░░] 0 of 6 phases complete (Phase 01 at 6/6 plans, 5/6 must-haves)

## Performance Metrics

**Velocity:**

- Total plans completed: 6
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 15min | 3 tasks | 3 files |
| Phase 01 P02 | ~20min | 3 tasks | 2 files |
| Phase 01 P03 | 35min | 2 tasks | 2 files |
| Phase 01 P04 | 50min | 3 tasks | 3 files |
| Phase 01 P05 | ~55min | 2 tasks | 1 files |
| Phase 01 P06 | ~50min | 3 tasks | 5 files |

## Accumulated Context

Decisions are logged in PROJECT.md Key Decisions table.

### Decisions

- Bugs before packaging — a working daily driver sooner, and packaging a buggy thing means packaging it twice. Phases 1-3 are defects; 4-5 are packaging.
- Never re-press held modifiers through `ydotool` — wedged real input on 2026-09-10, reverted to `92f64bc`. HOP-01 needs a different mechanism.
- Drive the hop from the server side only — input-leap ignores synthetic pointer input on clients.
- Optimistic recentre + detached self-check, never an awaited journald confirmation in the hot path (~450ms, rejected as laggy).
- v1 = Hyprland + AeroSpace only; adapters deferred to v2.
- [Phase 01]: Watcher-restart-gap evidence supports RESEARCH Q2 mechanism #1: 2 real transitions measured lost inside one journald-observed restart gap
- [Phase 01]: Deliberately did not mark HOP-02 complete — only reproduction is done; root-cause and closure are plans 01-05/01-06
- [Phase 01]: il-jump dbg() uses a human-readable wall-clock timestamp per the plan's explicit override, not PATTERNS.md's epoch-only suggestion
- [Phase 01]: A1 falsified by measurement: hyprctl cursorpos FROZE once input-leap capture took the pointer, discriminated from a screen-edge-clamp artifact via absence of il-jump's centre_mac() nudge over 2m12s — D-14's local landing oracle stands for plan 01-04
- [Phase 01]: Scored the 19:29:13 marker, not the chronologically-last one — two later crossings from an orchestrator-requested mouse jiggle (unrelated cursor-visibility diagnosis) were excluded via a new il-cursortrace --before bound
- [Phase 01]: Deliberately did not mark HOP-03 complete — this plan only establishes the A1 measurement oracle; plan 01-03/01-05 own HOP-03's actual determination
- [Phase 01]: Did not run requirements mark-complete HOP-02 -- reproduction (all 3 D-21 routes) and RESEARCH Q2 #1's consequence half are now proven, but root-cause and closure remain plans 01-05/01-06
- [Phase 01]: Route 2 (ILHOP_DEBUG passive logging) left armed for the remainder of the phase so an organic HOP-02 occurrence self-explains via il-repro --report
- [Phase 01]: HOP-03 settled: NOT A DEFECT per D-18's bar, measured not asserted; HOP-05 (Phase 3.1) supersedes the landing target — il-doctor:110/:112's circularity fixed (D-16): il-cursortrace --landed is a local-freeze-probe oracle built on 01-A1-RESULT.md's FROZE verdict, never reads il-side, proven non-circular via --selftest-oracle
- [Phase 01]: Did not run requirements mark-complete for HOP-02 or HOP-03 in plan 01-04 — HOP-02 still needs root-cause and closure (01-05/01-06); HOP-03's human-check is deferred to end-of-phase harvest per workflow.human_verify_mode
- [Phase 01]: [Phase 01]: HOP-02's Named mechanism populated (not NOT TRACED): il-side-watch's restart-reattach gap and jump-from line-shape mismatch feed il-jump's blindly-trusting guard, proven end to end by injection and a live watcher-restart test; whether this chain has been caught firing during a remembered failed press remains unconfirmed
- [Phase 01]: [Phase 01]: Corrected two unverified claims found while re-deriving the diff window and determination: 92f64bc landed 5h52m37s after 849b6ac, not 'about an hour later'; RESEARCH's mechanism #2 ranking rationale ('trigger so-far unobserved') is outdated -- 01-EVIDENCE.md already measured it firing 7 times
- [Phase 01]: [Phase 01]: Did not run requirements mark-complete for HOP-02 or HOP-03 in plan 01-05 -- root-cause determination is written but closure (choosing and shipping a fix, running the human-at-keyboard gate) is explicitly plan 01-06's work

- [Phase 01]: Human gate PASSED 2026-09-11 against a bar agreed before the presses (10 ALT+C presses, >=4 each direction, every one fires). Log tally for the gate window 16:43:17.828-16:43:54.728: 27 dispatch, 0 already-on-side, 0 of every other exit path, 0 retry-forced — the double-press override never had to rescue anything
- [Phase 01]: HOP-02 and HOP-03 both marked complete. HOP-03 closed as NOT A DEFECT per 01-HOP-03-FINDING.md, not as a repair
- [Phase 01]: Two il-repro FAILs seen mid-session were PROVEN (not argued) to be the author's hand on the mouse — hands-off re-run returned 80 ok / 0 failed, exit 0. Filed as a Phase 4 harness defect: a pointer-motion probe cannot distinguish the code under test from a human using the machine
- [Phase 01]: Three corrections to the .continue-here.md handoff, recorded not silently fixed — six commits carry 01-06 not five (e921752 omitted); Route 2 was NOT still armed (tmpfs, wiped by two reboots); il-repro's check total is not a fixed invariant (83 disarmed / 80 armed)
- [Phase 01]: Latency improved against the 01-EVIDENCE.md baseline — 24ms out (was 20ms) and 45ms back (was 53ms); the return leg was the one leg over PROJECT.md's ~50ms budget and is now 5ms under it

### Pending Todos

- **CR-01 gap plan owed in Phase 01 — now a VERIFIER GAP, not just a review finding.** `01-VERIFICATION.md` independently reproduced it (garbage cursor -> "Failed to seek to cursor: Invalid argument", exit 1, file left unrepaired) and fails the phase on it. (author's call, 2026-09-11). Code review found the phase's own `--cursor-file` reattach has no handling for `journalctl`'s hard failure on an unreadable cursor — a permanent silent crash loop under `Restart=always`, with the diagnostic discarded by `2>/dev/null` at `il-side-watch:71`, and `systemctl is-active` reporting `active` right through it. Not an input-path change, so fully script-testable.
- **Phase tail still owed:** aggregate_results → code review gate → verifier → ROADMAP update.
- **Route 2 disarm at phase close:** `il-repro --disarm`.

### Phase 4 (DIAG) inherits, found during Phase 01

- `il-repro`'s pointer-motion probe false-FAILs on a machine in use — needs an exclusive-input window or a second independent signal before a motion FAIL is believed.
- `il-repro`'s check total moves between runs (83 disarmed / 80 armed); one of the three-check delta traced to the arm-conditional skip at `il-repro:177-178`, the other two untraced. A moving denominator weakens "N ok, 0 failed" as a gate.
- `il-doctor:78` calls bare `hyprctl binds -j` while `:126` routes through the `hypr()` wrapper at `:25`. Without `HYPRLAND_INSTANCE_SIGNATURE` the bind checks emit a false FAIL with a misleading remedy.

### Blockers/Concerns

- **The scar (governs every phase).** No input-path change ships without the author physically at the keyboard. `ydotool` key events do not fire Hyprland keybinds and `il-heldmods` excludes ydotool's own device, so the keybind path cannot be simulated — not by a nested compositor, not by `libinput-replay`. A modifier-flag read alone is not proof.
- **Phase 1 defects are unreproduced.** HOP-02 and HOP-03 are user-reported and were both recorded tested-good on 2026-09-09 — suspected regressions from the `9d1f129` revert. Reproduction gates the fix.
- **Escape hatch before testing.** Any test of a change that synthesizes a hold needs a second input channel already open (second machine ssh'd in) *before* the run, not improvised after — recovering a wedged primary keyboard otherwise means a hard power-reset.
- **input-leap archived read-only (July 2026).** The dependency is unmaintained upstream; deskflow inherits the identical libei/libportal defects. Settled 2026-09-10, not re-litigated this milestone, but it is a live dependency risk.

### Roadmap Evolution

- HOP-06 (invisible cursor after a Mac→Ryuk return leg) unparked at Phase 1 close and added to Phase 2 as a third requirement, with ROADMAP criterion 6. It is far-side state immediately after a hop, the same class as HOP-01 and HOP-04. v1 requirement count 13 → 14.
- Phase 03.1 inserted after Phase 3: Window-Centre Landing (HOP-05) - planned scope raised during Phase 1 discussion, placed before Phase 5 so packaging does not document landing behaviour this phase changes

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-11T16:50:00.000Z
Stopped at: Completed 01-06-PLAN.md — Phase 01 closed
Resume file: None (`.continue-here.md` removed; its handoff is superseded by 01-06-SUMMARY.md)
