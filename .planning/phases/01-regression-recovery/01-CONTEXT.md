# Phase 1: Regression Recovery - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Reproduce, root-cause, and close HOP-02 (the hop intermittently does not fire) and
HOP-03 (the pointer lands somewhere other than dead centre). Reproduction is the
gate: no fix is written before a recorded sequence makes each defect happen on
demand. If a defect cannot be reproduced, that is the phase's finding and is
recorded as such.

This phase does not add capability. The one exception granted below is an
opt-in debug log, because the fastest route to reproduction is making `il-jump`
say why it refused.

</domain>

<decisions>
## Implementation Decisions

### Observed Behaviour (user report — the primary evidence)

- **D-01:** HOP-02 fails in **both** directions, not just the ssh return leg.
- **D-02:** When it fails it **stays dead for a while** — repeated presses keep
  doing nothing until something else changes. It is NOT a one-press transient.
  This rules out the single-shot silent exits (`il-jump:54` stale `flock`,
  `il-jump:168` superseded sequence), because either would clear on the next
  press. It points at persistent wrong *state*.
- **D-03:** HOP-03's landing position **varies each time** — not a fixed offset.
  This argues against the constant `mac_width / 4` nudge at `il-jump:140` being
  the sole cause, and toward the optimistic recentre racing the crossing.
- **D-04:** Whether the two defects co-occur is **unknown** — not yet observed
  either way. Do not assume a shared cause; do not assume independence.

### Leading Hypothesis (to be proven or killed, not assumed)

- **D-05:** The side file at `$XDG_RUNTIME_DIR/il-side` going stale or wrong is
  the leading candidate for HOP-02. `il-jump:91` is
  `[ "$CUR" = "$want" ] && exit 0` — if the file claims you are already on the
  target side, every press is a silent no-op until `il-side-watch` corrects it
  on a client connect/disconnect. That matches D-02's persistence exactly, and
  it is direction-symmetric, matching D-01.
- **D-06:** The side file and the toggle that reads it are `92f64bc` machinery —
  which lands *after* the last known-good test. See the commit window below.

### Diff Window (corrects a factual error in PROJECT.md and ROADMAP.md)

- **D-07:** The investigated window is **`849b6ac..9d1f129`**, not `9d1f129`
  alone. `~/.dotfiles` history:

  | Commit | Date | Subject |
  |---|---|---|
  | `6b2a311` | 09-09 18:48 | input-leap: two-machine screen switching, cursor centering |
  | `aa7b6c2` | 09-09 19:01 | il-jump: instant hop (~700ms -> ~25ms) and land on centre |
  | `849b6ac` | 09-09 19:04 | binds: one chord for the machine hop - ALT+C |
  | `92f64bc` | 09-10 00:57 | il-jump: direction-aware and self-healing |
  | `6fc6dbe` | 09-10 01:17 | il-jump: stop the far side being deaf |
  | `9d1f129` | 09-10 01:23 | Revert the modifier re-press; add il-reset |

  Both journals record the paths as tested-good on **2026-09-09**. The last
  09-09 commit is `849b6ac`. Everything from `92f64bc` onward — including the
  entire direction-aware / side-file rewrite — postdates that test and is inside
  the suspect window. PROJECT.md's Active list and ROADMAP.md Phase 1 both name
  `9d1f129` alone, which is 49 lines of `il-jump` plus `il-reset` and excludes
  the machinery D-05 points at.
- **D-08:** PROJECT.md and ROADMAP.md are **amended after this phase**, not
  before — the corrected window is evidence-backed but the *cause* is still
  provisional until reproduction confirms it. This CONTEXT.md is the record in
  the meantime.
- **D-09:** Method is **read the diffs cold first**. Only check out an
  older `il-jump` if reading cannot settle it. Rationale: checking out an old
  version puts it on the live input path, which the project's hardest constraint
  governs. — **Reversibility:** reversible — a reading order, not a structure.
- **D-10:** The working tree is **clean** against `9d1f129` (verified
  2026-09-10), so the live scripts are exactly HEAD. Bisecting is cheap and no
  uncommitted drift has to be reconciled first.

### Instrumentation

- **D-11:** Add a debug log behind **`ILHOP_DEBUG=1`**, writing one line per exit
  path in `il-jump`. Off by default — the daily driver's behaviour is unchanged
  when the variable is unset. There are at least four silent `exit 0` paths
  (`:54` stale lock, `:91` already-on-side, `:168` superseded sequence, `:169`
  watcher unknown) and today none of them is distinguishable from "the keybind
  never fired at all". — **Reversibility:** reversible — additive, gated,
  removable in one commit.
- **D-12:** The sink is a **log file under `$XDG_RUNTIME_DIR`**, alongside
  `il-side`. Chosen over `systemd-cat` specifically because `il-side-watch`
  follows the journal, and adding writes there pollutes the stream another
  component parses. Chosen over `notify-send` because toasts are useless for
  after-the-fact forensics.
- **D-13:** The instrumentation **survives the phase** and folds into
  `ilhop doctor` (DIAG-01, Phase 4). A refusal log is exactly what doctor should
  be able to read. Phase 4 inherits it rather than rebuilding it.

### Measurement and Ground Truth

- **D-14:** The oracle is **`hyprctl cursorpos` locally, plus input-leap's own
  journal enter/leave lines for the far side**. No new Mac-side helper.
  Rationale: a `CGEvent` location reader over ssh costs 40–110ms warm and ~1.6s
  on a lapsed control master — the exact leg Phase 2 exists to repair — and adds
  compiled code to the Mac against the POSIX-shell-only constraint. `cursorpos`
  is local, free, and decisive: if the pointer is still on Ryuk after a
  hop-to-Mac, the hop failed. The journal is the source `il-side` is *derived*
  from, so reading it directly removes the suspected middleman without changing
  the log level (which stays at `--debug INFO`; see PROJECT.md Constraints).
- **D-15:** Measurement runs **after the hop, detached** — never inside it.
  Awaiting confirmation in the hot path is the specific regression PROJECT.md
  bans (it cost ~450ms and made the hop feel laggy). Same shape as the existing
  detached self-check.
- **D-16:** **`il-doctor:110` is circular and is fixed in this phase.** It judges
  "hop landed" by reading `$RUN/il-side` — the file under suspicion. It can
  report a passing round trip while the hop did nothing. Phase 1 needs a
  trustworthy oracle regardless, so the reproduction harness and the health check
  share one truth source rather than each inventing their own.
  — **Reversibility:** costly — Phase 4 (DIAG-01) builds on whatever oracle this
  phase establishes; changing it later touches doctor and the reproduction
  harness together.

### Scope

- **D-17:** If the cause turns out to be `92f64bc`'s toggle/side-file **design**
  rather than a small slip, **Phase 1 fixes it here**. HOP-02 and HOP-03 are the
  requirements and this phase pays whatever they cost. Explicit user decision,
  chosen over checkpointing back for a scope call. — **Reversibility:** one-way —
  a redesign of the side-file/toggle mechanism changes the contract every later
  phase builds on (Phase 2's handoff, Phase 4's doctor, Phase 5's install), and
  undoing it after those land means unwinding all three.
- **D-18:** HOP-03's acceptance bar for **this phase** is "lands on the correct
  screen and is not pinned against an edge" — not a percentage ring around
  screen centre. Rationale: HOP-05 (below) replaces screen-centre as the target
  outright, so tightening a tolerance around a bullseye already agreed to be the
  wrong one is wasted work. Phase 1 catches the failure; HOP-05 defines the
  target. Claude's call, offered to the user for override.

### New Requirement Raised During Discussion — HOP-05

- **D-19:** The user rejects screen-centre as the correct landing target:
  with two windows on the Mac, screen-centre lands the pointer *between* them.
  The wanted behaviour is **the centre of the window nearest the crossed edge,
  with that window taking focus**; with a single window, the centre of that
  window rather than of the screen.
- **D-20:** This is accepted as a **new v1 requirement, HOP-05**, and slotted
  **after Phase 2 and Phase 3** so it inherits both — Phase 2's repaired return
  leg (the Mac-side geometry fetch runs over that link) and Phase 3's window
  geometry work (`hyprctl clients` is already used by `il-focus-jump`; AeroSpace
  is the Mac analogue). Not folded into Phase 1, whose job is minimal-change
  regression repair. Not deferred to v2 alongside VIS-02.
  **Action pending:** REQUIREMENTS.md gains HOP-05 and ROADMAP.md gains its
  phase via `/gsd-phase` — this CONTEXT.md is not that record.

### Claude's Discretion

The user declined a second discussion round; these stay open, with defaults:

- **`il-jump:91`'s guard.** Whether to repair the state and keep the guard,
  verify reality before trusting it, allow a second press to force through, or
  something else — deliberately **not pre-committed**. Decide once reproduction
  proves the mechanism. The guard's own comment says shoving again would bury the
  pointer further off-screen, so weakening it is not free.
- **Whether `il-side-watch` is in scope.** If the side file proves to be lying,
  the watcher that writes it is the suspect. It is a systemd unit following
  journald, so restarting it mid-hunt destroys the state being investigated.
  Default: read-only observation first; touch it only once the mechanism is
  proven.
- **Reproduction harness vs. organic waiting.** D-02 means organic reproduction
  could take a full session. Default: a scripted stressor invoking `il-jump`
  directly (keybinds cannot be simulated in any case — see Constraints), used to
  *narrow* the trigger, with the confirming press always made by hand.
- **How many good presses close an intermittent defect.** Default: a bar stated
  explicitly in the plan rather than left implicit; three presses prove nothing
  about a defect that appears occasionally.
- **How hard to repair the landing path**, given HOP-05 will rewrite
  `centre_mac` / `centre_nastralis`. Default: repair the mechanism, not the
  geometry — fix whatever makes the result vary, and leave the target coordinate
  alone for HOP-05.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level constraints (non-negotiable)
- `.planning/PROJECT.md` §Constraints — the verification, testability, tech
  stack, compositor coupling, log level, and latency-budget constraints. The
  verification constraint governs every task in this phase.
- `.planning/PROJECT.md` §Context "The scar" — why unverified reasoning is
  banned on the input path. Origin of the whole gating rule.
- `.planning/PROJECT.md` §Key Decisions — "Never re-press held modifiers through
  ydotool" is closed; do not reopen it.
- `.planning/REQUIREMENTS.md` §Verification Constraint — `ydotool` keys do not
  fire Hyprland keybinds; a modifier-flag read alone is not proof.

### Phase scope
- `.planning/ROADMAP.md` §"Phase 1: Regression Recovery" — the five success
  criteria. Note criterion 2 names `9d1f129`; D-07 above corrects that window.
- `.planning/ROADMAP.md` §Verification Gates — which work is scriptable and which
  requires a human; a green `il-doctor` is not a release gate on its own.

### Live source under investigation
- `~/.local/bin/il-jump` — the hop. Silent exits at `:54`, `:91`, `:168`, `:169`;
  centring at `:116` (`centre_nastralis`), `:137` (`centre_mac`), nudge at `:140`;
  optimistic recentre at `:156`–`:161`; detached self-check at `:166`–`:179`.
- `~/.local/bin/il-side-watch` — writes `$XDG_RUNTIME_DIR/il-side` by following
  the input-leap journal.
- `~/.local/bin/il-doctor` — `:110` is the circular landing check (D-16);
  `:102` caches `il-mac-width` and documents the `/4` recentre nudge.
- `~/.local/bin/il-reset`, `~/.local/bin/il-heldmods`,
  `~/.local/bin/il-focus-jump` — the rest of the surface.
- `~/.dotfiles` (bare repo, work tree `$HOME`) — the history holding
  `849b6ac..9d1f129`. Access as
  `git --git-dir=$HOME/.dotfiles --work-tree=$HOME`.

### Environment
- `.planning/codebase/README.md` — scope note: the codebase maps document
  `/home/nastralis`, the host environment, not the `ilhop` repo. Deliberate.
- `.planning/research/PITFALLS.md`, `.planning/research/ARCHITECTURE.md` —
  domain-level failure modes and build order.
- `~/.local/share/ryoku/rashin/journal/2026-09-09.md` and `2026-09-10.md` —
  the tested-good records and the scar's own account.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The detached self-check in `il-jump` (`:166`–`:179`)** — already the correct
  shape for D-15's after-the-fact measurement: it fires ~1.2s later, retries
  once, recentres and notifies if the far screen never took it. The measurement
  work extends this rather than inventing a second detached path.
- **`ydotool_ok()` (`:61`)** — the 0px liveness probe, already handling the stale
  socket case where `[ -S ]` lies.
- **The single-flight `flock` (`:54`)** — already prevents interleaved hops;
  whatever instrumentation is added must not race it.
- **`hyprctl clients` geometry reading in `il-focus-jump`** — the local-side
  window geometry pattern HOP-05 will build on.

### Established Patterns
- Every script is standalone POSIX shell with `set -uo pipefail`; no shared
  library exists yet. The `lib/backend-*.sh` seam is Phase 4's work — Phase 1
  must not start it.
- Compositor calls go through the Ryoku fork's Lua API (`hl.dsp.*`); plain
  `hyprctl dispatch movecursor` fails with a parse error. Do not scatter new
  call sites.
- `ydotool mousemove -a` (absolute) is broken on this stack — relative only,
  documented at `il-jump:34`.

### Integration Points
- `$XDG_RUNTIME_DIR/il-side` — written by `il-side-watch`, read by `il-jump`
  (`:41`) and by `il-doctor` (`:110`). The suspected liar and the shared
  coupling point between all three.
- `$XDG_RUNTIME_DIR/il-mac-width` — cached Mac width, source of the `/4` nudge.
- `input-leap-server.service` journal at `--debug INFO` — followed by
  `il-side-watch`, and D-14's far-side arbiter. Raising the log level to DEBUG
  is banned (~4487 lines/minute).
- The new debug log lands beside these under `$XDG_RUNTIME_DIR` (D-12).

</code_context>

<specifics>
## Specific Ideas

- The user's own words on the landing target: with the cursor starting on Ryuk
  and two windows open on the Mac, `ALT+C` / `ALT+H` puts the pointer at the
  actual centre *between* the two windows. Wanted: the centre of the window
  nearest the crossed edge, which then takes focus instantly; with one window,
  the centre of that window rather than of the screen. Recorded as HOP-05 (D-19,
  D-20) — this is user-supplied intent, not an instruction to a later agent.

</specifics>

<deferred>
## Deferred Ideas

- **HOP-05 — window-centre landing with focus.** Not deferred out of v1, but
  deferred out of *this phase*: slotted after Phase 2 and Phase 3 so it inherits
  the repaired return leg and the window-geometry work. See D-19/D-20. Needs
  REQUIREMENTS.md and ROADMAP.md updates via `/gsd-phase`.
- **`ilhop doctor`'s non-circular landing check** — Phase 1 establishes the
  oracle (D-16); Phase 4 (DIAG-01) is where doctor's full surface is built on it.
- **The `lib/backend-*.sh` compositor seam** — Phase 4, alongside the rename.
  Phase 1 must not begin isolating compositor calls.

</deferred>

---

*Phase: 01-regression-recovery*
*Context gathered: 2026-09-10*
