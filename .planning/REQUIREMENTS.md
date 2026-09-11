# Requirements: ilhop

**Defined:** 2026-09-10
**Core Value:** Pressing the hop key always lands you on the other machine, ready to type, with no lost keystroke and no wedged input device.

## v1 Requirements

Requirements for the first packaged release. Each maps to exactly one roadmap phase.

### Hop Correctness

- [ ] **HOP-01**: The first chord pressed after a hop registers on the destination machine — no eaten keystroke, no modifier left latched in `CGEventSourceFlagsState`. The fix must not re-press modifiers through `ydotool` (that mechanism wedged real input on 2026-09-10 and is a closed decision).
- [ ] **HOP-02**: The hop fires on every press of the bind — the intermittent "sometimes doesn't fire" report is reproduced, root-caused, and closed. Reproduction precedes any fix. **Reopened 2026-09-11 by the Phase 1 verifier (`01-VERIFICATION.md`, gaps_found 5/6).** The fix is shipped and passed the human gate, but the phase's own `--cursor-file` reattach (`il-side-watch:69-74`, commit `8408bcc`) can crash-loop silently and freeze `$STATE` forever — reintroducing exactly this requirement's defect class through code this phase shipped. Closes when the CR-01 gap plan lands.
- [x] **HOP-03**: The pointer lands dead centre of the destination screen on every hop, in both directions — never at an edge, never off-centre. **Closed 2026-09-11 as NOT A DEFECT, not as a repair** — measured in `.planning/phases/01-regression-recovery/01-HOP-03-FINDING.md` per ROADMAP Phase 1 criterion 4's own clause that recording the finding is how the criterion is met. Screen centre being the *wrong target* is HOP-05's problem, not this one's.
- [ ] **HOP-05**: The pointer lands at the centre of the window nearest the edge it crossed, and that window takes keyboard focus on arrival. With exactly one window open it lands at that window's centre; with none, it falls back to screen centre. Screen centre is not the target — on a two-window Mac it puts the cursor in the gap between them. Raised during Phase 1 discussion (`.planning/phases/01-regression-recovery/01-CONTEXT.md` D-19/D-20); supersedes HOP-03's screen-centre target once it lands.
- [ ] **HOP-04**: Mac→Ryuk hop completes within the same ~50ms budget as Ryuk→Mac, warm or cold — the current ssh return leg (40–110ms warm, ~1.6s on a lapsed launchd control master) is brought into budget without reintroducing an awaited journald confirmation in the hot path.
- [ ] **HOP-06**: After a Mac→Ryuk return leg the pointer is **drawn**, not merely present — no jiggle required to make it reappear. `centre_nastralis()` (`il-jump:142-151`) recentres with a `hyprctl` cursor warp, which updates the logical pointer but emits no pointer event, so no client re-sets a cursor image. Parked during Phase 1 by the author's explicit decision, unparked and assigned to Phase 2 on 2026-09-11 because it is far-side state immediately after a hop, the same class as HOP-01 and HOP-04. Candidate one-line fix is written (a `+1/-1` ydotool nudge after the warp) but deliberately NOT landed: it touches the input path, so it gates on a human at the keyboard, and ydotool deltas land at ~2x after accel so the nudge netting to zero must be measured, not reasoned about. Write-up: `~/.local/share/ryoku/rashin/journal/2026-09-10.md`.

### Focus Chain

- [ ] **FOCUS-01**: `ALT+H` focuses the window to the left when one exists and hops only when the focused window is genuinely leftmost — no hop while a window remains in that direction, no refusal when at the true edge.
- [ ] **FOCUS-02**: `ALT+H` feels as instant as the compositor's own focus-left — the `hyprctl clients` geometry query no longer adds perceptible delay ahead of the focus move.

### Diagnostics and Recovery

- [ ] **DIAG-01**: `ilhop doctor` runs the full check suite and `ilhop doctor --test` additionally drives a live round trip, reporting pass/fail per check.
- [ ] **DIAG-02**: `ilhop reset` recovers wedged input in one command, and cannot race an in-flight hop (single-flight lock holds across reset).

### Packaging

- [ ] **PKG-01**: `ilhop` installs from a standalone git repo via an install script, on a machine that has never had the `il-*` scripts — no Ryoku checkout required.
- [ ] **PKG-02**: An uninstall path removes every installed file, systemd user unit, and binding stanza, leaving no residue.
- [ ] **PKG-03**: A README a stranger can follow end to end: prerequisites, install, the two binds, `doctor`, `reset`, and the known limits (Hyprland + AeroSpace only).
- [ ] **PKG-04**: The command surface is renamed `il-*` → `ilhop`, with the old names kept working for the duration of this milestone so the author's daily driver never breaks mid-flight.

## v2 Requirements

Deferred. Tracked, not roadmapped.

### Visibility

- **VIS-01**: A lightweight indicator of which machine currently has focus. Trigger: a report of disorientation in practice — research found no well-loved tray-icon equivalent, so this waits for the pain.
- **VIS-02**: Configurable cursor-placement policy (centre vs. restore last position per side). Trigger: the centre default proving wrong in practice; no competitor data favours either for a chord trigger.

### Portability

- **PORT-01**: Both-sides-pluggable adapters — other Wayland compositors, yabai/skhd.
- **PORT-02**: Upstreaming into `ryoku-desktop`, after the repo proves installable standing alone.
- **PORT-03**: Optional mouse-edge trigger mode, only ever with a mandatory disable switch (Logitech Flow's corner-disable precedent).

## Out of Scope

Explicitly excluded. Reasoning recorded so it is not re-added.

| Feature | Reason |
|---------|--------|
| Both-sides-pluggable adapters in v1 | v1 targets exactly one tested combination; adapters for hardware the author cannot press keys on directly contradict the verification constraint |
| Upstreaming into `ryoku-desktop` in v1 | Repo first — prove it installs standalone before inheriting Ryoku's release cycle |
| The rest of the two-machine kit (`push` / `pull` / `openon`, copi clipboard, the `drop` syncthing folder, mosh aliases) | Same setup, different project. `ilhop` is the hop |
| Migrating off input-leap to deskflow or lan-mouse | Settled 2026-09-10. deskflow inherits the identical libei/libportal Wayland defects and targets GNOME 46+/KDE 6.1+; lan-mouse's macOS client is the weak half, and macOS is half this setup |
| Making input-leap's own `keystroke()` hotkeys work | Impossible on the `--use-ei` EiScreen backend — no global-hotkey grab exists through the input capture portal (X11-only). Already removed from `server.conf` |
| Clipboard sync, drag-and-drop, file transfer | Not reliably solved at this layer by input-leap, deskflow, or a clean-slate rewrite; deskflow's maintainers removed DnD outright as unfixable in practice |
| Screensaver / lock-screen sync | The transport's responsibility, incomplete even there, and outside the hop layer's boundary |
| Switch delay / dwell time before the hop fires | 700ms was the original implementation and was rejected as laggy; no tool in this space uses dwell deliberately. Accidental fires are prevented by the chord and the single-flight lock, not by time |
| Mouse-edge-crawl as a trigger in v1 | The single largest complaint-generating mechanism in the researched ecosystem (geometry misconfig, edge-trapping, wrap-around); chord-only avoids that class structurally |

## Traceability

Populated during roadmap creation. Every v1 requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| HOP-01 | Phase 2 | Pending |
| HOP-02 | Phase 1 | Gap closure pending |
| HOP-03 | Phase 1 | Complete |
| HOP-04 | Phase 2 | Pending |
| HOP-06 | Phase 2 | Pending |
| HOP-05 | Phase 3.1 | Pending |
| FOCUS-01 | Phase 3 | Pending |
| FOCUS-02 | Phase 3 | Pending |
| DIAG-01 | Phase 4 | Pending |
| DIAG-02 | Phase 4 | Pending |
| PKG-01 | Phase 5 | Pending |
| PKG-02 | Phase 5 | Pending |
| PKG-03 | Phase 5 | Pending |
| PKG-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0 ✓
- Duplicates (a requirement in two phases): 0 ✓

**By phase:**

| Phase | Requirements | Count |
|-------|--------------|-------|
| Phase 1 — Regression Recovery | HOP-02, HOP-03 | 2 |
| Phase 2 — Clean Handoff | HOP-01, HOP-04, HOP-06 | 3 |
| Phase 3 — Focus Chain Precision | FOCUS-01, FOCUS-02 | 2 |
| Phase 3.1 — Window-Centre Landing | HOP-05 | 1 |
| Phase 4 — The ilhop Surface | DIAG-01, DIAG-02, PKG-04 | 3 |
| Phase 5 — Standalone Install | PKG-01, PKG-02, PKG-03 | 3 |

## Verification Constraint

Every requirement in Hop Correctness and Focus Chain touches the input path. Per
PROJECT.md's hardest constraint, none of them ships without the author physically at
the keyboard. `ydotool` key events relay to the Mac but do **not** fire Hyprland
keybinds, and `il-heldmods` excludes ydotool's own device by design — so keybind paths
cannot be simulated at all. A modifier-flag read alone is not proof.

---
*Requirements defined: 2026-09-10*
*Last updated: 2026-09-10 after adding HOP-05 (Phase 3.1 inserted)*
