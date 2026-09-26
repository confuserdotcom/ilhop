#!/bin/sh
# Install or remove ilhop on this machine. uname picks the side: Linux gets
# the server side (Hyprland + input-leap server), macOS the client side
# (AeroSpace + input-leap client). Run it once on each machine.
#
#   ./install.sh               install (copies files into ~/.local/bin)
#   ./install.sh --link        install as symlinks into this checkout
#   ./install.sh --uninstall   remove everything install.sh put here
#
# Settings go to ~/.config/ilhop/config on first install, from these (or
# their defaults):
#   ILHOP_MAC_HOST=mac      Linux: ssh alias that reaches the Mac
#   ILHOP_LINUX_HOST=ryuk   macOS: ssh alias that reaches the Linux machine
#   ILHOP_SCREEN=$(uname -n) Linux: input-leap server's screen name (--name)
#   ILHOP_WM=<detected>      Linux: window-manager adapter (see bin/il-wm)
#   ILHOP_MAC_SIDE=<detected> both: side of the Linux screen the Mac is on
#                            (left/right; Linux reads it from server.conf)
#   ILHOP_MAC_WM=<detected>  macOS: aerospace, yabai or none
#
# Everything created is listed in ~/.local/share/ilhop/manifest, and every
# line added to your own config files ends in an `ilhop` marker comment, so
# --uninstall removes exactly what was added and nothing else.

set -u

REPO=$(cd "$(dirname "$0")" && pwd -P)
BIN="$HOME/.local/bin"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ilhop"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/ilhop"
MANIFEST="$DATA/manifest"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
OS=$(uname -s)
link=no

say()  { printf 'ilhop: %s\n' "$*"; }
warn() { printf 'ilhop: WARNING: %s\n' "$*" >&2; }
record() { printf '%s %s\n' "$1" "$2" >> "$MANIFEST"; }
have() { command -v "$1" >/dev/null 2>&1; }

put() { # $1 = source relative to the repo, $2 = destination
    [ -e "$2" ] || [ -L "$2" ] && say "replacing $2"
    rm -f "$2"
    if [ "$link" = yes ]; then ln -s "$REPO/$1" "$2"; else cp "$REPO/$1" "$2"; fi
    record file "$2"
}

# Appends/inserts a marked line unless a line matching $3 is already there.
# $1 = file, $2 = line (marker included), $3 = grep -E pattern for "already bound"
# $4 = awk condition for the line to insert AFTER ("" = append at the end,
#      "before-table" = before the first [table] header)
add_line() {
    grep -qE "$3" "$1" 2>/dev/null && { say "$(basename "$1"): already set, left alone"; return 0; }
    tmp="$1.ilhop.tmp"
    case "$4" in
        '') cat "$1" > "$tmp"; printf '%s\n' "$2" >> "$tmp" ;;
        before-table) awk -v l="$2" '!d && /^\[/ { print l; d = 1 } { print } END { if (!d) print l }' "$1" > "$tmp" ;;
        *) awk -v l="$2" -v p="$4" '{ print } !d && index($0, p) == 1 { print l; d = 1 }' "$1" > "$tmp" ;;
    esac
    cat "$tmp" > "$1"; rm -f "$tmp"
    record line "$1"
    say "$(basename "$1"): added $(printf '%s' "$2" | cut -c1-60)..."
}

write_config() {
    [ -e "$CFG/config" ] && { say "keeping existing $CFG/config"; return; }
    mkdir -p "$CFG"
    { echo "# ilhop settings - see install.sh for what each one means."
      for kv in "$@"; do echo "$kv"; done; } > "$CFG/config"
    record file "$CFG/config"
    say "wrote $CFG/config:"; sed 's/^/    /' "$CFG/config"
}

install_linux() {
    for c in hyprctl jq ydotool ydotoold input-leaps ssh flock cc systemctl; do
        have "$c" || warn "'$c' not found - install it first (see README)"
    done
    for f in "$REPO"/bin/*; do put "bin/${f##*/}" "$BIN/${f##*/}"; done
    if have cc && cc -O2 -o "$BIN/il-heldmods" "$REPO/src/il-heldmods.c"; then
        record file "$BIN/il-heldmods"
    else
        warn "could not build il-heldmods - doctor and reset lose the held-modifier check"
    fi

    hypr="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
    if [ -z "${ILHOP_WM:-}" ]; then
        if [ -f "$hypr/hyprland.lua" ]; then ILHOP_WM=hyprland-lua; else ILHOP_WM=hyprland; fi
    fi
    # The Mac's side is whichever link server.conf gives this screen.
    screen="${ILHOP_SCREEN:-$(uname -n)}"
    [ -n "${ILHOP_MAC_SIDE:-}" ] || ILHOP_MAC_SIDE=$(awk -v me="$screen:" '
        /^section: *links/ { l = 1; next } l && /^end/ { l = 0 }
        l { if ($1 == me) { m = 1; next } if ($1 ~ /:$/) m = 0
            if (m && ($1 == "left" || $1 == "right")) { print $1; exit } }' \
        "$HOME/.config/InputLeap/server.conf" 2>/dev/null)
    [ -n "$ILHOP_MAC_SIDE" ] || { ILHOP_MAC_SIDE=left; warn "no link for '$screen' in server.conf - assuming the Mac is on the left"; }
    write_config "ILHOP_MAC_HOST=${ILHOP_MAC_HOST:-mac}" "ILHOP_SCREEN=$screen" "ILHOP_WM=$ILHOP_WM" "ILHOP_MAC_SIDE=$ILHOP_MAC_SIDE"

    mkdir -p "$UNITS"
    put systemd/il-side-watch.service "$UNITS/il-side-watch.service"
    units=il-side-watch.service
    if systemctl --user cat ydotoold.service >/dev/null 2>&1 && ! grep -qx "file $UNITS/ydotoold.service" "$MANIFEST" 2>/dev/null; then
        say "using your existing ydotoold.service"
    else
        put systemd/ydotoold.service "$UNITS/ydotoold.service"
        units="ydotoold.service $units"
    fi
    systemctl --user daemon-reload
    for u in $units; do
        systemctl --user enable --now "$u" >/dev/null 2>&1 && record unit "$u" || warn "could not start $u"
    done

    # ALT+C, in the syntax of the config Hyprland is running. Lua: Ryoku keeps
    # hand edits in user.lua, plain Hyprland in hyprland.lua itself.
    if hyprctl binds -j 2>/dev/null | jq -e 'any(.[]; (.key|ascii_downcase)=="c" and .modmask==8)' >/dev/null 2>&1; then
        say "ALT+C is already bound, left alone (make sure it runs: ilhop toggle)"
    else
        case "$ILHOP_WM" in
            hyprland-lua)
                f="$hypr/user.lua"; [ -f "$f" ] || f="$hypr/hyprland.lua"
                line='hl.bind("ALT + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/ilhop toggle")) -- ilhop' ;;
            hyprland)
                f="$hypr/hyprland.conf"
                line="bind = ALT, C, exec, $BIN/ilhop toggle # ilhop" ;;
        esac
        if [ -f "$f" ]; then
            add_line "$f" "$line" 'ilhop toggle' ''
            hyprctl reload >/dev/null 2>&1
        else
            warn "no $f - bind ALT+C to '$BIN/ilhop toggle' yourself"
        fi
    fi

    ssh -o BatchMode=yes -o ConnectTimeout=5 "${ILHOP_MAC_HOST:-mac}" true 2>/dev/null \
        || warn "cannot ssh to '${ILHOP_MAC_HOST:-mac}' without a password yet (see README: ssh)"
}

install_mac() {
    PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
    if [ -z "${ILHOP_MAC_WM:-}" ]; then
        if have aerospace; then ILHOP_MAC_WM=aerospace; elif have yabai; then ILHOP_MAC_WM=yabai; else ILHOP_MAC_WM=none; fi
    fi
    say "window manager: $ILHOP_MAC_WM"
    for c in nc osascript ssh; do have "$c" || warn "'$c' not found - install it first (see README)"; done
    for f in il-jump-mac il-aim-mac il-hop-pipe il-mac-wm; do put "mac/$f" "$BIN/$f"; done

    write_config "ILHOP_LINUX_HOST=${ILHOP_LINUX_HOST:-ryuk}" "ILHOP_MAC_SIDE=${ILHOP_MAC_SIDE:-left}" "ILHOP_MAC_WM=$ILHOP_MAC_WM"

    agents="$HOME/Library/LaunchAgents"
    mkdir -p "$agents"
    load_agent() { # $1 = label; mac/$1.plist is the template
        sed "s#@BIN@#$BIN#" "$REPO/mac/$1.plist" > "$agents/$1.plist"
        record file "$agents/$1.plist"
        launchctl bootout "gui/$(id -u)/$1" 2>/dev/null
        launchctl bootstrap "gui/$(id -u)" "$agents/$1.plist" && record agent "$1" || warn "could not load $agents/$1.plist"
    }
    load_agent ilhop.hop-pipe

    if [ "$ILHOP_MAC_WM" = aerospace ]; then
        toml="$HOME/.config/aerospace/aerospace.toml"
        [ -f "$toml" ] || toml="$HOME/.aerospace.toml"
        if [ -f "$toml" ]; then
            grep -qE '^alt-c *=' "$toml" && ! grep -qE '^alt-c *=.*il-jump-mac' "$toml" \
                && warn "alt-c is already bound to something else in $toml - rebind it to 'exec-and-forget $BIN/il-jump-mac'"
            add_line "$toml" "alt-c = 'exec-and-forget $BIN/il-jump-mac' # ilhop" '^alt-c *=' '[mode.main.binding]'
            grep -qE '^on-focus-changed *=' "$toml" && ! grep -q il-aim-mac "$toml" \
                && warn "you already have on-focus-changed in $toml - add 'exec-and-forget $BIN/il-aim-mac' to it"
            add_line "$toml" "on-focus-changed = ['exec-and-forget $BIN/il-aim-mac'] # ilhop" '^on-focus-changed *=' before-table
            aerospace reload-config >/dev/null 2>&1
        else
            warn "no aerospace.toml found - bind alt-c to 'exec-and-forget $BIN/il-jump-mac' yourself"
        fi
        return
    fi

    # No AeroSpace: ALT+C comes from a small helper using the macOS hotkey API.
    if have cc && cc -O2 -o "$BIN/il-hotkey-mac" "$REPO/mac/il-hotkey-mac.c" -framework Carbon 2>/dev/null; then
        record file "$BIN/il-hotkey-mac"
        load_agent ilhop.hotkey
    else
        warn "could not build il-hotkey-mac (run: xcode-select --install) - bind ALT+C to $BIN/il-jump-mac yourself"
    fi

    if [ "$ILHOP_MAC_WM" = yabai ]; then
        rc="$HOME/.yabairc"; [ -f "$rc" ] || rc="$HOME/.config/yabai/yabairc"
        if [ -f "$rc" ]; then
            add_line "$rc" "yabai -m signal --add event=window_focused action='$BIN/il-aim-mac' label=ilhop # ilhop" 'il-aim-mac' ''
            yabai -m signal --add event=window_focused action="$BIN/il-aim-mac" label=ilhop 2>/dev/null
        else
            warn "no yabairc - the landing aim only refreshes when you press ALT+C on the Mac"
        fi
    fi
}

uninstall() {
    [ -r "$MANIFEST" ] || { say "nothing to remove (no $MANIFEST)"; exit 0; }
    sort -u "$MANIFEST" | while read -r kind what; do
        case "$kind" in
            unit)  systemctl --user disable --now "$what" >/dev/null 2>&1 ;;
            agent) launchctl bootout "gui/$(id -u)/$what" 2>/dev/null ;;
        esac
    done
    sort -u "$MANIFEST" | while read -r kind what; do
        case "$kind" in
            file) rm -f "$what" ;;
            line) grep -vE ' (#|--) ilhop$' "$what" > "$what.ilhop.tmp"; cat "$what.ilhop.tmp" > "$what"; rm -f "$what.ilhop.tmp" ;;
        esac
    done
    rm -f "$MANIFEST"; rmdir "$DATA" "$CFG" 2>/dev/null
    if [ "$OS" = Darwin ]; then
        rm -f "$HOME/.local/state/il-hop.sock" "$HOME/.local/state/il-hop.sock.in"
        PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
        aerospace reload-config >/dev/null 2>&1
        yabai -m signal --remove ilhop >/dev/null 2>&1
    else
        systemctl --user daemon-reload
        rm -f "$RUN"/il-* "$RUN"/ilhop-*
        hyprctl reload >/dev/null 2>&1
    fi

    # Proof, not a promise (PKG-02): look for anything ilhop-shaped left.
    left=$(ls -d "$BIN"/il-* "$BIN"/ilhop "$CFG" "$DATA" "$UNITS"/il-side-watch.service \
                 "$HOME/Library/LaunchAgents/ilhop.hop-pipe.plist" "$HOME/Library/LaunchAgents/ilhop.hotkey.plist" 2>/dev/null
           grep -lE ' (#|--) ilhop$' "$HOME/.config/hypr/user.lua" "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml" "$HOME/.yabairc" "$HOME/.config/yabai/yabairc" 2>/dev/null)
    if [ -n "$left" ]; then
        warn "left behind (not installed by this script, or failed to remove):"; printf '    %s\n' $left
        exit 1
    fi
    say "uninstalled - no trace left"
}

for a in "$@"; do
    case "$a" in
        --link) link=yes ;;
        --uninstall) uninstall; exit ;;
        -h|--help) sed -n '2,19s/^# \{0,1\}//p' "$0"; exit 0 ;;
        *) echo "usage: install.sh [--link | --uninstall]" >&2; exit 2 ;;
    esac
done

mkdir -p "$BIN" "$DATA"
case "$OS" in
    Linux)  install_linux ;;
    Darwin) install_mac ;;
    *) echo "ilhop: unsupported OS '$OS' (Linux + macOS only)" >&2; exit 1 ;;
esac
sort -u "$MANIFEST" -o "$MANIFEST"
say "installed. Check it with: ilhop doctor"
