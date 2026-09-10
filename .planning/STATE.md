---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: 01
current_phase_name: Regression Recovery
status: executing
stopped_at: Completed 01-04-PLAN.md
last_updated: "2026-09-10T23:06:22.312Z"
last_activity: 2026-09-10
last_activity_desc: Phase 01 execution started
state_head: 61cf10f695f7a125b44356f89056af9c2fd31d6f
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 6
  completed_plans: 4
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Pressing the hop key always lands you on the other machine, ready to type, with no lost keystroke and no wedged input device.
**Current focus:** Phase 01 — Regression Recovery

## Current Position

Phase: 01 (Regression Recovery) — EXECUTING
Plan: 4 of 6
Status: Ready to execute
Last activity: 2026-09-10 — Phase 01 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
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

### Pending Todos

None yet.

### Blockers/Concerns

- **The scar (governs every phase).** No input-path change ships without the author physically at the keyboard. `ydotool` key events do not fire Hyprland keybinds and `il-heldmods` excludes ydotool's own device, so the keybind path cannot be simulated — not by a nested compositor, not by `libinput-replay`. A modifier-flag read alone is not proof.
- **Phase 1 defects are unreproduced.** HOP-02 and HOP-03 are user-reported and were both recorded tested-good on 2026-09-09 — suspected regressions from the `9d1f129` revert. Reproduction gates the fix.
- **Escape hatch before testing.** Any test of a change that synthesizes a hold needs a second input channel already open (second machine ssh'd in) *before* the run, not improvised after — recovering a wedged primary keyboard otherwise means a hard power-reset.
- **input-leap archived read-only (July 2026).** The dependency is unmaintained upstream; deskflow inherits the identical libei/libportal defects. Settled 2026-09-10, not re-litigated this milestone, but it is a live dependency risk.

### Roadmap Evolution

- Phase 03.1 inserted after Phase 3: Window-Centre Landing (HOP-05) - planned scope raised during Phase 1 discussion, placed before Phase 5 so packaging does not document landing behaviour this phase changes

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-10T23:06:22.264Z
Stopped at: Completed 01-04-PLAN.md
Resume file: None
