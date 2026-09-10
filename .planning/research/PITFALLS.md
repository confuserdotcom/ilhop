# Pitfalls Research

**Domain:** Keyboard-driven cross-machine input redirection (software KVM) on Wayland, with a macOS peer — specifically the class of code that injects or reads synthetic keyboard/pointer state.
**Researched:** 2026-09-10
**Confidence:** MEDIUM — domain-pattern claims are cross-checked across 3+ independent issue trackers (input-leap, barrier, deskflow, lan-mouse) and count as verified. The macOS `0x20000000` bit identity is LOW confidence: it does not appear in any Apple header or doc, only in informal developer reports, and is flagged as such everywhere it is used below.

## Critical Pitfalls

### Pitfall 1: The stuck-modifier class of bug (the domain's chronic, unsolved defect)

**What goes wrong:**
A modifier held down while the pointer/focus crosses to the other machine never produces a matching key-down (or key-up) on the far side. Both sides can end up disagreeing about whether Shift/Ctrl/Alt/Cmd is down. The symptom a user reports is exactly what this project already has open: the first chord after a hop is silently eaten, or a modifier looks permanently "held" (Tab acts like Alt-Tab, typed letters come out shifted, hotkeys stop matching).

**Why it happens:**
This is not specific to input-leap or to this project — it is the single most commonly reported defect across the entire domain, and it has never been fully closed by any of the five projects surveyed:
- input-leap: [#1690 "Modifier keys stuck on the connected screen PC"](https://github.com/input-leap/input-leap/issues/1690), [#207 "super key gets stuck in pressed on client"](https://github.com/input-leap/input-leap/issues/207) (same defect reported against Barrier 2.2.0 and Synergy 1.10.1 before that — i.e., it survived two full rewrites), [#2124](https://github.com/input-leap/input-leap/issues/2124), [#617](https://github.com/input-leap/input-leap/issues/617).
- deskflow (the current upstream, formerly Synergy): [#8437 "Modifier states are not synced to client when changed on Wayland server"](https://github.com/deskflow/deskflow/issues/8437), [#8920 "Modifier keys occasionally get stuck"](https://github.com/deskflow/deskflow/issues/8920) (closed as duplicate of #8437), [#6239 "Modifier keys stuck most of the time"](https://github.com/deskflow/deskflow/issues/6239) (Windows→Linux, ~90% of switches, from 2018 — i.e., open across at least 8 years of the codebase's life).
- lan-mouse (the Wayland-native rewrite, in Rust): [#79 "Sometimes all the keys are not released"](https://github.com/feschber/lan-mouse/issues/79), plus a documented gap that wlroots compositors without libei support on the receiving end don't handle modifier events from a non-layer-shell sender at all.

The root cause is structural, not a specific bug: each side keeps its own idea of "which modifiers are down," those two models are updated by independent event streams (network packets vs. the local physical keyboard), and there is no atomic point at which both are guaranteed consistent. A held key that straddles the hop is the one case where the two models are *guaranteed* to be briefly wrong relative to each other, because the down-edge was seen by one side and the up-edge (or continuation) will be seen, if at all, by the other.

**How to avoid — the known-correct approach, not the one that failed here:**
Two real fixes exist in the ecosystem, and neither is "replay the held modifier through a synthetic input device":

1. **Gate the hop on state, don't paper over it after.** input-leap's actual fix for #1690/#1897 ([PR #1972](https://github.com/input-leap/input-leap/pull/1972), merged, tested across Wayland/X11/Windows/macOS) added a `canLeave()` check that gates the `leave()` transition itself — i.e., the switch does not complete in a state that would strand a modifier, rather than trying to reconcile modifier state after the fact.
2. **Track synthetic and physical key-state separately, and resync from ground truth.** Deskflow's `KeyState` class ([docs](https://deskflow.github.io/deskflow/classKeyState.html)) keeps a shadowed bitmask of modifiers, distinguishes keys *it* synthesized from keys the OS reports physically down, and exposes two different repair primitives: `fakeAllKeysUp()` — "synthesizes a key release event for every key that is **synthetically** pressed" (never touches physically-pressed keys, precisely because it cannot know whether releasing a real key is safe) — and `updateKeyState()` — "causes the key state to get updated to reflect the **physical** keyboard state" (i.e., re-read ground truth from the OS/kernel, don't trust your own model).

This second pattern is exactly what `il-heldmods` already does (`EVIOCGKEY` against the kernel, deliberately excluding ydotool's own virtual device) — that part of this project is already aligned with the only approach any upstream project has gotten to actually work. **The failed fix (re-pressing held modifiers through `ydotool`) violates rule 2 directly**: it manufactures a *new* synthetic key-down for a modifier that is already down on a *real* device, on the same shared uinput/libinput input stack the physical keyboard reports through. Wayland compositors aggregate all keyboard devices into one seat-level XKB modifier state; a synthetic press that never gets a paired, guaranteed release (because the script crashed, raced the hop, or the daemon was mid-restart) leaves that seat-level state wedged for every device, physical included — which is exactly what was observed (the real keyboard and mouse got wedged). Any next fix must not reintroduce a synthetic key-down for a modifier whose physical state is unknown or already down; it should either gate the hop (input-leap's approach) or read-and-resync from kernel ground truth on the receiving side (deskflow's approach, this project's own `il-heldmods` precedent).

**Warning signs:**
Any change that adds a `ydotool key`/`keydown` call for a modifier in the hop path — even one framed as "just fixing" the eaten-chord bug — is this exact failure mode recurring. Treat "press this modifier through the injection device" as a standing anti-pattern for this codebase specifically, per the scar.

**Recovery, not just prevention:**
Because this defect has never been fully eliminated by *any* project in the domain, design for fast, obvious recovery rather than for zero occurrences: this project's `il-reset` (a one-command, memorizable recovery path) is the correct shape of mitigation and should stay a first-class, always-available command — not something removed once the "real" fix lands.

**Verification:** Cannot be automated. `ydotool` key events do not fire Hyprland keybinds, so the actual chord-eating path can only be exercised by a human physically holding a modifier and crossing the hop boundary. Script-level checks (flag reads, `il-heldmods` output, journal state) can confirm state *after* a human-driven repro, not substitute for one.

**Phase to address:** The "first chord after a hop is silently eaten" defect (already Active in PROJECT.md).

---

### Pitfall 2: Misreading `CGEventSourceFlagsState`'s `0x20000000` as "a modifier is held"

**What goes wrong:**
The wedged-macOS symptom reads `CGEventSourceFlagsState` returning `0x20000000` and no AeroSpace hotkey matches. It is easy to treat this as "some modifier bit is stuck set" and go looking for which modifier mask `0x20000000` corresponds to — and find nothing, because it isn't one.

**Why it happens:**
Apple's actual `CGEventFlags` modifier masks are all in the low 24 bits: Shift = `0x20000`, Control = `0x40000`, Option/Alt = `0x80000`, Command = `0x100000`, NumericPad = `0x200000`, Help = `0x400000`, SecondaryFn = `0x800000`, NonCoalesced = `0x100` ([Apple's `CGEventTypes.h`](https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.8.sdk/System/Library/Frameworks/CoreGraphics.framework/Versions/A/Headers/CGEventTypes.h) — confirmed no `0x20000000`-valued constant exists anywhere in the header, and none of Apple's public docs define it either). `0x20000000` is bit 29 — an order of magnitude outside every documented mask. Developer reports (informal, not Apple-documented — **treat this claim as LOW confidence**) describe this bit as showing up specifically on **synthetic-origin events**, i.e. a marker for "this event/flag-state was produced by event injection," not a modifier-down indicator at all. If that is correct, the read of `0x20000000` may not mean "a real modifier is stuck" — it may mean "the last thing that touched the HID event flags state was a synthetic event from input-leap's client, and the *actual* modifier bits are 0 (nothing held), but a stale non-modifier marker bit is still set."

**How to avoid:**
Before building a fix around "clear the stuck modifier," mask the read value against the real modifier bits only (`value & 0xFC0000` roughly covers Shift/Control/Option/Command/Help/SecondaryFn/NumericPad) and check what's *actually* set versus what's in the high, undocumented bits. If the real modifier bits are all zero and only `0x20000000` (or `0x100` NonCoalesced) is set, the bug is not "AeroSpace thinks Alt is down" — it may be "AeroSpace's hotkey matcher, or whatever reads this flags state, is refusing to match because it sees a residual synthetic-marker bit and treats the state as untrustworthy or non-idle," which is a different, and possibly much simpler, problem to fix (e.g., a mask/comparison bug in the consuming code, not a device-state bug). This reframing changes where the fix belongs: possibly in how the flags value is *interpreted* downstream, not in how it's *cleared* upstream.
Separately: since the reported recovery ("tapping space clears it; a mouse move does not") is a *real, physical, HID-sourced* key event, this is consistent with the marker being tied to the event source rather than a persistent device register — a new real event overwrites/refreshes the flags state, while a mouse move (not a keyboard event) doesn't touch the keyboard flags register at all. That is a testable, scriptable distinction (see Verification) and worth confirming before designing a fix around it.

**Verification:** The *value itself* is easily scriptable — read `CGEventSourceFlagsState` before/after known actions from a small helper and log the raw hex. That part needs no human. Confirming *which specific physical gesture* clears it, and whether AeroSpace's own hotkey matcher is reading the same flags source `il-heldmods`'s Mac-side equivalent would read, requires a human trying different recovery inputs at the keyboard and watching whether the first chord after each still gets eaten.

**Phase to address:** The "first chord after a hop is silently eaten" defect — do this bit-masking exercise *before* designing the next fix attempt, since it may redirect the fix target entirely.

---

### Pitfall 3: Treating an untestable code path as testable because a *related* tool exists

**What goes wrong:**
Nested compositors, `libinput-record`/`libinput-replay` ([modern replacement for `evemu`](http://who-t.blogspot.com/2018/05/libinput-record-and-libinput-replay.html), records real kernel device events to YAML and replays them on a virtual device), and evdev-replay harnesses look like they solve "how do I test input-path code without a human." For this project specifically, they do not solve the one path that matters.

**Why it happens:**
`libinput-record`/`replay`, `evemu-play`, and `ydotool` all inject through the same mechanism: a `uinput`-backed virtual device. This project has already verified, empirically, that events from that mechanism do not reach Hyprland's keybind dispatcher (0 fires, even with control local — documented in this project's own Constraints). Replaying a recorded real keypress through `libinput-replay` goes through an equivalent virtual device and would very likely hit the exact same wall — it is not a new injection path, just a different tool wrapping the same `uinput` primitive. A nested Hyprland instance changes nothing about this: the keybind-matching code path being tested is the same regardless of whether the compositor is nested or not, and the question ("does synthetic input fire a real keybind") does not depend on nesting, it depends on whether the compositor's keybind dispatcher accepts input from a virtual device at all — which, per this project's own testing, it deliberately or incidentally does not (likely a feature, not a bug: gating keybind dispatch away from synthetic input is one of the few structural defenses against the exact feedback-loop category this project's own scar came from — an injected event re-triggering a script that injects more events).

**How to avoid:**
Do not spend effort building a nested-compositor or evdev-replay test harness expecting it to close the keybind-path testability gap — it won't, for a mechanistic reason specific to this stack, not a lack of test-harness sophistication. Instead, split the surface cleanly:
- **Scriptable without a human:** geometry logic (`hyprctl clients` parsing for `il-focus-jump`'s edge detection), side-file state transitions, the ssh round trip timing, `il-heldmods`/flag-read correctness, daemon liveness and revival, `flock` single-flight behavior.
- **Requires a human at the keyboard, no substitute:** anything gated on "does a real keybind fire after this state change" — which is precisely the modifier-hold-across-hop path.

This matches — and should reinforce, not attempt to route around — this project's own stated Testability constraint. If a future contributor proposes a nested-compositor or replay-based test suite specifically to cover the keybind path, that proposal should be rejected on the mechanistic grounds above, not merely deprioritized.

**Verification:** By definition, this pitfall is about a path that cannot be verified automatically. The concrete guardrail is procedural: any PR touching key/pointer injection must state which of the two buckets above each behavior change falls into, and anything in the second bucket requires a logged human keypress test before merge (this project's Verification constraint already requires this — the addition here is *why* no tooling investment will change that).

**Phase to address:** All six Active defects that touch key or pointer injection; explicitly call this out in any phase's plan so a contributor doesn't spend a cycle building the wrong kind of test harness.

---

### Pitfall 4: No dead-man's release for synthetic key-down state

**What goes wrong:**
Any script or daemon that synthesizes a key-down and, for whatever reason (crash, signal, race, an unhandled early exit) never synthesizes the matching key-up, leaves that key logically "held" as far as the shared input stack is concerned — for as long as nothing else clears it. This is the direct mechanism of the incident this project already had.

**Why it happens:**
Shell scripts driving `ydotool` typically issue a "down" and a "up" as two separate commands with application logic (sleeps, conditionals, ssh calls) in between. Any of: the script being killed (`SIGTERM`/`SIGKILL` from a watchdog, a user hitting Ctrl-C, the hop's own `flock` timing out), the far side never responding, or an exception path that `return`s or `exit`s before the paired release — all leave a dangling down-event with no automatic release. Generic input-injection tools do not provide this guarantee for you; it is the caller's responsibility.

**How to avoid — concrete practices, not just "be careful":**
1. **`trap ... EXIT` in every script that synthesizes a key-down.** Any shell function that issues a down event must register an `EXIT`/`INT`/`TERM` trap that issues the matching up event, so a kill signal or an uncaught error still releases the key. (Not currently what caused the incident, since the failed fix has already been reverted — but this is the concrete rule for any future code shaped like it.)
2. **Prefer "read real state and act," never "hold a synthetic press open across an unbounded wait."** If a fix needs to know whether a modifier is down on the far side, read it (this project's own `il-heldmods`/`EVIOCGKEY` pattern, or the Deskflow `updateKeyState()` pattern of re-reading OS ground truth) rather than synthesizing a press whose lifetime must span a network round trip.
3. **A recovery command that does not depend on the wedged state being clean.** `il-reset` already exists as exactly this — a single command that can run over ssh from a second machine, or via a keybind that isn't itself a modifier chord, to force-release everything regardless of what's stuck. Keep this independent of whatever the hop's normal logic believes the current key state is (i.e., `il-reset` should issue unconditional "up" events for every tracked key, not "up the keys we currently believe are down").
4. **A watchdog timer as a second line of defense**, not the primary mechanism: if a hop's helper process synthesizes a key-down, a systemd-level or script-level timer that fires an unconditional release after e.g. 2–3x the expected hop latency if the process hasn't confirmed completion is standard practice for input-injection tools and costs little to add.
5. **Never test this kind of change solo without an escape hatch already open** — a second real keyboard/mouse (even a phone with an SSH client, or a second machine's terminal already `ssh`'d in) *before* running anything that synthesizes a hold, precisely because the failure mode wedges the primary input devices and makes recovering without a second channel require a hard power-reset.

**Verification:** The trap/watchdog mechanism itself is scriptable (kill the script mid-run in a test harness and assert the key state cleared via `EVIOCGKEY`/`il-heldmods`, no human needed). Whether the *end-to-end* user-facing hop still feels correct after adding one of these mechanisms is not — that still needs a human hop.

**Phase to address:** Any phase that reopens the "first chord eaten" fix; make dead-man release a required property of the plan, not an afterthought bolted on after another incident.

---

### Pitfall 5: `ydotoold` stale socket after daemon death (already hit)

**What goes wrong:** `[ -S /path/to/socket ]` reports the socket file exists even after `ydotoold` has died, because the socket *file* can outlive the *process* that was listening on it. A liveness check based only on file presence lies.

**Mechanism:** Unix domain sockets aren't automatically unlinked when the owning process dies uncleanly; the inode can remain on disk pointing at nothing.

**Mitigation (already implemented, validated):** This project's actual liveness probe — attempt a real 0px `ydotool mousemove` and treat failure as "daemon is actually dead," reviving it rather than trusting `[ -S ]` — is the correct pattern and matches how `ydotoold` issue reports describe the failure (["Address already in use"](https://github.com/ReimuNotMoe/ydotool/issues/161) when a stale process/socket lingers). This is prevention-by-probing, not just file-existence checking.

**Verification:** Fully scriptable — kill the daemon, assert the probe detects it and revives correctly, no human needed.

**Phase to address:** Already shipped/validated; keep as a regression check in `il-doctor`.

---

### Pitfall 6: libinput device-adoption delay after creating a virtual uinput device (already hit)

**What goes wrong:** Immediately after `ydotoold` creates its virtual input device, the compositor/libinput hasn't finished enumerating and adopting it — commands issued too soon are silently dropped or ignored.

**Mechanism:** Device hotplug through `uinput` → udev → libinput → compositor is asynchronous; there is no synchronous "device is ready" signal exposed to the caller by default.

**Mitigation (already implemented — the 250ms settle):** A fixed sleep after (re)creating the device is the common workaround; it is fragile in a "stranger installs it" sense because 250ms was tuned on this project's specific hardware (an i5-5257U MacBook Pro) and OS/libinput version. **Stronger mitigation for the packaging phase:** make the settle time configurable, or replace the fixed sleep with a poll (retry the 0px probe move in a short loop with backoff, succeed as soon as it works, rather than trusting a hardcoded constant) so slower or faster machines aren't stuck with a number tuned for one box.

**Verification:** Scriptable — this is exactly what the existing liveness probe already exercises; a regression test can assert the probe eventually succeeds within a bounded number of retries on a fresh daemon start, no human needed.

**Phase to address:** Packaging phase — turn the fixed sleep into a bounded poll before shipping to a stranger's machine.

---

### Pitfall 7: Pointer acceleration swallowing large synthetic deltas (already hit)

**What goes wrong:** A single large relative `mousemove` delta (used for the sub-50ms overshoot-to-edge technique) doesn't translate 1:1 into cursor movement; it can be under- or over-scaled.

**Mechanism:** libinput's default "adaptive" pointer-acceleration profile scales relative deltas by an estimated velocity derived from recent motion history ([libinput pointer-acceleration docs](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html)). A single synthetic jump has no "recent velocity" context consistent with a real drag, so the adaptive curve can respond unpredictably compared to the same delta arriving as a sequence of real, evenly-timed motion events.

**Mitigation:** This project has already tuned the overshoot amount empirically to compensate, which works but is profile- and hardware-specific. **More robust alternative for the packaging phase:** if the ydotool virtual pointer device can be dedicated (not shared with real mouse input), set its libinput acceleration profile to "flat" (`LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT`) via a device-specific libinput config quirk, so a given relative delta always maps to the same on-screen distance regardless of velocity history — removing the need to empirically re-tune the overshoot constant per machine.

**Verification:** Partially scriptable — the resulting cursor position after a known delta can be read and asserted against expected bounds without a human. Whether it "feels" centered to the user is still a human judgment call, but the numeric part doesn't require one.

**Phase to address:** "Pointer lands wrong" defect (already Active) — check the acceleration-profile angle before assuming the regression is purely in the hop/recentre logic.

---

### Pitfall 8: `/dev/uinput` packaging — permission model mistakes that only surface on a stranger's machine

**What goes wrong:** The install works for the author (who already has broad access, is already in relevant groups, or is running as root during dev) and then fails, or silently over-grants, on a fresh machine.

**Why it happens, concretely:**
- **Group-membership-without-relogin.** The common fix is `usermod -aG input $USER` (or a dedicated `uinput` group) plus a udev rule (`KERNEL=="uinput", MODE="0660", GROUP="input"` or similar). Group membership changes do not take effect in an already-open session — the user has to log out/in (or the installer has to say so explicitly). A stranger following an install script that adds the group but doesn't warn about this will get "permission denied" and file a bug that looks like a broken install.
- **Rule-reload gap.** `udevadm control --reload-rules` alone does not retroactively fix an already-created device node's permissions; `udevadm trigger` (or a replug/reboot) is also needed. An install script that writes the rule file but forgets to trigger leaves the *old* permissions in place until next boot.
- **Competing/duplicate rules across distros.** Some distros or other packages may already ship a uinput udev rule with a different group name; a second, conflicting rule installed by this project can produce inconsistent results depending on rule ordering/priority, which is very hard for a stranger to debug.
- **`chmod 666 /dev/uinput` as a "quick fix."** Sometimes suggested in forum threads as a workaround; it is not persistent (reverts on reboot, since the device node is recreated) and is a broader security exposure than a group-scoped rule.
- **Security framing that's easy to skip.** Granting uinput read/write is equivalent to granting arbitrary keystroke/pointer injection capability system-wide — a keylogger-adjacent capability — for **any process** run by that user, not just this tool. This should be stated plainly in the install docs, not buried, per the concern raised directly in a [Fedora Discussion thread on this exact question](https://discussion.fedoraproject.org/t/implications-of-change-permissions-on-uinput/128865).

**How to avoid:** Ship a udev rule + group-creation script (the standard pattern: `groupadd uinput` or reuse the distro's `input` group, a `/etc/udev/rules.d/*.rules` file setting `MODE="0660" GROUP=<group>`, then `usermod -aG <group> $USER`), have the installer explicitly print "log out and back in (or reboot) for this to take effect" rather than assuming the user knows, and have `ilhop doctor` check group membership *of the running session* (not just `/etc/group`) so a stale-session false negative is caught and explained rather than silently failing.

**Verification:** Fully scriptable as a doctor check (does the current process's effective groups include the required group; can the process actually open `/dev/uinput` for read/write). Whether the *documentation* is clear enough for a stranger is not something a script can verify — that needs a human unfamiliar with the project trying the install cold, or at minimum a careful read-through treating every step as if group changes require a relogin.

**Phase to address:** Package as `ilhop` (already Active).

---

### Pitfall 9: What kills projects like this — churn, control drama, and "it works on my WM"

**What goes wrong:** The upstream lineage this project depends on (Synergy → Barrier → input-leap → Deskflow) is itself a case study in what kills tools in this space. Each rewrite happened not primarily for technical reasons but because of **repo/organization control disputes** ([Barrier forked from Synergy in 2018; input-leap forked from Barrier specifically over who controlled CI and repo ownership](https://github.com/input-leap/input-leap/wiki/History); [Deskflow is Synergy's 2024 rename/consolidation of the same lineage](https://symless.com/synergy/blog/what-happened-to-the-old-barrier-fork)) — and each rewrite **carried the same unresolved modifier-sync defect forward**, because rewriting the transport/UI layer doesn't touch the structural cause (Pitfall 1). Separately, input-leap itself was [archived as read-only in July 2026](https://github.com/input-leap/input-leap/issues/1690), consistent with the community consolidating onto Deskflow — which is itself a live risk for this project's dependency, not just historical trivia.

**Why it happens:** Maintenance burden in this domain is unusually high because the surface area (every OS's input-injection API, every compositor's keybind/portal model, every desktop environment's permission model) changes independently and constantly, while the userbase per fork is small enough that no single team can track all of it. "It works on my WM" is close to structurally guaranteed: a maintainer validates against their daily-driver desktop, and any other compositor's quirks (Hyprland's fork-specific `hl.dsp.*` API being one example already documented in this project's own Constraints) surface only when someone else tries it.

**How to avoid, for this project specifically:**
- The existing decision to scope v1 to exactly one tested combination (Hyprland fork + AeroSpace) and defer adapters to v2 is the correct response to this pattern — validated by the fact that every competing project's generalized "support N compositors" ambition is precisely where the unresolved defects concentrate (deskflow's own Wayland-support discussion lists the identical modifier/hotkey gaps this project already ruled out chasing).
- Treat "someone requests GNOME/KDE/sway support" as a request to reopen exactly the class of bug this research surfaces as domain-endemic, not a small compatibility patch — keep the compositor-specific calls isolated (already a stated goal) precisely so that temptation doesn't leak workarounds into the core hop logic.
- Track the input-leap → Deskflow migration path as a live dependency risk: input-leap being archived means security/portal-API fixes will come from Deskflow, if at all, not from the project this system currently runs against.

**Verification:** Not verifiable by script at all — this is a judgment call about scope discipline, revisited at milestone boundaries (already the project's own stated process for reviewing "Out of Scope" reasons).

**Phase to address:** Not phase-specific; a standing filter applied whenever a "just add support for X" request comes in, and specifically worth revisiting at the next milestone boundary given input-leap's archival.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|--------------------|-----------------|------------------|
| Fixed-duration sleep instead of a poll/probe for device settle time (the 250ms constant) | Simple, already works on this hardware | Wrong constant on a stranger's slower/faster machine; either flaky or needlessly slow | Only during initial bring-up on the author's own hardware; must become a poll before packaging |
| Trusting `[ -S socket ]` for daemon liveness | Cheap check, no round trip | Lies when the daemon died uncleanly (already hit) | Never — always probe with a real no-op action instead |
| Hardcoding overshoot-distance tuning for pointer acceleration | Fast to get working | Breaks silently if the accel profile changes (driver update, different mouse/touchpad config) | Acceptable for v1 single-machine target; revisit if packaging for other hardware |
| `chmod 666 /dev/uinput` instead of a udev rule | Works immediately, no relogin needed | Insecure (any local process gets injection rights) and reverts on reboot | Never in shipped packaging; fine only for a throwaway local test |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|------------------|--------------------|
| `ydotool`/`ydotoold` | Assuming socket-file presence means the daemon is alive | Probe with a real 0px action; revive on failure (already this project's pattern) |
| `uinput` device creation | Issuing input immediately after creating the virtual device | Poll/settle before first use; don't trust a fixed sleep across hardware |
| macOS `CGEventSourceFlagsState` | Comparing the raw returned value directly against known modifier masks without masking off high/undocumented bits | Mask to the documented modifier bits (`Shift/Control/Option/Command/Help/SecondaryFn/NumericPad`, all under `0x1000000`) before deciding "a modifier is down" |
| input-leap/Deskflow server↔client | Assuming a synthetic pointer/key event on the client will be treated like real input | Verify per-project: input-leap only honours synthetic pointer motion on the **server**, already confirmed the hard way in this project |
| Hyprland fork's Lua dispatch API | Calling plain `hyprctl dispatch ...` and assuming it behaves like upstream Hyprland | Use the fork's `hl.dsp.*` API; plain dispatch parse-errors on this fork (already documented in this project) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Awaiting journald/log confirmation in the hot path | Hop feels laggy (this project measured ~450ms/700ms from this exact mistake) | Optimistic recentre + detached async self-check, already this project's fixed pattern | Any time a future feature is tempted to "just wait and confirm" before recentring |
| ssh cold control-master on the return leg | Mac→Ryuk hop takes ~1.6s instead of ~40–110ms | Keep the launchd-managed warm control master alive; detect and pre-warm rather than reconnect on demand | Whenever the control master has lapsed (already an Active defect: "Return leg is slow and asymmetric") |
| `hyprctl clients` geometry query before dispatching focus | ALT+H feels laggier than plain focus-left (already an Active defect) | Consider dispatching focus optimistically and correcting only if geometry disagrees, mirroring the hop's own optimistic-recentre pattern | Any time a query is placed synchronously before an action the user expects to feel instant |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Granting broad `/dev/uinput` access via `chmod 666` or an overly-wide group | Any local process run by that user can inject arbitrary keystrokes/pointer input system-wide — a keylogger-equivalent capability, not scoped to this tool | Scope access via a dedicated group + udev rule, document the capability plainly rather than burying it |
| Assuming ssh control-master reuse is inherently safe with no attention to socket file permissions | A world- or group-readable control socket lets another local user ride the authenticated ssh session | Ensure the control socket path is user-only (default ssh behavior; don't override permissions when scripting around it) |
| Logging at `DEBUG` on `input-leap-server.service` | ~4487 lines/minute includes raw pointer/key motion events in the journal — a local information-exposure concern on a shared or logged-elsewhere machine, beyond the already-known performance cost | Stay at `--debug INFO` (already a hard constraint in this project) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|--------------|-------------------|
| Silent chord-eating after a hop | User doesn't know their keypress did nothing; retries, sometimes triggering an unintended second action | Recovery command must stay fast and memorizable (`il-reset`); consider a distinct notification/sound specifically for "a chord was likely eaten" if detectable |
| Asymmetric hop latency (15–20ms one way, 1.6s the other when cold) | Feels broken/inconsistent even when both directions technically "work" | Treat the warm-path latency as the actual UX contract; a cold path that's 10x+ slower needs its own fix, not just averaging-out in docs |
| A stuck modifier that requires knowing to "tap space" to clear | Undiscoverable recovery gesture; a stranger installing this tool has no way to know | Document the recovery gesture prominently, or better, have `il-reset`/`ilhop doctor` actively re-issue whatever the discovered clearing action is, rather than relying on the user's memorized workaround |

## "Looks Done But Isn't" Checklist

- [ ] **`il-doctor` all-green:** A 21/21 passing health report does not prove the keybind path works — it proves every *scriptable* check passes. Verify separately, by hand, that a held-modifier hop doesn't eat the first chord, every time doctor-passing is used as a release gate.
- [ ] **Daemon liveness probe passing:** Doesn't prove the daemon survives a reboot with correct socket ownership — verify the systemd unit's `Restart=` policy and ordering against a fresh boot, not just a live-session kill/revive test.
- [ ] **Side-file (`$XDG_RUNTIME_DIR/il-side`) correctness:** Doesn't prove modifier state is correct after the hop that updated it — these are two independent pieces of state that can each be individually correct while the combination still wedges input.
- [ ] **A working install on the author's machine:** Doesn't prove group/udev permissions are correct for a fresh user — the author's session may already have stale group membership or root-adjacent access from earlier development; test packaging changes from a genuinely fresh user account.
- [ ] **`CGEventSourceFlagsState` reading 0** after some recovery action: Doesn't prove no modifier is logically stuck from AeroSpace's own perspective if AeroSpace reads a different state source than the raw flags call — confirm against AeroSpace's actual hotkey-matching behavior, not just the flags value.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| Stuck modifier / eaten first chord | LOW | Tap space (observed to clear it on macOS); `il-reset` for a full clear; keep both bound/memorized |
| Wedged real keyboard/mouse (the incident's own failure mode) | HIGH if no second channel is open | ssh in from a second machine/device and run the unconditional-release recovery command; this is why a second channel must be open *before* testing any change to this code, not improvised after |
| Stale `ydotoold` socket | LOW | Existing liveness-probe-and-revive logic already handles this automatically |
| Wrong pointer landing position | LOW | Existing detached self-check already retries once and recentres/notifies on failure |
| Bad `/dev/uinput` permissions on a stranger's machine | LOW–MEDIUM | Relog/reboot after group add; re-run `udevadm control --reload-rules && udevadm trigger`; `ilhop doctor` should detect and name this specific cause rather than a generic permission error |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|--------------------|----------------|
| Stuck modifier / eaten first chord (Pitfall 1) | The open "first chord eaten" defect phase | Human-at-keyboard hop test holding each modifier in turn; cannot be scripted |
| Misread `0x20000000` (Pitfall 2) | Same phase, as a pre-step before designing the fix | Scriptable: log raw `CGEventSourceFlagsState` masked against real modifier bits before/after known actions |
| Untestable keybind path mistaken for testable (Pitfall 3) | Any phase touching key/pointer injection | Procedural: PR must classify each change as scriptable vs. human-required; reject nested-compositor/replay test proposals for the keybind path specifically |
| No dead-man release on synthetic key-down (Pitfall 4) | Any future fix to the modifier-hold defect | Scriptable (kill-mid-run + assert release) for the mechanism; human hop test for end-to-end feel |
| `ydotoold` stale socket (Pitfall 5) | Already shipped | Scriptable regression test in `il-doctor` |
| libinput device-adoption delay (Pitfall 6) | Packaging phase | Scriptable: assert probe succeeds within bounded retries on fresh daemon start |
| Pointer acceleration swallowing deltas (Pitfall 7) | "Pointer lands wrong" defect phase | Partially scriptable: assert landing position within bounds for a known delta |
| `/dev/uinput` packaging permissions (Pitfall 8) | Package as `ilhop` phase | Scriptable doctor check for effective group membership + device open test; documentation clarity needs a fresh-user walkthrough |
| Maintenance-burden / scope-creep churn (Pitfall 9) | Standing filter, revisit at milestone boundary | Not verifiable by script; judgment call against stated Out-of-Scope reasons |

## Sources

- [input-leap/input-leap #1690 — Modifier keys stuck on the connected screen PC](https://github.com/input-leap/input-leap/issues/1690)
- [input-leap/input-leap #207 — super key gets stuck in "pressed" on client](https://github.com/input-leap/input-leap/issues/207)
- [input-leap/input-leap #2124 — Keyboard keys randomly stop working on client](https://github.com/input-leap/input-leap/issues/2124)
- [input-leap/input-leap #617 — Input freezes or gets stuck](https://github.com/input-leap/input-leap/issues/617)
- [input-leap/input-leap PR #1972 — canLeave() gate fix, merged, closes #1690 and #1897](https://github.com/input-leap/input-leap/pull/1972)
- [input-leap/input-leap Wiki — History](https://github.com/input-leap/input-leap/wiki/History)
- [deskflow/deskflow #8437 — Modifier states are not synced to client when changed on Wayland server](https://github.com/deskflow/deskflow/issues/8437)
- [deskflow/deskflow #8920 — Modifier keys occasionally get stuck](https://github.com/deskflow/deskflow/issues/8920)
- [deskflow/deskflow #6239 — Modifier keys stuck most of the time](https://github.com/deskflow/deskflow/issues/6239)
- [deskflow/deskflow Discussion #7499 — Wayland support: Known bugs](https://github.com/deskflow/deskflow/discussions/7499)
- [Deskflow KeyState class reference — fakeAllKeysUp / updateKeyState / updateKeyMap](https://deskflow.github.io/deskflow/classKeyState.html)
- [feschber/lan-mouse #79 — Sometimes all the keys are not released](https://github.com/feschber/lan-mouse/issues/79)
- [Symless blog — What happened to the old Barrier fork](https://symless.com/synergy/blog/what-happened-to-the-old-barrier-fork)
- [Apple CGEventTypes.h (MacOSX10.8 SDK mirror) — full CGEventFlags mask list, confirms 0x20000000 is not a named constant](https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.8.sdk/System/Library/Frameworks/CoreGraphics.framework/Versions/A/Headers/CGEventTypes.h)
- [Apple Developer Forums thread #733161 — CGEventSourceFlagsState reset by concurrent mouse events](https://developer.apple.com/forums/thread/733161)
- [Nick Liu — "What replaced CGEventPost in my Stream Deck daemon" (macOS Tahoe synthesized-event gating, CGXSenderCanSynthesizeEvents)](https://www.nick-liu.com/posts/tahoe-hotkey-dead-end/)
- [ReimuNotMoe/ydotool #161 — stale socket / "Address already in use"](https://github.com/ReimuNotMoe/ydotool/issues/161)
- [Who-T (Peter Hutterer) — libinput-record and libinput-replay](http://who-t.blogspot.com/2018/05/libinput-record-and-libinput-replay.html)
- [libinput — Pointer acceleration documentation](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html)
- [Fedora Discussion — Implications of changing permissions on uinput](https://discussion.fedoraproject.org/t/implications-of-change-permissions-on-uinput/128865)
- Project's own PROJECT.md (`/home/nastralis/Projects/ilhop/.planning/PROJECT.md`) — "The scar," Constraints, and Active defect list, used as the ground truth this research is checked against.

---
*Pitfalls research for: keyboard-driven cross-machine screen switching (software KVM) on Wayland, with a macOS peer*
*Researched: 2026-09-10*
