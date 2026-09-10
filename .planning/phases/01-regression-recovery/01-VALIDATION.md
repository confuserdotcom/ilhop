---
phase: "1"
slug: "regression-recovery"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-10"
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

**Read this first.** This phase's subject is the input path, and the project's
binding constraint is that no input-path change ships without the author
physically at the keyboard. `ydotool` key events do **not** fire Hyprland
keybinds (measured: 0 fires), so the keybind path cannot be simulated by any
means. Everything below splits deliberately into what a script can prove and
what only a human can. A green `il-doctor` is necessary and explicitly **not
sufficient** — ROADMAP.md's Verification Gates table says so, and `il-doctor:110`
is itself circular until this phase repairs it (D-16).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — loose POSIX shell, not a packaged suite. Packaging is Phase 5; do not introduce a framework here |
| **Config file** | none — see Wave 0 |
| **Quick run command** | `~/.local/bin/il-doctor` (scriptable checks only) |
| **Full suite command** | `~/.local/bin/il-doctor --test` (adds the live round trip) |
| **Estimated runtime** | ~1s quick, ~4–6s full |

---

## Sampling Rate

- **After every task commit:** `~/.local/bin/il-doctor`
- **After every plan wave:** `~/.local/bin/il-doctor --test`
- **Before `/gsd-verify-work`:** full suite green **and** the human-only rows
  below satisfied
- **Max feedback latency:** ~6 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | HOP-02 | — | N/A | integration | `journalctl --user -u il-side-watch.service --since "-7 days" \| grep -c "Started\|Stopped"` — restart-history check, zero keypresses | ✅ exists | ⬜ pending |
| 1-01-02 | 01 | 0 | HOP-03 | — | N/A | manual-only | falsification pass for A1 — see Manual-Only table | N/A | ⬜ pending |
| 1-01-03 | 01 | 0 | HOP-02 | T-1-01 | Debug log writes only script-internal state; bounded size | unit | `ILHOP_DEBUG=1 il-jump left; test -s "$XDG_RUNTIME_DIR/ilhop-debug.log"` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | HOP-02 | — | N/A | unit | `echo mac > "$XDG_RUNTIME_DIR/il-side"; il-jump left; assert exit 0 with zero ydotool invocations` — Route 3 injection | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | HOP-02 | — | N/A | integration | `systemctl --user restart il-side-watch.service` timed against a scripted `il-jump` stressor; assert no permanently-stuck state | ❌ W0 | ⬜ pending |
| 1-03-01 | 03 | 2 | HOP-02 | — | N/A | manual-only | every press fires — see Manual-Only table | N/A | ⬜ pending |
| 1-03-02 | 03 | 2 | HOP-03 | — | N/A | manual-only | correct screen, not pinned at an edge — see Manual-Only table | N/A | ⬜ pending |
| 1-03-03 | 03 | 2 | HOP-02 | — | N/A | integration | `il-doctor --test` green after the change, and the detached self-check still recentres a deliberately failed hop | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task IDs are provisional — the planner owns the real numbering. The wave
assignment is not: Wave 0's falsification pass gates everything built on the
oracle.*

---

## Wave 0 Requirements

Ordered. The first item is free and should run before any code is written.

- [ ] **`il-side-watch` restart-history check** —
      `journalctl --user -u il-side-watch.service --since "-7 days"`. Zero
      keypresses, zero risk, and it either supports or deflates the research's
      top-ranked mechanism (`Restart=always RestartSec=3` with
      `journalctl -f -n 0` losing every transition in the ~3s gap). Run it first.
- [ ] **A1 falsification pass** — one human-driven known-good hop with
      `hyprctl cursorpos` sampled immediately before and immediately after
      `centre_mac()`. Everything downstream depends on the answer, and a failure
      here has design cost: the fallback likely reintroduces the ~450ms journal
      wait D-15 forbids. **Blocks the oracle work; does not block the restart
      check.**
- [ ] **`ILHOP_DEBUG` logging (D-11/D-12)** — the log lines that both the harness
      and the passive route depend on do not exist yet. Not optional preamble;
      it is Wave 0 work. Must carry a wall-clock timestamp per line, so that the
      *absence* of a line correlated with a human's failed press is itself
      diagnostic of a failure upstream of `il-jump`.
- [ ] **Reproduction harness** — Routes 1 and 3 combined: inject a known side-file
      value, invoke `il-jump` directly, assert on exit code, absence of a
      `ydotool` invocation, and debug-log content.
- [ ] **Non-circular landing oracle (D-14/D-16)** — blocked on the A1 pass above.

---

## Manual-Only Verifications

The author's keypresses are a budgeted resource. Per D-21 they are spent
**confirming**, never fishing for a failure — no plan may ask for repeated
pressing to make a bug appear.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A1 falsification: does `cursorpos` freeze under capture? | HOP-03 | Requires a genuine hop, and the keybind path cannot be simulated | Sample `hyprctl cursorpos`; hop by hand; sample again immediately after `centre_mac()`. Frozen at the pre-crossing edge value ⇒ A1 holds. Tracking the local deltas ⇒ A1 is false and D-14 needs replacing |
| Every press fires, both directions | HOP-02 | `ydotool` cannot fire a Hyprland keybind — 0 fires measured | Author presses the bind in ordinary use across a session, both directions. No silent no-op, no swallowed press. The pass bar is a stated count agreed in the plan, not "it seemed fine" |
| Lands on the correct screen, not pinned at an edge | HOP-03 | Requires the author watching it land | Author watches the landing in both directions. **Expected to confirm, not repair** — per D-03 the user reports landing at screen centre already works; screen centre being the wrong *target* is HOP-05 / Phase 3.1's problem, not a defect here |
| No wedged keyboard or mouse after the change | HOP-02 | The project's scar — this exact class of failure shipped once on reasoning alone | Run the changed code as the daily driver for a full working session with no reach for `il-reset` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 6s
- [ ] Human-only rows satisfied with the author at the keyboard
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
