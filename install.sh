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

    write_config "ILHOP_MAC_HOST=${ILHOP_MAC_HOST:-mac}" "ILHOP_SCREEN=${ILHOP_SCREEN:-$(uname -n)}"

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

    # ALT+C. Ryoku's Hyprland reads hl.bind() from ~/.config/hypr/user.lua.
    if hyprctl binds -j 2>/dev/null | jq -e 'any(.[]; (.key|ascii_downcase)=="c" and .modmask==8)' >/dev/null 2>&1; then
        say "ALT+C is already bound, left alone (make sure it runs: ilhop toggle)"
    elif [ -f "$HOME/.config/hypr/user.lua" ]; then
        add_line "$HOME/.config/hypr/user.lua" \
            'hl.bind("ALT + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/ilhop toggle")) -- ilhop' \
            'ilhop toggle' ''
        hyprctl reload >/dev/null 2>&1
    else
        warn "no ~/.config/hypr/user.lua - bind ALT+C to '$BIN/ilhop toggle' yourself"
    fi

    ssh -o BatchMode=yes -o ConnectTimeout=5 "${ILHOP_MAC_HOST:-mac}" true 2>/dev/null \
        || warn "cannot ssh to '${ILHOP_MAC_HOST:-mac}' without a password yet (see README: ssh)"
}

install_mac() {
    for c in aerospace nc osascript ssh; do have "$c" || warn "'$c' not found - install it first (see README)"; done
    for f in il-jump-mac il-aim-mac il-hop-pipe; do put "mac/$f" "$BIN/$f"; done

    write_config "ILHOP_LINUX_HOST=${ILHOP_LINUX_HOST:-ryuk}"

    agent="$HOME/Library/LaunchAgents/ilhop.hop-pipe.plist"
    mkdir -p "${agent%/*}"
    sed "s#@BIN@#$BIN#" "$REPO/mac/ilhop.hop-pipe.plist" > "$agent"
    record file "$agent"
    launchctl bootout "gui/$(id -u)/ilhop.hop-pipe" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "$agent" && record agent ilhop.hop-pipe || warn "could not load $agent"

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
        aerospace reload-config >/dev/null 2>&1
    else
        systemctl --user daemon-reload
        rm -f "$RUN"/il-* "$RUN"/ilhop-*
        hyprctl reload >/dev/null 2>&1
    fi

    # Proof, not a promise (PKG-02): look for anything ilhop-shaped left.
    left=$(ls -d "$BIN"/il-* "$BIN"/ilhop "$CFG" "$DATA" "$UNITS"/il-side-watch.service \
                 "$HOME/Library/LaunchAgents/ilhop.hop-pipe.plist" 2>/dev/null
           grep -lE ' (#|--) ilhop$' "$HOME/.config/hypr/user.lua" "$HOME/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml" 2>/dev/null)
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
