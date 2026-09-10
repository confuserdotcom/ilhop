# Phase 1: Regression Recovery - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-10
**Phase:** 01-regression-recovery
**Areas discussed:** What you actually see, Breaking the silent exits, Diff window, Ground truth for landing

---

## What You Actually See

### HOP-02 no-fire: which direction?

| Option | Description | Selected |
|--------|-------------|----------|
| Ryuk → Mac | Only when hopping away from the Linux box | |
| Mac → Ryuk | Only on the return leg (the ssh path) | |
| Both directions | Happens either way | ✓ |
| Haven't tracked it | Noticed the failure but not which way | |

### HOP-02: does pressing again immediately work?

| Option | Description | Selected |
|--------|-------------|----------|
| Second press works | One dud, then fine — transient (stale lock, in-flight seq) | |
| Stays dead a while | Repeated presses do nothing until something else happens | ✓ |
| Mouse-cross fixes it | Dead until pointer dragged across the edge — fingers the side file | |
| Haven't tried | Usually just grab the mouse | |

### HOP-03: where does the pointer end up?

| Option | Description | Selected |
|--------|-------------|----------|
| Pinned at an edge | Overshoot pinned it, recentre never ran | |
| Off-centre but on screen | Fits the `mac_width/4` nudge at `il-jump:140` | |
| Varies each time | No consistent spot | ✓ |
| Wrong screen entirely | Back where it started, or wrong monitor | |

### Do the two bugs co-occur?

| Option | Description | Selected |
|--------|-------------|----------|
| Independent | Seen each alone, no linking pattern | |
| Often same session | Suggests one shared cause | |
| Landing bug is constant | Only the no-fire is intermittent | |
| Haven't noticed | No read on this | ✓ |

**Notes:** "Stays dead a while" was the decisive answer — it eliminates the
single-shot silent exits, since a stale lock or a superseded sequence would clear
on the next press. Persistent refusal implicates persistent state, which points
at the side file.

---

## Breaking the Silent Exits

### Add instrumentation at all?

| Option | Description | Selected |
|--------|-------------|----------|
| Debug log behind env var | `ILHOP_DEBUG=1`, off by default, zero daily-driver risk | ✓ |
| Always-on, user-visible | Every refusal fires a toast — ships noise to v1 | |
| Diagnose read-only first | Watch side file and journal by hand, no code change | |

### Where does the signal land?

| Option | Description | Selected |
|--------|-------------|----------|
| Log file in `XDG_RUNTIME_DIR` | Beside `il-side`; tailable, no journald noise | ✓ |
| `systemd-cat` to the journal | Correlatable — but adds writes to the stream `il-side-watch` follows | |
| `notify-send` toast | Unmissable live, useless for forensics | |

### If the side file is the cause, what may change at `il-jump:91`?

| Option | Description | Selected |
|--------|-------------|----------|
| Fix the state, keep the guard | Guard is right; the file lying is the bug | |
| Verify state before trusting it | Cross-check reality before refusing — costs hot-path time | |
| Let a second press force it | Escape hatch even if root cause survives | |
| You decide after reproduction | Do not pre-commit | ✓ |

### Does the instrumentation survive?

| Option | Description | Selected |
|--------|-------------|----------|
| Survives — folds into `ilhop doctor` | Phase 4's DIAG-01 should read a refusal log | ✓ |
| Rip it out | Phase 1 leaves no trace beyond the fix | |

---

## Diff Window

### Which commit window does Phase 1 investigate?

| Option | Description | Selected |
|--------|-------------|----------|
| `849b6ac..9d1f129` | Last 09-09 commit through HEAD; includes the `92f64bc` rewrite | ✓ |
| `9d1f129` only | As PROJECT.md says — 49 lines plus `il-reset` | |
| Empirical bisect, no prior frame | Let `git bisect` name it | |

### How far do we go in testing old commits?

| Option | Description | Selected |
|--------|-------------|----------|
| Read the diffs first | Only check out an old version if reading cannot settle it | ✓ |
| Check out and press keys | Real bisect — swaps the daily driver's hop each step | |
| Side-by-side scratch copy | Invoke `il-jump-849b6ac` directly, keybind stays live | |

### When are the docs corrected?

| Option | Description | Selected |
|--------|-------------|----------|
| CONTEXT.md now, amend after the phase | Cause is provisional until reproduction confirms it | ✓ |
| Amend PROJECT.md now | Commit dates are hard evidence, independent of reproduction | |

### If the cause is `92f64bc`'s design, not a slip?

| Option | Description | Selected |
|--------|-------------|----------|
| Fix it here | HOP-02/03 are the requirements; the phase pays the cost | ✓ |
| Record and checkpoint | Stop, report, let the user rescope | |

**Notes:** The commit-date evidence was gathered by scouting `~/.dotfiles`
before any question was asked. The 09-09 tested-good record ends at `849b6ac`
(19:04); `92f64bc` lands 00:57 the following day. Working tree verified clean
against `9d1f129`, so bisecting has no uncommitted drift to reconcile.

---

## Ground Truth for Landing

### What establishes where the pointer really is?

| Option | Description | Selected |
|--------|-------------|----------|
| `hyprctl cursorpos` + a Mac helper | Both halves answer for themselves; Mac helper is new code over the slow leg | |
| `hyprctl cursorpos` only | Linux side authoritative for "did it leave" | |
| input-leap journal as arbiter | The transport's own truth, no new code | |

**User's choice:** free text — *"choose the best course of action for performance,
scalability, and latency."*

**Resolution (Claude's call, recorded as D-14):** `hyprctl cursorpos` locally
**plus** the input-leap journal for the far side; **no** new Mac-side helper. A
`CGEvent` reader over ssh costs 40–110ms warm and ~1.6s cold on precisely the leg
Phase 2 exists to repair, and adds compiled code to the Mac against the
POSIX-shell-only constraint.

### Hot path or after?

| Option | Description | Selected |
|--------|-------------|----------|
| After, detached | Never touches the 50ms budget | ✓ |
| Inside the hop, behind the debug flag | Measures live — but a debug-only path is not the shipped path | |

### `il-doctor:110` circularity — now or Phase 4?

| Option | Description | Selected |
|--------|-------------|----------|
| Fix it in Phase 1 | Reproduction and health check share one truth source | ✓ |
| Note it, leave for Phase 4 | DIAG-01 owns doctor | |

### What counts as "dead centre"?

| Option | Description | Selected |
|--------|-------------|----------|
| Within 5% of screen centre | ~64px on a 1280-wide screen | |
| Anywhere not touching an edge | Catches the pinned failure and nothing else | |
| You cannot tell by eye | Human judgement as criterion | |

**User's choice:** free text — the user rejected the premise rather than picking a
tolerance: *"the cursor begins on ryuk right, and on mac i have actually two
windows, so when i move the cursor to mac using alt-h or alt-c it moves to the
actual center BETWEEN the two windows, why not just the center of the nearest
window to the edge and it gets focus instantly you know, and if there is just one
window same get the center of that actual window, not the center of the screen."*

**Follow-up asked (plain text, per the freeform rule):** whether to (a) write it
up as new v1 requirement HOP-05 slotted after Phases 2 and 3, (b) fold it into
Phase 1, or (c) park it in v2 beside VIS-02.

**User's answer:** **(a)**.

**Tolerance left unanswered — Claude's call, recorded as D-18:** for Phase 1 the
bar is "lands on the correct screen and is not pinned against an edge". HOP-05
replaces screen-centre as the target, so tightening a ring around a bullseye
already agreed to be wrong is wasted work. Offered to the user for override.

---

## Second Round

Four further gray areas were offered after the main areas closed:
`il-side-watch` scope, reproduction harness vs. organic waiting, what proves an
intermittent bug fixed, and how hard to repair landing given HOP-05.

**User's response:** *"Nothing, never mind"* — declined. All four are recorded in
CONTEXT.md under Claude's Discretion with stated defaults so planning is not
blocked.

---

## Claude's Discretion

- The fate of `il-jump:91`'s guard — explicitly deferred by the user until
  reproduction proves the mechanism.
- Whether `il-side-watch` is in scope.
- Reproduction harness vs. waiting for organic recurrence.
- How many good presses close an intermittent defect.
- How hard to repair the landing path given HOP-05 will rewrite it.
- The far-side measurement approach (resolved above as D-14).
- HOP-03's Phase 1 acceptance bar (resolved above as D-18).

## Deferred Ideas

- **HOP-05** — window-centre landing with focus. New v1 requirement, slotted
  after Phases 2 and 3. Requires REQUIREMENTS.md and ROADMAP.md updates.
- **Non-circular landing check in `ilhop doctor`** — oracle established in
  Phase 1, doctor's full surface built on it in Phase 4 (DIAG-01).
- **`lib/backend-*.sh` compositor seam** — Phase 4, with the rename.
