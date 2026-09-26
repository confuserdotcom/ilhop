# ilhop

## What This Is

`ilhop` is a keyboard-driven screen-hop layer for [input-leap](https://github.com/input-leap/input-leap)
on Wayland. One chord moves the pointer and keyboard focus between a Linux box
and a Mac, in both directions. It exists because input-leap's own
keyboard screen-switching does not work on Wayland at all.

Today it is ~457 lines of shell and C living loose in `~/.local/bin/il-*` on one
machine. This project turns it into `ilhop`: a named, installable, documented
thing with its bugs killed.

## Core Value

Pressing the hop key always lands you on the other machine, ready to type, with
no lost keystroke and no wedged input device.

Everything else — packaging, docs, adapters, upstreaming — is negotiable. That
one sentence is not.

## Requirements

### Validated

Shipped, live, and confirmed working by `il-doctor` (21/21 checks passing as of
2026-09-10) plus hands-on testing across two sessions.

- ✓ `il-jump toggle` — one chord hops both ways, reads `$XDG_RUNTIME_DIR/il-side`
  to pick its own direction, stays correct after crossing with the mouse — existing
- ✓ Sub-50ms hop outbound (Ryuk→Mac measured 15–20ms) via relative `ydotool
  mousemove` overshoot that pins against the destination's far edge — existing
- ✓ `il-side-watch.service` — follows the input-leap journal at `--debug INFO`,
  keeps the side file accurate, resets on client connect/disconnect — existing
- ✓ Single-flight `flock` — rapid double-press cannot interleave two hops — existing
- ✓ ydotool liveness probe by moving 0px, with daemon revival and a 250ms
  libinput settle (a stopped `ydotoold` leaves a stale socket, so `[ -S ]` lies) — existing
- ✓ No-op when already on the target side — existing
- ✓ Detached self-check ~1.2s after the hop: retries once, and if the far screen
  never took it, recentres locally and notifies rather than stranding the
  pointer at the edge — existing
- ✗ RETIRED 2026-09-26 — `il-focus-jump` — geometry-checked edge detection via `hyprctl clients`, so
  ALT+H focuses the left window normally and only hops when nothing is further
  left — existing
- ✓ Mac-side mirror on AeroSpace — `il-jump-mac` at `alt-c` (`il-focus-jump-mac`
  at `alt-l` retired 2026-09-26), warm ssh control master via launchd — existing
- ✓ `il-doctor [--test]` — 21-check health report plus live round trip — existing
- ✓ `il-reset` — one-command recovery when input is wedged — existing
- ✓ `il-heldmods` — reads genuinely-held modifiers from the kernel via
  `EVIOCGKEY`, deliberately skipping ydotool's own virtual device — existing

### Active

Six defects and the packaging work. Bugs first, in this order.

- [ ] First chord after a hop is silently eaten — a modifier held while the
      pointer crosses never produces a key-DOWN on the far side, wedging macOS
      with `CGEventSourceFlagsState` at `0x20000000`. Tapping space clears it; a
      mouse move does not. The obvious fix (re-press held modifiers through
      ydotool) was tried on 2026-09-10, wedged the real keyboard and mouse, and
      was reverted to `92f64bc`. Needs a different mechanism.
- [ ] Hop "sometimes doesn't fire" — user-reported, not yet reproduced. Both
      journals record this path as tested-good on 2026-09-09, so this is most
      likely a regression introduced by the `9d1f129` revert. Reproduce before
      theorising.
- [ ] Pointer lands wrong — user-reported: ends at an edge or off-centre instead
      of dead centre. Also recorded as tested-good on 2026-09-09; same regression
      suspicion, same rule — reproduce first.
- [ ] Return leg is slow and asymmetric — Ryuk→Mac is 15–20ms, Mac→Ryuk goes
      over ssh at ~40–110ms warm and ~1.6s if the launchd control master has
      lapsed. The hop should feel the same in both directions.
- [-] DROPPED 2026-09-26 — ALT+H edge detection misfires — hops when a window still exists in that
      direction, or refuses to hop when genuinely at the edge.
- [-] DROPPED 2026-09-26 — ALT+H feels laggy against plain focus — the `hyprctl clients` geometry
      query runs before the focus moves, so the shipped focus-left feels instant
      and ours does not.
- [ ] Package as `ilhop` — standalone git repo, install script, uninstall path,
      `ilhop doctor`, README that a stranger can follow.
- [ ] Rename the surface from `il-*` to `ilhop`, with the old names kept working
      through this milestone so the daily driver never breaks mid-flight.

### Out of Scope

- **Both-sides-pluggable adapters (other Wayland compositors, yabai/skhd)** —
  deferred to v2 by explicit decision. v1 targets exactly one tested combination.
  Building adapters for hardware the author cannot press keys on directly
  contradicts this project's hardest constraint.
- **Auto-hop on the window-focus keys** — Retired 2026-09-26 by the author's decision: `ALT+C` is the only hop key on both machines. Edge-hop on the focus keys cost more than it gave — fiddly edge detection, and `ALT+H` firing two handlers per press. `il-focus-jump` / `il-focus-jump-mac` backed up to `~/.local/share/ilhop-retired/`, AeroSpace `alt-l` restored to plain focus.
- **Upstreaming into `ryoku-desktop`** — v2. Repo first, so it is provably
  installable standing alone before it inherits Ryoku's release cycle.
- **The rest of the two-machine kit** — `push` / `pull` / `openon`, copi
  clipboard sync, the `drop` syncthing folder, mosh aliases. Same setup, different
  project. `ilhop` is the hop.
- **Migrating off input-leap** — settled 2026-09-10, do not re-litigate. deskflow
  1.26.0 and lan-mouse 0.11.0 were both evaluated. deskflow's own "Wayland
  support: Known bugs" discussion lists the identical defects (modifiers not sent
  to clients when on host screen; hotkeys blocked on libportal global-shortcuts)
  and targets GNOME 46+/KDE 6.1+ with Hyprland only "nearly ready". lan-mouse is
  Wayland-native but its macOS client is the weak half, and macOS is half of this
  setup.
- **Making input-leap's own `keystroke()` hotkeys work** — impossible on the
  `--use-ei` EiScreen backend. No global-hotkey grab exists through the input
  capture portal; it is X11-only. Zero `registered hotkey` lines at startup.
  Already removed from `server.conf`.

## Context

**The upstream gap this compensates for.** input-leap on Wayland cannot switch
screens from the keyboard. Two separate upstream holes cause it: libportal has no
global-shortcuts support yet, and modifiers are not delivered to clients while
the pointer is on the host screen. `ilhop` works around both by driving synthetic
pointer motion on the *server* — the only place input-leap honours it.

**Why the hop must run on the Linux side.** input-leap only reacts to synthetic
pointer input on the server. Everything faked on the Mac fails: `cliclick` needs
Accessibility permission (blocked over ssh), and a compiled
`CGWarpMouseCursorPosition` + `CGEventPost` helper still did not move
input-leap's tracked cursor — the client ignores non-HID mouse events. This is
why the return leg from the Mac shells back over ssh, and why that leg is slow.

**Current binding layout.** `ALT+C` → `il-jump toggle` (unconditional hop, same
chord on both machines). It is the only hop key: `ALT+H` / `ALT+L` are plain
focus on both machines since 2026-09-26 (edge-hop retired). The binds live in
a fork of `binds.lua` at `~/.config/ryoku/user_edits/hypr/modules/binds.lua`
rather than `user.lua`, because only `binds.lua` is parsed into the Super+K
cheatsheet.

**Hardware.** Ryuk is a 2015 MacBook Pro 13" running Arch (i5-5257U, Iris 6100,
Hyprland 0.56.2 via the Ryoku fork). The Mac is a MacBook Air on AeroSpace.
Linked over Tailscale, which is already direct p2p — the remaining jitter is the
Air's WiFi, and that was settled as not worth chasing. Keyboard is a MAD60 60%
with no arrow keys, which is why the bindings are letter chords.

**The scar.** On 2026-09-10 a fix shipped that re-pressed held modifiers through
ydotool after a hop. It wedged the author's real keyboard and mouse and had to be
reverted. It went out on reasoning alone, because that code path is not testable
from a script. That incident is the origin of the constraint below and is the
single most important piece of context in this document.

## Constraints

- **Verification**: No input-path change ships without the author physically at
  the keyboard — This project already broke its own input once by shipping
  unverified reasoning. Every phase touching key or pointer injection gates on a
  human keypress.
- **Testability**: `ydotool` key events relay to the Mac but do **not** fire
  Hyprland keybinds (verified: 0 fires even with control local), and
  `il-heldmods` excludes ydotool's own device by design — Keybind paths cannot be
  simulated at all. Test by calling scripts directly, by reading Mac modifier
  flags with `modstate`, and by driving real `aerospace workspace` switches. A
  flag read alone is not proof.
- **Tech stack**: POSIX shell plus one small C helper; no runtime beyond
  `ydotool`, `systemd --user`, and ssh — It has to install on a stranger's box
  without dragging a language runtime along.
- **Compositor coupling**: The Ryoku Hyprland fork replaces `hyprctl dispatch`
  with a Lua API (`hl.dsp.*`); plain `hyprctl dispatch movecursor` fails with a
  parse error — Every compositor call is fork-specific today. Isolating them is
  what makes v2's adapters possible, so v1 should not scatter new ones.
- **Log level**: `input-leap-server.service` must run `--debug INFO`, never
  `DEBUG` — At DEBUG it emits ~4487 journal lines/minute of motion events, and
  `il-side-watch` follows that journal.
- **Latency budget**: The hop must stay under ~50ms in both directions — 700ms
  was the original implementation and the author rejected it as laggy. Awaiting
  journald confirmation (~450ms) in the hot path is the specific thing that must
  never come back.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stay on input-leap; do not migrate to deskflow or lan-mouse | Both inherit the same libei/libportal Wayland bugs; lan-mouse's macOS client is weak and macOS is half this setup | ✓ Good — settled 2026-09-10, closed |
| Drive the hop from the server side only | input-leap ignores synthetic pointer input on clients; two Mac-side approaches were built and both failed | ✓ Good |
| `toggle` mode reading a side file, rather than fixed-direction binds | One chord works both ways and survives crossing with the mouse | ✓ Good |
| Optimistic recentre + detached self-check, not awaited confirmation | Awaiting journald cost ~450ms and made the hop feel laggy; the detached check covers the failure case | ✓ Good |
| Never re-press held modifiers through ydotool | Wedged the real keyboard and mouse on 2026-09-10; reverted to `92f64bc` | ✓ Good — and the "first chord eaten" bug still needs a different fix |
| One hop key (`ALT+C`); no auto-hop on the focus keys | Edge detection was fiddly and doubled up `ALT+H`; one chord both ways is simpler to use and to develop | ✓ Good — decided 2026-09-26, dropped Phase 3 |
| Accept HOP-01 (modifier held across a hop is not carried) as upstream | input-leap's server ignores the compositor's modifier state (`EI_EVENT_KEYBOARD_MODIFIERS: // FIXME`); ydotool re-press is banned and Mac-side injection is overwritten by the client. Patch tracked as UPSTREAM-01 | — Accepted 2026-09-26; workaround: re-press the modifier |
| Bugs before packaging | A working daily driver sooner, and packaging a buggy thing means packaging it twice | — Pending |
| v1 = Hyprland + AeroSpace only; adapters in v2 | Adapters for untestable hardware contradict the verification constraint | — Pending |
| Repo first, upstream to Ryoku second | Prove it installs standalone before inheriting Ryoku's release cycle | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-10 after project initialization*
