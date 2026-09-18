---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: 01
current_phase_name: Regression Recovery
status: phase-complete
stopped_at: Phase 01 COMPLETE — re-verified passed (6/6), CR-01 closed by 01-07
last_updated: "2026-09-18T18:05:00.000Z"
last_activity: 2026-09-18
last_activity_desc: 01-07 closed the CR-01 gap; Phase 01 re-verified passed (6/6) and closed. Phase 02 is next but blocked on Mac availability
state_head: c5cfeb92e62276041e4b80ed4c9c14dedff5a126
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 7
  completed_plans: 7
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Pressing the hop key always lands you on the other machine, ready to type, with no lost keystroke and no wedged input device.
**Current focus:** Phase 02 — Clean Handoff (not yet planned)

## Current Position

Phase: 01 (Regression Recovery) — COMPLETE
Plan: 7 of 7 executed
Status: Re-verified 2026-09-18 — passed (6/6). CR-01 closed by 01-07.
Last activity: 2026-09-18 — CR-01 gap verified closed in live code; phase records updated

Next: Phase 02 (Clean Handoff) — HOP-01, HOP-04, HOP-06. Not planned yet.
**The Mac is reachable** (ssh 0.120s over LAN mDNS via `Host mac`, up 10 days; Tailscale
showing it offline is irrelevant — the hop path does not use `mac-ts`). An earlier note in
this file claiming Phase 02 was "gated on the Mac being reachable" was wrong and is retracted.
Phase 02's *human* criteria still need the author at the keyboard; nothing else is blocked.

Progress: [██░░░░░░░░] 1 of 6 phases complete (Phase 01 at 7/7 plans, 6/6 must-haves)

## Performance Metrics

**Velocity:**

- Total plans completed: 7
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
| Phase 01 P07 | — | 3 tasks | 3 files |

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
- [Phase 01]: CR-01 closed by 01-07 — the self-heal is bounded to exactly one `Restart=always` cycle, not "fixed" in the sense of never failing: a corrupt cursor still costs one restart and ~3s of unreplayed transitions. That cost is stated in the code, not hidden
- [Phase 01]: The crash-loop check is journal-history based (grep systemd's own `Scheduled restart job` line over a trailing 10s window), deliberately NOT `systemctl is-active` — CR-01 measured `is-active` reporting `active` on roughly 1 in 10 polls mid-loop
- [Phase 01]: WR-01 (a well-formed-but-unresolvable cursor replaying the full retained backlog) explicitly deferred to Phase 4, not fixed — it converges to the correct value rather than freezing, a materially lower-severity shape, and fixing it needs this journal's retention policy plus a place to log a large unexpected replay
- [Phase 01]: 01-07's own dual-branch assertion caught a real self-referential bug live — il-doctor's PASS text originally read "is not crash-looping", which contains the substring the reproduction mode matched on, so PASS and FAIL were indistinguishable. Reworded to "restart history looks healthy". The lesson: a health check's wording is part of what its test tests
- [Phase 01]: Re-verification 2026-09-18 deliberately did NOT re-run the `--cursor-crash-loop` induction (it corrupts the cursor and restarts the watcher on purpose, and the author was mid-triage on an unrelated input-leap client issue). Closed on a static read of the live code plus 01-07's recorded live run — and said so rather than implying a fresh run

### Pending Todos

- *(none blocking)* — Phase 01's three owed items are all discharged:
  - **CR-01 gap plan** — landed as `01-07`, re-verified 2026-09-18 (`il-side-watch:115-131`, `il-doctor:81-88`, `il-repro --cursor-crash-loop`).
  - **Phase tail** (aggregate → code review → verifier → ROADMAP) — complete.
  - **Route 2 disarm** (`il-repro --disarm`) — discharged for free: `$XDG_RUNTIME_DIR/ilhop-debug.on` is on tmpfs and was wiped by the 2026-09-16 reboot. Confirmed absent 2026-09-18. `ILHOP_DEBUG` is currently OFF; re-arm before any session where a failure should self-explain.

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

### Pre-Phase-2 measurement — 2026-09-18: criterion 2 is answered, and it redirects HOP-01

Taken read-only over ssh before any Phase 2 planning, because ROADMAP Phase 2 criterion 2
requires it *before* the HOP-01 fix is designed. Source: `/Users/Apple/tmp/modstate.c`
(binary at `~/.local/bin/modstate` on the Mac).

**`modstate` never masks before it judges.** Its verdict line is literally
`if (f == 0) printf(" CLEAN"); else printf("  <-- DIRTY");` — so *any* non-zero
`CGEventSourceFlagsState` value is reported DIRTY, including values with zero modifier bits.

Three values observed in one 60-second window, masked against the union of the six flags
modstate itself tests (`kCGEventFlagMaskAlphaShift|Shift|Control|Alternate|Command|SecondaryFn`
= `0x009F0000`):

| Raw | `& 0x009F0000` | Actually held | modstate verdict |
|---|---|---|---|
| `0x00080120` | `0x00080000` | Option (genuine; `0x20` = left-alt device bit, `0x100` = NonCoalesced) | DIRTY — correct |
| `0x00000100` | `0` | nothing (NonCoalesced only) | DIRTY — **false positive** |
| `0x20000000` | `0` | nothing | DIRTY — **false positive** |

`0x20000000` is the exact value ROADMAP criterion 2 flagged as matching no documented
`CGEventFlags` constant. It matches none because it **is** none: masked against the documented
modifier bits it reads clear. Six consecutive samples returned it as the steady state.

**Consequence for Phase 2 (must be carried into planning, not re-derived):**
- The persistent "a modifier is latched on the Mac" signal underpinning HOP-01 is substantially
  an artifact of the measuring instrument. Criterion 2's own escape clause applies: *"if the real
  modifier bits read clear the fix belongs somewhere else entirely."*
- HOP-01 is **not** thereby disproved. The first sample was a real Option hold that cleared on its
  own within seconds — so genuine latches occur, but transiently, not permanently as the DIRTY
  readings implied. Whether a transient latch is long enough to eat the first chord after a hop is
  the open question, and it is a *timing* question, not a *stuck-flag* question.
- Fixing `modstate.c` (mask before judging, print the masked value) is a prerequisite for trusting
  any further HOP-01 evidence. It is a diagnostic-only change, no input-path risk, no human gate —
  but it belongs in a Phase 2 plan, not an ad-hoc edit, and was deliberately not made here.
- Every prior HOP-01 observation recorded via modstate's DIRTY verdict should be re-read with this
  in mind before it is used as evidence.

### Field note — 2026-09-18 (not a phase defect)

Author reported input-leap "not working" and planned a Linux reboot. Investigated
before closing the phase, since a broken input-leap would false-FAIL the gate:

- `input-leap-server.service` healthy, up 1d 21h. `il-side-watch.service` healthy, zero restarts.
- `il-doctor`: 21 ok / 0 failed (the 21-check figure is the documented non-`--test` tally).
- The Mac client dropped at 17:35:10 with `SSL routines::unexpected eof while reading`, then
  reconnected cleanly 10s later (fingerprint matched, TLS 1.3). Connected since.
- Continuous clipboard `missequenced` spam (~10 lines / 10 min) — the one genuinely abnormal
  signal, originating client-side.
- `ssh mac` answers in 0.120s. The hop path uses `Host mac` → `MacBook-Air.local` over LAN
  mDNS, **not** `mac-ts`/Tailscale — so Tailscale showing the Mac offline (last seen 3d)
  does not affect the hop.

Conclusion: nothing server-side to fix; a Linux reboot was not indicated. Filed here because
the clipboard missequence behaviour is unexplained and may resurface.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-18T18:05:00.000Z
Stopped at: Phase 01 closed for real — 01-07 executed, re-verified passed (6/6), all records updated
Resume file: None. Next command: `/gsd-plan-phase 02` (planning is safe offline; Phase 2 verification needs the Mac)
