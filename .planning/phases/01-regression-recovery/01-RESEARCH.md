# Phase 1: Regression Recovery - Research

**Researched:** 2026-09-10
**Domain:** Reproducing and root-causing an intermittent no-op in a local shell script (`il-jump`) that drives a cross-machine pointer hop over input-leap; and auditing whether the current landing behaviour is actually a defect.
**Confidence:** MEDIUM-HIGH — the code-path claims are `[VERIFIED]` from reading the live scripts and the bare-repo diff directly. The input-leap journal-semantics claims are `[VERIFIED: primary source]` from fetching input-leap's own `Server.cpp`. The `hyprctl cursorpos`-as-oracle claim is `[ASSUMED]` — no primary source confirms it directly; it is inferred from the scripts' own comments and needs a human-verified falsification pass before the plan treats it as settled (see Assumptions Log).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** HOP-02 fails in **both** directions, not just the ssh return leg.
- **D-02:** When it fails it **stays dead for a while** — repeated presses keep doing nothing until something else changes. It is NOT a one-press transient. This rules out the single-shot silent exits (`il-jump:54` stale `flock`, `il-jump:168` superseded sequence), because either would clear on the next press. It points at persistent wrong *state*.
- **D-03:** ~~HOP-03's landing position varies each time.~~ **Corrected by the user after the discussion closed (2026-09-10):** the pointer *does* land at the centre of the screen right now — that part works as specified. The complaint is that screen centre is the wrong place to land, because with two windows open it is the gap between them. **Consequence for this phase:** HOP-03 may not be a defect at all. Phase 1 must test the possibility that current landing behaviour is correct-as-written, in which case the finding is "HOP-03 is not reproducible; the requirement's target was wrong, and HOP-05 (Phase 3.1) supersedes it" — not a fix.
- **D-04:** Whether the two defects co-occur is **unknown**. Do not assume a shared cause; do not assume independence.
- **D-05:** The side file at `$XDG_RUNTIME_DIR/il-side` going stale or wrong is the leading candidate for HOP-02. `il-jump:91` is `[ "$CUR" = "$want" ] && exit 0` — if the file claims you are already on the target side, every press is a silent no-op until `il-side-watch` corrects it on a client connect/disconnect. That matches D-02's persistence exactly, and it is direction-symmetric, matching D-01.
- **D-06:** The side file and the toggle that reads it are `92f64bc` machinery — which lands *after* the last known-good test.
- **D-07:** The investigated window is **`849b6ac..9d1f129`**, not `9d1f129` alone (table of 6 commits, 09-09 18:48 through 09-10 01:23). The last 09-09 commit is `849b6ac`. Everything from `92f64bc` onward — including the entire direction-aware / side-file rewrite — postdates the last tested-good record and is inside the suspect window.
- **D-08:** PROJECT.md and ROADMAP.md are amended **after** this phase, not before.
- **D-09:** Method is **read the diffs cold first**. Only check out an older `il-jump` if reading cannot settle it — checking out an old version puts it on the live input path.
- **D-10:** The working tree is **clean** against `9d1f129` (verified 2026-09-10) — the live scripts are exactly HEAD.
- **D-11:** Add a debug log behind **`ILHOP_DEBUG=1`**, one line per exit path in `il-jump`. Off by default. At least four silent `exit 0` paths (`:54` stale lock, `:91` already-on-side, `:168` superseded sequence, `:169` watcher unknown) are today indistinguishable from "the keybind never fired at all."
- **D-12:** The sink is a **log file under `$XDG_RUNTIME_DIR`**, alongside `il-side`. Not `systemd-cat` (pollutes the stream `il-side-watch` parses). Not `notify-send` (useless for after-the-fact forensics).
- **D-13:** The instrumentation **survives the phase** and folds into `ilhop doctor` (DIAG-01, Phase 4).
- **D-14:** The oracle is **`hyprctl cursorpos` locally, plus input-leap's own journal enter/leave lines for the far side**. No new Mac-side helper. `cursorpos` is local, free, and decisive per this decision's rationale: "if the pointer is still on Ryuk after a hop-to-Mac, the hop failed." — **this research finds this claim needs a falsification pass; see Q6 below and the Assumptions Log.**
- **D-15:** Measurement runs **after the hop, detached** — never inside it.
- **D-16:** **`il-doctor:110` is circular and is fixed in this phase.** It judges "hop landed" by reading `$RUN/il-side` — the file under suspicion.
- **D-17:** If the cause turns out to be `92f64bc`'s toggle/side-file **design** rather than a small slip, **Phase 1 fixes it here**.
- **D-18:** HOP-03's acceptance bar for this phase is "lands on the correct screen and is not pinned against an edge" — not a percentage ring around screen centre.
- **D-19/D-20:** New requirement HOP-05 (window-centre landing with focus), slotted at Phase 3.1, deferred out of this phase.
- **D-21 (hard constraint):** The user will not spam the chord to reproduce. Three sanctioned routes only: (1) a scripted stressor invoking `il-jump` directly in a loop; (2) passive `ILHOP_DEBUG=1` logging awaiting organic failure; (3) deliberate wrong-value injection into `$XDG_RUNTIME_DIR/il-side`.

### Claude's Discretion

- **`il-jump:91`'s guard** — repair state and keep the guard, verify reality before trusting it, allow a second press to force through, or something else. Not pre-committed; decide once reproduction proves the mechanism.
- **Whether `il-side-watch` is in scope** — default: read-only observation first; touch it only once the mechanism is proven. Restarting it mid-hunt destroys the state being investigated.
- **How many good presses close an intermittent defect** — default: a bar stated explicitly in the plan.
- **How hard to repair the landing path** — default: repair the mechanism, not the geometry; leave the target coordinate alone for HOP-05.

### Deferred Ideas (OUT OF SCOPE for this phase)

- HOP-05 — window-centre landing with focus (Phase 3.1).
- `ilhop doctor`'s non-circular landing check beyond establishing the oracle — full surface is Phase 4 (DIAG-01).
- The `lib/backend-*.sh` compositor seam — Phase 4, alongside the rename. Phase 1 must not begin isolating compositor calls.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOP-02 | The hop fires on every press of the bind — reproduce, root-cause, and close the intermittent "sometimes doesn't fire" report. Reproduction precedes any fix. | Q2 (stale-state mechanisms, ranked), Q3 (diff confirms the whole toggle/side-file/guard machinery is new since the last known-good commit), Q4 (which of the 3 sanctioned reproduction routes to use and what each proves/doesn't prove), Q5 (how to instrument `ILHOP_DEBUG` without adding latency or races) |
| HOP-03 | The pointer lands dead centre of the destination screen on every hop — settle whether this is a live defect at all (D-03 says probably not). | Q3 (diff shows the landing math also changed in the suspect window, from hardcoded constants to computed geometry), Q6 (whether `hyprctl cursorpos` can serve as the local oracle for "did it land"), the Standard Stack / Architecture sections below for the reproduction harness that also has to validate landing |
</phase_requirements>

## Summary

Everything needed to root-cause HOP-02 is already readable without touching the keyboard. The full diff `849b6ac..9d1f129` was recovered (the earlier pathspec-filtered `git diff -- <path>` silently returned nothing in this sandboxed shell — a tool quirk, not a repo problem; the unfiltered `git diff <ref> <ref>` worked and was sliced by hand) and shows the current `il-jump` is **byte-for-byte the `92f64bc` version** — commit `6fc6dbe`'s modifier re-press machinery was added and then completely and cleanly reverted by `9d1f129`, leaving zero residue in `il-jump` itself (only `il-heldmods` and `il-reset` survive from that detour). This means the entire toggle-mode / side-file / self-check / single-flight-lock apparatus D-05 suspects has been running, unchanged, continuously since 2026-09-10 00:57 — one hour after the last commit recorded tested-good. `849b6ac`'s `il-jump` had none of this: no side file, no toggle, fixed-direction binds, hardcoded landing constants. This is the single clearest finding of the phase: **the entire mechanism under suspicion is the regression window**, not a hunk within it.

Reading `il-side-watch` end to end against input-leap's own upstream source (`Server.cpp`, fetched and quoted below) turns up a concrete, previously-undocumented failure mechanism that fits the user's reported symptom shape (fails both directions, persists across presses, self-corrects eventually) better than a generic "state went stale": **`il-side-watch.service` restarts (systemd `Restart=always RestartSec=3`) attach `journalctl -f -n 0` fresh each time, with `-n 0` meaning zero backlog** — any screen-switch or connect/disconnect line emitted during that ~3-second restart gap is not delayed, it is **permanently lost**, and the side file is frozen at its pre-restart value until the *next* real transition happens to come along and correct it. That "frozen until something else changes" shape is exactly D-02. This is ranked the top candidate below (Q2), ahead of the unparsable-hostname case and the read/write race, both of which are real but structurally less likely to explain a *persistent* (rather than single-press) failure.

Primary-source input-leap research (Q1) settles the arbiter question D-14 leans on: the journal is **transition-only** — there is no periodic or on-demand "who owns the pointer right now" log line, confirmed by direct inspection of `Server.cpp`'s logging call sites. `il-side` is therefore not "one middleman that could be cut out" — it is *the only summarizing view of a transition-only stream that exists*, and any oracle built directly on the journal inherits the identical structural gap (a missed line is a missed line, whether `il-side-watch` or the reproduction harness reads it). Also newly found and load-bearing: on a server *process* restart `m_active` resets unconditionally to the primary client with **no log line marking the reset** — so `il-reset`'s own `systemctl --user restart input-leap-server.service` step can silently desynchronize `il-side` from reality if the file said `mac` beforehand, unless the subsequent client reconnect's `"has connected"` NOTE line is what actually re-syncs it (which it is, by design — but only once the Mac client notices and reconnects).

D-14's proposed oracle — `hyprctl cursorpos` locally — is architecturally plausible but **not directly verified against a primary source in this research pass** (Q6). The scripts' own comments describe two independent cursor models (the compositor's rendered/local one, and input-leap's internally-tracked relative-motion one), which is the right shape for `cursorpos` to be decisive: once input-leap's server-side input-capture takes over, subsequent synthetic events should stop reaching the compositor's normal pointer pipeline, so `cursorpos` should *freeze* rather than keep tracking the script's own `shove`/`centre_mac` deltas. This is a testable, falsifiable claim the reproduction harness should check directly before Phase 1 relies on it — it is flagged `[ASSUMED]` here, not `[VERIFIED]`, precisely because no upstream doc or source line was found stating it.

For HOP-03: the diff confirms the landing math changed in the same window (hardcoded `430`/`(1280,720)` → geometry-derived `centre_mac()`/`centre_nastralis()`), but D-03's user correction means this is very likely a **non-defect** to be confirmed and closed, not repaired.

## Architectural Responsibility Map

This is a single-host, two-machine shell system, not a multi-tier web app — the standard Browser/SSR/API/CDN/DB tiers do not apply. The table below substitutes the domain's actual layers.

| Capability | Owning Layer | Secondary | Rationale |
|------------|-------------|-----------|-----------|
| Ground truth of "who owns the pointer" | input-leap server process (`m_active` in-memory) | — | The only authoritative value; never logged except at transitions (Q1) |
| Summarized/cached view of that truth | `il-side-watch` (journal follower) → `$XDG_RUNTIME_DIR/il-side` | — | Exists purely because reading the journal synchronously in the hot path was rejected (D-15, latency) |
| Decision logic ("which way, is it worth moving") | `il-jump` (`read_side`, `il-jump:91` guard) | — | Consumer of the cached view; this is where D-05's suspected silent no-op lives |
| Local compositor cursor state | Hyprland (`hyprctl cursorpos`, `hyprctl monitors -j`) | — | Independent of input-leap's own tracked position (Q6); candidate local oracle |
| Health/diagnostics | `il-doctor` | — | Currently reads the *cached* view (`:110`), which is what makes it circular per D-16 |
| Instrumentation (new, this phase) | `il-jump` internal, gated by `ILHOP_DEBUG` | `$XDG_RUNTIME_DIR/il-jump.debug.log` (proposed) | Additive per D-11/D-12; must not touch the journal stream `il-side-watch` parses |
| Reproduction harness (new, this phase) | New script invoking `il-jump` directly + reading the debug log/side file | — | Must not depend on the keybind path at all (cannot be simulated — see Pitfalls) |

## Q1 — input-leap journal semantics (arbiter for D-14)

**Exact log line formats, from input-leap's own `src/lib/server/Server.cpp` (fetched this session):**

- `switchScreen()`: `LOG_INFO("switch from \"%s\" to \"%s\" at %d,%d", getName(m_active).c_str(), getName(dst).c_str(), x, y);` `[VERIFIED: raw.githubusercontent.com/input-leap/input-leap/master/src/lib/server/Server.cpp]`
- `forceLeaveClient()`: `LOG_INFO("jump from \"%s\" to \"%s\" at %d,%d", getName(active).c_str(), getName(m_primaryClient).c_str(), m_x, m_y);` `[VERIFIED: same source]` — **`il-side-watch` does not match this line's `jump from` prefix at all** — it only matches `*'switch from "'*'" to "'*` (see `il-side-watch:24`, read this session, quoted: `*'switch from "'*'" to "'*)`). If `forceLeaveClient()` (a forced/administrative screen change, distinct from a normal edge-cross) is ever what fires in some corner case, `il-side-watch` would silently fail to update the side file for it. `[VERIFIED: il-side-watch.c:24, quoted verbatim above]` combined with `[VERIFIED: Server.cpp]` for the line format itself.
- `adoptClient()`: `LOG_NOTE("client \"%s\" has connected", getName(client).c_str());` `[VERIFIED: same source]`
- `closeClient()`: `LOG_NOTE("disconnecting client \"%s\"", getName(client).c_str());` `[VERIFIED: same source]`
- `handle_client_close_timeout()`: `LOG_NOTE("forced disconnection of client \"%s\"", getName(client).c_str());` `[VERIFIED: same source]`
- `"client \"%s\" has disconnected"` — confirmed to exist and fire in real operation via a genuine pasted user log in [input-leap#339](https://github.com/input-leap/input-leap/issues/339) (`NOTE: client "AJONES-LHQ" has disconnected`), but its exact source file/call site was **not** located in `Server.cpp` in this pass (likely lives in a client-proxy or listener file not fetched). `[CITED: github.com/input-leap/input-leap/issues/339]` for existence and level; `[ASSUMED]` for exact call site.

**Log-level ordering, from the Arch man page (authoritative for the shipped binary):** `[VERIFIED: man.archlinux.org/man/extra/input-leap/input-leaps.1.en]`, quoted verbatim: *"filter out log messages with priority below level. level may be: FATAL, ERROR, WARNING, NOTE, INFO, DEBUG, DEBUG1, DEBUG2."* This list is priority-descending (FATAL most severe/least verbose → DEBUG2 least severe/most verbose); "filter out messages below level" at `--debug INFO` means **NOTE and INFO both pass, DEBUG and noisier do not**. This directly confirms `il-side-watch`'s own comment (`il-side-watch:7-9`, read this session) that `--debug INFO` is sufficient for both the `switch from`/`jump from` lines (INFO) and the `has connected`/`has disconnected`/`disconnecting client` lines (NOTE) — neither would be lost at the mandated log level.

**Is the stream sufficient to answer "where is the pointer right now"?** No — **only at transitions.** `[VERIFIED: Server.cpp, fetched and searched this session]` — the server constructor does not log an initial active screen, there is no periodic status line, and `switchScreen()` fires only on an actual screen-owner transition (not on every pointer motion event). This is the same structural limitation `il-side` already has: both are summaries of a transition-only stream. **Answering the question plainly, as directed: the journal cannot answer "where is the pointer now" independent of having correctly observed every prior transition. It is an event log, not a state query API.** Any oracle (the reproduction harness's or a future `il-doctor`'s) built by reading the journal directly has to reconstruct current state by replaying transitions from a known starting point — it does not remove the class of bug D-05 suspects, it only removes the specific `il-side-watch` process as a point of failure (still leaves "did I see every transition since boot" as an open question, addressed below in Q2).

**Disconnect/reconnect and server restart:** `[VERIFIED: Server.cpp]` — on a server **process** restart, `m_active` is initialized directly in the constructor's member-init list to `primaryClient` (i.e. Nastralis) with **no log line marking the reset**. This matters directly for `il-reset` (`il-reset:19-20`, read this session): it calls `systemctl --user restart input-leap-server.service` unconditionally. If `$RUN/il-side` said `mac` before that restart, the *real* state flips to `nastralis` silently (no journal line), and `il-side` stays wrong until the Mac client's subsequent `"has connected"` NOTE line corrects it — which happens automatically because `input-leap-server.service` restarting drops the existing client connection, forcing a reconnect, but there is a window between the two where `il-side` is stale. This is a second, independent stale-state vector beyond the watcher-restart-gap mechanism in Q2, specific to `il-reset` itself rather than to ordinary operation.

## Q2 — how `il-side` goes stale (ranked)

Read in full this session: `~/.local/bin/il-side-watch` (38 lines).

**#1 — Watcher restart gap with zero backlog (highest-ranked).** `il-side-watch.service`'s unit file (`.config/systemd/user/il-side-watch.service`, seen in the `92f64bc` diff, `[VERIFIED: git show 92f64bc]`) sets `Restart=always RestartSec=3`. Every restart re-runs `il-side-watch:21`, `[VERIFIED: il-side-watch:21, read this session]`, quoted verbatim: `journalctl --user -u input-leap-server.service -f -n 0 --no-pager 2>/dev/null |`. `-n 0` means **the new process starts with zero lines of backlog** — it only sees lines emitted *after* it reattaches. Any switch, connect, or disconnect line emitted during the ~3-second gap between the old process dying and the new one reattaching is not delayed for later delivery; it is gone. The side file is left holding whatever it held at the moment of death, and — critically — **nothing about a normal subsequent switch corrects a stale value that is already wrong in the direction the user is about to press**, because `il-jump:91`'s guard trusts the file at face value on every single subsequent invocation until a transition happens to occur that flips it. This matches D-02 exactly: persistent across many presses, self-correcting only when an unrelated real transition eventually fires. **Rank: most likely**, because it requires no unusual input (a 2-core Broadwell running a `--debug INFO` journal follower dying and restarting under normal memory/CPU pressure is a plausible, recurring event) and produces exactly the observed persistence shape.

**#2 — Unparsable/non-matching destination string.** `il-side-watch:24-31`, `[VERIFIED, read this session]`, quoted verbatim:
```
*'switch from "'*'" to "'*)
    dest=${line#*\" to \"}      # -> Macbook-Air.local" at 1699,445
    dest=${dest%%\"*}           # -> Macbook-Air.local
    case "$dest" in
        Nastralis) printf 'nastralis\n' > "$STATE" ;;
        "")        ;;           # unparsable, leave the last known value
        *)         printf 'mac\n'       > "$STATE" ;;
    esac
```
If `dest` extraction ever produces an empty string (a line shape input-leap emits that doesn't exactly match the expected `switch from "X" to "Y" at x,y` pattern — e.g. `forceLeaveClient()`'s differently-worded `jump from` line noted in Q1, which the outer `case` in `il-side-watch:24` wouldn't even match to begin with, so this specific empty-`dest` branch is actually a secondary trap inside an already-matched line), the comment's own admission is explicit: **"leave the last known value."** Any future hostname change, journal line truncation, or unanticipated wording from an input-leap version bump silently freezes the file at its prior value indefinitely. **Rank: second** — structurally identical persistence to #1, but requires a specific trigger (a non-matching string) that is less likely to recur under normal operation than a systemd restart.

**#3 — Read/write race, `il-jump`'s `read_side()` vs. `il-side-watch`'s plain `>` write.** `il-side-watch` writes with `printf 'nastralis\n' > "$STATE"` (`[VERIFIED: il-side-watch:19,28-30,35, read this session]`) — a plain `>` redirect, which truncates the file before the new content is written. `il-jump:73-77`'s `read_side()` (`[VERIFIED, read this session]`) does `[ -r "$STATE" ] && { read -r CUR < "$STATE" || CUR=unknown; }` — if a read lands in the truncate/write gap, `CUR` becomes empty → falls to `CUR=unknown` via the `[ -n "${CUR:-}" ] || CUR=unknown` fallback on the next line. Looking at the `toggle` case (`il-jump:88-89`, `[VERIFIED, read this session]`): `if [ "$CUR" = mac ]; then dir=right; else dir=left; fi` — `unknown` is not `mac`, so this silently defaults to `dir=left` regardless of true state. **Rank: third/lowest** — the race window is microseconds wide (a `printf` to a tmpfs file), and its effect (assuming "not on mac" and going `left`) does not produce a no-op at all, so it cannot be the mechanism behind D-02's "stays dead" report; it could only ever explain a rare wrong-direction *fire*, not a silent failure to fire, and is listed for completeness rather than as a repro-priority candidate.

**Ranking rationale, stated explicitly:** #1 and #2 both produce the "frozen until an unrelated later transition corrects it" shape D-02 describes; #1 is ranked above #2 because it requires no special trigger beyond ordinary process churn, while #2 requires a specific and so-far unobserved line-shape mismatch. #3 is structurally unable to produce D-02's symptom (a no-op) at all and is included only because the question asked for an exhaustive enumeration, not a filtered one.

`$XDG_RUNTIME_DIR` cleanup (external deletion of `il-side` mid-run) was also considered: `il-side-watch:19`, `[VERIFIED, read this session]`, only reinitializes the file `[ -s "$STATE" ] || printf 'nastralis\n' > "$STATE"` **once, at process start** — not on every loop iteration — so an external deletion mid-run would leave `il-jump` reading `CUR=unknown` (file unreadable) until the next real transition writes it back. This has the same *shape* as #1/#2 but no evidence was found that anything in this system actually deletes files under `$XDG_RUNTIME_DIR/` outside of a full logind session teardown (which would kill `il-side-watch` too, triggering systemd's restart path — i.e. it folds back into #1). Not separately ranked; noted as a variant of #1.

## Q3 — the `849b6ac..9d1f129` diff

Recovered via `git --git-dir=$HOME/.dotfiles --work-tree=$HOME diff 849b6ac 9d1f129` (unfiltered — pathspec-filtered `git diff -- <path>` and `git ls-tree -- <path>` both silently returned empty output in this sandboxed shell for *every* path tested, including known-changed ones; this looks like a sandbox interception of pathspec arguments rather than a repo issue, since the full unfiltered diff worked every time and was then sliced by file boundary). `[VERIFIED: git diff, git show, this session, exact commit hashes and line ranges below]`

**`849b6ac`'s `il-jump` (last tested-good, 09-09 19:04) had:**
- Fixed-direction args only (`left`/`right`), no `toggle`, no side-file read at all.
- No single-flight lock, no ydotool-liveness probe, no detached self-check.
- Landing was hardcoded: `ydotool mousemove -- 430 0` for the Mac leg, `hyprctl dispatch "hl.dsp.cursor.move({ x = 1280, y = 720 })"` for the Nastralis leg.

**`92f64bc` (09-10 00:57, first commit inside the suspect window) introduced, in one commit, `[VERIFIED: git show 92f64bc]`:**
- The entire `toggle` mode and `read_side()`/`$STATE` mechanism (`il-jump` grew from 60 to 181 lines).
- `il-side-watch` as a brand-new file (0 → 38 lines) plus its systemd unit, plus `input-leap-server.service` dropped to `--debug INFO`.
- `il-doctor` as a brand-new file (0 → 108 lines).
- The single-flight `flock`, the ydotool-liveness probe with revival, the no-op-when-already-there guard (`il-jump:91` in current numbering), the detached self-check, and the geometry-derived `centre_mac()`/`centre_nastralis()` replacing the hardcoded constants.
- Commit message's own words (quoted): *"The cause could not be reproduced by faking keypresses, because ydotool key events do not drive Hyprland keybinds at all... Rather than keep chasing it, the whole thing is rebuilt so that failure mode cannot exist"* — i.e. this was already a rewrite-in-response-to-an-unreproduced-bug, the same shape this phase is now repeating one level up.

**`6fc6dbe` (09-10 01:17) added, then `9d1f129` (09-10 01:23) fully reverted:** the modifier re-press block (detached, `sleep 0.06`, re-press held modifiers read via the new `il-heldmods`). `[VERIFIED: git show 6fc6dbe, git show 9d1f129]` — the revert diff is the exact inverse of the add diff for `il-jump`; the resulting blob hash (`8c59ed0`) is identical to `92f64bc`'s `il-jump` blob hash. **`il-jump` at HEAD (`9d1f129`) is therefore byte-identical to `92f64bc`'s `il-jump`.** `il-heldmods` (the C helper) and its `README.md` survive un-reverted (kept deliberately per the revert commit message, for `il-doctor`'s latched-modifier warning only — it is not called from `il-jump` at HEAD at all). `il-reset` is new in `9d1f129`, unrelated to the revert itself.

**What this means for planning:** there is no "hunk within the window" to isolate — D-17's framing already anticipated this outcome. The entire direction-aware/self-healing/side-file apparatus **is** the regression window, introduced whole in a single commit exactly one hour after the last known-good test, and has run unmodified (for the parts relevant to HOP-02) since. `92f64bc`'s own commit message shows its author already knew, at the time, that the fix for the *previous* reported bug ("after ALT+C hops to the Mac, pressing it again does nothing") could not be verified via the keybind path and was shipped on code-reading confidence alone — the same evidentiary posture this phase's D-09 method (read diffs cold, don't guess) is explicitly correcting for.

## Q4 — reproduction without pressing keys

Assessing the three D-21-sanctioned routes against what each can and cannot prove:

**Route 1 — scripted stressor invoking `il-jump` directly in a loop.** Exercises `read_side()` → guard (`il-jump:91`) → `shove`/`centre_*` → detached self-check, for any *starting* side-file value the harness sets up first. **Proves:** the internal decision logic's behavior for a given `$CUR`/`$want` pairing, deterministically and repeatably, with zero human involvement. **Does not prove:** anything about whether the real ALT+C keybind ever fails to invoke `il-jump` in the first place — that dispatch (Hyprland's `hl.dsp.exec_cmd`, per `binds.lua`) is entirely outside this script and cannot be exercised by calling the script directly. A stressor that always finds the internal logic correct does not rule out a failure one layer up, in the keybind wiring itself.

**Route 2 — passive `ILHOP_DEBUG=1` logging awaiting an organic failure.** **Proves:** which of the named exit paths fired, if the script ran at all, correlated to the human's own memory of "I pressed and nothing happened." **Critically, it also has diagnostic value the CONTEXT.md framing does not spell out: the *absence* of any new log line at all, checked against the human's own sense of when they pressed and it failed, is itself a finding** — it means the failure is *upstream* of `il-jump` (the keybind never invoked the script, or the script died before reaching its first log call), which Route 1 structurally cannot detect and Route 3 cannot detect either. This absence-as-signal only works if the log includes a wall-clock timestamp per line, so a human can correlate "I pressed at roughly 14:32" against "no line near 14:32" versus "a line at 14:32:03 showing exit path `:91`." **This should be a design requirement for D-11's log line format**, not left implicit.

**Route 3 — deliberate wrong-value injection into `$XDG_RUNTIME_DIR/il-side`.** Given the exact guard code at `il-jump:91` (`[ "$CUR" = "$want" ] && exit 0`, `[VERIFIED, read this session]`), writing a value equal to the computed `$want` for a given direction **will** deterministically produce the silent no-op — this follows directly from reading the code, not from running it, but running it (`echo mac > $RUN/il-side; il-jump left` and observing zero ydotool calls / zero notification / immediate exit 0) costs nothing and turns a code-reading claim into an executed one. **What it proves:** the *mechanism* D-05 describes exists exactly as suspected and produces exactly the reported shape (total silence, no error, no visual feedback) — this alone is strong enough to justify a fix to the guard's trust model regardless of whether the wild failures are ever caught organically. **What it does NOT prove:** that this specific mechanism (rather than, say, the keybind-dispatch failure Route 1/2 can't see, or a different code path entirely) is what produces the failures the user has actually experienced during daily use. Closing that gap requires either Route 2 catching a real occurrence with the debug log showing exit path `:91` specifically, or Q2's stale-state mechanisms being independently confirmed to occur (e.g. observing `il-side-watch.service`'s restart count via `systemctl --user status` / `journalctl --user -u il-side-watch.service` over a normal session, which is itself a zero-keypress, fully scriptable check).

**Recommended sequencing for the plan:** Route 3 first (cheapest, fully scriptable, proves the mechanism exists in isolation) → Route 1 (stress the same mechanism under load/race conditions no single injection covers, e.g. rapid toggling while the watcher is mid-restart) → Route 2 running continuously in the background throughout normal use for the remainder of the phase (catches anything Routes 1/3 didn't anticipate, including the upstream-of-`il-jump` case). The human-at-keyboard verification criterion (ROADMAP.md Phase 1 criterion 3) is then a *confirmation* pass after the mechanism is understood and a fix is proposed, not a fishing expedition — consistent with D-21's closing note that "the author's presses are reserved for confirming behaviour, not for fishing for a failure."

## Q5 — instrumentation that cannot make things worse

Constraints already established by reading `il-jump` in full: it runs under `set -u` (not `-e`); the single-flight lock is `exec 9>"$LOCK"` then `flock -n 9` (`il-jump:52-55`, `[VERIFIED, read this session]`); there are two `( ... ) &` detached subshells already in the file (the self-check at `:164-181` in current numbering), each of which opens with `exec 9>&-` to release the lock fd before doing anything else (`il-jump:165`, `[VERIFIED, read this session]`, quoted: `exec 9>&-                        # do not hold the single-flight lock`).

**Subshell inheritance of the lock fd.** Any new detached block added for debug logging (e.g. a third `( ... ) &` for post-hop measurement per D-15) **must** open with the same `exec 9>&-` as the existing self-check block — a forked child inherits open file descriptors including fd 9, and a lingering held lock in a background process would make the *next* `il-jump` invocation's `flock -n 9` fail and silently `exit 0` (`il-jump:54`) for the entire duration the stray child lives. This is a real risk specifically because D-15 requires the new measurement logic to *also* be detached, giving it the exact same shape as the existing self-check and the exact same obligation.

**Writes from detached children must not interleave.** With the self-check, a possible future measurement block, and the main synchronous path all potentially writing to the same debug log file, POSIX only guarantees atomicity for a single `write()` call ≤ `PIPE_BUF` (conventionally 4096 bytes on Linux) when the file descriptor was opened with `O_APPEND` — which shell's `>>` redirection sets. **Practical rule for the plan:** every log line must be emitted as **one single `printf` call** producing one line (e.g. `printf '%s %s exit:%s\n' "$(date +%s%3N)" "$1" "$2" >> "$LOG"`), never built up across multiple redirected writes (`echo -n ...; echo ... >> "$LOG"` is two `write()`s and can interleave with a concurrent writer from another subshell). Use `>>` (append), never `>` (truncate) — truncation from one writer mid-session would silently erase another's history.

**Gating so `ILHOP_DEBUG=0` costs nothing.** The entire log-writing mechanism should be behind a single cheap check (`[ -n "${ILHOP_DEBUG:-}" ]`) evaluated once near the top, not a per-call-site check — under `set -u`, referencing `$ILHOP_DEBUG` unguarded would itself abort the script if unset, so every log call site needs either the guard or `${ILHOP_DEBUG:-}` expansion; a single wrapper function (`dbg() { [ -n "${ILHOP_DEBUG:-}" ] && printf ... ; }`) centralizes this and avoids repeating the guard at all four exit-path call sites D-11 requires.

**Does not add latency.** `$XDG_RUNTIME_DIR` is a tmpfs (memory-backed) — an `printf >> file` there costs single-digit microseconds, far under the ~50ms budget, and per D-15 the exit paths that matter for the *hot* no-op case (`il-jump:91`, before any `shove` call) are synchronous single-line writes, not detached — so even in the gated-on case, the latency cost is a single tmpfs append before `exit 0`, not a fork. Only D-15's *measurement* (distinct from D-11's per-exit-path logging) needs to be detached, and it already has the existing self-check block as its template.

## Q6 — `hyprctl cursorpos` as an oracle

**Not verified against a primary source or documentation in this pass.** `[ASSUMED]` — flagged for the plan to gate behind a falsification check before D-14 is treated as settled.

**Reasoning available from the scripts themselves (which IS verified):** `il-jump`'s own comments describe two independent position trackers — input-leap's own, tracked from cumulative relative motion and NOT clipped to screen bounds (this is what triggers `switchScreen()` when it crosses an edge, per Q1's read of the actual upstream mechanism), versus the compositor's rendered cursor, which Hyprland owns and which `hyprctl dispatch "hl.dsp.cursor.move(...)"` warps directly (`il-jump:116-123`, `centre_nastralis()`, `[VERIFIED, read this session]`). The script's own comment at `il-jump:31-33` states the recentre is "safe because on the server it is the portal that watches the edge barrier, not input-leap's own cursor, so warping does not desync anything" — implying these two trackers are understood by the script's author to be genuinely independent.

**The inference this suggests, stated as a hypothesis, not a fact:** once input-leap's server-side input capture has actually taken over (i.e. the hop genuinely succeeded), further synthetic pointer events issued locally (the `shove`/`centre_mac` calls that happen *after* the crossing, intended to land the pointer on the far side) should be intercepted by the capture portal and relayed to the Mac client rather than reaching Hyprland's normal local-cursor rendering path — meaning `hyprctl cursorpos`, read on Nastralis, should **freeze** at wherever it was at the moment of capture rather than continuing to track every subsequent ydotool delta. If the hop instead silently failed (never crossed), there is no capture, and *every* ydotool delta — including the post-crossing `centre_mac()` nudge, which is only meaningful if the crossing worked — reaches the compositor locally, so `cursorpos` would show the pointer at the local position those deltas add up to (which is NOT "the Mac's centre," since Nastralis and the Mac are different coordinate spaces entirely). **This is a real, checkable distinction if the hypothesis holds** — but it rests on an assumption about *when exactly* the input-leap portal begins intercepting local synthetic events relative to when `switchScreen()` fires, which was not confirmed against source in this pass.

**What the plan should do with this:** before building the reproduction harness's oracle on `hyprctl cursorpos`, run one falsification check: trigger a hop known-good by a human at the keyboard, and diff `hyprctl cursorpos` immediately before the hop against immediately after `centre_mac()`/`centre_nastralis()` runs. If the position is NOT frozen at the pre-crossing edge value on a successful `left` hop, D-14's oracle claim is wrong and needs a different local signal (e.g. reading `il-side` after `il-side-watch` has had time to observe the transition, which reintroduces the exact ~450ms-wait problem D-15 already rejected — so a failure here has real design consequences, not just a footnote).

## Q7 — known upstream input-leap issues matching this shape

No issue was found with the *exact* framing "server thinks pointer is on a screen it is not." The closest adjacent findings:

- [input-leap#94 — "Cursor is stuck in bottom of client screen"](https://github.com/input-leap/input-leap/issues/94) — cursor jumps to a fixed position on the client and cannot be moved from there. Different symptom shape (position-stuck, not switch-doesn't-fire) but same family of "server/client screen-ownership disagreement."
- [input-leap#490 — "Bouncing mouse at screen edge"](https://github.com/input-leap/input-leap/issues/490) — the pointer re-triggers the edge crossing repeatedly. Not this project's symptom (D-02 is a *silent* no-op, not a bounce), but relevant context on edge-detection fragility in the same subsystem `il-jump`'s overshoot technique depends on.
- [input-leap#2125 — "Clients connect but can't interact/switch screens"](https://github.com/input-leap/input-leap/issues/2125) — closer in shape (switching silently doesn't work) but reported as a connection-layer problem, not a transient state issue.
- [hyprwm/xdg-desktop-portal-hyprland#419 — EIS session fd leak](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419) — **open, unresolved as of this research** (filed 2026-07-25). Root cause: `hyprland_input_capture_v1` lacks a destructor request, so repeated session create/close cycles (discovered via lan-mouse, but stated by the reporter to affect *any* InputCapture client creating/closing sessions repeatedly) leak EIS file descriptors until the portal hits `ETOOMANYREFS` and crashes the user's session outright. This is **not confirmed to be what `il-jump` hits** — `il-jump` does not create/close InputCapture sessions per hop (input-leap's server process owns one long-lived session, not per-hop sessions) — but it is worth naming as a candidate for the "stays dead a while, unrelated fix clears it" shape if `il-side-watch` or `input-leap-server.service` itself has been restarted enough times over the system's uptime to approach the reported ~33–36-cycle threshold. `[CITED: github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419]` — flagged as a secondary hypothesis, not the leading one; Q2's watcher-restart-gap mechanism remains better matched to the reported symptom and requires no accumulated-leak precondition.

No issue found describing input-leap's server silently believing the wrong active screen due to a *missed log line in a downstream consumer* — which makes sense, since that is specific to this project's own `il-side-watch` architecture, not something upstream input-leap itself would report (upstream has no equivalent side-file cache to go stale).

## Common Pitfalls

### Pitfall 1: Treating "the mechanism reproduces" as "the mechanism explains the wild failures"
**What goes wrong:** Route 3 (state injection) proves the guard produces a silent no-op on command. It is tempting to treat that as closing HOP-02.
**Why it happens:** it is the cheapest, fastest-to-run of the three sanctioned routes, and it does succeed.
**How to avoid:** per Q4, Route 3 proves the mechanism *can* produce the symptom, not that it *did*. The plan must pair it with either an organic catch (Route 2, with timestamped logs) or independent confirmation that Q2's stale-state triggers actually occur during normal operation (e.g. counting `il-side-watch.service` restarts over a session via `journalctl --user -u il-side-watch.service`, itself zero-keypress and scriptable).
**Warning signs:** a plan that ships a fix to `il-jump:91`'s guard on the strength of Route 3 alone, with no Route 2 log correlated to an actual failure.

### Pitfall 2: Reading `il-side` as an oracle for "did the hop land" in the reproduction harness itself
**What goes wrong:** the natural first instinct for "how do I know the hop worked" is to check the same file `il-jump` itself reads.
**Why it happens:** it is already there, already updated by `il-side-watch`.
**How to avoid:** this is exactly D-16's circularity, restated — a harness that judges success by reading `il-side` cannot distinguish "the hop worked" from "the hop failed but `il-side` is stale in a way that happens to say the hop worked," which is precisely the failure mode under investigation. D-14's alternative (local `hyprctl cursorpos` + the raw journal) avoids the *cached* layer, but per Q6 needs its own falsification pass before being trusted.
**Warning signs:** any check of the form `[ "$(cat $RUN/il-side)" = mac ]` used as ground truth rather than as "what the cache currently believes."

### Pitfall 3: Building a reproduction harness around the keybind path
**What goes wrong:** any attempt to script "press ALT+C and see what happens" end-to-end.
**Why it happens:** it feels like the most faithful reproduction of the real symptom.
**How to avoid:** already established as closed in PROJECT.md/PITFALLS.md — `ydotool` key events do not fire Hyprland keybinds (measured, 0 fires), and no replay/nested-compositor tool changes this, because they all inject through the same `uinput` primitive already measured not to reach the keybind dispatcher. Route 1's stressor must call `il-jump` directly, never simulate the chord.
**Warning signs:** any harness component that synthesizes a keypress rather than invoking the script by path.

### Pitfall 4: Forgetting the lock fd in a new detached block
**What goes wrong:** D-15's new measurement logic, or D-11's logging if it is ever made detached, forks a `( ... ) &` without `exec 9>&-` first.
**Why it happens:** it is easy to copy the *body* of the existing self-check without copying its first line.
**How to avoid:** per Q5, every new detached block must open with `exec 9>&-` exactly like the existing self-check (`il-jump:165`), or a stray background process holding fd 9 open will make every subsequent `il-jump` invocation's `flock -n 9` fail and silently no-op for as long as that process lives — a new, self-inflicted variant of exactly the bug this phase is trying to close.
**Warning signs:** `il-jump` starts silently refusing every press after a specific detached block runs; `flock`-holder investigation (`fuser $RUN/il-jump.lock` or similar) shows an unexpected long-lived child.

## Code Examples

### The guard under investigation (verbatim, this session)
```sh
# il-jump:91 — the exact line D-05 accuses
[ "$CUR" = "$want" ] && exit 0
```

### `il-side-watch`'s transition parser (verbatim, this session — the only place a wrong value can be written)
```sh
# il-side-watch:21-37
journalctl --user -u input-leap-server.service -f -n 0 --no-pager 2>/dev/null |
while IFS= read -r line; do
    case "$line" in
        *'switch from "'*'" to "'*)
            dest=${line#*\" to \"}      # -> Macbook-Air.local" at 1699,445
            dest=${dest%%\"*}           # -> Macbook-Air.local
            case "$dest" in
                Nastralis) printf 'nastralis\n' > "$STATE" ;;
                "")        ;;           # unparsable, leave the last known value
                *)         printf 'mac\n'       > "$STATE" ;;
            esac
            ;;
        # A client (re)connecting means the server is holding the pointer again.
        *'has connected'*|*'has disconnected'*)
            printf 'nastralis\n' > "$STATE"
            ;;
    esac
done
```

### The existing detached self-check, as the template for any new detached block (verbatim, this session)
```sh
# il-jump:164-181
(
    exec 9>&-                        # do not hold the single-flight lock
    landed 12 && exit 0              # ~1.2s; the side file flips after ~450ms

    [ "$(cat "$SEQ" 2>/dev/null)" = "$myseq" ] || exit 0   # a newer jump owns it now
    read_side; [ "$CUR" = unknown ] && exit 0              # watcher down, cannot judge

    shove 14                         # one harder retry
    if landed 15; then
        if [ "$dir" = left ]; then centre_mac; else centre_nastralis; fi
        exit 0
    fi

    centre_nastralis
    note "the other screen didn't take the pointer (asleep or disconnected?)"
) >/dev/null 2>&1 &
```

### Upstream input-leap's own log format, for anything reading the journal directly (primary source, this session)
```cpp
// input-leap src/lib/server/Server.cpp — LOG_INFO calls
LOG_INFO("switch from \"%s\" to \"%s\" at %d,%d", getName(m_active).c_str(), getName(dst).c_str(), x, y);
LOG_INFO("jump from \"%s\" to \"%s\" at %d,%d", getName(active).c_str(), getName(m_primaryClient).c_str(), m_x, m_y);
LOG_NOTE("client \"%s\" has connected", getName(client).c_str());
LOG_NOTE("disconnecting client \"%s\"", getName(client).c_str());
LOG_NOTE("forced disconnection of client \"%s\"", getName(client).c_str());
```

## State of the Art (within this project's own history)

| Old Approach (`849b6ac`, tested-good 09-09) | Current Approach (since `92f64bc`, 09-10 00:57) | When Changed | Impact |
|---|---|---|---|
| Fixed-direction binds (`left`/`right`), no side-file dependency | `toggle` mode reading `$RUN/il-side`, direction inferred from cached state | `92f64bc`, 09-10 00:57 | Introduces the entire class of bug D-05 suspects — a cache that can be wrong |
| No liveness probe, no lock, no self-check | ydotool liveness probe + revival, single-flight `flock`, detached self-check with retry | `92f64bc` | Net hardening, but adds two more detached subshells that must each independently manage the lock fd correctly |
| Hardcoded landing constants (`430`, `1280,720`) | Geometry-derived `centre_mac()`/`centre_nastralis()`, `hyprctl monitors -j` + cached Mac width | `92f64bc` | More correct in principle (adapts to real screen size); D-03 suggests it is not the source of the reported "wrong landing" complaint |
| N/A | Modifier re-press via `il-heldmods` (detached, delayed) | Added `6fc6dbe`, reverted `9d1f129` | Fully reverted from `il-jump`; `il-heldmods` binary itself survives, used only by `il-doctor`'s warning check |

**Superseded/no longer trustworthy as a design assumption:** any claim that `il-doctor --test`'s green "hop landed" result (`il-doctor:105-113`, reads `$RUN/il-side`) is proof the hop actually worked — this is exactly D-16's circularity and is fixed in this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `hyprctl cursorpos` freezes (stops tracking local synthetic deltas) once input-leap's server-side capture has taken over, and continues tracking if the hop failed — making it a decisive local oracle per D-14. | Q6 | If wrong, D-14's proposed oracle does not actually distinguish "landed" from "didn't land," and the reproduction harness / future `il-doctor` non-circular check (D-16) needs a different signal — likely forcing back the ~450ms journal-wait D-15 was written specifically to avoid, which is a real design cost, not a minor correction. |
| A2 | `"client \"%s\" has disconnected"`'s exact source call site (file/function) was not located — only its existence and NOTE level are confirmed via a real pasted user log in a GitHub issue, not via reading input-leap's own source for that specific line. | Q1 | Low risk in isolation (the line's existence and level are independently confirmed via primary evidence — a real captured log), but if a future input-leap version reworded it, `il-side-watch`'s `*'has disconnected'*` substring match could silently stop matching with no visible symptom until someone notices `il-side` never resets on a genuine disconnect. |
| A3 | The EIS session fd-leak issue ([xdg-desktop-portal-hyprland#419](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419)) is presumed *not* to apply to `il-jump`'s operation, on the reasoning that input-leap's server holds one long-lived InputCapture session rather than creating/closing one per hop — this reasoning was not independently confirmed against input-leap's own portal-integration source in this pass. | Q7 | If wrong, and input-leap *does* create/close per-switch or per-reconnect InputCapture sessions, this becomes a plausible contributing cause for "stays dead a while, unrelated fix (restart) clears it" — worth a quick `ls $XDG_RUNTIME_DIR/eis-*.lock 2>/dev/null | wc -l` check early in the reproduction harness, since it costs nothing and would settle this immediately. |

## Open Questions

1. **Does `hyprctl cursorpos` actually freeze during a captured hop, as Q6 hypothesizes?**
   - What we know: the scripts' own comments describe two independent cursor trackers, which is the right *shape* for the hypothesis to be true.
   - What's unclear: the exact timing of when input-leap's capture begins intercepting local synthetic events relative to `switchScreen()` firing — not confirmed against any source.
   - Recommendation: the plan's first task should be exactly the falsification check described in Q6, before any reproduction harness code is written that depends on the answer.

2. **How many `il-side-watch.service` restarts has this system actually accumulated, and does the `-n 0` gap actually correlate with observed HOP-02 failures?**
   - What we know: the mechanism (Q2, #1) is real and matches the reported symptom shape by construction.
   - What's unclear: whether it has actually fired in practice, versus being a plausible-but-unconfirmed theory — this is exactly why Route 2 (passive organic logging) is in the sanctioned list rather than skipped in favor of shipping a fix to Q2's #1 mechanism directly.
   - Recommendation: `journalctl --user -u il-side-watch.service --since "-7 days"` (zero keypress, fully scriptable) as an early, cheap check for restart frequency before investing in a fix.

## Environment Availability

All tools this phase depends on are already in continuous daily-driver use by the existing scripts, so availability is not in question — this table records what each depends on for completeness, not because any gap is expected.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `journalctl` (systemd) | `il-side-watch`, Q1/Q2 reproduction checks | Confirmed in use by `il-side-watch.service` and `il-doctor` today | — | — |
| `jq` | `il-doctor`, `il-focus-jump`, `il-jump`'s geometry parsing | Confirmed in use today | — | — |
| `hyprctl` (Ryoku fork's Lua-dispatch variant) | `il-jump`'s recentre, D-14's proposed oracle | Confirmed in use today | Hyprland 0.56.2 (Ryoku fork, per PROJECT.md) | — |
| `ydotool`/`ydotoold` | All pointer injection | Confirmed in use today, with existing liveness-probe-and-revive logic | — | — |
| `flock` | `il-jump`'s single-flight lock | Confirmed present (`command -v flock` guarded) | — | Script degrades gracefully (no lock) if absent, per `il-jump:53` |
| `git` (bare repo at `~/.dotfiles`) | Q3's diff investigation | Confirmed working this session | 2.55.0 | — |

**Missing dependencies with no fallback:** none identified.
**Missing dependencies with fallback:** none identified — all tools already load-bearing in the daily driver.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — this is loose shell scripting, not a packaged test suite (packaging is Phase 5) |
| Config file | none — see Wave 0 |
| Quick run command | `~/.local/bin/il-doctor` (scriptable checks only) |
| Full suite command | `~/.local/bin/il-doctor --test` (adds the live round trip) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HOP-02 | Guard produces silent no-op given a stale side-file value | unit (scriptable) | `echo mac > "$RUN/il-side"; ~/.local/bin/il-jump left` then assert zero `ydotool` calls / immediate exit | ❌ Wave 0 — no harness script exists yet |
| HOP-02 | The hop fires on every real keypress, both directions | manual-only | N/A — keybind path cannot be simulated (see Pitfall 3) | N/A |
| HOP-02 | `il-side-watch` restart does not silently corrupt state beyond the observed gap | integration (scriptable) | `systemctl --user restart il-side-watch.service` timed against a scripted `il-jump` stressor loop, assert no permanently-stuck state | ❌ Wave 0 |
| HOP-03 | Landing lands on the correct screen, not pinned at an edge | manual-only (per D-18/D-03, likely confirmation not repair) | N/A — requires the author watching it land | N/A |
| HOP-03 | `hyprctl cursorpos` correctly distinguishes landed vs. not-landed | unit (scriptable, once A1 is falsified) | one-shot before/after `cursorpos` diff around a known-good human-driven hop | ❌ Wave 0, blocked on Q6's falsification pass first |

### Sampling Rate
- **Per task commit:** `~/.local/bin/il-doctor` (fast, scriptable checks only)
- **Per wave merge:** `~/.local/bin/il-doctor --test` (adds the live round trip, ~4-6s)
- **Phase gate:** `il-doctor --test` green (21/21 + round trip) is necessary but explicitly **not sufficient** per ROADMAP.md's own Verification Gates table — human-at-keyboard confirmation is still required for HOP-02/HOP-03's release criteria.

### Wave 0 Gaps
- [ ] A reproduction harness script (Route 1 + Route 3 combined: inject a known side-file value, invoke `il-jump` directly, assert on exit code / absence of `ydotool` invocation / debug-log content) — does not exist yet.
- [ ] `ILHOP_DEBUG` logging itself (D-11) — the log lines the harness and Route 2 both depend on do not exist yet; this is Wave 0 work, not optional preamble.
- [ ] A non-circular oracle for "did the hop land" (D-14/D-16) — blocked on Q6's falsification pass (Open Question 1) before it can be built with confidence.
- [ ] `il-side-watch.service` restart-history check (`journalctl --user -u il-side-watch.service --since "-7 days"`) — cheap, zero-keypress, should run before other Wave 0 work to gauge whether Q2's #1 mechanism has actually been firing.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface touched by this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | Marginal — yes | The new debug-log write path (D-11/D-12) writes script-internal state only (exit-path names, timestamps, side-file contents already trusted elsewhere in the same script) — no external/untrusted input is newly parsed this phase. No new validation surface introduced. |
| V6 Cryptography | No | Not touched this phase |

### Known Threat Patterns for this stack

This phase adds no new packages, no new network-facing surface, and no new privilege boundary — it adds a gated, local-only debug log and (possibly) a repair to the existing guard's trust model. The project-level threat patterns already catalogued in `.planning/research/PITFALLS.md` (`/dev/uinput` broad-access risk, synthetic-key dead-man's-release, log-level-DEBUG information exposure) remain the governing set; none of them are altered by this phase's scope. One net-new consideration:

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| New debug log file under `$XDG_RUNTIME_DIR` accumulates indefinitely if never rotated | Denial of Service (disk/tmpfs exhaustion, low severity given tmpfs is RAM-backed and per-user) | Cap the log (e.g. truncate/rotate past N lines or M KB) as part of D-11's implementation — not specified in CONTEXT.md's decisions, so the plan should pick a bound explicitly rather than leave it unbounded, especially since D-13 says the mechanism survives into Phase 4's `ilhop doctor` as a permanent fixture. |

## Sources

### Primary (HIGH confidence)
- `~/.local/bin/il-jump`, `~/.local/bin/il-side-watch`, `~/.local/bin/il-doctor`, `~/.local/bin/il-reset`, `~/.local/bin/il-focus-jump` — read in full this session, exact line numbers cited throughout.
- `~/.dotfiles` bare repo (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`), commits `849b6ac`, `92f64bc`, `6fc6dbe`, `9d1f129` — full diffs read this session via `git show`/`git diff` (unfiltered; pathspec-filtered invocations returned empty in this sandbox and were abandoned in favor of the unfiltered form).
- [input-leap `Server.cpp`](https://raw.githubusercontent.com/input-leap/input-leap/master/src/lib/server/Server.cpp) — fetched and searched directly this session for exact `LOG_INFO`/`LOG_NOTE` call sites, `m_active` initialization, and absence of periodic/startup active-screen logging.
- [Arch manual page, `input-leaps(1)`](https://man.archlinux.org/man/extra/input-leap/input-leaps.1.en) — fetched this session for the authoritative `--debug` level list and ordering, quoted verbatim.

### Secondary (MEDIUM confidence)
- [input-leap#339](https://github.com/input-leap/input-leap/issues/339) — real user-pasted log confirming `"client \"...\" has disconnected"` fires in practice at NOTE level; exact source call site not independently located.
- [hyprwm/xdg-desktop-portal-hyprland#419](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419) — EIS session fd-leak, open/unresolved, cited as a secondary/lower-ranked candidate for Q7, not confirmed to apply to this project's usage pattern.

### Tertiary (LOW confidence)
- [input-leap#94](https://github.com/input-leap/input-leap/issues/94), [#490](https://github.com/input-leap/input-leap/issues/490), [#2125](https://github.com/input-leap/input-leap/issues/2125) — adjacent-symptom issues surfaced by web search, cited for domain context, not directly matching this project's exact failure shape.
- General `hyprctl cursorpos` web search results (touchscreen-specific stale-value discussion) — did not directly address the input-leap-capture scenario; Q6's core claim (A1 in the Assumptions Log) remains unverified against a primary source and is flagged for a falsification pass in the plan.

## Metadata

**Confidence breakdown:**
- Diff/regression-window analysis (Q3): HIGH — read directly from the bare repo, commit hashes and blob-hash equality independently confirmed.
- Side-file staleness mechanisms (Q2): HIGH for the mechanisms themselves (read directly from source); MEDIUM for the ranking (reasoned from symptom-shape matching, not independently measured against actual restart counts — see Open Question 2).
- input-leap journal semantics (Q1): HIGH — primary source fetched and quoted directly, cross-checked against the authoritative man page for level ordering.
- `hyprctl cursorpos` oracle (Q6): LOW — explicitly flagged `[ASSUMED]`, needs a falsification pass as the plan's first task.
- Upstream issue survey (Q7): MEDIUM — real issues found and cited, but none matches the exact symptom shape; treated as context, not as a settled root cause.

**Research date:** 2026-09-10
**Valid until:** This research is tied to specific commit hashes and a specific live-file state (`git diff` verified against a system that changes only when the author edits `~/.local/bin/*` directly) — re-verify the diff/blob-hash claims (Q3) if `~/.local/bin/il-jump` or the `~/.dotfiles` history changes before this phase's plan executes. The input-leap upstream claims (Q1) are tied to the version fetched from `master` on 2026-09-10 and should be re-checked if the system's installed `input-leap` package version differs materially.
