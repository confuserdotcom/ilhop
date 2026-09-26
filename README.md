# ilhop

One key moves your pointer and keyboard between a Linux machine and a Mac
shared with [input-leap](https://github.com/input-leap/input-leap), in both
directions. On Wayland, input-leap's own keyboard screen-switching does not
work at all; ilhop replaces it with a hop that takes ~25ms.

- **ALT+C** on either machine hops to the other one.
- The pointer lands in the middle of the window nearest the edge it crossed,
  and that window gets keyboard focus, so you can type straight away.

## What it runs on

This is the one tested combination. Anything else is untested and probably
will not work without changes.

| | Linux (input-leap **server**) | Mac (input-leap **client**) |
|---|---|---|
| Window manager | Hyprland with Lua dispatch (`hl.dsp.*`, the Ryoku fork) | [AeroSpace](https://github.com/nikitabobko/AeroSpace) |
| input-leap | `input-leaps --use-ei` as a systemd user service named `input-leap-server`, at `--debug INFO` | `input-leapc` connected to it |
| Tools | `ydotool`, `jq`, `ssh`, `flock`, a C compiler, systemd | `nc`, `osascript` (both ship with macOS) |

The Mac must be the **left** neighbour of the Linux screen in `server.conf`:

```
section: links
    <linux-screen>:
        left = <mac-screen>
    <mac-screen>:
        right = <linux-screen>
end
```

Keep `input-leap-server` at `--debug INFO`: ilhop follows its journal to know
which machine has the pointer, and `DEBUG` floods it.

## Before installing: ssh both ways

The two machines talk over ssh with keys, never passwords:

- **Linux → Mac** under an alias (default `mac`). Turn on *Remote Login* on the Mac.
- **Mac → Linux** under an alias (default `ryuk`). The Mac holds this session
  open so a hop from the Mac costs ~10ms instead of a fresh ssh.

Check both work without a prompt: `ssh -o BatchMode=yes mac true` on Linux,
`ssh -o BatchMode=yes ryuk true` on the Mac.

Your Linux user must be able to write `/dev/uinput`, which usually means
being in the `input` group. `ilhop doctor` says exactly what is wrong if not.

## Install

Clone this repo on **both** machines and run the installer on each:

```sh
git clone <this repo> ilhop && cd ilhop
ILHOP_MAC_HOST=mac ./install.sh      # on Linux: the alias that reaches the Mac
ILHOP_LINUX_HOST=ryuk ./install.sh   # on the Mac: the alias that reaches Linux
```

The installer:

- **Linux:** copies the commands to `~/.local/bin`, builds `il-heldmods`,
  installs and starts `il-side-watch.service` (and `ydotoold.service` if you
  do not already have one), and binds ALT+C in `~/.config/hypr/user.lua`
  unless ALT+C is already bound.
- **Mac:** copies three scripts to `~/.local/bin`, loads the `ilhop.hop-pipe`
  launchd agent, and adds `alt-c` and `on-focus-changed` to `aerospace.toml`
  (it leaves either alone if you already set it, and tells you what to add).
- **Both:** writes the settings to `~/.config/ilhop/config`. Edit it later
  if an alias or the screen name changes.

`./install.sh --link` symlinks instead of copying, for working on ilhop itself.

## Use

| Command | What it does |
|---|---|
| `ilhop` / `ilhop toggle` | Hop to the other machine (what ALT+C runs on Linux) |
| `ilhop left` / `ilhop right` | Hop to the Mac / back to Linux |
| `ilhop doctor` | Check every moving part, with the fix for each failure |
| `ilhop doctor --test` | Also do a real round trip and time it |
| `ilhop reset` | Panic button: release every modifier, restart the input services, bring the pointer home |
| `ilhop help` | List every command |

If your keyboard is stuck, run `ilhop reset` over ssh from the Mac:
`ssh ryuk ilhop reset`. It releases every modifier whether or not it thinks
one is held, and it waits for any hop in flight rather than interleaving
with it.

The old `il-*` command names still work.

## Uninstall

On each machine, from the clone:

```sh
./install.sh --uninstall
```

It removes every file, unit, launchd agent and config line the installer
added, then checks for leftovers and prints `no trace left` or lists what
remains. Lines you wrote yourself are never touched: the installer marks its
own with an `ilhop` comment.

## Known limits

- **A modifier held across a hop needs a patched input-leap.** Stock
  input-leap drops it: hold ALT through the hop, press `1` on the Mac, and
  nothing happens until you release and re-press ALT. `upstream/input-leap/`
  has the fix as an Arch package (`cd upstream/input-leap && makepkg -si
  --nocheck`, then `systemctl --user restart input-leap-server`). The next
  stock input-leap update replaces it; `ilhop doctor` warns when that happens.
- **The Mac landing aims only horizontally.** Moving the pointer vertically
  would sweep through the Mac's hot corners. With two windows stacked on the
  right-hand side of the Mac, the pointer may land in the one that does not
  have focus.
- **The landing spot is worked out when you last left a machine.** If a window
  moves or closes while you are on the other side, the next hop can land on
  empty space. On the Mac, AeroSpace refreshes it on every focus change.
- **Right after sleep or a network change**, the Mac's fast connection takes
  a second or two to come back. ALT+C on the Mac still works in that window;
  it just goes over a slower fresh ssh.
- One monitor per machine, and the Mac always on the left.
