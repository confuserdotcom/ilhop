# Roadmap: ilhop

**Milestone:** v1.0
**Granularity:** standard
**Created:** 2026-09-10

## Overview

`ilhop` already exists and is in daily use — ~457 lines of shell plus one C helper
living loose in `~/.local/bin/il-*`. This milestone does not build it. It kills the
six open defects, then turns the surviving thing into something a stranger can
install. That ordering is a recorded decision in PROJECT.md ("bugs before
packaging"): a working daily driver sooner, and packaging a buggy thing means
packaging it twice.

The four bug phases are sequenced by blast radius, not by severity. Phase 1 takes
the two defects that were recorded tested-good on 2026-09-09 and are therefore
suspected regressions from the `9d1f129` revert — reproduce and diff against
known-good before theorising. Phase 2 takes the two that both concern far-side
state immediately after a hop, and are the ones that carry the project's scar.
Phase 3 takes the focus chain, which is isolated to one component and interacts
with nothing else. Phase 4 renames the surface and lands the diagnostics under it.
Phase 5 makes it installable standing alone.

**The constraint that governs every phase below.** On 2026-09-10 a fix shipped on
reasoning alone — re-pressing held modifiers through ydotool — wedged the author's
real keyboard and mouse, and was reverted to `92f64bc`. No input-path change ships
without the author physically at the keyboard. `ydotool` key events do **not** fire
Hyprland keybinds, and `il-heldmods` excludes ydotool's own device by design, so
the keybind path cannot be simulated at all — not by a nested compositor, not by
`libinput-replay`, both of which inject through the same `uinput` primitive that
was already measured at 0 fires. A modifier-flag read alone is not proof. Every
phase from 1 to 5 carries at least one success criterion that only a human at the
keyboard can satisfy.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Regression Recovery** - Reproduce and close the two defects suspected of riding in on the `9d1f129` revert
- [ ] **Phase 2: Clean Handoff** - The first chord after a hop lands, and the return leg is as fast as the outbound
- [ ] **Phase 3: Focus Chain Precision** - `ALT+H` is indistinguishable from the compositor's own focus-left until there is nowhere left to go
- [ ] **Phase 3.1: Window-Centre Landing** (INSERTED) - the pointer lands in the window nearest the crossed edge, and that window takes focus
- [ ] **Phase 4: The ilhop Surface** - One name for every command, with `doctor` and `reset` under it and the old names still live
- [ ] **Phase 5: Standalone Install** - A stranger clones the repo, installs, uses it, and removes it without residue

## Phase Details

### Phase 1: Regression Recovery

**Goal**: The hop fires on every press, and the landing question is settled — the two user-reported defects are reproduced and root-caused, or shown not to be defects, and closed either way.
**Depends on**: Nothing (first phase)
**Requirements**: HOP-02, HOP-03
**Success Criteria** (what must be TRUE):

  1. Both defects are reproducible on demand before any fix is written — a recorded sequence makes the hop fail to fire, and a recorded sequence makes the pointer land off-centre. If either cannot be reproduced, that is the phase's finding and is recorded as such rather than papered over with a speculative fix.
  2. The cause is traced to a named change — either a specific hunk carried in by the `9d1f129` revert (both paths were recorded tested-good on 2026-09-09) or a mechanism ruled out by diff against the last known-good commit. No fix ships on a guess.
  3. The author presses the hop bind at the keyboard, repeatedly and in both directions, and every single press fires — no silent no-op, no swallowed press.
  4. The pointer arrives on the correct destination screen and is never pinned against an edge, in both directions, with the author watching it land. Screen-centre accuracy is NOT the bar here: the author confirmed on 2026-09-10 that landing is at screen centre today and that screen centre is the wrong target — Phase 3.1 (HOP-05) owns moving it to the window nearest the crossed edge. If HOP-03 proves not to be a defect, recording that is how this criterion is met.
  5. `il-doctor --test` reports 21/21 and a passing live round trip after the change, and the detached self-check still catches and recentres a deliberately failed hop.

**Plans**: 2/6 plans executed in 4 waves

Plans:

- [x] 01-01-PLAN.md — Zero-keypress evidence sweep, then the tracer: the accused refusal at `il-jump:91` wired end to end from guard to `ILHOP_DEBUG` log to harness assertion
- [x] 01-02-PLAN.md — Falsify assumption A1 (does `hyprctl cursorpos` freeze under capture?) on one human-driven hop, before any oracle is built on it
- [ ] 01-03-PLAN.md — Every exit path names itself; route 1's stressor, the watcher-gap assertion, and route 2 armed
- [ ] 01-04-PLAN.md — Replace the circular landing check at `il-doctor:110`, and settle HOP-03 as a finding rather than a repair
- [ ] 01-05-PLAN.md — Re-verify the corrected diff window `849b6ac..9d1f129`, then the root-cause determination with proven and inferred kept apart
- [ ] 01-06-PLAN.md — Choose the fix shape at a blocking decision gate, ship it whole, and run the phase gate including the human criteria

### Phase 2: Clean Handoff

**Goal**: A hop delivers the next chord to the destination machine and feels the same in both directions.
**Depends on**: Phase 1
**Requirements**: HOP-01, HOP-04
**Success Criteria** (what must be TRUE):

  1. The author holds a modifier across a hop and the first chord on the destination machine registers — verified by a real AeroSpace workspace actually switching, for each of ALT, Shift, Ctrl, and Cmd in turn. A `CGEventSourceFlagsState` read showing zero is not accepted as proof of this criterion.
  2. Before the fix is designed, the raw flags value is masked against the documented low-24-bit modifier masks and logged before and after known actions, so it is known whether `0x20000000` means "a modifier is held" at all — it matches no documented `CGEventFlags` constant, and if the real modifier bits read clear the fix belongs somewhere else entirely.
  3. No code path holds a synthetic key-down open across a wait: killing any helper mid-run leaves nothing held, confirmed by `il-heldmods` reading clear afterwards. Modifiers are never re-pressed through `ydotool` — that mechanism is a closed decision.
  4. A Mac→Ryuk hop completes inside the same ~50ms budget as Ryuk→Mac, measured both warm and after the control master has lapsed, with no awaited journald confirmation anywhere in the hot path.
  5. The author runs the changed code as the daily driver for a full working session with no wedged keyboard, no wedged mouse, and no reach for `il-reset`.

**Plans**: TBD

### Phase 3: Focus Chain Precision

**Goal**: `ALT+H` moves focus left like the compositor does, and hops only when the focused window is genuinely leftmost.
**Depends on**: Phase 2
**Requirements**: FOCUS-01, FOCUS-02
**Success Criteria** (what must be TRUE):

  1. With another window to the left, the author presses `ALT+H` and focus moves to it — no hop — across tiled, floating, and mixed layouts.
  2. With the leftmost window focused, the author presses `ALT+H` and the hop fires, every time, with no refusal at the true edge.
  3. `ALT+H` feels the same as the compositor's own focus-left — the author alternates between the two at the keyboard and cannot tell which one fired.
  4. The edge-detection geometry is exercised without a human against recorded `hyprctl clients` output, including a single window, no windows, and windows sharing an x-coordinate, and gets the answer right in each case.

**Plans**: TBD

### Phase 03.1: Window-Centre Landing (INSERTED)

**Goal**: The pointer lands at the centre of the window nearest the edge it crossed, and that window takes focus — not at the centre of the screen, which on a two-window Mac puts the cursor in the gap between them.
**Depends on**: Phase 3
**Requirements**: HOP-05
**Success Criteria** (what must be TRUE):

  1. With two or more windows open on the destination machine, the author hops and the pointer arrives inside the window nearest the crossed edge — not between windows, not at screen centre — in both directions, watched landing.
  2. That window has keyboard focus on arrival: the author types immediately and the characters go to it, with no click and no second keypress to claim focus.
  3. With exactly one window open, the pointer lands at the centre of that window rather than the centre of the screen.
  4. With no windows open, the landing falls back to screen centre and nothing errors.
  5. The hop still completes inside the ~50ms budget in both directions with the geometry fetch included — measured, not assumed. If the Mac-side query cannot be made to fit, the geometry is resolved off the hot path and the criterion is met by the pointer's final resting place, never by an awaited round trip during the hop.

**Note on the (INSERTED) marker**: this phase was added mid-milestone via
`/gsd-phase --insert`, which stamps every insertion `(INSERTED)`. It is planned
scope raised during Phase 1 discussion (see
`.planning/phases/01-regression-recovery/01-CONTEXT.md` D-19/D-20), not urgent
remediation. It sits here rather than at the end of the milestone because it
must land before Phase 5 packages an installer and a README that would otherwise
document landing behaviour this phase changes.

**Plans**: TBD

### Phase 4: The ilhop Surface

**Goal**: Every command answers to `ilhop`, the diagnostics and the panic button work under that name, and the author's daily driver never breaks during the change.
**Depends on**: Phase 3
**Requirements**: PKG-04, DIAG-01, DIAG-02
**Success Criteria** (what must be TRUE):

  1. Every command is reachable under its `ilhop` name, and every old `il-*` name still works for the duration of this milestone — the author's existing binds keep firing untouched through and after the rename.
  2. `ilhop doctor` runs the full check suite and reports pass/fail per check; `ilhop doctor --test` additionally drives a live round trip and reports its outcome.
  3. `ilhop reset` recovers wedged input in one command, including when the primary keyboard is unresponsive and the command is run over ssh from a second machine — it issues unconditional releases rather than releasing only what it believes is held.
  4. Firing `ilhop reset` while a hop is in flight cannot interleave with it: the single-flight lock holds across the reset, proven by a scripted race with no human involved.
  5. After the rename the author presses both binds at the keyboard and the hop behaves exactly as it did in Phase 3 — same landing, same latency, no new compositor call sites outside the one place they are isolated.

**Plans**: TBD

### Phase 5: Standalone Install

**Goal**: `ilhop` installs, works, and uninstalls cleanly on a machine that has never had the `il-*` scripts.
**Depends on**: Phase 4
**Requirements**: PKG-01, PKG-02, PKG-03
**Success Criteria** (what must be TRUE):

  1. A user account with no `il-*` scripts, no Ryoku checkout, and no prior setup installs from a git clone via the install script and ends up with a working hop — the author's own broad group membership and dev-time access are not what makes it work.
  2. When `/dev/uinput` permissions or group membership are wrong on that fresh machine, `ilhop doctor` names that specific cause and the remedy, rather than reporting a generic permission failure.
  3. Uninstall leaves nothing behind — no installed files, no systemd user unit or its enablement symlink, no binding stanza. A fresh `doctor` run on the uninstalled machine finds no trace.
  4. A reader who has never seen this project follows the README end to end: prerequisites, install, the two binds, `doctor`, `reset`, and the stated limits (Hyprland + AeroSpace only, this one tested combination).
  5. On the freshly installed machine the author presses the hop bind at the keyboard and it works on the first try, in both directions.

**Plans**: TBD

## Requirement Coverage

Every v1 requirement maps to exactly one phase. No orphans, no duplicates.

| Requirement | Phase | Summary |
|-------------|-------|---------|
| HOP-01 | Phase 2 | First chord after a hop registers |
| HOP-02 | Phase 1 | Hop fires on every press |
| HOP-03 | Phase 1 | Pointer lands dead centre |
| HOP-05 | Phase 3.1 | Lands in the window nearest the crossed edge, which takes focus |
| HOP-04 | Phase 2 | Return leg inside the ~50ms budget |
| FOCUS-01 | Phase 3 | `ALT+H` edge detection is correct |
| FOCUS-02 | Phase 3 | `ALT+H` feels as instant as plain focus |
| DIAG-01 | Phase 4 | `ilhop doctor` and `--test` |
| DIAG-02 | Phase 4 | `ilhop reset`, lock-safe |
| PKG-01 | Phase 5 | Installs from a standalone repo |
| PKG-02 | Phase 5 | Uninstall leaves no residue |
| PKG-03 | Phase 5 | README a stranger can follow |
| PKG-04 | Phase 4 | `il-*` → `ilhop` rename, old names live |

**Coverage: 13/13 v1 requirements mapped.**

## Verification Gates

Per PROJECT.md's hardest constraint, these phases cannot be closed on a green
script alone. Recorded here so no phase plan has to rediscover it.

| Phase | Scriptable | Requires the author at the keyboard |
|-------|------------|--------------------------------------|
| 1 | Landing position within bounds for a known delta; side-file transitions; `il-doctor --test` | Repeated real presses of the bind, both directions, watching every landing |
| 2 | Raw `CGEventSourceFlagsState` masking; dead-man release under mid-run kill; ssh round-trip timing warm and cold | Held-modifier hop per modifier, confirmed by a real AeroSpace workspace switch; a full session on the daily driver |
| 3 | `hyprctl clients` geometry parsing against recorded output and edge cases | `ALT+H` in real layouts; blind alternation against the compositor's own focus-left |
| 4 | `reset`-versus-in-flight-hop race; `doctor` check-by-check output; old-name wrappers resolve | Both binds pressed after the rename, confirming unchanged behaviour |
| 5 | Fresh-account install and uninstall; residue scan; `/dev/uinput` group and device-open check | The hop pressed for real on the freshly installed machine |

**A green `il-doctor` is not a release gate on its own.** 21/21 proves every
*scriptable* check passes; it says nothing about whether a held-modifier hop eats
the first chord. The two must be verified separately, every time.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Regression Recovery | 2/6 | In Progress|  |
| 2. Clean Handoff | 0/TBD | Not started | - |
| 3. Focus Chain Precision | 0/TBD | Not started | - |
| 4. The ilhop Surface | 0/TBD | Not started | - |
| 5. Standalone Install | 0/TBD | Not started | - |

## Out of Scope for v1

Deferred by explicit decision, recorded in PROJECT.md and REQUIREMENTS.md. Not
roadmapped here: both-sides-pluggable adapters (other compositors, yabai/skhd),
upstreaming into `ryoku-desktop`, a focus-side indicator, configurable
cursor-placement policy, mouse-edge trigger mode, clipboard/DnD/file transfer,
screensaver sync, switch dwell time, and migrating off input-leap.

---
*Roadmap created: 2026-09-10*
