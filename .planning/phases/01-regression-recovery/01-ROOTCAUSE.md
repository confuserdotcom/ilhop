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

