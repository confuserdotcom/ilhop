---
gsd_state_version: '1.0'
status: planning
milestone: v1.0
current_phase: '01'
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Pressing the hop key always lands you on the other machine, ready to type, with no lost keystroke and no wedged input device.
**Current focus:** Phase 1 — Regression Recovery

## Current Position

Phase: 1 of 5 (Regression Recovery)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-09-10 — Roadmap created, 12/12 v1 requirements mapped across 5 phases

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

## Accumulated Context

Decisions are logged in PROJECT.md Key Decisions table.

### Decisions

- Bugs before packaging — a working daily driver sooner, and packaging a buggy thing means packaging it twice. Phases 1-3 are defects; 4-5 are packaging.
- Never re-press held modifiers through `ydotool` — wedged real input on 2026-09-10, reverted to `92f64bc`. HOP-01 needs a different mechanism.
- Drive the hop from the server side only — input-leap ignores synthetic pointer input on clients.
- Optimistic recentre + detached self-check, never an awaited journald confirmation in the hot path (~450ms, rejected as laggy).
- v1 = Hyprland + AeroSpace only; adapters deferred to v2.

### Pending Todos

None yet.

### Blockers/Concerns

- **The scar (governs every phase).** No input-path change ships without the author physically at the keyboard. `ydotool` key events do not fire Hyprland keybinds and `il-heldmods` excludes ydotool's own device, so the keybind path cannot be simulated — not by a nested compositor, not by `libinput-replay`. A modifier-flag read alone is not proof.
- **Phase 1 defects are unreproduced.** HOP-02 and HOP-03 are user-reported and were both recorded tested-good on 2026-09-09 — suspected regressions from the `9d1f129` revert. Reproduction gates the fix.
- **Escape hatch before testing.** Any test of a change that synthesizes a hold needs a second input channel already open (second machine ssh'd in) *before* the run, not improvised after — recovering a wedged primary keyboard otherwise means a hard power-reset.
- **input-leap archived read-only (July 2026).** The dependency is unmaintained upstream; deskflow inherits the identical libei/libportal defects. Settled 2026-09-10, not re-litigated this milestone, but it is a live dependency risk.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-10
Stopped at: ROADMAP.md and STATE.md written; REQUIREMENTS.md traceability populated
Resume file: None
