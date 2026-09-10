# Architecture Research

**Domain:** Keyboard-driven cross-machine input switching (software KVM layer over input-leap), POSIX shell + one C helper
**Researched:** 2026-09-10
**Confidence:** MEDIUM overall — systemd unit semantics and XDG runtime-dir lifetime are HIGH (official docs, ArchWiki, cross-checked); adapter-seam patterns are MEDIUM (well-established real tools, verified via search but pattern-matching to this project is my synthesis); specific latency numbers for untried transport variants (persistent coproc, socket-over-ssh) are LOW — flagged inline, need bench-out before committing.

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────┐
│ Linux box ("Ryuk") — server side, drives the hop                   │
│                                                                      │
│  ┌───────────────┐   reads side file    ┌──────────────────────┐   │
│  │  ilhop-jump    │◄──────────────────── │ $XDG_RUNTIME_DIR/    │   │
│  │  (hot path)    │                      │ ilhop-side  + .lock  │   │
│  └──────┬─────────┘                      └──────────▲───────────┘   │
│         │ backend_* calls                            │ writes       │
│         ▼                                             │              │
│  ┌───────────────┐                          ┌─────────┴──────────┐  │
│  │ lib/backend-  │  ydotool mousemove        │ ilhop-side-watch   │  │
│  │ hypr.sh       │  (overshoot + pin)         │ (systemd --user)   │  │
│  └───────────────┘                          └─────────▲──────────┘  │
│         │                                              │ follows     │
│         ▼                                    ┌─────────┴──────────┐  │
│  ┌───────────────┐  detached, ~1.2s later     │ journalctl --user  │  │
│  │ self-check     │  (systemd-run --scope)     │ -u input-leap-     │  │
│  │ child          │                            │ server -f          │  │
│  └───────────────┘                            └────────────────────┘  │
│                                                                      │
│  ┌───────────────┐   hyprctl clients geometry                        │
│  │ ilhop-focus-  │◄── queries before deciding to hop                 │
│  │ jump           │                                                  │
│  └──────┬─────────┘                                                  │
│         │ hops via ilhop-jump when at edge                           │
│         ▼                                                            │
│  ┌────────────────────────────────────────────────────────────┐      │
│  │ ssh ControlMaster (warm, ControlPersist) — cross-machine    │      │
│  │ transport, over Tailscale (WireGuard-authenticated overlay) │      │
│  └──────────────────────────┬───────────────────────────────────┘    │
└─────────────────────────────┼────────────────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────────────┐
│ Mac ("MacBook Air") — client side, receives input-leap, cannot drive │
│ the hop itself (input-leap ignores synthetic pointer events here)    │
│                                                                       │
│  ┌────────────────┐   ssh -> ilhop-jump-mac / ilhop-focus-jump-mac   │
│  │ AeroSpace bind  │──────────────────────────────────────────────►  │
│  │ alt-c / alt-l   │   (shells back to the Linux box over ssh)       │
│  └────────────────┘                                                  │
│  ┌────────────────┐                                                  │
│  │ launchd: keeps  │  warms/refreshes the ControlMaster proactively  │
│  │ ssh master warm │                                                  │
│  └────────────────┘                                                  │
└───────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|-------------------------|
| `ilhop-jump` (hot path) | Read side, no-op check, single-flight lock, fire the ydotool overshoot move, recentre, spawn detached self-check | POSIX shell, one process, sub-50ms budget end to end |
| `ilhop-focus-jump` | Geometry check via compositor backend, plain focus vs. hop-at-edge decision | POSIX shell, calls `backend_*` functions, then delegates to `ilhop-jump` |
| `lib/backend-*.sh` | The **only** place compositor-specific calls live (hyprctl/Lua today, sway/etc. in v2) | Sourced shell library, fixed function-name contract |
| `ilhop-side-watch` | Follow the input-leap journal, keep the side file authoritative, reset on connect/disconnect | systemd --user service wrapping a `journalctl -f` loop |
| Side file + lock (`$XDG_RUNTIME_DIR/ilhop-side`, `ilhop-side.lock`) | Ephemeral, single-writer/multi-reader shared state for "which side is active" and "is a hop in flight" | Plain file + `flock -n` |
| Self-check child | Retry-once, recentre-if-still-wrong, notify — runs off the hot path, ~1.2s after the hop | Detached transient unit (`systemd-run --user --scope`), not inline, not a daemon |
| `ilhop-heldmods` (C) | Read genuinely-held modifier keys via `EVIOCGKEY`, skipping ydotool's own virtual device | Small standalone C binary, no shell dependency |
| ssh ControlMaster | Cross-machine command dispatch, authenticated + encrypted transport | `ControlMaster auto` + `ControlPersist` + a warm unix socket in `ControlPath` |
| `ilhop-doctor` | Health checks + live round trip, the only place allowed to *exercise* the input path outside a human keypress-gated change | POSIX shell, read-only checks + one opt-in `--test` round trip |
| Mac-side mirror (`ilhop-jump-mac`, `ilhop-focus-jump-mac`) | Same two entry points, but every action shells back to the Linux box — the Mac never drives the hop locally | POSIX shell + AeroSpace binds + launchd keepalive for the ssh master |

## Recommended Project Structure

```
ilhop/
├── bin/
│   ├── ilhop-jump                # hot path, was il-jump
│   ├── ilhop-focus-jump           # was il-focus-jump
│   ├── ilhop-side-watch           # was il-side-watch (journal follower body)
│   ├── ilhop-doctor
│   ├── ilhop-reset
│   └── ilhop-heldmods.c           # compiled at install time
├── lib/
│   ├── backend-detect.sh          # one-time case dispatch, sources exactly one backend-*.sh
│   ├── backend-hypr.sh            # v1: wraps hyprctl / Ryoku's hl.dsp.* Lua API
│   ├── backend-sway.sh            # v2: same function names, different bodies
│   └── common.sh                  # side-file path, lock helpers, logging — shared, backend-agnostic
├── mac/
│   ├── ilhop-jump-mac
│   ├── ilhop-focus-jump-mac
│   └── aerospace-warm-master.plist  # launchd job keeping ControlMaster hot
├── systemd/
│   └── ilhop-side-watch.service    # installed to ~/.local/share/systemd/user/, NOT ~/.config
├── install.sh
├── uninstall.sh
└── README.md
```

### Structure Rationale

- **`lib/backend-*.sh` is the v2 seam, cut now, filled once.** Every `hyprctl`/`hl.dsp.*` call moves behind `backend_move_cursor_rel`, `backend_focused_window_geometry`, `backend_neighbor_exists` — even though only `backend-hypr.sh` exists in v1. This is the direct answer to the "compositor coupling" constraint: v1 changes nothing about behavior, it just stops new call sites from touching `hyprctl`/Lua directly.
- **`mac/` stays a separate tree, not a runtime-dispatched backend.** The Linux and Mac scripts never run on the same machine, so there is no runtime detection to do — the "adapter" for OS is the packaging split (which bundle you install where), not a `case` at runtime. Don't unify these into one script with an `if [[ $(uname) == Darwin ]]` branch; that adds a branch that's always taken the same way on a given install and buys nothing.
- **`lib/common.sh` holds the side-file/lock helpers so backend files never touch state directly** — backends only answer "where is the window/cursor," never "which side are we on." Keeps the state-machine logic in one place regardless of how many backends exist later.
- **`ilhop-heldmods.c` stays a standalone compiled binary**, not folded into a "framework" — it's the one piece of the tool that must talk to `/dev/input` directly, and C is the right tool for `EVIOCGKEY`; shell has no business wrapping it beyond invoking it.

## Architectural Patterns

### Pattern 1: Case-dispatch, single file (xdg-open's `detectDE`)

**What:** One `detect_X()` function runs a `case` over environment signals (here: `$XDG_CURRENT_DESKTOP`, `$DESKTOP_SESSION`, fallback heuristics) and sets a variable; every call site does `case "$DE" in gnome) ... ;; kde) ... ;; esac` inline, in the same file.
**When to use:** Small number of call sites, backend is fixed for the life of the process, you want zero extra fork/exec.
**Trade-offs:** Scales badly past a handful of call sites (every call site repeats the `case`); but it is the cheapest possible seam and is exactly what a project this size (~500 lines) can afford. `xdg-open` (part of `xdg-utils`, shipped by every Linux desktop) has used this shape for two decades without needing a plugin system.
**Example (paraphrased from xdg-open's structure):**
```sh
detectDE() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME*) DE=gnome ;;
    *KDE*)   DE=kde   ;;
    *)       DE=generic ;;
  esac
}
detectDE
case "$DE" in
  gnome) gio open "$1" ;;
  kde)   kde-open5 "$1" ;;
  *)     xdg-mime query default "$1" ;;
esac
```

### Pattern 2: Sourced backend files with a fixed function contract (Homebrew's `os/mac` vs `os/linux`)

**What:** A detection step runs once at process start and sources exactly one implementation file; every implementation defines the *same function names*, so call sites never branch — they just call `backend_move_cursor_rel 400 0` and whichever file got sourced supplies the body.
**When to use:** More than a handful of call sites, or a surface expected to grow (a second real backend is a known future requirement, as it is here for v2). Zero per-call overhead (sourcing happens once, then it's a plain shell function call) — critical for the sub-50ms hot path.
**Trade-offs:** Requires discipline to keep function names identical across backend files (no compiler to catch drift — `ilhop-doctor` should assert the contract, e.g. `type backend_move_cursor_rel >/dev/null || fail`). Real precedent: Homebrew's formula/OS code uses `OS.mac?`/`OS.linux?` conditionals and OS-specific directories (`Library/Homebrew/os/mac`, `os/linux`) implementing the same interface so the bulk of formula code stays OS-agnostic.
**Example:**
```sh
# lib/backend-detect.sh — runs once, in ilhop-jump's startup
case "$XDG_CURRENT_DESKTOP:${HYPRLAND_INSTANCE_SIGNATURE:-}" in
  *Hyprland*|*:*) . "$ILHOP_LIB/backend-hypr.sh" ;;
  *sway*)         . "$ILHOP_LIB/backend-sway.sh" ;;   # v2
  *)              echo "ilhop: unsupported compositor" >&2; exit 1 ;;
esac

# lib/backend-hypr.sh
backend_move_cursor_rel() { hl.dsp.movecursor "$1" "$2"; }   # Ryoku's Lua API, not hyprctl dispatch
backend_focused_window_geometry() { hyprctl -j activewindow; }
```
This is the seam v1 should cut. **It is the single highest-leverage structural change for the "compositor coupling" constraint** — it costs nothing in v1 (one implementation, sourced once, no new fork) and makes v2's Sway/GNOME adapters purely additive.

### Pattern 3: Separate executables on PATH, discovered by naming convention (git subcommands, asdf plugins, kubectl plugins, docker-machine drivers)

**What:** Any executable named `<tool>-<verb>` (or living in a fixed `bin/` convention directory, as asdf plugins do with `bin/install`, `bin/list-all`, `bin/list-bin-paths`) is discovered and invoked as a subprocess, in whatever language it wants, with no shared shell state.
**When to use:** Independently installable/pluggable extensions, strong isolation wanted (a crashing plugin can't corrupt the caller's shell state), or the extension genuinely needs a different language/runtime. `kubectl` plugins and `docker-machine-driver-*` binaries use exactly this convention for third-party extensibility.
**Trade-offs:** Fork+exec cost per invocation (roughly 1-5ms locally, PATH search adds more) — **irrelevant for `ilhop-doctor` (runs once, human-triggered) but a real tax if it ever crept into the `ilhop-jump` hot path.** Also harder to share helpers (arg parsing, logging) across executables without a small shared library sourced by each.
**Recommendation for this project:** Use this pattern only for `ilhop-doctor`'s per-backend checks (each backend could ship an optional standalone `ilhop-check-hypr`, `ilhop-check-sway` invoked once per doctor run) — never for anything inside `ilhop-jump`. The hot path stays on Pattern 2.

## Data Flow

### Local hop (`ilhop-jump toggle`, hot path)

```
keypress (ALT+C)
    │
    ▼
read $XDG_RUNTIME_DIR/ilhop-side          (no-op check: already on target side?)
    │
    ▼
flock -n ilhop-side.lock  ─── contended? ──► exit silently (single-flight; do NOT queue —
    │                                         queueing a second press would blow the 50ms
    │                                         budget; the in-flight hop's self-check
    │                                         reconciles state within ~1.2s regardless)
    ▼
backend_move_cursor_rel(dx, dy)            (overshoot + pin against far edge — the
    │                                        only network-free, compositor-coupled call)
    ▼
recentre on destination                     (optimistic — no wait for input-leap's journal)
    │
    ▼
spawn detached self-check (systemd-run --user --scope, async — does not block return)
    │
    ▼
release lock, exit                          ← total elapsed must stay < 50ms up to here
```

```
~1.2s later, off the hot path, in the detached child:
  check side actually flipped → if not: retry once → still not: recentre locally + notify
```

### Cross-machine hop (Mac → Linux leg, currently the slow/asymmetric one)

```
AeroSpace bind (alt-c)
    │
    ▼
ilhop-jump-mac  ──►  ssh (ControlMaster: warm ~40-110ms / cold ~1.6s) ──► Linux box
                                                                              │
                                                                              ▼
                                                                    ilhop-jump toggle
                                                                    (same hot path as above)
```
Because input-leap only honours synthetic pointer input on the **server** (the Linux box), every Mac-initiated hop is fundamentally: *authenticate/reach the Linux box → run the same local hot path there.* The cross-machine leg is pure dispatch latency stacked in front of the identical hot path — it is not part of the hot path's own budget, but it dominates user-perceived latency for that direction today (see transport section below).

### State ownership (who writes, who reads)

```
ilhop-side-watch  ──writes──►  $XDG_RUNTIME_DIR/ilhop-side  ◄──reads──  ilhop-jump, ilhop-focus-jump
        ▲                              ▲
        │ follows                      │ truncated/reinitialized on service start
   journalctl -f (input-leap-server)    (closes the "stale file from a dead session" gap)
```
Single writer (`ilhop-side-watch`), multiple readers, file-based rather than IPC — correct for this cardinality (one producer, low-frequency readers, no need for push notification since readers already run on-demand at keypress time).

## Suggested Build Order

1. **Fix the 6 defects on the current structure — no refactor in the same pass.** Root-cause the two regression-suspects (hop sometimes doesn't fire; pointer lands wrong) by diffing against the last known-good commit before the `9d1f129` revert, rather than reasoning from scratch — both were tested-good on 2026-09-09. Investigate first-chord-eaten and return-leg asymmetry together — both are about far-side state immediately after a hop, and a race in one plausibly explains "sometimes doesn't fire." Do the `ilhop-focus-jump` geometry misfire and pre-hop-query latency last — isolated to that one component, no interaction with the cross-machine cluster.
2. **Re-verify against `ilhop-doctor` (21/21) and a live human-keypress round trip on both machines** — required by the project's own Verification and Testability constraints before anything else proceeds.
3. **Cut the `lib/backend-*.sh` seam as a pure, behavior-preserving refactor** (Pattern 2 above), re-run doctor + live round trip again to prove latency and behavior are unchanged. This is deliberately sequenced *after* defects are fixed, so seam-cutting can't hide or introduce a behavioral regression.
4. **Rename `il-*` → `ilhop-*`**, old names as thin `exec` wrappers, so the daily driver never breaks mid-flight (per the milestone's own stated rule). Do this after step 3 so the renamed tree is the clean post-seam version, not a second rename-then-refactor pass.
5. **Package**: install script, unit file placed at `~/.local/share/systemd/user/` (never `~/.config/systemd/user/`), uninstall path, `ilhop doctor`. This is the natural point to also fix the two systemd-hygiene issues raised in this research (side-file reinit on watcher start; `StartLimitBurst` tuning) since packaging already touches the install-time unit file.
6. **v2 adapters (next milestone)**: implement `lib/backend-sway.sh` (or GNOME/other) purely against the function contract frozen in step 3. Because the seam predates any second implementation, v2 is additive-only — important given the Testability constraint means the author cannot personally verify a compositor they don't run; the contract must already be proven correct by the one implementation that WAS hand-tested.

## Anti-Patterns

### Anti-Pattern 1: Reviving rexec/rlogin's trust model for the cross-machine transport

**What people do:** Stand up a small always-on listener bound to a "trusted" network (a VPN, a LAN) with no per-message authentication, reasoning that network-level trust (Tailscale ACLs, WireGuard peer identity) is sufficient.
**Why it's wrong:** This is precisely the `.rhosts`/rexec/rlogin model that ssh replaced, for the reason ssh replaced it — it collapses "this specific key can run this specific command" down to "anything that can reach this port on the tailnet can trigger the action." For a tool whose entire job is synthetic keyboard/pointer injection, that failure mode is arbitrary remote input injection, not a minor risk.
**Do this instead:** Keep ssh (or something layered under an existing ssh channel/socket-forward) as the authentication and encryption boundary; if a persistent listener is ever justified, it should ride inside that boundary (a unix socket forwarded via `ssh -L`, or a resident process reached over an already-open ssh channel), never bare on the tailnet.

### Anti-Pattern 2: Retry/recovery logic living inline in the hot path

**What people do:** "Just wait and confirm the hop worked" before returning control to the user — exactly what this project already tried and rejected (the ~450ms journald-await implementation).
**Why it's wrong:** Confirmation requires waiting on a cross-process/cross-machine signal, which cannot be bounded under the 50ms budget; awaiting it inline is the single specific regression the project's own constraints forbid re-introducing.
**Do this instead:** Optimistic action + recentre inline (fast, no waiting), verification and repair in a detached child (Pattern already adopted — keep it, and prefer `systemd-run --user --scope` for the detach so the child is supervisable/visible rather than an orphaned background job).

### Anti-Pattern 3: Installing packaged systemd --user units into `~/.config/systemd/user/`

**What people do:** Drop the shipped `.service` file straight into `~/.config/systemd/user/` because that's "the user units directory" everyone remembers.
**Why it's wrong:** That directory is systemd's highest-priority, user-authored tier — the same place `systemctl --user edit` writes overrides and the same place a user's own hand-rolled units live. A package silently placing a file there risks colliding with (or looking indistinguishable from) something the user wrote themselves, and an uninstall can't safely tell the two apart.
**Do this instead:** Install to `~/.local/share/systemd/user/` (the XDG_DATA_HOME tier, explicitly for user-installed *packages*, lower priority than `~/.config`), then `systemctl --user daemon-reload && systemctl --user enable --now <unit>` — the resulting enablement symlink in `~/.config/systemd/user/*.wants/` is expected and is exactly what `disable` cleanly reverses.

### Anti-Pattern 4: Trusting the side-file's mere existence as proof of a live session

**What people do:** Treat "the side file exists and says X" as sufficient to act on.
**Why it's wrong:** `$XDG_RUNTIME_DIR` lifetime is tied to *any* login session for the user, not specifically the graphical one — and with `loginctl enable-linger` it can survive full logout entirely (persisting until reboot, since `user@.service` and its runtime dir stay up). A side file can outlive the compositor/watcher that wrote it.
**Do this instead:** Keep the existing ydotool liveness probe as the actual source of truth for "is the destination alive," and additionally have `ilhop-side-watch` reinitialize the file to a known default on every service start, so a stale value from an ended session can never leak into a new one.

## Integration Points

### External Services / Processes

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| `ydotoold` / `ydotool` | Local unix socket, invoked as a subprocess per hop | Existing liveness probe (0px move) is correct — `[ -S socket ]` alone lies when the daemon is dead but the socket file lingers |
| Hyprland (Ryoku Lua fork) | `hl.dsp.*` Lua-API calls today, plain `hyprctl dispatch` elsewhere | Must go through `lib/backend-hypr.sh` exclusively — this is the seam |
| input-leap-server | Read-only, via `journalctl --user -u input-leap-server.service --debug INFO -f` | Must stay at `--debug INFO`; `DEBUG` floods ~4487 lines/min and would overwhelm the watcher |
| AeroSpace (Mac) | Keybinds shell out to `ilhop-jump-mac` / `ilhop-focus-jump-mac` | Mac never drives the hop locally — input-leap ignores synthetic pointer events there; everything routes back over ssh |
| ssh / Tailscale | `ControlMaster auto` + `ControlPersist` (long, e.g. `1d`) + `ServerAliveInterval` to survive brief link blips | The trust boundary for all cross-machine dispatch; do not bypass it for raw sockets on the tailnet |
| systemd --user | Hosts `ilhop-side-watch` (long-lived) and the detached self-check (transient, via `systemd-run`) | Two different systemd relationships: one durable service, one fire-and-forget scope per hop |
| launchd (Mac) | Keeps the ssh ControlMaster warm proactively | The macOS analogue of the systemd-run detach — same "let the OS supervise the persistent piece" principle |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `ilhop-jump` ↔ `lib/backend-*.sh` | Direct shell function call after one-time `source` | Zero fork overhead — required for the hot path |
| `ilhop-jump` ↔ `ilhop-side-watch` | Shared file in `$XDG_RUNTIME_DIR`, no direct IPC | Single writer, multiple readers; correct for low-frequency, poll-on-demand access |
| `ilhop-jump` ↔ self-check child | Process spawn only, no return channel | Fire-and-forget by design — the child notifies the user directly (desktop notification) rather than reporting back |
| `ilhop-jump-mac` ↔ `ilhop-jump` (Linux) | ssh exec over the warm ControlMaster channel | Candidate for a persistent-coproc upgrade (see below) to cut the remaining 40-110ms floor |
| `ilhop-heldmods` (C) ↔ shell scripts | Invoked as a subprocess, communicates via exit status / stdout only | Deliberately excludes ydotool's own virtual input device from its `EVIOCGKEY` read — a real, load-bearing detail, not incidental |

### Cross-Machine Dispatch: Options Considered

| Option | Warm latency (approx.) | Security posture | Verdict |
|--------|------------------------|-------------------|---------|
| ssh + ControlMaster/ControlPersist (current) | ~40-110ms per report; ~1.6s cold | Full ssh auth + encryption — the gold standard here | **Keep.** Fix the cold case first: push `ControlPersist` much longer (e.g. `1d`) plus `ServerAliveInterval`/`ServerAliveCountMax` so the master survives brief Tailscale blips instead of expiring, and/or have launchd proactively refresh it (already partly done) |
| ssh, persistent remote coprocess over one already-open channel (write/read a pipe instead of exec-per-call) | Unverified, likely single-digit-to-low-double-digit ms (LOW confidence — bench before trusting) | Same as above — still ssh-authenticated, just reusing one channel instead of opening a new one per call | **Worth prototyping** if (1) doesn't get the warm case low enough. Same shape as `tmux -CC` control mode over ssh, or Eternal Terminal's "authenticate once, then talk continuously." Needs explicit, non-silent fallback to plain one-shot ssh if the pipe breaks. |
| unix-socket forwarded via `ssh -L` (socket-to-socket) | Similar to the coproc option, more structured framing | Same ssh trust boundary, more mechanism (you write and supervise a listener) | Only pursue if the coproc's line-based pipe proves too fragile in practice |
| Bare TCP/unix listener directly on the tailscale interface, no ssh | Lowest possible floor, unmeasured | **Rejects ssh's per-command authentication** — degrades to Tailscale-node-level trust only, the rexec/rlogin failure mode | **Do not build**, unless it adds its own per-message signing — at which point it has reinvented most of what ssh gives for free |
| mosh | N/A | N/A | **Not applicable** — designed for interactive terminals over lossy/roaming links with predictive echo; explicitly does not support non-interactive/scripted use or port forwarding, and still needs ssh to bootstrap |
| New HTTP/gRPC/MQ listener | N/A | New runtime dependency | **Rejected by the tech-stack constraint** ("no runtime beyond ydotool, systemd --user, and ssh") |

## Sources

- xdg-open / xdg-utils source (`detectDE`, case-dispatch pattern) — https://github.com/moljac024/scripts/blob/master/xdg-open , https://chromium.googlesource.com/chromium/deps/xdg-utils/+/ab7ff01695bb56426dd4405d5acf415a9059cd6a/scripts/xdg-open — MEDIUM (long-stable shipped tool, structure cross-checked across mirrors)
- Homebrew Linux/macOS abstraction (`OS.mac?`/`OS.linux?`, shared formula code) — https://docs.brew.sh/Homebrew-on-Linux , https://github.com/orgs/Homebrew/discussions/2631 — MEDIUM
- asdf plugin architecture (`bin/install`, `bin/list-all` convention) — https://asdf-vm.com/plugins/create.html , https://github.com/asdf-vm/asdf/blob/master/docs/plugins/create.md — MEDIUM (official docs)
- systemd user-unit search path and `~/.config` vs `~/.local/share` precedence, `PartOf=`/`After=graphical-session.target` convention — https://wiki.archlinux.org/title/Systemd/User , sway/niri systemd-integration examples: https://github.com/swaywm/sway/wiki/Systemd-integration , https://niri-wm.github.io/niri/Example-systemd-Setup.html — HIGH (official/ArchWiki, cross-checked against multiple compositor projects using the identical convention)
- `$XDG_RUNTIME_DIR` lifetime, lingering, `user@.service` persistence — https://wiki.archlinux.org/title/Systemd/User , systemd upstream issue discussion https://github.com/systemd/systemd/issues/40604 — HIGH (cross-checked, matches XDG Base Directory spec semantics)
- udev long-running-task guidance (detach via systemd-run rather than backgrounding) — https://man7.org/linux/man-pages/man8/systemd-udevd.8.html , https://wiki.archlinux.org/title/Udev — HIGH (man page + ArchWiki agree)
- ssh `ControlMaster`/`ControlPersist` multiplexing mechanics and latency profile — https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing , https://www.cyberciti.biz/faq/linux-unix-reuse-openssh-connection/ — MEDIUM-HIGH (widely documented, consistent across sources)
- mosh design scope (interactive-only, no scripted/port-forward use, ssh-bootstrapped) — https://mosh.org/mosh-paper.pdf , ArchWiki https://wiki.archlinux.org/title/Mosh — HIGH (primary paper + wiki agree)
- `flock(1)` single-flight idiom (`exec 9>lockfile; flock -n 9 || exit`) — standard flock(1) manual page usage pattern — HIGH (canonical, stable Unix convention)
- git subcommand / kubectl-plugin / docker-machine-driver naming-convention dispatch — general, well-known convention across these three shipped tools — MEDIUM (not independently re-verified this session, but stable and widely documented public convention)

---
*Architecture research for: keyboard-driven cross-machine screen switching (software KVM) on Wayland, POSIX shell + C helper*
*Researched: 2026-09-10*
