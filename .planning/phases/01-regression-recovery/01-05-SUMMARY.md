---
phase: 01-regression-recovery
plan: 05
subsystem: infra
tags: [shell, posix-sh, input-leap, hyprland, root-cause, journalctl]

requires:
  - phase: 01-01
    provides: "01-EVIDENCE.md's six measurements plus the tracer's proved/not-proved split; il-repro --inject-noop"
  - phase: 01-02
    provides: "01-A1-RESULT.md's FROZE verdict, D-14's local landing oracle"
  - phase: 01-03
    provides: "il-jump's full refusal log, il-repro's full D-21 harness (--stress/--watcher-gap/--arm/--report), Route 2 armed and running continuously since"
  - phase: 01-04
    provides: "01-HOP-03-FINDING.md's NOT A DEFECT settlement, the non-circular il-cursortrace --landed oracle"
provides:
  - "01-ROOTCAUSE.md: the corrected 849b6ac..9d1f129 diff window re-verified read-only against ~/.dotfiles, and the HOP-02 determination split into Proven / Evidenced-but-not-proven / Not-established, closing with seven fix properties for 01-06's decision checkpoint"
affects: ["01-06"]

actuals:
  tokens: 7077
  tasks: 2
  commits: 2
  plan_head_before: ced2d2561719bf6c9bb757ab3b18ec5233867fd2

tech-stack:
  added: []
  patterns:
    - "Blob content-hash comparison via `git show <rev>:<path> | sha256sum` as the RESEARCH-Q3-documented workaround for this sandbox's pathspec-filtered git diff/ls-tree returning silently empty output"
    - "Rate bracketing (naive-uniform lower bound vs. single-sample-extrapolation upper bound) when a mechanism is proven capable but its real-world frequency rests on n=1 — state both bounds and why each is untrustworthy alone, rather than picking one and presenting it as settled"

key-files:
  created:
    - .planning/phases/01-regression-recovery/01-ROOTCAUSE.md
  modified: []

key-decisions:
  - "Named mechanism is NOT 'NOT TRACED' — the causal chain (il-side-watch's two independent transition-loss gaps feeding il-jump's blindly-trusting guard) is proven end-to-end by direct injection and by a live watcher-restart test, so it is named. What is explicitly NOT claimed is that this chain has been caught firing during a press the author remembers failing — no organic catch exists yet."
  - "Corrected the plan's own task text: '92f64bc landed about an hour later' is wrong. Re-derived from the two commits' own author timestamps: the gap is 5h52m37s. Restated rather than propagated, per this plan's purpose of not repeating unchecked claims."
  - "Corrected RESEARCH's own ranking rationale for mechanism #2 (the forceLeaveClient/'jump from' line-shape mismatch): RESEARCH ranked it second because its trigger was 'so-far unobserved' — 01-EVIDENCE.md's own measurement 2 already observed it firing 7 times in the same 7-day window used to score mechanism #1. Recorded as evidenced-but-not-proven, not promoted to co-equal with mechanism #1, because whether it ever fires as a consequence of the author's own hop presses (vs. some unrelated disconnect event) is still unconfirmed."
  - "D-10's literal wording ('HEAD is still 9d1f129') no longer holds and is not restated as if it did: ~/.dotfiles HEAD is now 7 commits ahead (this phase's own D-11/D-13-licensed instrumentation, two of which touch il-jump itself). The working tree is still clean (the actual safety property D-09/D-10 protect) — restated precisely rather than the imprecise original sentence."
  - "Computed an expected-rate bracket for mechanism #1 from the measured restart count, overlap count, and transition rate rather than leaving 'is this consistent with the user's report' as an impression: naive-uniform-spacing lower bound ~1 lost transition per ~81 days; single-restart-sample upper bound ~1 per ~23 hours. Neither bound is trusted alone — flagged why for each."
  - "Did not run requirements mark-complete for HOP-02 or HOP-03 — closure is explicitly plan 01-06's output per this plan's own artifact-ownership table and every upstream plan's identical precedent."

patterns-established:
  - "Pattern: when a plan's own task prose states an unverified factual claim (a timestamp gap, a ranking rationale), check it against the primary source before restating it in the determination, and record the correction plainly rather than silently fixing it or silently repeating it."

requirements-completed: []

coverage:
  - id: D1
    description: "The corrected diff window (849b6ac..9d1f129) re-verified read-only against ~/.dotfiles at execution time: working tree clean, 849b6ac cross-checked as last-tested-good against the dated journal, 92f64bc's one-commit apparatus confirmed by file stat, il-jump at 9d1f129 confirmed byte-identical to 92f64bc's by direct content diff"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "git --git-dir=$HOME/.dotfiles --work-tree=$HOME status --porcelain (empty, exit 0); grep -Eq '^## The diff window' && grep -Eq '849b6ac' && grep -Eq '92f64bc' against 01-ROOTCAUSE.md"
        status: pass
    human_judgment: false
  - id: D2
    description: "The HOP-02 determination: four sections (Proven / Evidenced but not proven / Not established / The diff window) plus a populated Named mechanism line, every claim cited to the executed assertion that produced it, an expected-rate bracket computed from measured counts, and the live organic Route 2 log (47 dispatches, 4 isolated no-ops, zero buggy exit paths) read fresh this session"
    requirement: HOP-02
    verification:
      - kind: other
        ref: "grep -Eq '^## Proven' && grep -Eq '^## Evidenced but not proven' && grep -Eq '^## Not established' && grep -Eq '^## The diff window' && grep -Eq '^\\*\\*Named mechanism:\\*\\* .+' against 01-ROOTCAUSE.md; il-doctor and il-repro --all both re-run this session, both green"
        status: pass
    human_judgment: true
    rationale: "Whether the determination correctly separates demonstration from inference — the core judgment call this plan exists to get right, per RESEARCH Pitfall 1 and the project's governing scar — is exactly the kind of call this phase's own design keeps out of unreviewed automated pass/fail. The automated checks confirm the required sections and citations exist; whether the split itself is honest is for the author (and 01-06's decision checkpoint) to judge against the cited evidence."

duration: ~55min
completed: 2026-09-11
status: complete
---

# Phase 1 Plan 05: Root-Cause Determination Summary

**HOP-02's silent no-op traced to a named, proven mechanism — `92f64bc`'s `il-side-watch` losing transitions via two independent gaps (restart-reattach, `jump from` line-shape mismatch) feeding `il-jump`'s guard, which trusts the result without verification — with an explicit, evidence-computed gap between "proven capable" and "caught actually firing," and seven fix properties handed to plan 01-06 instead of a foregone implementation.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-09-10 (session start, reading the required evidence base)
- **Completed:** 2026-09-11T00:13:41+01:00 (final verification pass)
- **Tasks:** 2/2
- **Files modified:** 1 (created)

## Accomplishments

- **The diff window re-verified from the history itself, not restated from RESEARCH.** Confirmed the working tree is clean, but corrected D-10's literal "HEAD is still `9d1f129`" — `~/.dotfiles` HEAD is now 7 commits ahead (this phase's own licensed instrumentation), stated precisely rather than glossed over. `849b6ac` cross-checked as the last tested-good commit against the dated journal (`2026-09-09.md`, "All tested" closing line). `92f64bc`'s one-commit apparatus confirmed by file stat (`il-side-watch` and `il-doctor` both created whole, `il-jump` +217 lines, all in one commit) — but the plan's own "about an hour later" framing was checked against the commits' actual author timestamps and found wrong: the real gap is **5h52m37s**, corrected on the record rather than propagated. `il-jump` at `9d1f129` confirmed byte-identical to `92f64bc`'s by direct content `diff` (empty) and matching SHA-256 hashes, not by trusting the revert diff inverts cleanly.
- **The determination split into Proven / Evidenced-but-not-proven / Not-established, each claim cited to its assertion.** Proven: the `already-on-side` guard's silent-noop behavior under a forced-stale cache (Route 3), the watcher-restart-gap's survive-then-refuse consequence (`--watcher-gap`), A1's FROZE verdict, and HOP-03's NOT A DEFECT finding — plus a fresh `il-doctor`/`il-repro --all` re-run this session, both green, unchanged.
- **An expected-rate bracket computed from the measured counts, not left as an impression.** From the one observed restart-gap instance (2 transitions lost, ~4s gap) and the measured 166.5s mean transition interval: a naive uniform-spacing lower bound of ~1 lost transition per ~81 days, and a single-sample-extrapolation upper bound of ~1 per ~23 hours — both bounds explicitly flagged as untrustworthy alone (transitions are measurably bursty, not uniform; the one sample most plausibly coincided with `92f64bc`'s own build-and-test session, not later ordinary use).
- **A correction to RESEARCH's own ranking rationale.** RESEARCH ranked the `forceLeaveClient()`/`jump from` line-shape mismatch (mechanism #2) second because its trigger was "so-far unobserved" — `01-EVIDENCE.md`'s own measurement already observed it firing 7 times in the same 7-day window used to score mechanism #1. Recorded as a real, deterministic-when-triggered second gap, not promoted to equal footing, because whether it ever fires as a consequence of the author's own hop presses (versus an unrelated disconnect event) remains unconfirmed.
- **The live organic Route 2 log read fresh, in full, not summarized from memory.** Since arming at plan 01-03 (~20:03 on 2026-09-10) through this plan's execution (~00:13 on 2026-09-11, ~4 hours): 47 real dispatches, 4 isolated `already-on-side` no-ops (none clustered, none matching D-02's "stays dead" shape), zero occurrences of any of the other five exit paths. A genuine organic null result for this window — recorded as such, not stretched into either "the bug doesn't exist" or "the bug is ruled out."
- **Named mechanism is populated, not "NOT TRACED."** The causal chain — `il-side-watch`'s two independent transition-loss gaps feeding `il-jump`'s guard, which trusts whatever survives without verification — is proven end-to-end by direct injection and by a live watcher-restart test. What is explicitly not claimed: that this chain has been caught firing during a press the author remembers failing. No fix was chosen; the document closes with seven properties (guard trust model, watcher blind-spot closure, the `jump from` gap's disposition, preserving the toggle model's own reason for existing, the 50ms budget, the human-at-keyboard gate, and not regressing `il-doctor`'s non-circularity or the single-flight lock) for plan 01-06's decision checkpoint to choose among.

## Task Commits

1. **Task 1: Re-verify the diff window against the history, read-only** - `da81038` (docs) — the `## The diff window` section, read-only against `~/.dotfiles`, corrected the "about an hour later" claim
2. **Task 2: The determination — proven, evidenced, and not established, kept apart** - `fca18f4` (docs) — the four-section determination, the expected-rate bracket, the live Route 2 log, the Named mechanism line, and the seven fix properties

**Plan metadata:** this commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified

- `.planning/phases/01-regression-recovery/01-ROOTCAUSE.md` (created) — the phase's determination, 479 lines, no code touched, no script modified, nothing checked out

## Decisions Made

See `key-decisions` in the frontmatter above — the Named mechanism vs. NOT TRACED call, the two factual corrections (the timestamp gap, RESEARCH's ranking rationale), the precise restatement of D-10's now-inaccurate wording, and the deliberate non-completion of `requirements mark-complete` for HOP-02/HOP-03.

## Deviations from Plan

None — plan executed exactly as written. Two factual corrections were made to claims stated in the plan's own task prose and in upstream RESEARCH.md (the "about an hour later" timestamp gap, and RESEARCH's ranking-rationale premise that mechanism #2's trigger was "so-far unobserved") — these are not deviations from the plan's instructions, which explicitly directed re-verifying rather than restating; they are exactly what the plan asked for, recorded here for visibility rather than filed as auto-fixes since no code, script, or live state was touched.

## Issues Encountered

- **`git ls-tree -r` (no pathspec) returned zero lines against `~/.dotfiles` in this sandboxed shell**, reproducing the same empty-output quirk RESEARCH Q3 already documented for pathspec-filtered `git diff`/`git show`. Worked around identically: `git show <rev>:<path>` (content read, not tree listing) was used throughout for every blob comparison in this plan, exactly as RESEARCH Q3's own noted workaround prescribes. No script or config was touched to fix this — it is a sandbox interception of certain git subcommands' path arguments, out of this plan's scope to chase further.
- **The one observed watcher-restart-gap instance (`01-EVIDENCE.md` measurement 1, `00:53:34`→`00:53:38` on 2026-09-10) falls minutes before `92f64bc`'s own commit timestamp (`00:57:29`)** — meaning the single sample underlying the expected-rate bracket's upper bound most plausibly reflects the author's own build-and-test activity for `92f64bc`, not later ordinary daily-driver use. This was flagged explicitly in `01-ROOTCAUSE.md` as a reason the upper bound should not be trusted as a long-run rate; not investigated further since doing so would require guessing at intent behind a timestamp coincidence rather than measuring anything.

## User Setup Required

None — no external service configuration required. Route 2 stays armed (unchanged by this plan) for plan 01-06 to inherit.

## Next Phase Readiness

- `01-ROOTCAUSE.md` is the determination plan 01-06's decision checkpoint reads from: the named mechanism, the re-verified diff-window facts (including the two corrections), and the seven fix properties.
- **Not yet done, by design:** choosing a fix shape, shipping it, and running the phase's human-at-the-keyboard gate are explicitly plan 01-06's work per this plan's own artifact-ownership table. `PROJECT.md` and `ROADMAP.md`'s "`9d1f129` alone" wording is still uncorrected — per D-08, that amendment happens after this phase, not before, and is out of this plan's declared `files_modified` scope.
- Route 2 (`$XDG_RUNTIME_DIR/ilhop-debug.on`) remains armed and logging; plan 01-06 inherits a longer organic observation window than this plan had (~4h vs. whatever elapses before 01-06 executes).
- Nothing on the daily driver was altered: `$XDG_RUNTIME_DIR/il-side` reads `mac`, its real current value, untouched by this plan; `~/.dotfiles` working tree is clean; `il-doctor` (no `--test`) reports 21/21 and `il-repro --all` reports 54/54, both re-run fresh this session and unchanged from the upstream plans' baselines.

---
*Phase: 01-regression-recovery*
*Completed: 2026-09-11*

## Self-Check: PASSED

All claimed files found on disk (`01-ROOTCAUSE.md`); both claimed commits found in `ilhop` (`da81038`, `fca18f4`); `git rev-list --count ced2d25..HEAD` = 2, matching `actuals.commits`.
