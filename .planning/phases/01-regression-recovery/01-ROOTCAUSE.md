# Phase 1 Plan 05 — Root-Cause Determination

Session: 2026-09-11T00:13+0100. Read-only against `~/.dotfiles`; nothing checked
out, nothing on the live input path touched. Consumes `01-EVIDENCE.md`,
`01-A1-RESULT.md`, `01-HOP-03-FINDING.md`, `01-RESEARCH.md`, and the live
`$XDG_RUNTIME_DIR/ilhop-debug.log` (Route 2, armed since plan 01-03).

## The diff window

**Method, per D-09:** read the diffs cold against `~/.dotfiles`
(`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`). No revision was checked
out. Every command below and its raw output is reproducible by re-running the
same invocation.

### Confirmation 1 — working tree clean, and what "HEAD is 9d1f129" now means

```
$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis status --porcelain
(empty)

$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis log --oneline -1
5d9015f il-doctor: cut the circularity out of --test's live round trip
```

The working tree is clean — **confirmed**, no uncommitted drift. D-10's literal
wording ("HEAD is still `9d1f129`") does **not** hold any more: current HEAD is
`5d9015f`, seven commits ahead of `9d1f129`:

```
$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis log --oneline 9d1f129..HEAD
5d9015f il-doctor: cut the circularity out of --test's live round trip
b407b76 il-cursortrace: add the non-circular landing oracle (--landed)
a9128f1 il-repro: route 1 stressor, watcher-gap assertion, route 2 arm/report
d3833e7 il-jump: name every remaining exit path, and the successful dispatch
efc1cfa il-cursortrace: fix journalctl timestamp format, add --before bound
1ae5cf0 il-cursortrace: cursor sampler and A1 falsification oracle
926abb7 il-jump: ILHOP_DEBUG-gated refusal logging; add il-repro reproduction harness
```

This is expected, not drift: all seven are this same phase's own plans
(01-01 through 01-04), landing exactly the instrumentation and oracle work
CONTEXT.md's domain note explicitly licenses as the one capability this phase
is allowed to add. Two of the seven (`926abb7`, `d3833e7`) touch `il-jump`
itself — so the literal claim "`il-jump` at HEAD is byte-identical to
`92f64bc`'s" is **also no longer true of current HEAD**, for the same reason.
What D-10/D-09 actually guard against — untested, uncommitted code sitting on
the live input path — does not apply to these seven: each went through this
phase's own per-task commit-and-verify protocol, and 01-03's paired latency
samples confirmed the added `dbg()` calls cost no measurable latency. The
safety property holds; the specific sentence describing it needs restating at
execution time rather than assumed, which is what this confirmation does.

**Restated precisely:** the working tree is clean (no uncommitted drift, the
actual D-09/D-10 safety property). The revert-window comparison below is done
against the commits that bound the suspect window itself (`92f64bc` and
`9d1f129`), not against today's HEAD, because today's HEAD includes seven
commits of this phase's own licensed instrumentation on top of it.

### Confirmation 2 — `849b6ac` is the last commit from the day both paths were tested-good

```
$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show -s --format='%H %ai %s' 849b6ac
849b6ac8b95473f9fef841d820437b9ac7e1f044 2026-09-09 19:04:52 +0100 binds: one chord for the machine hop - ALT+C on both machines
```

Cross-checked against `~/.local/share/ryoku/rashin/journal/2026-09-09.md`: the
"One chord for the hop: ALT+C on both machines" section is the **last** dated
entry under 2026-09-09, its wording matches `849b6ac`'s commit message
verbatim in substance, and it sits at the end of a "Two-machine 'feels like
one' pass" section whose closing line reads "All tested." — corroborating
D-07's claim independently of CONTEXT.md's own table. **Confirmed.**

### Confirmation 3 — `92f64bc` carried the whole apparatus in one commit

```
$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show -s --format='%H %ai %s' 92f64bc
92f64bc53f37da8640580e053a03c72f88c25573 2026-09-10 00:57:29 +0100 il-jump: make the screen hop direction-aware and self-healing

$ git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show --stat 92f64bc | tail -8
 .config/ryoku/user_edits/hypr/modules/binds.lua |   2 +-
 .config/systemd/user/il-side-watch.service      |  14 ++
 .config/systemd/user/input-leap-server.service  |  13 ++
 .local/bin/il-doctor                            | 108 ++++++++++++
 .local/bin/il-jump                              | 217 ++++++++++++++++++------
 .local/bin/il-side-watch                        |  38 +++++
 6 files changed, 343 insertions(+), 49 deletions(-)
```

Confirmed: `il-side-watch` and `il-doctor` both go from 0 lines to full files
inside this one commit (`+14`/`+38` and `+108` respectively, both brand new
paths in the diff), and `il-jump` itself grows by 217 lines in the same commit
(toggle mode, `read_side()`, the single-flight lock, the ydotool-liveness
probe, the detached self-check, `centre_mac()`/`centre_nastralis()`). This is
**one commit**, not a series — there is no earlier or later hunk within
`92f64bc` itself to isolate further.

**Correction to the plan's own framing:** the plan's task text describes
`92f64bc` as landing "about an hour later" than `849b6ac`. The measured gap is
**5 hours 52 minutes 37 seconds** (`849b6ac` at `19:04:52`, `92f64bc` at
`00:57:29` the same calendar night, crossing midnight) — re-derived directly
from the two commits' own author timestamps above, not from the plan's prose.
Restated here rather than propagated, per this plan's own purpose: a claim
that goes unchecked because it "reads like" something already established is
exactly the failure mode `01-05`/`01-06` exist to correct for.

### Confirmation 4 — `il-jump` at HEAD (`9d1f129`) is byte-identical to `92f64bc`'s

```
$ diff <(git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show 92f64bc:.local/bin/il-jump) \
       <(git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show 9d1f129:.local/bin/il-jump)
(empty — no output, exit 0)

$ for rev in 849b6ac 92f64bc 6fc6dbe 9d1f129; do
    printf '%s -> ' "$rev"
    git --git-dir=/home/nastralis/.dotfiles --work-tree=/home/nastralis show "$rev:.local/bin/il-jump" | sha256sum
  done
849b6ac -> 44549eb7548110e162fc3aedff4cbc55d591bf48f5ccdf17c3bc79564380c9ba
92f64bc -> 0854987858f57ef09a5ae1f79cc14166518cc3fc97eac16d0caf2163b09331d1
6fc6dbe -> 262cb65cdecca9ba74110b28cc513806fff63ec85f39cb365e29ac0905c06f54
9d1f129 -> 0854987858f57ef09a5ae1f79cc14166518cc3fc97eac16d0caf2163b09331d1
```

`92f64bc` and `9d1f129`'s `il-jump` share the identical content hash, and a
direct `diff` between the two blobs is empty. `6fc6dbe` (the modifier
re-press, in between) has a distinct hash, confirming the revert genuinely
undid `6fc6dbe`'s change and left no residue — done here by direct content
comparison, not by reading the revert diff and trusting it inverts cleanly.
`git ls-tree -r <rev> | grep il-jump` (the RESEARCH Q3-documented pathspec
route) reproduced the same empty-output sandbox quirk RESEARCH.md already
flagged (`git ls-tree -r` with no filter returned zero lines against this
repo in this shell for every revision tried); `git show <rev>:<path>` was used
instead throughout, per RESEARCH Q3's own noted workaround, and is what
produced every hash and diff above. **Confirmed.**

### The consequence, per D-06/D-07

**The investigated window is `849b6ac..9d1f129`**, not `9d1f129` alone as
`PROJECT.md`'s Active list and `ROADMAP.md`'s Phase 1 criterion 2 currently
read. There is no hunk within that window to isolate further, because
`92f64bc` introduced the entire toggle/side-file/self-healing apparatus whole,
in one commit, five hours fifty-two minutes after the last tested-good state,
and the only later change inside the window (`6fc6dbe`'s modifier re-press)
was fully reverted by `9d1f129` with no residue in `il-jump` — confirmed above
by direct content diff, not inferred from the revert commit's diff alone.

**Per D-08, `PROJECT.md` and `ROADMAP.md` are amended after this phase, not
before.** This document is the record of the corrected window in the
meantime; neither project document is touched by this plan (out of its
declared `files_modified` scope).

**From RESEARCH Q3, on the record here as instructed:** `92f64bc`'s own commit
message states directly that its author already knew, at the time, the fix
for the *previous* reported bug could not be verified through the keybind path
and was shipped on code-reading confidence — quoted verbatim from
`git show 92f64bc`: *"The cause could not be reproduced by faking keypresses,
because ydotool key events do not drive Hyprland keybinds at all... Rather
than keep chasing it, the whole thing is rebuilt so that failure mode cannot
exist."* That is the identical evidentiary posture — a rebuild shipped on
reasoning, not verified execution — that this phase's method (D-09: read
cold, don't guess; Route 3 before Route 1 before trusting either) exists to
correct for one level up. It is on the record for whoever reads this before
choosing 01-06's fix, not offered as an accusation.

---

## Proven

Executed and observed this session or by the four upstream plans, not
reasoned from reading code. Each claim below names the assertion that
produced it.

- **The guard now labelled `already-on-side` (`il-jump:91` in the revert's own
  numbering, `il-jump:120` in the current, phase-instrumented file) turns a
  wrong cached `$XDG_RUNTIME_DIR/il-side` value into a silent, motionless
  `exit 0` on every press, in both directions.** Demonstrated by
  `il-repro --inject-noop` (`01-EVIDENCE.md` "What the tracer proved"): forcing
  the side file to the guard's computed `$want` produced exit 0, zero pointer
  motion (`hyprctl cursorpos` unchanged, `dx=0 dy=0`/`dx=0 dy=1`px), and,
  once instrumented, exactly one self-explaining log line naming the refusal —
  in both `left` and `right` directions. RED was observed first against the
  unmodified guard (4 assertions failed specifically on "a refusal line
  appeared," not on exit code or pointer stillness, which already passed) —
  isolating precisely what changed: the guard already produced D-02's
  *symptom* before instrumentation; instrumentation made it *explain itself*.
  This matches D-02's persistence (repeated presses, not a one-shot
  transient — every repeated injected invocation refused identically) and
  D-01's direction symmetry (`left` under a forced-`mac` value, `right` under
  a forced-`nastralis` value, both refuse the same way).
- **A stale value survives an `il-side-watch.service` restart untouched, and
  the surviving stale value then produces the identical silent no-op.**
  Demonstrated end-to-end, not argued from the code, by
  `il-repro --watcher-gap` (`01-03-SUMMARY.md` coverage D3, 5/5 checks; also
  re-run this session as part of `il-repro --all`, still green — see
  "Live re-verification" below). The mode injects a wrong value, restarts the
  real `il-side-watch.service`, and asserts both that the wrong value survived
  unmodified and that it then produced the guard's silent no-op. Measured
  restart gap in this synthetic test: 15–18ms across three runs (this
  session's rerun: 16ms) — explicitly and correctly caveated by the tool's own
  output as a manual `systemctl restart` (skips `RestartSec`'s automatic-crash
  delay), not representative of the real `Restart=always` cycle's timing.
- **The decision table's two refusal combinations hold under load.**
  `il-repro --stress` looped both combinations 20× each with zero pointer
  motion, 41/41 green (`01-03-SUMMARY.md` coverage D2).
- **`hyprctl cursorpos`, read locally on Nastralis, freezes once input-leap's
  server-side capture takes the pointer, and the freeze is genuine capture,
  not a screen-edge-clamp artifact.** `01-A1-RESULT.md`: verdict FROZE at the
  `19:29:13` marker, independently discriminated from a clamp by the absence
  of `il-jump`'s own post-crossing `centre_mac()` rightward nudge — which an
  edge clamp alone would not block — across 3,481 consecutive local samples
  over the following ~2m12s. This is D-14's oracle, now the non-circular
  landing check `il-doctor --test` runs (`01-04-SUMMARY.md`), and it underwrote
  HOP-03's own settlement.
- **HOP-03 clears D-18's bar on both legs, from live geometry, not a
  hardcoded fallback.** `01-HOP-03-FINDING.md`'s four measurements: the `jq`
  read in `centre_nastralis()` genuinely computes `1280 720` from real monitor
  JSON (independently reproduced by manual arithmetic against the same raw
  JSON, not just pattern-matched); the target clears the 100px-edge bar by
  more than 7× on every axis; `centre_mac()`'s nudge (427px, 854px at the
  measured ~2× post-acceleration value) stays inside the Mac's cached 1710px
  width with margin to spare; and `il-cursortrace --landed nastralis` agreed
  with the cache at measurement time. **Finding: NOT A DEFECT** — no HOP-03
  live-system claim from this document overturns that determination.

### Live re-verification this session

Re-run now, not assumed from the upstream plans' own reports, per D-09's
"confirm at execution time" standard applied to the phase's own prior claims
as well as to the diff window:

```
$ /home/nastralis/.local/bin/il-doctor
21 check(s) ok, 0 failed

$ /home/nastralis/.local/bin/il-repro --all
54 check(s) ok, 0 failed
  ok    il-jump right exited 0 against the surviving wrong value
  ok    the surviving wrong value produced a silent no-op, logged as already-on-side
  ok    il-side-watch.service still active at exit
```

Both green, unchanged from the upstream plans' own baselines. Nothing in this
plan altered live state: `$XDG_RUNTIME_DIR/il-side` reads `mac`, its real
current value, not forced by anything this plan did.

## Evidenced but not proven

The occurrence half — that a wrong value has actually happened, or does
happen often enough to explain the user's reports — separated from the
mechanism half above, per this plan's purpose.

- **The watcher-restart-gap mechanism (RESEARCH Q2 #1) has fired at least
  once, with real consequence, but the sample size is one.**
  `01-EVIDENCE.md` measurement 1: one confirmed same-boot
  `Restart=always`/`RestartSec=3` cycle in the 7-day journald window
  (`00:53:34`→`00:53:38`, gap ~4s), inside which **2 real transitions
  provably landed and were never observed** by `il-side-watch` (measurement
  3). In this one instance the pair happened to net back to the same value
  the cache already held, so `il-side` was not *visibly* corrupted that time
  — coincidence, not correctness; an odd-count or differently-ordered pair
  would have left it stale in exactly D-02's shape, and no code path here
  could have told the difference at the time.

  **Expected rate, computed from the measured counts (not an impression):**
  mean transition interval 166.5s (measurement 2); restart gap ~4s
  (measurement 1). A naive uniform-spacing estimate gives
  `4s / 166.5s ≈ 0.024` expected lost transitions per restart. The one
  restart observed lost **2** — about 83× the naive estimate — because real
  transitions cluster in bursts (`01-EVIDENCE.md`'s own side note: "usage is
  bursty... not evenly spaced") rather than arriving evenly; both lost
  transitions in this instance were one second apart (`00:53:35`,
  `00:53:36`), consistent with a rapid double-hop rather than isolated
  ordinary presses. Combined with the observed restart frequency (1 restart
  in 46.8h of actual logged uptime ≈ 0.0214/hour), this brackets a wide range:
  - **Lower bound** (naive uniform spacing): `0.0214 × 0.024 ≈ 0.0005`
    lost transitions/hour ≈ roughly **one lost transition per ~81 days**.
  - **Upper bound** (extrapolating from the one observed restart's actual
    loss): `0.0214 × 2 ≈ 0.043` lost transitions/hour ≈ roughly **one lost
    transition per ~23 hours**.

  Neither bound is trustworthy on its own: the lower bound assumes spacing
  the data itself says is wrong (bursty, not uniform); the upper bound
  extrapolates a long-run rate from a single sample that occurred at
  `00:53`–`00:57` on 2026-09-10 — minutes *before* `92f64bc`'s own commit
  timestamp (`00:57:29`), meaning this one observed restart most plausibly
  happened during the author's own build-and-test activity for `92f64bc`
  itself, not during later, ordinary daily-driver use. Whether that makes it
  more or less representative of the failure rate the user has actually
  experienced since is not determined by this document. **Is this
  consistent with the user's report?** D-02/PROJECT.md describe HOP-02 as
  intermittent ("sometimes doesn't fire"), not constant. A rate anywhere in
  the ~1/day to ~1/81-days range is not inconsistent with "sometimes," but
  the bracket is wide enough that this measurement supports the mechanism's
  *plausibility*, not its *frequency*, with any confidence.

- **A second, independent gap exists and is more certain in one respect: it
  is deterministic when triggered, not restart-dependent.** RESEARCH Q1/Q2
  mechanism #2 — `il-side-watch:24`'s case statement matches only
  `switchScreen()`'s `switch from "X" to "Y"` line shape and **never**
  matches `forceLeaveClient()`'s differently-worded `jump from "X" to "Y"`
  line, confirmed by direct code read (`il-side-watch:24`, unmodified this
  entire phase — see "The diff window" confirmations). `01-EVIDENCE.md`
  measurement 2 counted **7** `jump from` occurrences in the same 7-day
  window against 1005 `switch from` occurrences (0.69% of all 1012
  transitions) — **a correction to RESEARCH's own ranking rationale**, which
  ranked this mechanism second specifically because its trigger was
  "so-far unobserved." It has now been observed, seven times, in the same
  measurement pass that found mechanism #1's single restart-gap instance.
  Every one of those seven is a transition `il-side-watch` structurally
  cannot see, with no restart or race window required — 100% of `jump from`
  events are missed by construction, not by chance.

  **What is not established about this second gap:** whether
  `forceLeaveClient()` ever fires as a consequence of the author's own
  `ALT+C`/`ALT+H` presses at all, versus firing only for some other
  administrative event (a forced client disconnect, for instance) unrelated
  to ordinary hop usage. RESEARCH Q1 itself could not locate
  `forceLeaveClient()`'s call site precisely enough to settle this, and this
  document does not settle it either — it is recorded here as a real,
  measured, and under-examined second staleness vector, not folded into
  mechanism #1's rate above because its relevance to D-02's reported
  workflow is unconfirmed. It is also possible a `jump from` event
  co-occurs with a companion `has disconnected`/`has connected` NOTE line for
  the same underlying event, which **would** be caught by
  `il-side-watch:34-35`'s separate branch and could self-correct the state
  regardless of the missed `jump from` line — this was not checked in this
  document and is a discriminating test for whoever picks up this thread.

- **Since Route 2 was armed (`01-03`, ~20:03 on 2026-09-10) through this
  plan's own execution (~00:13 on 2026-09-11 — roughly 3h50m–4h of real,
  organic, unattended daily-driver use), no occurrence of any of the
  suspect-adjacent failure shapes has been caught.** Read directly from the
  live log via `il-repro --report`, not summarized from memory:

  ```
  Tally by exit path:
    already-on-side  4
    stale-lock       0
    superseded       0
    watcher-unknown  0
    usage            0
    die              0
    dispatch         47
  ```

  51 total lines: 47 real dispatches (real hops fired, confirmed by the
  `seq=` field's presence), 4 `already-on-side` no-ops. **Every one of the 4
  no-ops is isolated** — the full log (reproduced below, not just the tail)
  shows no two `already-on-side` lines for the same direction occurring back
  to back without an intervening successful `dispatch` in between, which is
  the specific shape D-02 describes ("stays dead for a while, repeated
  presses do nothing"). This is consistent with each of the 4 being an
  *ordinary, correct* no-op (the author pressing while genuinely already on
  the target side) rather than a cache-staleness bug — but this document
  cannot rule the alternative out from the log alone, because the log does
  not record whether the human expected a hop at that exact press; it only
  records that the guard's own comparison agreed with itself. Full log:

  ```
  2026-09-10T20:13:28.320+0100 already-on-side: dir=right CUR=nastralis want=nastralis
  2026-09-10T20:29:08.266+0100 already-on-side: dir=right CUR=nastralis want=nastralis
  2026-09-10T21:09:51.892+0100 dispatch: dir=right ...
  [... 18 more dispatch lines between 21:09 and 21:23 ...]
  2026-09-10T23:35:51.757+0100 dispatch: dir=right ...
  2026-09-10T23:35:53.196+0100 already-on-side: dir=right CUR=nastralis want=nastralis
  2026-09-10T23:35:58.310+0100 dispatch: dir=left ...
  [... 22 more dispatch lines between 23:38 and 00:02 ...]
  2026-09-10T23:47:07.383+0100 already-on-side: dir=right CUR=nastralis want=nastralis
  2026-09-11T00:02:15.436+0100 dispatch: dir=left want=mac CUR=nastralis seq=546659-1789081335434812211
  ```

  This is a genuine organic null result for the observation window it covers
  — not "the bug doesn't exist," but "it did not fire, or did not fire
  visibly, during these ~4 hours of real use." Given the rate bracket above
  (anywhere from ~1/day to ~1/81-days for mechanism #1 alone, plus an
  unknown contribution from mechanism #2), a 4-hour window not catching an
  occurrence is not informative on its own either way — it is consistent
  with both bounds of the bracket. The log stays live past this plan;
  whoever executes 01-06 inherits it with more hours on the clock.

## Not established

Outside what any of the three sanctioned reproduction routes, or the
occurrence evidence above, can reach at all.

- **Whether the Hyprland keybind (`ALT+C`/`ALT+H`) ever fails to invoke
  `il-jump` in the first place.** That dispatch lives entirely in Hyprland's
  own keybind layer, outside every script this phase can touch, and — per
  PROJECT.md's Testability constraint, measured directly, not assumed —
  `ydotool` key events do not fire Hyprland keybinds at all (0 fires). No
  route available to this phase, including the live Route 2 log above, can
  observe this layer: Route 1 calls `il-jump` directly and so never exercises
  dispatch; Route 3 starts even further downstream, inside a specific guard.
  Route 2's dispatch tally (47 in ~4 hours) confirms presses **are** reaching
  `il-jump` at a rate consistent with ordinary use, but says nothing about
  whether some other press, remembered as failed, never reached it at all —
  that would show up as **no new line whatsoever** near the remembered press
  time, which this document did not have a specific remembered failure
  timestamp to check against this session.
- **Whether HOP-02 and HOP-03 co-occur.** D-04 recorded this as unknown
  either way. It remains unknown either way. `01-HOP-03-FINDING.md` settled
  HOP-03 as NOT A DEFECT, so there is currently no live HOP-03 occurrence to
  correlate a HOP-02 occurrence against — the question is not answered, it is
  now moot in practice until/unless HOP-05's work (Phase 3.1) surfaces a new
  landing-side defect to compare against.
- **Whether the `forceLeaveClient()`/`jump from` gap (mechanism #2, above)
  ever actually fires as a consequence of the author's own hop presses**, as
  opposed to some unrelated administrative disconnect event. Recorded under
  "Evidenced but not proven" above as the specific open sub-question it is,
  not restated here as a separate item — flagged again because it is the
  single most concrete follow-up this document identifies for whoever
  extends Route 2 or reads `input-leap`'s own `forceLeaveClient()` call
  sites next.

## What the fix must accomplish

Properties, not an implementation — 01-06's decision checkpoint chooses among
implementations against these, per D-17: if the cause is `92f64bc`'s
toggle/side-file **design**, Phase 1 pays whatever that costs; this document
does not pre-select which of the following shapes that payment takes.

1. **The guard must stop treating a cache it cannot currently verify as
   ground truth for a silent, unrecoverable no-op.** Either the value is
   checked against something less prone to the backlog-loss and
   line-shape-mismatch gaps named above before a press is allowed to refuse
   silently, or a refused press is made recoverable — e.g. a second press
   shortly after the first forces the hop through rather than repeating an
   identical silent no-op indefinitely, the way Route 3 demonstrated it does
   today.
2. **Whatever writes the cache must not have an unbounded blind spot across
   its own restarts.** The `journalctl -f -n 0` zero-backlog reattach
   (mechanism #1) is a specific, named gap; closing it (bounded backlog on
   reattach, or re-deriving current state some other way at startup) or
   making the consumer resilient to the writer having one are both valid
   directions — this document does not choose between them.
3. **The `jump from` line shape must stop being a silent gap.** Either
   `il-side-watch` (or its replacement) matches it too, or its actual
   relationship to the hop workflow is investigated and the gap is
   consciously ruled in or out — it must not remain an unexamined second
   mechanism alongside whatever else ships.
4. **The fix must not regress the property `92f64bc` was built to earn over
   `849b6ac`.** One chord that hops both ways and stays correct after a
   manual mouse-cross is the entire reason the toggle/side-file model exists;
   reverting to fixed-direction binds would resurrect the original bug
   `92f64bc` was answering, which D-17 does not license.
5. **The fix must stay inside PROJECT.md's ~50ms latency budget.** No
   awaited journald confirmation in the hot decision path — the specific
   regression this project has already banned once, at real cost (~450ms,
   rejected as laggy).
6. **Any change that touches key or pointer injection gates on a human at
   the keyboard**, per PROJECT.md's Verification constraint — the same rule
   every other input-path change in this project already follows, restated
   here because 01-06 is the plan that will actually ship code against it.
7. **The fix must not reintroduce `il-doctor`'s circularity (D-16) or
   disturb the single-flight lock's correctness** (RESEARCH Pitfall 4) —
   both are load-bearing for every plan downstream of this phase.

**Named mechanism:** `92f64bc`'s new `il-side-watch` process can silently
lose real screen-transition events — via a zero-backlog restart reattach
(RESEARCH Q2 #1, confirmed firing at least once with 2 real transitions lost)
and via a case statement that never matches `forceLeaveClient()`'s `jump
from` line shape at all (RESEARCH Q2 #2, confirmed firing 7 times in the same
7-day window) — and the same commit's `il-jump` guard (`already-on-side`)
then trusts whatever value results without verification; this causal chain
is proven end-to-end, by direct injection and by a live watcher-restart
test, to produce exactly D-02's silent, persistent, direction-symmetric
refusal. What is **not** established is that this chain has been caught
actually firing during a press the author remembers failing: the one
observed restart-gap loss most plausibly coincided with `92f64bc`'s own
build-and-test session rather than later ordinary use, and ~4 hours of live
organic logging since Route 2 was armed shows 47 real hops, 4 isolated
ordinary-looking no-ops, and none of the buggy exit paths firing at all. The
mechanism is real and sufficient to explain the reported symptom exactly;
whether it is *the* explanation for how often it happens in the wild remains
open, and is not a gap a guess should paper over before 01-06 chooses a fix.

---
*Phase: 01-regression-recovery*
*Plan: 05*
*Written: 2026-09-11*
