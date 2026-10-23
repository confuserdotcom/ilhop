---
phase: quick-261022-6sg-mac-side-irrelevant
verified: 2026-10-23T12:27:53Z
status: gaps_found
score: 4/8 must-haves verified
behavior_unverified: 3
overrides_applied: 0
gaps:
  - truth: "ilhop side left|right rewrites only the two link lines atomically with a .bak, restarts input-leap, and does nothing when already set (D-6); ilhop doctor fails on an unmirrored link pair (D-7) with remedy `ilhop side <L2M>`"
    status: partial
    reason: >-
      On an unmirrored conf (e.g. Nastralis.right = Mac, Mac.right = Nastralis) the rewrite
      changes only ONE line (the Linux line already holds the requested direction), but the
      validation demands exactly two changed lines, so il-mac-side refuses with the misleading
      "the rewrite touched more than the two link lines". il-doctor's remedy for exactly this
      shape is `ilhop side <L2M>`, which therefore always fails. Reproduced in a sandbox for
      right/right + `side right`, right/right + `side left`, left/left + `side left`: rc=1 each.
      The plan's step 2 admits unmirrored confs into the rewrite and step 5 only forbids
      changes "other than those two" lines; the `-eq 2` check is stricter than the spec.
    artifacts:
      - path: "bin/il-mac-side"
        issue: "lines 140-141 require exactly 2 '<' and 2 '>' diff lines; an unmirrored fix legitimately changes 1"
      - path: "bin/il-doctor"
        issue: "line 102 prescribes `ilhop side $l2m`, a command that refuses for every unmirrored conf"
    missing:
      - "Accept 1 or 2 changed lines in il-mac-side's diff validation (still 0 changes outside the two targeted link lines; the links read-back check already proves the result)"
      - "Add an --side-conf fixture: unmirrored (f) + `il-mac-side <L2M>` exits 0, reads back mirrored, exactly one line differs"
behavior_unverified_items:
  - truth: "With server.conf linking the Mac on the RIGHT, ALT+C on Linux lands on the Mac and ALT+C on the Mac lands on Linux, with no side setting in any ilhop config file (D-1)"
    test: "Human gate steps 0-5 with the real desk (Mac on the right)"
    expected: "Every press hops in the right direction, focus follows, no lost keystroke, hold-Alt repeated C never drops a press"
    why_human: "ydotool/Hyprland keybind paths cannot be simulated (CLAUDE.md Testability); only the decision table is provable offline"
  - truth: "A hop lands on the window nearest the edge the pointer crosses at, on both machines, for both sides (D-4, D-5)"
    test: "Human gate steps 3, 4, 7, 10 with two windows side by side on each machine"
    expected: "Mac-right: Mac lands at its leftmost window, Linux at its rightmost; flipped for left"
    why_human: "centre_mac's right-side (tx - width)/2 nudge depends on 2x accel on real hardware; the Mac JXA live pick was not discriminated (one window on the focused workspace)"
  - truth: "Both hop directions stay under ~50ms with no journal wait added to the hot path (D-8)"
    test: "Human gate step 9: ilhop doctor --test out/back ms, il-jump side x100 on Linux"
    expected: "Each leg under ~50ms (baseline 24 / 45ms)"
    why_human: "Latency is only measurable on the Linux box; offline proxy is SIDE_AWK at 1.86ms/call (BSD awk) and no journalctl in il-jump code"
human_verification:
  - test: "Full human keypress gate, steps 0-10 (PLAN.md 'Human Keypress Gate')"
    expected: "Pass = every step as described"
    why_human: "CLAUDE.md: no input-path change ships without the author at the keyboard"
---

# Quick 261022-6sg: the Mac's side is irrelevant - Verification Report

**Goal:** make the Mac's physical side (left or right of the Linux screen) irrelevant to ilhop, with server.conf's links as the single, live source of truth, and Mac-left behaviour byte-for-byte unchanged.
**Verified:** 2026-10-23T12:27:53Z (Mac checkout, offline; commits f8011d0, 6a9c1aa, c39661d vs 2779016)
**Status:** gaps_found (one narrow gap; the human keypress gate is also still PENDING and would otherwise make this human_needed)
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Mac-RIGHT conf: ALT+C hops both ways, no side setting in any ilhop config | PRESENT_BEHAVIOR_UNVERIFIED | Offline parts hold: Mac-right resolve rows (my own dash run: toggle/mac/right -> `mac right 800 10`, toggle-from-mac/linux/left -> `nastralis left -800 3`); listener maps `right`->linux; il-jump-mac sends `linux` with a side line. No `ILHOP_MAC_SIDE` anywhere. Keypress needed. |
| 2 | Mac-LEFT conf: every verb resolves to main's want/dir/step/burst (D-3) | VERIFIED | `il-repro --resolve` 53 ok / 0 failed (sh and dash); independent table run matches 2779016's `case` (toggle/left -> `mac left -800 10`, toggle-from-mac/right -> `nastralis right 800 3`); `mac`=`left`, `linux`=`right`. Dispatch `shove "$burst"` and `want = mac` branch reduce to the old `dir = left` literals. |
| 3 | Side read live from server.conf every hop, one awk; unusable conf -> left + dbg, never blocks | VERIFIED | il-jump:240 calls `mac_side` before `resolve` on every invocation; mac_side:129-134 is one awk command substitution with stderr discarded; fallback rc 1 + `dbg "side-unknown: ..."`; no-conf fixture prints `left` + stderr note, rc 0; side-conf[g] shows the next `il-jump side` follows an edit. SIDE_AWK 1.86ms/call (100 calls, BSD awk). |
| 4 | Landing on the window nearest the crossing edge, both machines, both sides | PRESENT_BEHAVIOR_UNVERIFIED | Linux AIM_JQ: `--aim` 9 ok (5 left cases unchanged, 4 right cases). Mac JXA: t2-pick no-ids ok for left/right/unknown on both scripts; live pick not discriminated (1 window). centre_mac right branch (il-jump:364-377) untestable offline. |
| 5 | `ilhop side` prints / rewrites two lines atomically with .bak / restarts / idempotent | FAILED (partial) | Mirrored confs: side-conf (g)(h)(i) pass, mode preserved (600/600), CRLF ok, DRY prints `would:` only. Unmirrored confs: always refused (see Gaps). |
| 6 | Every Mac/Linux version mix keeps Mac ALT+C working (D-5) | VERIFIED | `--listen` 8 ok (stdout exactly `ready`, stderr exactly `side right`/nothing, calls `linux linux mac toggle left`, aim 123). t2-verb (ssh-stubbed copy): no file/garbage -> `right`, any valid side line -> `linux`, then `aim N`. Fallback remote string runs correctly in sh/dash/bash (old il-jump exit 2 -> `right` retry). See Warning W1 for a degraded-path caveat. |
| 7 | Doctor reports the side and fails on missing/unmirrored links; il-repro covers both sides without breaking Mac-left | VERIFIED | Doctor links block extracted and run on fixtures: left/right PASS, right/left PASS, unmirrored/none/many/no-link-back each FAIL with a named reason. il-repro live-mode substitutions read: every MAC_DIR/LINUX_DIR equals the old literal under Mac-left; `mac`/`linux` verbs resolve identically to `left`/`right` there. Live run needs Linux (gate step 8). |
| 8 | Both directions under ~50ms, no journal wait (D-8) | PRESENT_BEHAVIOR_UNVERIFIED | No `journalctl` in il-jump code; only hot-path addition is one awk (~1.9ms BSD). Linux timing is gate step 9. |

**Score:** 4/8 truths verified (3 present, behavior-unverified; 1 partial failure)

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| bin/il-jump | VERIFIED | SIDE_AWK, mac_side, resolve, `side` verb, RESOLVE/AIM seams before lock, `--arg side`, centre_mac mirror, off-path width warm |
| bin/il-jump-listen | VERIFIED | `echo ready` first and only stdout; `side X` on stderr; `right`->linux; whitelist kept |
| bin/il-reset | VERIFIED (code) | `home=-800` only when `il-jump side` says right; default 800 |
| bin/il-mac-side | PARTIAL | 163 lines, mode 100755 in git; unmirrored rewrite refused (gap) |
| bin/il-repro | VERIFIED | --aim/--resolve/--listen/--side-conf all 0 failed; pure modes skip the side-file snapshot |
| mac/il-hop-pipe | VERIFIED | only change `2>"$SIDEF"`; handshake line identical |
| mac/il-jump-mac, mac/il-aim-mac | VERIFIED | builtin `while read` side parse, side as argv to JXA |
| bin/il-doctor | VERIFIED | one counted check replaces one; --test uses `linux` |
| README.md | VERIFIED | `ilhop side` story, both mirrored blocks, use table, known limits |
| install.sh | VERIFIED | uninstall rm adds il-hop.side; `bin/*` loop installs il-mac-side |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| bin/il-jump | ~/.config/InputLeap/server.conf | `awk -v me="$SCREEN" "$SIDE_AWK" "$SERVERCONF"` every hop (il-jump:130, 240) | WIRED |
| bin/il-jump-listen | mac/il-hop-pipe | `side X` on stderr -> `2>"$SIDEF"` (listener:41-42, pipe:43) | WIRED |
| mac/il-jump-mac | bin/il-jump-listen | `verb=linux` iff side line, else `right` (il-jump-mac:28-41) | WIRED |
| bin/il-doctor | bin/il-mac-side | `il-mac-side --links` cross-checked with `il-jump side` (doctor:89-102) | WIRED (remedy text points at a refusing path - gap) |

### User-requested code checks

| Check | Result |
|-------|--------|
| Mac-left il-jump resolve unchanged vs 2779016 | Yes (table above, --resolve) |
| il-repro live modes: substituted values = old literals when MAC_DIR=left | Yes: inject-noop, stress, stress-live (mac/linux verbs, resolve-equivalent), watcher-gap, retry-forced, selfcheck-rescue. inject_case's log match tightened to `already-on-side: dir=$ldir ...want=$want` (stricter, still matches the unchanged dbg format) |
| il-doctor --test Mac-left unchanged | Yes: only `il-jump right` -> `il-jump linux` (identical decision under Mac-left) |
| il-hop-pipe ready-handshake line byte-identical | Yes (`diff` of the line vs 2779016: identical; `git diff -U0` shows no +/- line with `read -r ready`) |
| il-mac-side safety | temp `$conf.ilhop.$$` same dir (131) via `cp -p`; validation line count / read-back / diff (136-141); `.bak` via `cp -p` (146); atomic `mv -f` (147); `readlink -f` keeps symlink (104, fixture i); DRY prints `would:` and runs nothing (153-157); names only via `awk -v` + string `==` and `in`, never regex/sed/eval |
| il-doctor non --test tally 21 | Unchanged: the only non-test hunk replaces one `pass || fail` with one if/elif chain that emits exactly one pass/fail |
| il-jump-mac ssh fallback valid in fish 3 and sh | sh/dash/bash run it correctly; fish 3 supports `||`, `2>/dev/null`, leading `~` (fish not installed here, checked by grammar) |
| hyprctl/aerospace/osascript inline | Yes: only new file is bin/il-mac-side; no new sourcing; no compositor call moved; no bin/il-wm, mac/il-mac-wm |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| T1 automated verify | sh -n x4, il-repro --aim/--resolve/--listen, journalctl grep, no il-wm | 9/53/8 ok, 0 failed | PASS |
| T2 automated verify | sh -n x4, handshake grep = 0, t2-pick.sh, t2-verb.sh (run as an ssh-stubbed copy), no il-mac-wm | all ok; live pick not discriminated | PASS |
| T3 automated verify | full `<automated>` chain | T3_VERIFY_OK; --side-conf 31 ok | PASS |
| dash portability | `dash -n` on all 11 touched scripts; pure modes under dash | clean; same counts | PASS |
| Unmirrored remedy | `IL_MAC_SIDE_DRY=1 il-mac-side right` on right/right conf | rc=1 "touched more than the two link lines" | FAIL |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| bin/il-mac-side | 140-141 | exact-2 diff check | Blocker (for the remedy) | unmirrored confs cannot be fixed by `ilhop side`; error message wrong |
| bin/il-mac-side | 136 | `wc -l` equality | Info | a conf with no trailing newline is refused ("line count changed"); safe failure |
| bin/il-mac-side | 109, 137 | `set -- $(links ...)` unquoted | Info | screen names are subject to globbing (not eval); names with `*`/`?` would misparse |
| README.md | 95 | "order does not matter" | Warning (W1) | an OLD il-jump-mac's ssh fallback (pipe down) sends `il-jump right`; with Mac-right a new il-jump reads that as "toward the Mac" and refuses/no-ops. Pipe path is fine. Transitional only |

No TBD/FIXME/XXX/TODO in added lines.

### Human Verification Required

The full keypress gate (PLAN.md steps 0-10) is PENDING and covers truths 1, 4, 8 and the live half of 7. Key items: ALT+C both ways with the Mac on the right; hold-Alt repeated C (the port-01 regression); landing with two windows per machine; `ilhop doctor` tally 21/0; `ilhop repro --all` 0 failed; latency under ~50ms each way; `ilhop reset` pulls home on the Mac-right desk; flip to left and back.

### Gaps Summary

One real gap, narrow in scope: `ilhop side` cannot repair an unmirrored links pair, yet that is exactly what `ilhop doctor` tells the user to run for that failure (bin/il-mac-side:140-141, bin/il-doctor:102). Every mirrored-conf path, the Mac-left no-op proof, the handshake, the version-mix protocol and the rewrite safety properties hold offline. The hop itself is untouched by this gap. After the fix, status drops to human_needed pending the keypress gate.

---

_Verified: 2026-10-23T12:27:53Z_
_Verifier: Claude (gsd-verifier)_

## Gap closure (post-verification)

- Gap 1 fixed: `bin/il-mac-side` accepts one or two changed lines (equal on
  both sides of the diff), so `ilhop side` repairs an unmirrored pair as
  il-doctor advises. New `il-repro --side-conf` fixture (f') covers
  right/right asking right and asking left; `--side-conf` now 33 ok, 0 failed.
- W1 fixed in README: the old-Mac-with-pipe-down exception is stated, with
  "upgrade the Mac soon after Linux".
- Glob note fixed: `set -f` in il-mac-side.
- Trailing-newline refusal left as is (fails safe).

Status after closure: **human_needed** (keypress gate).
