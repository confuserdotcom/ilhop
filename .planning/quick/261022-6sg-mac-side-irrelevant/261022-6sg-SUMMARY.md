---
phase: quick-261022-6sg-mac-side-irrelevant
plan: 01
status: built, human keypress gate PENDING
commits:
  - f8011d0 feat(quick-6sg): read the Mac's side live from server.conf on the Linux hop path
  - 6a9c1aa feat(quick-6sg): Mac learns its side from the session's stderr
  - c39661d feat(quick-6sg): ilhop side, side-aware doctor and harness, README
requirements: [PORT-01 (side slice only; adapters stay parked on port-01)]
---

# Summary: the Mac's side is irrelevant

**Human keypress gate: PENDING.** Nothing is installed on either machine and
the real server.conf is untouched. Not shippable until the gate below passes.

## What was built

- **T1 (f8011d0)** il-jump reads the side live from `~/.config/InputLeap/server.conf`
  on every hop (one awk, `SIDE_AWK`), resolves neutral verbs `mac|linux` plus
  directional `left|right`, `il-jump side`, side-aware aim and il-reset.
  il-jump-listen prints `ready` on stdout only, `side X` on stderr, maps legacy
  `right` to linux.
- **T2 (6a9c1aa)** il-hop-pipe keeps the session's stderr in
  `~/.local/state/il-hop.side` (handshake line byte-identical to main).
  il-jump-mac sends `linux` only once that file has a side line, else `right`;
  ssh fallback `il-jump linux 2>/dev/null || il-jump right` (fish- and
  sh-valid). Both Mac pickers take the side as argv: side right picks the
  smallest left X, left/unknown keep today's largest right edge. Uninstall
  removes the side file.
- **T3 (c39661d)** new `bin/il-mac-side` (`ilhop side [left|right|--links]`):
  validated temp file, `.bak`, atomic rename, symlink-safe, idempotent,
  restarts input-leap and kills the listener so the Mac redials. il-doctor's
  one links check (tally unchanged) names the side and fails on none / many /
  no link back / unmirrored / parser disagreement. il-repro live modes follow
  `MAC_DIR`/`LINUX_DIR` from `il-jump side` (Mac-left values equal the old
  literals), inject-noop gains `mac`/`linux` refusal cases, new `--side-conf`
  pure mode. ilhop routes `mac|linux|side`. README tells the `ilhop side` story.

## Automated verification (this Mac)

- `sh -n` on every touched script: ok. shellcheck is not installed here.
- `il-repro --side-conf` 31 ok, `--resolve` 53 ok, `--aim` 9 ok, `--listen` 8 ok; 0 failed each.
- Scratch `t2-verb.sh` (sandbox HOME, fake `nc -lkU` socket): no file -> `right`,
  `side right` -> `linux`, `side left` -> `linux`, garbage -> `right`,
  ssh noise then `side left` -> `linux`; every run then sent `aim N`.
- Scratch `t2-pick.sh`: no-ids case returns `- 735` / `735` for left, right,
  unknown on both scripts. **Live pick not discriminated**: only one window was
  on the focused workspace. Gate step 7 covers it.
- No `bin/il-wm`, no `mac/il-mac-wm`, no `ILHOP_MAC_SIDE` anywhere, no
  `journalctl` in il-jump code.

## Measurements

- `SIDE_AWK` alone, BSD awk: ~1.9ms/call (100 calls, 0.186s). Matches the
  planning prototype (~1.8ms). This is the only hot-path addition.
- Whole `il-jump side` process (sh start, config source, `uname`, awk):
  ~8.3ms/call. Not on the hop path; the listener calls it once per session.
- Linux figures are gate step 9.

## Design notes

- D-5: the side travels on the listener's **stderr**, captured by the new
  pipe's `2>`. A second stdout line would be relayed by every deployed pipe to
  a socket client (EPIPE risk); `ready side=` breaks the exact-match handshake;
  a second blocking read hangs against an old listener.
- Version mix: the listener maps legacy `right` to linux, and il-jump-mac
  sends `linux` only after the listener proved it knows it.
- `ilhop side` also kills the listener so the Mac relearns the side.

## Known edges

- `il-cursortrace`'s freeze probe moves +5px. It could cross only if the
  pointer sat within 5px of the Linux edge facing the Mac; after a hop it never
  does (arrive_nastralis warps to a window centre). Out of scope.
- After `ilhop side`, the Mac's landing pick is stale until the pipe redials
  (seconds). Documented in the README.

## Human keypress gate (verbatim from the plan)

Before starting: from the Mac, open `ssh ryuk` in a terminal and leave it open, so `ilhop reset` is one command away. Sync this branch to the Linux clone.

0. **Linux first, old Mac.** On Linux, `./install.sh` from the updated clone. Do not reinstall the Mac yet. Press ALT+C on the Mac: it must still hop to Linux (the old `right` mapped by the new listener). On Linux, `ilhop side` prints the side server.conf currently says.
1. **Set the real side.** On Linux, `ilhop side right` (a no-op if the conf already says right). Then `ilhop doctor`: the links line reads "the Mac is on the right ... il-jump agrees", the tally is 21 ok / 0 failed, and the input-leap client reconnects within seconds.
2. **Mac install.** On the Mac, `./install.sh`. Within ~10s `cat ~/.local/state/il-hop.side` shows `side right`, and `ls ~/.local/state/il-hop.sock` exists.
3. **ALT+C on Linux -> Mac.** The pointer lands on the Mac window nearest the Mac's LEFT edge, which has focus. Type a word immediately: no lost keystroke.
4. **ALT+C on Mac -> Linux.** It lands on the Linux window nearest Linux's RIGHT edge, which has focus. Type immediately.
5. **Hold Alt, press C repeatedly** (at least 6 presses, at least 3 each way; the regression that got port-01 reverted). Every press hops and none is dropped. After releasing, `ilhop heldmods` is empty and plain letters type plainly on both machines.
6. **Physical mouse crossing.** Mouse off Linux's right edge -> Mac. Mouse off the Mac's left edge -> Linux.
7. **Landing with two windows** side by side on each machine: repeat 3-4 and confirm the window nearest the crossing edge is picked on both.
8. **Harness, hands off the mouse.** `ilhop repro --all`: 0 failed. `ilhop doctor --test`: both hop times printed.
9. **Latency.** Record `ilhop doctor --test`'s out and back ms (bar: each under ~50ms; baseline 24ms out / 45ms back). Record `time (for i in $(seq 100); do il-jump side >/dev/null; done)` divided by 100 as the per-hop parse cost. With `ilhop repro --arm`, do 10 ALT+C presses, then `ilhop repro --report`: there must be no `side-unknown` line. Then `ilhop reset`: the pointer ends on Linux, not on the Mac. Finally `ilhop repro --disarm`.
10. **Flip and back.** `ilhop side left`. Doctor says left, and the Mac's il-hop.side shows `side left` after the redial. Either move the Mac to the left physically, or keep it where it is, accept that the mouse crossing is reversed relative to the desk, and test the keyboard hop only. Repeat 3-5 with mirrored expectations: the Mac lands at the window nearest its RIGHT edge, Linux at its leftmost window. Then `ilhop side right` to match the desk again, and re-run step 1's doctor.

Pass = every step as described. Any failure: `ilhop reset` over the open ssh, then report the failing step. Do not patch at the keyboard.
