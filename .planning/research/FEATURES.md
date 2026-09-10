# Feature Research

**Domain:** Cross-machine keyboard/mouse input-sharing ("software KVM"), keyboard-driven screen switching specifically
**Researched:** 2026-09-10
**Confidence:** MEDIUM overall (cross-checked GitHub issue trackers + vendor docs; no primary user surveys found, so demand-ranking claims are inference from repeated complaints, not polling data)

## Context for this research

`ilhop` is not a general KVM — it is a thin keyboard-hop layer riding on top of input-leap,
which does the actual pointer/keyboard transport, clipboard (where supported), and
screen-saver sync. That division of labor matters throughout this document: several
things that read as "table stakes for a KVM tool" are input-leap's job, not ilhop's, and
recommending ilhop build them would duplicate work input-leap already does badly.

## Answers to the seven research questions (before the categorized tables)

**1. Trigger mechanism — what do users prefer/complain about?**
Every mature tool offers edge-crossing as the default and treats hotkey/chord switching
as a secondary or power-user mode:
- Synergy/Barrier/input-leap: continuous mouse-edge-crossing is the *only* well-supported
  trigger; a "switch to screen N" hotkey exists but is thinly documented and rarely
  discussed.
- Logitech Flow: edge-reach (auto), edge-reach-while-holding-Ctrl, and corner-switch —
  with an explicit setting to **disable corner-switching**, because corners fire
  accidentally. That "give me an escape hatch" pattern recurs everywhere corners or
  edges are the trigger.
- Apple Universal Control: pure edge-push, continuous, with a visual "pushing through"
  cue so the user isn't surprised by an unannounced jump. No dwell, no delay.
- Nobody in this space uses double-tap or gesture switching as a primary mechanism for
  desktop-to-desktop KVM; that pattern belongs to phone/tablet software (todo not found
  in any of the tools researched).

Complaint pattern: edge/corner triggers are complained about almost entirely as
*mis-fires* (accidental corner activation, cursor trapped/bouncing at the boundary,
wrap-to-opposite-edge from bad neighbor config) — not as "I wish it worked differently."
Chord/hotkey triggers are complained about as *silence* (nothing happens, or it fires the
wrong direction) rather than false positives. `ilhop`'s single-chord, non-continuous
design structurally avoids the entire edge-mis-fire complaint class that dominates
Synergy/Barrier/input-leap issue trackers — this is a validated advantage, not
incidental.

**2. Classic keyboard-switching complaints in issue trackers**
Cross-checked across input-leap and deskflow (input-leap's issues:
[#1690](https://github.com/input-leap/input-leap/issues/1690),
[#207](https://github.com/input-leap/input-leap/issues/207),
[#617](https://github.com/input-leap/input-leap/issues/617),
[#576](https://github.com/input-leap/input-leap/issues/576),
[#532](https://github.com/input-leap/input-leap/issues/532),
[#1132](https://github.com/input-leap/input-leap/issues/1132),
[#107](https://github.com/input-leap/input-leap/issues/107); deskflow's:
[discussion #7499](https://github.com/deskflow/deskflow/discussions/7499),
[#7596](https://github.com/deskflow/deskflow/issues/7596),
[#8920](https://github.com/deskflow/deskflow/issues/8920),
[#8083](https://github.com/deskflow/deskflow/issues/8083),
[#8899](https://github.com/deskflow/deskflow/issues/8899)) — the recurring defect
classes are:
- **Stuck modifiers** — ctrl/shift/alt/super left "pressed" on one side after a
  switch, often surfacing after screensaver unlock or after rapid switching.
  This is the *identical* symptom class as ilhop's own "first chord after a hop is
  silently eaten... wedging macOS with `CGEventSourceFlagsState`" defect. It's not
  an ilhop-specific bug; it's the ecosystem's hardest recurring problem, and mature,
  funded projects have not solved it either (deskflow's workaround as of the latest
  issue is still "restart the server").
- **Input freeze / lost control for seconds** — both keyboard and mouse stop
  responding after a switch, sometimes clearing on its own, sometimes requiring a
  physical unplug-replug of the input device or a full reboot.
- **Wrong-screen / wrong-layout landings** — keyboard layout silently changes when
  crossing screens; dead keys and special characters break; Right Alt on Windows
  producing capitalized characters on a Wayland Linux client.
- **Hotkeys don't work on Wayland at all** — deskflow's own discussion attributes
  this to the same libei/libportal global-shortcut gap that `ilhop`'s PROJECT.md
  already documents as the reason it exists.

Net: ilhop's Active defect list (eaten first chord, stuck modifier, wrong-screen
landing, intermittent no-fire) is not idiosyncratic — it is the exact same defect
family every tool in this space fights, which raises confidence that the fixes ilhop
is pursuing (kernel-level held-modifier read via `EVIOCGKEY`, detached self-check with
local recovery) are attacking the right layer of the problem (nobody else has fixed
this by re-injecting synthetic keys, and ilhop's own attempt at that approach on
2026-09-10 also wedged input — corroborating evidence, not just prior belief).

**3. Cursor placement after a switch**
Continuous-edge tools (Synergy/Barrier/input-leap/Flow/Universal Control) use
**edge-continuation**: the cursor exits one screen's edge and enters proportionally at
the matching point on the neighbor's edge, because the switch is a continuous mouse
motion, not a discrete event. Their complaint tracker is full of geometry
misconfiguration breaking this (wrap-to-self, trapped-at-edge, wrong-corner-under-scaling
— see [#1025](https://github.com/input-leap/input-leap/issues/1025),
[#490](https://github.com/input-leap/input-leap/issues/490),
[#94](https://github.com/input-leap/input-leap/issues/94)).
For **discrete, non-continuous** triggers (chord/hotkey — ilhop's actual mechanism),
edge-continuation has no natural input to derive from (there's no mouse motion to
carry position across), so **centre-of-target-screen** is the closest analogue in this
research (Flow's Ctrl+edge and Universal Control's push-through still rely on physical
mouse position, so this is the one area with no directly-comparable discrete-switch
product). ilhop's existing "recentre locally on self-check failure, notify rather than
strand the pointer" is a reasonable and defensible default for a chord-triggered hop —
just be aware it's an ilhop-original design decision, not an industry-copied one,
because no competitor does discrete cursor teleportation the way ilhop does.

**4. Clipboard, drag-and-drop, file transfer — table stakes or separable?**
**Separable — ilhop's exclusion is well defended, not just convenient.** Evidence:
- input-leap drag-and-drop is reported broken on Windows, macOS, *and* Linux
  ([#258](https://github.com/input-leap/input-leap/issues/258),
  [#226](https://github.com/input-leap/input-leap/issues/226),
  [#378](https://github.com/input-leap/input-leap/issues/378),
  [#855](https://github.com/input-leap/input-leap/issues/855)) — dragging a file
  between screens can hard-lock the cursor.
- Deskflow's own maintainers **removed drag-and-drop entirely**, stating it "never
  worked reliably" — this is the direct successor project giving up on the feature,
  not a third party's opinion.
- input-leap clipboard sync is reported to work on Windows/macOS but explicitly **not
  supported on Linux/Wayland** — the exact platform ilhop's server side runs on.
- lan-mouse, a from-scratch Wayland-native rewrite with a clean slate, still has
  clipboard sync as a *roadmap item*, not a shipped feature, as of the version
  reviewed.

Three independent projects (one legacy, one funded successor, one clean-slate rewrite)
all fail to ship reliable clipboard/DnD on Linux/Wayland. This is strong confirmation
that these features are separately-hard, not merely deprioritized, and belong to a
different tool (or a `copi`/syncthing-style sidecar, which PROJECT.md already
identifies as "the rest of the two-machine kit — different project"). **No re-add
recommended.**

**5. Diagnostics — do comparable tools ship a doctor/health-check command?**
**No.** Across Synergy, Barrier, input-leap, and deskflow, troubleshooting is entirely
manual and documented as prose: ping the peer, manually check TCP port 24800
reachability from both server and client, check firewall ICMP/TCP rules. None of them
ship an automated, scripted, multi-check diagnostic. `ilhop`'s existing 21-check
`il-doctor` (soon `ilhop doctor`) is therefore a genuine, currently-unmatched
differentiator in this specific space — worth keeping and marketing as such in the
README, not a "nice to have" to deprioritize. A good health-check in this domain
should report (synthesizing from what's manually recommended across these wikis, since
no automated equivalent exists to copy): daemon/service liveness (both directions),
transport reachability (port/socket), input-injection-tool liveness (ilhop's own
ydotool probe is already ahead of the field here), current tracked side/state
consistency, permission/portal grants where relevant, and a live round-trip test —
which is close to what `il-doctor --test` already does.

**6. Anti-features — things that look obvious but mature tools avoid**
- **Switch delay / dwell time before a hop fires.** No tool in this space adds this
  deliberately. The closest analogue — hardware KVM switches — have 100–500ms+ delays
  as an unwanted *side effect* of HDMI handshaking, and their own user forums treat it
  as a defect, not a feature, with missed/doubled keystrokes as the direct complaint.
  ilhop already removed a 700ms dwell as "laggy" — this research corroborates that call
  rather than contradicting it. Do not reintroduce, even as an optional setting; nobody
  wants it and the closest real-world comparison treats it as pure liability.
- **Mouse-edge-crawl as the trigger.** This is the single largest source of complaints
  in the entire researched ecosystem (geometry misconfig → wrap-around, edge-trapping,
  wrong-corner landings under scaling). ilhop's chord-only design already sidesteps this
  whole class. If a mouse-based trigger is ever considered for v2, it must ship with an
  explicit disable/escape-hatch (as Flow does for corner-switching) — never a bare,
  unconditional geometry trigger.
- **Full clipboard sync / drag-and-drop / file transfer** — see Q4. Confirmed anti-feature
  for this project at this layer.
- **Screensaver/lock-screen synchronization** — input-leap partially implements this
  (and by its own maintainers' admission, incompletely — no known hook into KDE
  Plasma's lock event) and Barrier had genuine regressions where sync-screensaver
  caused client monitors to never sleep. This is squarely input-leap's job as the
  transport, not ilhop's job as a hop layer riding on top of it; ilhop should not take
  on hooking into screensaver/lock state.

**7. Installation and safety affordances users expect for an input-path tool**
No mainstream tool researched documents a formal dry-run, one-command uninstall,
"what did you change" report, or panic-button reset as a *marketed* feature — but the
issue trackers make clear users *need* exactly this and don't get it: the only documented
recovery method for a wedged input-leap/Barrier session is "physically unplug and
replug the mouse/keyboard, possibly several times" or "reboot the server entirely."
That is the ecosystem's de facto panic button, and it is terrible. `ilhop`'s existing
`il-reset` (soon `ilhop reset`) already does better than every competitor's documented
recovery path. For a tool "packaged for other people" that runs in the input path, the
expected safety affordances — validated by the absence of anything better in this
space, not by a competitor doing it well — are: an uninstall path that fully reverts
(binaries, systemd units, keybinds), a doctor/self-check runnable any time (not just at
install), and a panic/reset command that's discoverable in the README's first screen,
since the alternative the rest of the ecosystem falls back to is unplugging hardware.

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Reliable keystroke delivery across a switch (no eaten chords) | Direct core-value requirement; ecosystem-wide failure point (stuck modifiers, dropped keys) makes this the #1 complaint everywhere researched | HIGH | ilhop Active defect #1; kernel-level held-modifier tracking (`EVIOCGKEY`) is the right layer per this research — re-injection via ydotool already proven unsafe |
| Deterministic cursor landing (predictable position, not random edge/off-centre) | #2 most common complaint class across input-leap/Barrier issue trackers | MEDIUM | ilhop Active defect #3; centre-of-target as default is defensible for a discrete/chord trigger since no continuous-edge competitor is directly comparable |
| Sub-~100ms perceived switch latency, symmetric in both directions | Any perceptible lag reads as a defect (see hardware-KVM complaint literature); asymmetric feel is itself a complaint-worthy inconsistency | MEDIUM–HIGH | ilhop already hits 15–20ms one direction; Active defect notes the return leg is 40–1600ms over ssh — symmetry gap, not just speed |
| No stuck modifiers surviving past the switch | Ecosystem-wide recurring defect (input-leap #1690/#207, deskflow #8920); workaround elsewhere is "restart the server" | HIGH | Hardest problem in the whole domain; nobody has a clean fix, so ilhop solving it is a genuine (not just table-stakes) accomplishment if achieved |
| One-command recovery when input wedges | De facto expectation exists because the alternative documented across every competitor is "unplug the physical device" or "reboot" | LOW (already built) | `il-reset` → `ilhop reset`; keep prominent in README |
| Clean install / uninstall path | "Packaged for other people" implies strangers must be able to remove it without residue | LOW–MEDIUM | Already an Active packaging item; no competitor sets a bar here, so any complete uninstall clears it |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|--------------------|------------|-------|
| Multi-check automated doctor/health-check command | No competitor (Synergy/Barrier/input-leap/deskflow) ships one; troubleshooting elsewhere is manual prose (ping, check port 24800) | MEDIUM (already built, 21 checks) | Market this explicitly in the README — it's not table stakes here, it's ahead of the entire field |
| Detached self-check + local auto-recovery after an optimistic switch | No competitor researched has an async "verify the far side took it, recentre+notify if not" pattern — they either block-and-wait (slow) or don't verify at all (silent failure) | MEDIUM–HIGH (already built) | This is the mechanism that lets ilhop stay fast *and* safe; worth calling out as the core technical differentiator |
| Edge-aware focus-chain hop (`il-focus-jump`: focus left normally, hop only when nothing further left) | No competitor has keyboard *window*-focus semantics tied to the hop at all — Flow/Universal Control only reason about screen edges, never window geometry | HIGH | Genuinely novel in this space; the "misfires/feels laggy" active defects are refinement issues on a differentiator, not table-stakes gaps |
| Kernel-level held-modifier read (`EVIOCGKEY`, skipping the virtual ydotool device) | Directly targets the root cause of the ecosystem's worst recurring bug class (stuck modifiers) at a lower layer than any competitor is documented to operate at | HIGH | Untestable via script per PROJECT.md constraints — highest-value, highest-risk differentiator |
| One-command panic/reset | Ecosystem's actual fallback is unplug-hardware-or-reboot; a scripted reset is a real, demonstrable step up | LOW (already built) | Low complexity to keep, high perceived-safety value for a stranger installing this |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Switch delay / dwell time before the hop fires | Feels like it would prevent accidental switches | No tool in this space uses it deliberately; the only real-world analogue (hardware KVM HDMI handshake delay) is universally treated as a defect, and ilhop already measured 700ms as "laggy" and rejected it | Keep the hop instant; prevent accidental fires via the chord itself (single distinctive combo) and single-flight locking, not time |
| Mouse-edge-crawl as a trigger mechanism | Feels "standard" because Synergy/Barrier/input-leap/Flow all default to it | It is the single largest complaint-generating mechanism in the entire researched ecosystem (geometry misconfig, edge-trapping, wrap-around, wrong-corner-under-scaling) | Stay chord-only; if ever added in v2, ship with an explicit disable switch the way Logitech Flow does for corners |
| Clipboard sync | Looks like an obvious "complete the KVM experience" feature | Not reliably solved on Linux/Wayland by input-leap (the transport ilhop rides on), by deskflow, or by a clean-slate rewrite (lan-mouse still has it as a roadmap item) | Leave to input-leap where it partially works, or a separate sidecar tool (already the plan per PROJECT.md's "rest of the two-machine kit") |
| Drag-and-drop file transfer | Same appeal as clipboard | Reported broken on every OS combination in input-leap; deskflow's maintainers removed it outright as unfixable-in-practice | Network share / syncthing (`drop` folder, already named in PROJECT.md as a separate concern) |
| Screensaver/lock-screen sync | Seems like it belongs with "screen switching" | It's the underlying transport's (input-leap's) responsibility, and even there it's incomplete (no KDE Plasma lock hook) and has caused regressions (client monitors never sleeping) | Don't take this on in the hop layer; it's out of ilhop's actual responsibility boundary |

## Feature Dependencies

```
Reliable keystroke delivery (no eaten chords)
    └──requires──> Kernel-level held-modifier tracking (EVIOCGKEY)
                       └──requires──> ydotool liveness probe (already built)

Deterministic cursor landing
    └──requires──> Detached self-check with local recovery (already built)

Doctor/health-check command
    └──requires──> Daemon liveness probing + side-file consistency + live round-trip test (already built, 21 checks)

One-command panic/reset
    └──enhances──> User trust in "packaged for other people" installability
    └──requires──> Single-flight lock (so a reset cannot race an in-flight hop)

Clean install/uninstall path
    └──requires──> Stable naming (il-* → ilhop rename, currently Active)

Mouse-edge-crawl trigger (if ever added, v2+)
    └──conflicts──> Chord-only design's freedom from geometry-misconfig complaint class
```

### Dependency Notes

- **Reliable keystroke delivery requires kernel-level held-modifier tracking:** the
  ecosystem's stuck-modifier defect class is not solved by re-injecting synthetic keys
  (ilhop tried this on 2026-09-10 and it wedged real input); reading genuine kernel
  state via `EVIOCGKEY` is a structurally different, lower-layer approach and is the
  one this research found no competitor attempting.
- **Deterministic cursor landing requires the detached self-check:** because ilhop's
  hop is optimistic (recentre immediately, verify after), the self-check is what turns
  "probably landed right" into "guaranteed to land right or be caught and corrected" —
  removing the self-check would silently reintroduce the wrong-screen-landing defect
  class documented across every competitor.
- **Doctor command requires daemon liveness + side-file consistency + round-trip test:**
  these three are the same three failure modes this research found scattered across
  competitor troubleshooting wikis as separate manual steps; ilhop having them scripted
  together is the differentiator, not any one check in isolation.
- **Panic/reset requires the single-flight lock:** a reset command racing an in-flight
  hop is exactly the kind of double-fire that causes the "sometimes doesn't fire" /
  interleaved-state bugs seen in Barrier's issue tracker (#1132, jumpy/duplicated
  keystrokes under rapid re-triggering).
- **Mouse-edge-crawl conflicts with the chord-only design's advantage:** adding a
  continuous-edge trigger mode would import the single largest complaint class in the
  researched ecosystem back into a tool that currently avoids it structurally — this is
  a real architectural tension, not just scope creep, and should be treated as a
  deliberate tradeoff decision if ever proposed, not a default v2 feature.

## MVP Definition

### Launch With (v1)

Already scoped in PROJECT.md's Active list — this research confirms none of it should
be cut and nothing critical is missing:

- [ ] Fix eaten first chord / stuck modifier — table stakes, ecosystem's hardest bug
- [ ] Fix wrong/off-centre cursor landing — table stakes
- [ ] Fix intermittent no-fire — table stakes
- [ ] Symmetric hop latency both directions — table stakes (asymmetry itself reads as a defect)
- [ ] `ilhop doctor` — already a differentiator vs. the entire researched field, keep and market it
- [ ] `ilhop reset` (panic button) — already ahead of the ecosystem's "unplug the device" fallback
- [ ] Install/uninstall script, README — table stakes for "packaged for other people"

### Add After Validation (v1.x)

- [ ] A lightweight status indicator (which machine currently has focus) — no
      competitor's tray-icon equivalent was found to be well-loved, but ilhop currently
      has zero visible state signal beyond the side file; add if users report
      disorientation, not preemptively.
- [ ] Configurable cursor-placement policy (centre vs. a "restore last position per
      side" option) — trigger: only if users report the centre default feels wrong in
      practice; no competitor data supports one over the other for a discrete/chord
      trigger, so don't guess ahead of feedback.

### Future Consideration (v2+)

- [ ] Both-sides-pluggable adapters (other compositors, yabai/skhd) — already deferred
      in PROJECT.md; this research adds no new urgency.
- [ ] Optional mouse-edge trigger mode — only with a mandatory disable/escape-hatch
      (per Logitech Flow's corner-disable precedent); defer until there's a concrete
      request, since it reintroduces the ecosystem's largest complaint class.
- [ ] Clipboard / drag-and-drop / file transfer — do not build at this layer; confirmed
      separately-hard even for funded, multi-year, clean-slate projects. Revisit only as
      a distinct sidecar tool, per PROJECT.md's existing "rest of the two-machine kit"
      framing.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Fix eaten first chord / stuck modifier | HIGH | HIGH | P1 |
| Fix cursor landing | HIGH | MEDIUM | P1 |
| Fix intermittent no-fire | HIGH | MEDIUM (needs reproduction first) | P1 |
| Symmetric latency both directions | MEDIUM | MEDIUM–HIGH | P1 |
| Install/uninstall + doctor/panic packaging | HIGH (for "packaged for others") | LOW–MEDIUM | P1 |
| Status indicator (current side) | LOW–MEDIUM | LOW | P2 |
| Configurable cursor-placement policy | LOW | LOW | P3 |
| Mouse-edge trigger mode (with disable) | LOW (untested demand) | HIGH | P3 |
| Clipboard / DnD / file transfer | LOW (repeatedly fails elsewhere) | HIGH | Do not build |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | input-leap / Barrier | deskflow | lan-mouse | Logitech Flow | Universal Control | ilhop's approach |
|---------|----------------------|----------|-----------|----------------|--------------------|-------------------|
| Trigger mechanism | Continuous mouse-edge crossing (+ thin hotkey support) | Same as input-leap (fork) | Continuous edge crossing, Wayland-native backends | Edge-reach, Ctrl+edge, disable-able corner switch | Continuous edge-push with visual cue | Single keyboard chord, bidirectional, side-tracked — deliberately not edge-based |
| Wayland keyboard switching | Broken — no global-shortcut path via libportal | Broken — same libei/libportal gap, documented in its own "known bugs" discussion | Best-effort per-compositor backend (wlroots vs KDE), inconsistent | N/A (not Wayland-scoped) | N/A (Apple stack, not this problem space) | Works by design — drives synthetic pointer motion server-side, the one path input-leap honours |
| Stuck modifiers | Recurring, unresolved (#1690, #207) | Recurring, unresolved (#8920), workaround = restart server | Not documented either way | Not documented | Not applicable (different transport) | Active defect being fixed via kernel-level `EVIOCGKEY` read, not re-injection |
| Cursor placement after switch | Edge-continuation (proportional), frequently misconfigured/broken | Same as input-leap | Edge-continuation | Edge-continuation (mouse-position-driven) | Edge-continuation with push-through visual cue | Recentre-on-target (discrete/chord trigger has no continuous position to carry) |
| Clipboard sync | Partial (not on Linux/Wayland) | Same limitation inherited | Roadmap item, not shipped | N/A (different problem domain) | Yes (Apple ecosystem) | Deliberately out of scope — confirmed unreliable at this layer everywhere else |
| Drag-and-drop / file transfer | Broken across all OS combos | Removed entirely by maintainers as unfixable | Not offered | N/A | N/A | Deliberately out of scope — same call as deskflow made |
| Diagnostics / doctor command | None — manual ping/port-check wiki only | None | None documented | None documented | None documented (Apple, opaque) | 21-check `il-doctor` / `ilhop doctor` — clear differentiator |
| Panic-button / reset | None — "unplug the device" or reboot | None documented | None documented | Not needed (hardware-backed) | Not needed (Apple-managed) | `il-reset` / `ilhop reset` — clear differentiator |

## Sources

- [input-leap/input-leap#1690 — Modifier keys stuck on the connected screen PC](https://github.com/input-leap/input-leap/issues/1690)
- [input-leap/input-leap#207 — super key gets stuck in "pressed" on client](https://github.com/input-leap/input-leap/issues/207)
- [input-leap/input-leap#617 — Input freezes or gets stuck, losing control for a few seconds](https://github.com/input-leap/input-leap/issues/617)
- [input-leap/input-leap#576 — Dead key issue Win10 <-> Win10](https://github.com/input-leap/input-leap/issues/576)
- [input-leap/input-leap#532 — Some keyboard strokes are not working properly](https://github.com/input-leap/input-leap/issues/532)
- [input-leap/input-leap#1132 — Barrier Jumpy](https://github.com/input-leap/input-leap/issues/1132)
- [input-leap/input-leap#107 — Keyboard changes language when moving from Windows to Mac](https://github.com/input-leap/input-leap/issues/107)
- [input-leap/input-leap#1025 — Cursor jumps position crossing monitors](https://github.com/input-leap/input-leap/issues/1025)
- [input-leap/input-leap#490 — Bouncing mouse at screen edge](https://github.com/input-leap/input-leap/issues/490)
- [input-leap/input-leap#94 — Cursor is stuck in bottom of client screen](https://github.com/input-leap/input-leap/issues/94)
- [input-leap/input-leap#258, #226, #378, #855 — Drag and drop file transfer not working](https://github.com/input-leap/input-leap/issues/258)
- [input-leap/input-leap discussions #2338, #2022 — Drag and Drop File Transfers](https://github.com/input-leap/input-leap/discussions/2338)
- [input-leap/input-leap discussion #1707 — Inhibit screen saver while connected?](https://github.com/input-leap/input-leap/discussions/1707)
- [debauchee/barrier#1700 — Screensaver not activating in sync](https://github.com/debauchee/barrier/issues/1700)
- [input-leap/input-leap#338, #993 — Barrier Service inhibits screen blanker / interferes with sleep](https://github.com/input-leap/input-leap/issues/338)
- [input-leap/input-leap Wiki — Troubleshooting](https://github.com/input-leap/input-leap/wiki/Troubleshooting)
- [deskflow/deskflow discussion #7499 — Wayland support: Known bugs](https://github.com/deskflow/deskflow/discussions/7499)
- [deskflow/deskflow#7596 — Wayland: Hotkeys don't work](https://github.com/deskflow/deskflow/issues/7596)
- [deskflow/deskflow#8920 — Modifier keys occasionally get stuck](https://github.com/deskflow/deskflow/issues/8920)
- [deskflow/deskflow#8083 — Keyboard layout on client changes unexpectedly](https://github.com/deskflow/deskflow/issues/8083)
- [deskflow/deskflow#8899 — Incorrect keyboard layout conversion](https://github.com/deskflow/deskflow/issues/8899)
- [deskflow/deskflow Wiki — Known Issues](https://github.com/deskflow/deskflow/wiki/Known-Issues)
- [feschber/lan-mouse#187 — Input capture not working with Wayland/Linux/labwc](https://github.com/feschber/lan-mouse/issues/187)
- [feschber/lan-mouse#166 — Hyprland -> macOS problem](https://github.com/feschber/lan-mouse/issues/166)
- [feschber/lan-mouse README](https://github.com/feschber/lan-mouse/blob/main/README.md)
- [Logitech Support — Move from one screen to another with Logitech Flow](https://support.logi.com/hc/en-us/articles/360023192914-Move-from-one-screen-to-another-with-Logitech-Flow)
- [Logitech Support — Control screen switching with Logitech Flow](https://support.logi.com/hc/en-001/articles/360023359653-Control-screen-switching-with-Logitech-Flow)
- [Apple Support — Universal Control: Use a single keyboard and mouse between Mac and iPad](https://support.apple.com/en-us/102459)
- [9to5Mac — How to use Universal Control for iPad and Mac](https://9to5mac.com/2024/01/04/universal-contorl-ipad-and-mac-feature/)
- KVM hardware switch latency/lag complaints (Arch Linux Forums, DPReview Forums, avaccess.com) — used only as the "delay is universally disliked" corroboration, LOW confidence (forum anecdotes, not a KVM-software source), see individual research-store cache entries for URLs.

---
*Feature research for: cross-machine keyboard-driven screen switching (software KVM), Wayland + macOS peer*
*Researched: 2026-09-10*
