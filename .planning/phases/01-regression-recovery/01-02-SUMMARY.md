---
phase: 01-regression-recovery
plan: 02
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, ydotool, journalctl, hop-oracle]

requires:
  - phase: 01-01
    provides: "ILHOP_DEBUG-gated il-jump instrumentation, il-repro reproduction harness, 01-EVIDENCE.md"
provides:
  - "il-cursortrace: bounded local cursor sampler with a self-test control (--selftest), an armable detached trace recorder (--arm), and a verdict reader (--verdict) that locates an input-leap switch-from marker and reports FROZE/TRACKED/INCONCLUSIVE"
  - "01-A1-RESULT.md: A1 falsified by measurement — hyprctl cursorpos FROZE on capture, independently discriminated from a screen-edge-clamp artifact"
affects: ["01-03", "01-04", "01-05"]

actuals:
  tokens: 6550
  tasks: 3
  commits: 3
  plan_head_before: 8e6b90c12073b5bdfbca6fe1e8541789bafa480c

tech-stack:
  added: []
  patterns:
    - "to_jctl_ts(): journalctl --since/--until rejects the project's own %z offset shape (+0100); needs the colon-separated form (+01:00). Any future script reading journalctl by timestamp inherits this."
    - "String-lexical timestamp windowing in awk instead of a date -d fork per trace line: fixed-width ISO-8601+ms+tz strings sort chronologically as plain strings, one awk pass replaces thousands of forks"
    - "--before ISO alongside --since ISO: bounding a search window on both ends, not just the lower one, so a later unrelated event can be excluded reproducibly instead of hand-picked"

key-files:
  created:
    - /home/nastralis/.local/bin/il-cursortrace
    - .planning/phases/01-regression-recovery/01-A1-RESULT.md
  modified: []

key-decisions:
  - "Scored the 19:29:13 Nastralis→Mac marker, not the chronologically-last one — two later crossings (19:31:25, 19:32:11) were real pointer motion from an orchestrator-requested mouse jiggle for an unrelated cursor-visibility diagnosis, not the plan's checkpoint action, and were excluded via the new --before bound rather than by silently trusting 'most recent'"
  - "FROZE verdict independently discriminated from a screen-edge-clamp artifact: checked whether il-jump's post-crossing centre_mac() rightward nudge ever appears in the local trace after the pointer parks at the left edge. It does not, across 3,481 consecutive samples (~2m12s) — an edge clamp would not have blocked that rightward move, so the freeze is capture, not clamping"
  - "Did NOT run `requirements mark-complete HOP-03` — this plan only establishes the measurement oracle A1 falsifies; REQUIREMENTS.md's HOP-03 line requires the pointer confirmed landing correctly on every hop, which is plan 01-03/01-05's determination (same reasoning 01-01 applied to HOP-02)"
  - "The reported vanished-cursor symptom (local cursor disappears after a hop, stays gone until real mouse motion) is documented as related context but explicitly not investigated or fixed here — hyprctl cursorpos is a position query, not a visibility query, and the centre_mac()-nudge discriminator shows the position itself is genuinely frozen, independent of whatever the compositor renders"

patterns-established:
  - "Pattern: falsify an [ASSUMED]-confidence research claim with a purpose-built sampler + self-test control before any downstream code builds on it, rather than trusting the reasoning"
  - "Pattern: when a diagnostic tool's own search window can pick up unrelated real activity, bound it explicitly (--before/--since) and show the excluded inventory, rather than trusting whatever 'most recent' happens to be"

requirements-completed: []

coverage:
  - id: D1
    description: "il-cursortrace built: --sample/--arm/--verdict/--selftest modes, proven able to see an 8px local move before any verdict is trusted"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "il-cursortrace --selftest (exit 0: 3 distinct positions, 13px x-span, control probe returned pointer to within 10px of start)"
        status: pass
      - kind: other
        ref: "sh -n il-cursortrace && test -x il-cursortrace && test -s $XDG_RUNTIME_DIR/ilhop-cursor.trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "A1 falsified by measurement: hyprctl cursorpos FROZE at the scored marker, verdict recorded in 01-A1-RESULT.md with the raw evidence and marker-selection reasoning re-derivable by a reader"
    requirement: HOP-03
    verification:
      - kind: other
        ref: "grep -Eq '^\\*\\*Verdict:\\*\\* (FROZE|TRACKED|INCONCLUSIVE)$' and grep -Eq 'switch from'/'01-04' against 01-A1-RESULT.md"
        status: pass
    human_judgment: true
    rationale: "Marker selection required excluding trace contamination from an unrelated diagnostic and distinguishing genuine capture-freeze from a screen-edge-clamp artifact by absence-of-evidence reasoning (centre_mac()'s nudge never appearing). This is exactly the kind of judgment call PROJECT.md's governing scar exists to keep out of unreviewed reasoning before plan 01-04 builds il-doctor's landing check on it."

duration: ~20min (includes one human checkpoint pause of unknown real-world length)
completed: 2026-09-10
status: complete
---

# Phase 1 Plan 02: A1 Falsification Summary

**`hyprctl cursorpos` measured to FROZE once input-leap's capture takes the pointer, independently discriminated from a screen-edge-clamp artifact via absence of `il-jump`'s post-crossing recentre nudge over a 2m12s window — D-14's local landing oracle stands for plan 01-04.**

## Performance

- **Duration:** ~20 min active work (excludes the human checkpoint's own real-world wait, which is outside the executor's control)
- **Started:** 2026-09-10T18:19:00Z (approx, first script-authoring pass)
- **Completed:** 2026-09-10T18:39:47Z
- **Tasks:** 3/3
- **Files modified:** 2 (1 new script, 1 new finding document)

## Accomplishments

- **`il-cursortrace` built and proven able to see its own control move before any verdict from it is trusted.** `--selftest` issues a known 8px local `ydotool` delta and asserts the sampler records at least two distinct positions spanning it — passed (3 distinct positions, 13px span) after two real bugs found and fixed in the process (below).
- **A1 falsified by measurement, not inference.** The checkpoint's human-driven round trip produced multiple screen crossings; the one scored (`19:29:13` Nastralis→Mac) was deliberately selected and its exclusion of two later, unrelated crossings is reproducible via `il-cursortrace --verdict --before <ISO>`, not asserted in prose. Verdict: **FROZE**.
- **The FROZE reading was independently checked against its own most likely confound** — a screen-edge clamp producing an identical-looking constant reading regardless of capture. `il-jump`'s `centre_mac()` issues a rightward nudge immediately after the crossing that an edge clamp alone would not block; it never appears in 3,481 consecutive local samples over the following ~2m12s. That rules out the clamp-only explanation and supports genuine capture.
- **Two real tool bugs found and fixed while building and scoring this**, both documented as deviations below: the `pass`/`fail`/`warn`/`head` reporting idiom (copied verbatim from `il-doctor` per PATTERNS.md) shadowed the coreutils `head` command needed by the verbatim-copied `hypr()` wrapper and the script's own trace reads; and `journalctl --since`/`--until` silently rejected the script's own `%z` timestamp shape, making `--verdict` report a false "no marker found" on every run until found.
- **`--before ISO` added** alongside the plan-specified `--since ISO`, because `--since` alone cannot exclude a marker that is chronologically *later* than the one under test — which is exactly what happened the first time this ran against real data (an orchestrator-requested mouse-jiggle diagnostic, for an unrelated cursor-visibility bug, injected two later crossings into the live trace).
- System left clean: no `il-cursortrace` process left running (the sampler had already stopped on its own, having hit the 512 KiB trace cap before its 1200s expiry), `il-doctor` (no `--test`) reports 21/21 with 0 failed, and `$XDG_RUNTIME_DIR/il-side` was restored to `nastralis` — the same value it read before this plan began — after the mouse-jiggle diagnostic left it on `mac`.

## Task Commits

Split-repo routing followed exactly per the plan's table: `il-cursortrace` → `~/.dotfiles` bare repo; `.planning/**` → `ilhop` repo.

1. **Task 1: Build the cursor sampler, prove it can see motion, and arm it** - `1ae5cf0` (`~/.dotfiles`) — new `il-cursortrace` script, `--selftest` green
2. **Task 2: One hop at the keyboard** - checkpoint, no commit (human-action gate)
3. **Task 3: Record the A1 verdict** - `efc1cfa` (`~/.dotfiles`, fix) + `7a4f777` (`ilhop`, docs) — journalctl-timestamp and `--before`-bound fixes to `il-cursortrace`, then `01-A1-RESULT.md`

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified

- `/home/nastralis/.local/bin/il-cursortrace` (created, `~/.dotfiles`) — `--sample`/`--arm`/`--verdict`/`--selftest` cursor sampler and A1 oracle; POSIX shell, `il-doctor`'s tolerant style, `il-jump:111-114`'s `hypr()` wrapper verbatim, no `flock`/fd 9
- `.planning/phases/01-regression-recovery/01-A1-RESULT.md` (created, `ilhop`) — the falsification verdict, marker-selection reasoning, raw evidence, and the discriminator check ruling out an edge-clamp-only reading

## Decisions Made

See `key-decisions` in the frontmatter above — marker selection and its `--before` fix, the edge-clamp discriminator, the deliberate non-completion of `HOP-03`, and the scope boundary drawn around the vanished-cursor symptom.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `head()` reporting function shadowed the coreutils `head` command**
- **Found during:** Task 1, first `--selftest` run
- **Issue:** The `pass`/`fail`/`warn`/`head` reporting idiom, copied verbatim from `il-doctor` per PATTERNS.md, defines a shell function named `head`. That silently shadowed the coreutils `head` used inside the verbatim-copied `hypr()` wrapper (`ls -1 "$RUN/hypr" | head -n1`) and in the script's own `first_ts`/`firstx` trace reads, producing an arithmetic-syntax crash the first time the fallback path was exercised.
- **Fix:** Routed the three real invocations through `command head -n1`, leaving the `head()` reporting function and its call sites untouched.
- **Files modified:** `/home/nastralis/.local/bin/il-cursortrace`
- **Verification:** `sh -n` clean; `--selftest` subsequently exercised the fixed reporting path without error.
- **Committed in:** `1ae5cf0`

**2. [Rule 1/3 - Bug/Blocking] `journalctl --since`/`--until` rejects the script's own `%z` timestamp format**
- **Found during:** Task 3, scoring the real checkpoint round trip
- **Issue:** `date +%Y-%m-%dT%H:%M:%S.%3N%z` produces an offset like `+0100` (no colon); `journalctl --since`/`--until` requires `+01:00` and fails with `Failed to parse timestamp` on stderr — silently swallowed by the `2>/dev/null` already in place for the tool's tolerant-failure style. `--verdict` was reporting a false "no marker found" on every run, including an earlier smoke test during Task 1 that (coincidentally, since no marker existed yet in that window either) looked correct.
- **Fix:** Added `to_jctl_ts()`, converting to the colon-offset form only for the two `journalctl` call sites; the awk-based pre/post windowing compares trace timestamps to each other as plain strings and never touches `journalctl`, so it needed no change.
- **Files modified:** `/home/nastralis/.local/bin/il-cursortrace`
- **Verification:** `--verdict` located real markers after the fix; confirmed against a direct `journalctl` invocation with both offset shapes.
- **Committed in:** `efc1cfa`

**3. [Rule 1/3 - Bug/Blocking] No way to bound the marker search window's upper edge**
- **Found during:** Task 3, same session — the trace held more crossings than the plan's checkpoint alone produced (see key-decisions)
- **Issue:** `--verdict` only exposed `--since` (lower bound); "most recent switch from" over an unbounded window picked up two later, unrelated crossings instead of the checkpoint's own round trip.
- **Fix:** Added `--before ISO`, mirroring `--since`, capping `window_end`. The tool now prints the bound applied when given, so the exact window scored is visible in its own output, not just describable in prose.
- **Files modified:** `/home/nastralis/.local/bin/il-cursortrace`
- **Verification:** `il-cursortrace --verdict --before "2026-09-10T19:30:00+0100"` reproducibly selects the `19:29:13` marker; documented and re-derivable in `01-A1-RESULT.md`.
- **Committed in:** `efc1cfa`

---

**Total deviations:** 3 auto-fixed (1 bug found in Task 1, 2 bug/blocking found in Task 3)
**Impact on plan:** All three were necessary for the tool to produce a trustworthy verdict at all; none changed the plan's scope or objective. No repair was proposed or made to `il-jump`, `il-doctor`, or HOP-03 itself.

## Issues Encountered

- **Raw `ydotool mousemove` probing during Task 1's debugging accidentally triggered real screen crossings.** While diagnosing the first `--selftest` failure, several manual test moves (issued directly, not through `il-jump`) were large enough and frequent enough that input-leap's own independent cumulative-relative-motion tracker (distinct from Hyprland's compositor cursor, per `il-jump`'s own header comment) crossed an edge on its own, flipping `$RUN/il-side` without any `il-jump` invocation. Restored via `il-jump right` each time it was noticed. Operational lesson, not a code defect: on this system, `ydotool mousemove` is not a side-effect-free diagnostic probe, even when the local `hyprctl cursorpos` appears unaffected — it can still cross real input-leap edge thresholds. Left explicit in `il-cursortrace`'s design (the `--selftest` control move is a single, small, immediately-cancelled 8px pair) but worth flagging for anyone debugging this surface by hand.
- **The checkpoint's trace held an unrelated diagnostic's pointer motion.** The orchestrator asked the author to jiggle the mouse mid-session to investigate a separate, unrelated cursor-visibility bug, while `il-cursortrace`'s trace was still recording. This is disclosed and handled explicitly in `01-A1-RESULT.md`'s marker-selection section, not silently absorbed into the scored result.
- **The sampler's 1200s arm expired early (by design, not by fault): it hit the 512 KiB trace cap (`T-1-05`) at `19:32:10.928`, after 8m53s, rather than running the full 1200s.** This is the cap working as intended — the trace was already long-closed and complete for everything needed by the time it was scored, and no process was left running to clean up.

## User Setup Required

None beyond the plan's own Task 2 checkpoint (already completed) — no external service configuration required.

## Next Phase Readiness

- `01-A1-RESULT.md` gives plan 01-04 an unambiguous, re-derivable oracle to build on: a local freeze test (issue a small known local probe delta after a hop, see whether the local pointer moves) rather than the input-leap journal — which RESEARCH.md Q1 already established cannot answer "where is the pointer now" independent of having observed every prior transition.
- `il-cursortrace`'s `--sample`/`--arm`/`--verdict`/`--selftest` surface is exactly what D-13 requires to survive into Phase 4's `ilhop doctor` migration; plan 01-04 owns adding `--landed`/`--selftest-oracle` per this plan's frontmatter's ownership table.
- **Not yet done, by design:** `HOP-03` itself remains open — this plan only establishes the measurement oracle; plan 01-03's manual confirmation (`1-03-02` in `01-VALIDATION.md`) and plan 01-05's determination still own whether `HOP-03` is a live defect at all, per `D-03`'s correction that landing already appears to work.
- The reported vanished-cursor symptom is explicitly out of this plan's scope and is being tracked separately; `01-A1-RESULT.md` records only that this plan's own data is consistent with a genuine positional freeze, not a rendering-only artifact, as context for whoever investigates it.
- Nothing on the daily driver was left restarted, rebound, or in an injected state: `$XDG_RUNTIME_DIR/il-side` reads `nastralis`, matching its value before this plan began; no `il-cursortrace` process remains running; `il-doctor` (no `--test`) reports 21/21 clean, matching the baseline.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-10*
