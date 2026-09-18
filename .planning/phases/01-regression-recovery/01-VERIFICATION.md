---
phase: 01-regression-recovery
verified: 2026-09-11T17:10:00Z
re_verified: 2026-09-18T18:05:00Z
status: passed
score: 6/6 must-haves verified
covered_files: [".planning/REQUIREMENTS.md", ".planning/ROADMAP.md", ".planning/phases/01-regression-recovery/01-01-PLAN.md", ".planning/phases/01-regression-recovery/01-01-SUMMARY.md", ".planning/phases/01-regression-recovery/01-02-PLAN.md", ".planning/phases/01-regression-recovery/01-02-SUMMARY.md", ".planning/phases/01-regression-recovery/01-03-PLAN.md", ".planning/phases/01-regression-recovery/01-03-SUMMARY.md", ".planning/phases/01-regression-recovery/01-04-PLAN.md", ".planning/phases/01-regression-recovery/01-04-SUMMARY.md", ".planning/phases/01-regression-recovery/01-05-PLAN.md", ".planning/phases/01-regression-recovery/01-05-SUMMARY.md", ".planning/phases/01-regression-recovery/01-06-PLAN.md", ".planning/phases/01-regression-recovery/01-06-SUMMARY.md", ".planning/phases/01-regression-recovery/01-A1-RESULT.md", ".planning/phases/01-regression-recovery/01-EVIDENCE.md", ".planning/phases/01-regression-recovery/01-HOP-03-FINDING.md", ".planning/phases/01-regression-recovery/01-REVIEW.md", ".planning/phases/01-regression-recovery/01-ROOTCAUSE.md"]
covered_digest: "v1:sha256:ccf5d8b5f791588b1900b9e3e11c289b99aed9816cc76247ea220a34dc79e910"
behavior_unverified: 0
overrides_applied: 0
gaps: []
closed_gaps:
  - truth: "The fix does not reintroduce a silent, permanent no-op regression through the mechanism it modified (ROADMAP Phase 1 goal: 'the hop fires on every press'; success criterion 3: 'no silent no-op, no swallowed press')"
    id: CR-01
    status: closed
    closed_by: "01-07-PLAN.md / 01-07-SUMMARY.md"
    closed_at: 2026-09-18T18:05:00Z
    evidence:
      - "il-side-watch:117 - the unconditional 2>/dev/null is gone; journalctl's exit status is captured through a portable brace-group + CURSOR_RC side-file rather than pipefail/PIPESTATUS"
      - "il-side-watch:124-130 - nonzero exit writes a named diagnostic to stderr (which now reaches the unit's own journal) and deletes $CURSOR, so the next Restart=always cycle cold-starts via the documented -n 0 fallback. Bounded to exactly one restart, not an unbounded series"
      - "il-doctor:81-88 - crash-loop detector greps systemd's own 'Scheduled restart job' lines over a trailing 10s window; >=2 is a loop. Chosen because systemctl is-active was measured reporting 'active' mid-loop"
      - "il-repro --cursor-crash-loop, folded into --all - permanent regression gate proving both halves (self-heal bounded; detector accurate on a real loop and not false-positive on one legitimate restart)"
    live_recheck_2026_09_18:
      - "il-doctor (non-invasive): 21 check(s) ok, 0 failed - including 'il-side-watch.service restart history looks healthy (0 restart(s) in the last 10s)'"
      - "il-side-watch.service active, no restarts, up 1d21h since 2026-09-16 20:37:51"
      - "The --cursor-crash-loop induction was deliberately NOT re-run this session: it intentionally corrupts the cursor and restarts the watcher, and the author was mid-triage on an unrelated input-leap client issue. Its live green run (6 ok / 0 failed) is recorded in 01-07-SUMMARY.md D2/D3 against this same code"
deferred:
  - truth: "il-repro's pointer-motion probe false-FAILs when a human touches the mouse during a run (needs an exclusive-input window or a second independent signal before a motion FAIL is believed)"
    addressed_in: "Phase 4"
    evidence: "Phase 4 success criterion 2: 'ilhop doctor runs the full check suite and reports pass/fail per check; ilhop doctor --test additionally drives a live round trip and reports its outcome' — 01-06-SUMMARY.md and STATE.md both file this diagnostic-reliability defect as a Phase 4 (DIAG) inheritance"
  - truth: "il-repro's total check count is not a fixed invariant across runs (83 disarmed / 80 armed), weakening 'N ok, 0 failed' as a gate"
    addressed_in: "Phase 4"
    evidence: "Same Phase 4 success criterion 2 (diagnostic suite correctness); explicitly filed as a Phase 4 (DIAG) inheritance in 01-06-SUMMARY.md and STATE.md"
  - truth: "il-doctor:78 calls bare hyprctl instead of the hypr() wrapper, producing a false FAIL under ssh/systemd/agent shells with a misleading remedy"
    addressed_in: "Phase 4"
    evidence: "Phase 4 success criterion 2 (doctor's per-check pass/fail accuracy); explicitly filed as a Phase 4 (DIAG) inheritance in 01-06-SUMMARY.md and STATE.md"
---

# Phase 1: Regression Recovery Verification Report

**Phase Goal:** The hop fires on every press, and the landing question is settled — the two user-reported defects are reproduced and root-caused, or shown not to be defects, and closed either way.
**Verified:** 2026-09-11T17:10:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (source) | Status | Evidence |
|---|---|---|---|
| 1 | Both defects reproducible on demand before any fix is written, or shown not reproducible and recorded as such (ROADMAP SC1) | ✓ VERIFIED | HOP-02: `il-repro --inject-noop` (Route 3) demonstrated the `already-on-side` guard producing D-02's exact silent, motionless refusal in both directions, with a self-explaining log line, before any fix (01-EVIDENCE.md, re-confirmed live in 01-ROOTCAUSE.md "Live re-verification"). HOP-03: measured NOT reproducible as a defect against D-18's bar — recorded as the finding, not papered over (01-HOP-03-FINDING.md). |
| 2 | Cause traced to a named change — a specific hunk or a mechanism ruled out by diff against last known-good (ROADMAP SC2) | ✓ VERIFIED | 01-ROOTCAUSE.md: diff window corrected and re-verified by direct content hash comparison (`92f64bc` and `9d1f129`'s `il-jump` share identical SHA-256; `6fc6dbe`'s modifier re-press confirmed fully reverted with no residue). Named mechanism: `il-side-watch`'s restart-reattach zero-backlog gap (confirmed firing, 2 transitions lost in one observed cycle) plus the unmatched `jump from` line shape (confirmed firing 7x/7 days), feeding `il-jump`'s guard that trusts the cache unconditionally. Proven end-to-end by injection and a live watcher-restart test, not guessed. |
| 3 | Author presses the bind at the keyboard, repeatedly, both directions, every press fires (ROADMAP SC3) | ✓ VERIFIED | Human gate performed 2026-09-11 per `workflow.human_verify_mode: end-of-phase`, bar agreed before the presses (10 ALT+C presses, ≥4 each direction, every one fires). Gate window `16:43:17.828`–`16:43:54.728`: 27 `dispatch` lines, 0 lines on any refusal path (`already-on-side`, `stale-lock`, `superseded`, `watcher-unknown`, `die`, `usage`). Author reported 10 presses, 5 each direction, all fired (01-06-SUMMARY.md D6). Log independently re-read this session via `il-repro --report`; log mechanics (timestamps, tally buckets) match the code that produces them. |
| 4 | Pointer arrives on the correct destination screen, never pinned against an edge, both directions, author watching (ROADMAP SC4, HOP-03) | ✓ VERIFIED | 01-HOP-03-FINDING.md: NOT A DEFECT, measured not asserted. Independently re-derived this session: `hyprctl monitors -j | jq ...` on the live machine reproduces the identical `1280 720` target from real geometry (2560×1440 monitor); all four edge margins clear D-18's 100px bar by >7×; the Mac-leg nudge (427px, 854px doubled) stays inside the cached 1710px width. Per D-03/D-18, screen-centre accuracy is explicitly not this phase's bar (HOP-05/Phase 3.1 owns the target). Author's watched session confirmed landing on the correct screen, never pinned (01-06-SUMMARY.md D7). |
| 5 | `il-doctor --test` reports its full tally and a passing live round trip; the detached self-check still catches and recentres a deliberately failed hop (ROADMAP SC5) | ✓ VERIFIED | Independently ran non-invasive `il-doctor` this session: 21/21 checks pass live. `il-doctor:110-152` code-read confirms the circular `$RUN/il-side` verdict (D-16) is gone — the live round trip's pass/fail now comes from `il-cursortrace --landed` (the oracle 01-A1-RESULT.md licensed), with the cache reported only as a `warn`-level cross-check, never the verdict. `il-repro`'s `mode_selfcheck_rescue` (`il-repro:534-...`) exists, stops the watcher, forces `$STATE` stale, dispatches for real, and asserts on the dispatch log, the bail conditions, and the oracle's functional-landing verdict — matching 01-06-SUMMARY.md D3/D5's detailed, specific execution-time numbers (23/23, 24ms/45ms, dispatch-in-log, no early bail). `--test` and `--selfcheck-rescue` were not re-executed live by this verifier because both perform real ydotool hops and stop/start the live `il-side-watch.service` on the author's actively-used daily-driver machine — outside the "no state mutation" bound for an automated spot-check. |
| 6 | The fix does not reintroduce a silent, permanent no-op regression through the mechanism it modified (ROADMAP goal statement + SC3's "no silent no-op, no swallowed press") | ✗ FAILED | See Gaps below. Code review CR-01, independently reproduced this session against the real `journalctl`. |

**Score:** 5/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `~/.local/bin/il-jump` | ILHOP_DEBUG logging, every exit path named, dispatch line, same-direction double-press override | ✓ VERIFIED | Read in full. `dbg()` gated by `ILHOP_DEBUG`/arm file (:75-78), size-capped rotation (:84-92), single-flight lock with `stale-lock` log (:99), `usage`/`die` paths logged, `already-on-side`/`retry-forced` override at :143-159 with `RETRY_MIN_MS=200`/`RETRY_MAX_MS=5000` measured constants, `dispatch` line at :218, detached self-check with `superseded`/`watcher-unknown`/rescue at :232-250. Matches every plan's must-have artifact claim. |
| `~/.local/bin/il-side-watch` | `jump from` matched, bounded-backlog `--cursor-file` reattach, `handle_line()` test seam | ✓ VERIFIED (with the CR-01 caveat above) | `handle_line()` factored out with `IL_SIDE_WATCH_TEST` seam (:26-54); `*'switch from "'*'" to "'*|*'jump from "'*'" to "'*` alternation at :34 closes the second named mechanism; `--cursor-file="$CURSOR"` reattach at :71 closes the first. The reattach itself is unguarded against `journalctl`'s own documented hard-failure — see gap. |
| `~/.local/bin/il-repro` | Full reproduction harness: inject-noop, stress, watcher-gap, retry-forced, watcher-parser, selfcheck-rescue, arm/disarm/report, all | ✓ VERIFIED | All eleven modes present and wired (`mode_inject_noop`, `mode_stress`, `mode_stress_live`, `mode_arm`, `mode_disarm`, `mode_report`, `mode_watcher_gap`, `mode_retry_forced`, `mode_watcher_parser`, `mode_selfcheck_rescue`, `mode_all`), each reachable from the CLI case statement. |
| `~/.local/bin/il-doctor` | Non-circular `--test` live round trip via the landing oracle | ✓ VERIFIED | Confirmed by direct code read (:116-152) and a live, non-invasive `il-doctor` run this session (21/21). |
| `~/.local/bin/il-cursortrace` | Bounded cursor sampler, A1 falsification oracle, non-circular `--landed` landing check | ✓ VERIFIED | `--verdict`, `--selftest`, `--landed`, `--selftest-oracle` all present in the CLI dispatch; used correctly by `il-doctor` and `01-HOP-03-FINDING.md`'s measurement 4. |
| `~/.config/systemd/user/il-side-watch.service` | `Restart=always`/`RestartSec=3`/`StartLimitIntervalSec=0` unit backing the reattach | ✓ VERIFIED | Read in full; matches every claim made about it in 01-REVIEW.md and 01-ROOTCAUSE.md. Confirmed live: `active (running)`, currently following `journalctl ... --cursor-file=/run/user/1000/il-side-watch.cursor`. |
| `.planning/phases/01-regression-recovery/01-EVIDENCE.md`, `01-A1-RESULT.md`, `01-HOP-03-FINDING.md`, `01-ROOTCAUSE.md` | Phase-level determination artifacts | ✓ VERIFIED | All exist, all substantive (read in full), internally consistent with each other and with the live system state observed this session. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `il-repro --inject-noop` / `--watcher-gap` / `--retry-forced` | `il-jump` | invokes by absolute path, never through the keybind | ✓ WIRED | Confirmed by reading `il-repro`'s `JUMP="$HOME/.local/bin/il-jump"`-style invocations and the mode functions calling it directly. |
| `il-doctor --test` | `il-cursortrace --landed` | live round trip's verdict, non-circular since plan 01-04 | ✓ WIRED | `il-doctor:123,138,146` calls `"$ORACLE" --landed <side>` for the pass/fail verdict; `$RUN/il-side` is read only for a `warn`-level cross-check (`report_cache`), never the verdict. |
| `il-side-watch` | `journalctl --cursor-file` | bounded-backlog reattach | ✓ WIRED | Confirmed at `il-side-watch:71`. **But unguarded** — see gap; the link exists and functions in the common case, but has no failure-mode handling. |
| `il-repro --all` | every named exit path in `il-jump`/`il-side-watch` | re-runs every defect-demonstrating assertion, now expecting fixed behaviour | ✓ WIRED | `mode_all` (:671-679) calls all six sub-modes in sequence. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Six claimed `~/.dotfiles` commits exist, in order | `git --git-dir=~/.dotfiles --work-tree=~ log --oneline -25` | e921752, e1af5ee, 16772b9, fc739bc, 8408bcc, 8daf23e all present, correct order, correct parentage from 5d9015f | ✓ PASS |
| `~/.dotfiles` working tree is clean | `git ... status --porcelain` | empty | ✓ PASS |
| No debt markers in phase-modified files | `grep -nE 'TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER'` across all 6 files | no matches | ✓ PASS |
| `il-doctor` (non-invasive) passes live | `il-doctor` | 21 check(s) ok, 0 failed | ✓ PASS |
| `il-side-watch.service` is genuinely running the new code | `systemctl --user status il-side-watch.service` | active (running), following journal via `--cursor-file=...il-side-watch.cursor` | ✓ PASS |
| HOP-03's `jq` geometry computation reproduces independently | `hyprctl monitors -j \| jq -r '...'` | `1280 720`, matching 01-HOP-03-FINDING.md exactly | ✓ PASS |
| CR-01's core claim: an invalid cursor file hard-fails `journalctl --cursor-file` with no repair | scratch cursor file with garbage content, ran `journalctl --user -u input-leap-server.service -f -n 0 --cursor-file=<scratch> --no-pager` | `Failed to seek to cursor: Invalid argument`, exit 1, cursor file left as garbage afterward | ✓ PASS (confirms the defect is real, not overstated) |
| `il-doctor --test` / `il-repro --selfcheck-rescue` (real hops, stops/starts the live watcher service) | — | not run | ? SKIP — invasive: performs real `ydotool` cursor moves and stops/starts `il-side-watch.service` on the author's live daily-driver machine; relied on 01-06-SUMMARY.md's detailed, specific execution-time evidence (D3/D5) instead, cross-checked against independently-verified static code and the currently-running service |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| HOP-02 | 01-01, 01-03, 01-04, 01-05, 01-06 | The hop fires on every press — intermittent non-fire reproduced, root-caused, closed | ⚠ PARTIAL | Reproduction (SC1), root-cause (SC2), the fix's three parts, and the human gate (SC3) are all verified. But the fix itself ships a new, unresolved Critical regression path (CR-01) back into exactly this requirement's failure class — see gap. REQUIREMENTS.md marks this `[x] Complete`; this verification does not concur that closure is safe to stand as-is without CR-01's gap-closure plan. |
| HOP-03 | 01-02, 01-04, 01-05, 01-06 | Pointer lands dead centre on every hop, both directions | ✓ SATISFIED | Closed as NOT A DEFECT per 01-HOP-03-FINDING.md, which is how ROADMAP criterion 4 explicitly allows this requirement to be met. Independently re-derived this session. No orphaned requirements — REQUIREMENTS.md's traceability table maps only HOP-02/HOP-03 to Phase 1, both accounted for. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `il-side-watch` | 69-74 | No exit-status check / no cursor cleanup on `journalctl` hard-fail | 🛑 Blocker | See gap — CR-01, unresolved, own STATE.md marks a gap-closure plan owed |
| `il-side-watch` | 69-74 | Well-formed-but-unresolvable cursor silently replays full retained backlog | ⚠ Warning | Already recorded (01-REVIEW.md WR-01); not new, not blocking — no observed/logged trace when it fires, contradicts the phase's own "bounded" design property in spirit but does not lose data |
| `il-repro` | 102-107, 413-478 | `$RETRY` test file not covered by the `$STATE` cleanup trap | ⚠ Warning | Already recorded (WR-02); live-system contamination risk on interrupt, self-correcting, not blocking |
| `il-jump` | 232-250 | Detached self-check's rescue branch logs only via toast, never `$DBGLOG`; `centre_nastralis` success unchecked | ⚠ Warning | Already recorded (WR-03); pre-existing since 01-01, not introduced by 01-06; not blocking |
| `il-jump` | 49-56 | 200ms floor's comment cites a `--stress` invocation shape that cannot produce the cited same-direction timing | ⚠ Warning | Already recorded (WR-04); documentation/traceability gap only, value itself not shown wrong |
| `il-side-watch` | 44-46 | Unanchored substring match on `has connected`/`has disconnected` | ⚠ Warning | Already recorded (WR-05); low-confidence, self-correcting, not blocking |
| — | — | No shell-injection vector found in any of the 5 scripts | ℹ Info | Positive finding (IN-02), independently plausible given quoting patterns observed while reading all 5 files |

None of the Warning/Info items above are new discoveries of this verification — all are already filed in 01-REVIEW.md and STATE.md, most explicitly assigned to Phase 4. They are listed here for completeness and do not affect the status determination. Only the Blocker (CR-01) does.

### Human Verification Required

None outstanding. Per `workflow.human_verify_mode: end-of-phase`, the phase's human criteria (SC3's press-and-fire test, SC4's watched landing) were already performed on 2026-09-11 and are documented with a specific, checkable log tally (01-06-SUMMARY.md D6-D8) rather than an impression. This verification does not re-request them.

### Gaps Summary

Five of six observable truths hold, backed by re-derivable evidence this verification independently reproduced where it was safe to do so (six commits, clean tree, no debt markers, live `il-doctor` pass, live `il-side-watch.service` state, HOP-03's geometry arithmetic, and CR-01's own core failure mode).

The one gap is substantive, not cosmetic. This phase's entire reason for existing is to close a silent, permanent no-op class of defect (HOP-02). The fix it shipped to do that (`il-side-watch`'s bounded-backlog `--cursor-file` reattach, commit `8408bcc`) introduces a new, unguarded path back into that exact failure class: on `journalctl`'s own documented hard-failure mode for an unreadable cursor, `il-side-watch` crash-loops forever under the unit's real `Restart=always`/`RestartSec=3` config, `$STATE` freezes permanently, every press becomes a silent no-op, and — because `systemctl is-active` was measured (01-REVIEW.md CR-01) to report `active` on roughly 1 in 10 polls even mid-crash-loop — the phase's own automated health checks (`il-doctor`, `il-repro --watcher-gap`) cannot reliably catch it either.

This was found by this phase's own code review (01-REVIEW.md, the phase's only Critical finding), independently reproduced by this verification against the real `journalctl` on this machine, and is already acknowledged as unresolved and owed by the project itself: `.planning/STATE.md`'s "Pending Todos" section lists "CR-01 gap plan owed in Phase 01" as of this session, separate from and prior to the three items explicitly deferred to Phase 4. The phase's own bookkeeping agrees with this verification that Phase 1 is not yet safe to consider fully closed against its stated goal — "the hop fires on every press" — until a gap-closure plan lands for CR-01.

What is NOT in question: the reproduction, root-cause determination, the shipped fix's three intended parts, the human-at-the-keyboard gate, and the HOP-03 finding are all real, well-evidenced, and independently checked out by this verification. This is a real, close-to-complete phase with one specific, already-identified, already-owned piece of unfinished work — not a phase built on unverified claims.

---

_Verified: 2026-09-11T17:10:00Z_
_Verifier: Claude (gsd-verifier)_

---

## Re-verification — 2026-09-18

**Status: gaps_found (5/6) → passed (6/6).**

The single gap that reopened this phase (CR-01) is closed by `01-07`, which landed all three of the gap's own `missing:` items:

| `missing:` item from the 2026-09-11 gap | Where it landed | Checked |
|---|---|---|
| Check journalctl's exit status after the reattach pipeline; on nonzero, delete `$CURSOR` so the next restart cold-starts via `-n 0` | `il-side-watch:115-131` (`CURSOR_RC` sidecar, `rm -f "$CURSOR"`, `exit "${rc:-0}"`) | ✅ read live |
| Stop discarding journalctl's stderr unconditionally, so a future occurrence is discoverable | `il-side-watch:117` (`2>/dev/null` removed) + `:127` (named diagnostic to `>&2`) | ✅ read live |
| Land the gap-closure plan STATE.md's Pending Todos anticipated | `01-07-PLAN.md` / `01-07-SUMMARY.md`, 3 commits | ✅ |

Beyond the gap's literal ask, `01-07` also added the crash-loop detector the gap's *reasoning* implied was needed — the original finding noted `systemctl is-active` reports `active` on roughly 1 in 10 polls mid-loop, so a point-in-time liveness check could not catch this class at all. `il-doctor:81-88` replaces that with a journal-history check (systemd's own `Scheduled restart job, restart counter is at N` line, ≥2 inside a trailing 10s window), and `il-repro --cursor-crash-loop` makes both halves a permanent regression gate rather than a one-off finding.

**Live recheck this session:** `il-doctor` 21 ok / 0 failed, including the new crash-loop check reporting healthy; `il-side-watch.service` active with zero restarts, up 1d 21h.

**Deliberately not re-run:** the `--cursor-crash-loop` induction. It corrupts the cursor file and restarts the watcher on purpose, and the author was triaging an unrelated input-leap client problem at the time. Its live green run (6 ok / 0 failed, plus the unfixed-code reproduction at 3 ok / 3 failed) is recorded in `01-07-SUMMARY.md` D1–D3 against this same code, and the static read above independently confirms the mechanism is present. Saying so rather than quietly skipping it.

The three `deferred:` items above are unchanged and remain Phase 4's.

---

_Re-verified: 2026-09-18T18:05:00Z_
_Verifier: Claude (Opus 5)_
