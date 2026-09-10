# Phase 1: Regression Recovery - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 3 (1 modified script, 1 modified script, 1 new harness script)
**Analogs found:** 3 / 3

**Tracked-source note:** these files live loose under `~/.local/bin/` and
`~/.local/share/ryoku/rashin/` but ARE git-tracked, in the bare repo
`~/.dotfiles` (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`), work-tree
`$HOME`. Verified this session: `git ls-tree -r HEAD --name-only` lists
`.local/bin/il-jump`, `.local/bin/il-doctor`, `.local/bin/il-side-watch`,
`.local/bin/il-reset`, `.local/bin/il-focus-jump`, `.local/src/il-heldmods.c`,
and `.config/systemd/user/il-side-watch.service`. All analog paths below are
absolute `$HOME`-relative paths on disk (`~/.local/bin/...`), which are the
tracked work-tree paths themselves — not a gitignored mirror. There is no
`ilhop` repo copy of this code; `/home/nastralis/Projects/ilhop` holds only
`.planning/`. Do not invent a repo-relative path for these files.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `~/.local/bin/il-jump` (MODIFIED — add `ILHOP_DEBUG` logging at 4 exit paths) | utility/controller (input-dispatch script) | event-driven, request-response | itself (same file; extend existing style) — secondary analog `~/.local/bin/il-doctor` for the `pass`/`fail`/timestamp idiom | exact (self) |
| new reproduction-harness script (e.g. `~/.local/bin/il-jump-harness` or similar, TBD by planner) | test/diagnostic script | batch, CRUD (state injection + assertion) | `~/.local/bin/il-doctor` | exact — same role (standalone POSIX-shell health/diagnostic driver), same flow shape (state setup → invoke → assert → report pass/fail counts) |
| `~/.local/bin/il-doctor` (MODIFIED — replace circular landing check at `:110`) | utility/diagnostic script | request-response (health check) | itself (same file; `il-jump`'s `landed()` helper is the pattern for a non-circular retry-with-timeout oracle) | exact (self) |

## Pattern Assignments

### `~/.local/bin/il-jump` (MODIFIED — add `ILHOP_DEBUG=1`-gated logging)

**Analog:** itself, plus `il-doctor`'s pass/fail idiom for line format inspiration.

**Shell strictness header** (`il-jump:38`):
```sh
set -u
```
Note: NOT `set -uo pipefail` here — `il-jump` uses only `set -u` (unlike
CLAUDE.md's generic "mandatory `set -uo pipefail`" claim; this specific script
diverges and any new logging code must not assume `pipefail` semantics or `-e`
abort-on-error. Match `il-jump`'s own convention, not the general one.)

**Path/state var block** (`il-jump:40-44`):
```sh
RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RUN/il-side"          # written by il-side-watch.service
LOCK="$RUN/il-jump.lock"
WCACHE="$RUN/il-mac-width"
YSOCK="$RUN/.ydotool_socket"
```
The new debug-log path (D-12: "a log file under `$XDG_RUNTIME_DIR`, alongside
`il-side`") belongs in this same block, e.g. `DBGLOG="$RUN/ilhop-debug.log"`.

**note()/die() helper pattern** (`il-jump:46-47`) — the existing model for a
tiny wrapper function used at every call site instead of repeating a guard
inline:
```sh
note() { notify-send -a il-jump "il-jump" "$1" 2>/dev/null || true; }
die()  { note "$1"; echo "il-jump: $1" >&2; exit 1; }
```
The new `dbg()` function should follow this exact shape — one-liner, defined
near the top alongside `note`/`die`, called at each of the four silent exit
sites. Per RESEARCH.md Q5, it must be:
```sh
dbg() { [ -n "${ILHOP_DEBUG:-}" ] && printf '%s %s\n' "$(date +%s%3N)" "$1" >> "$DBGLOG" 2>/dev/null; }
```
— one single `printf` per call (POSIX write-atomicity, per Q5), `>>` append
never `>` truncate, gated by a single `[ -n "${ILHOP_DEBUG:-}" ]` check so the
default (unset) path costs nothing, guarded against `set -u` aborting on an
unset var via `${ILHOP_DEBUG:-}` expansion. Wall-clock timestamp required
(`date +%s%3N`, matching the existing `t0=$(date +%s%3N)` idiom already used in
`il-doctor:109/111`) so absence-of-a-line is itself diagnostic (RESEARCH.md Q4).

**The four exit-path call sites, exact locations to instrument:**
1. `il-jump:54` — `flock -n 9 || exit 0` → becomes `flock -n 9 || { dbg "stale-lock: another jump in flight"; exit 0; }`
2. `il-jump:91` — `[ "$CUR" = "$want" ] && exit 0` → becomes `[ "$CUR" = "$want" ] && { dbg "already-on-side: CUR=$CUR want=$want"; exit 0; }`
3. `il-jump:168` (current numbering, inside the detached block) — `[ "$(cat "$SEQ" 2>/dev/null)" = "$myseq" ] || exit 0` → append `dbg "superseded: a newer jump owns SEQ"` before the exit
4. `il-jump:169` — `read_side; [ "$CUR" = unknown ] && exit 0` → append `dbg "watcher-unknown: CUR=unknown, cannot judge"` before the exit

**Detached-subshell lock-fd discipline — the load-bearing existing pattern to
preserve** (`il-jump:164-165`):
```sh
(
    exec 9>&-                        # do not hold the single-flight lock
    landed 12 && exit 0              # ~1.2s; the side file flips after ~450ms
    ...
```
Any `dbg` calls added inside this detached block are safe as-is (they run
after `exec 9>&-` already released fd 9), but do NOT add a *new* detached
block for logging — the two exit paths inside this subshell (`:168`,`:169`)
already run post-`exec 9>&-`; just add the `dbg` line inline before their
`exit 0`. Per RESEARCH.md Pitfall 4, if the planner ever needs a third
detached block (e.g. for D-15 measurement work — out of this phase's four
call sites but adjacent), it MUST open with the identical `exec 9>&-` first.

**Error handling pattern** — this script has none in the try/catch sense;
POSIX shell error handling here is `cmd || fallback` and explicit `die()`.
Follow that, not a language-level exception idiom.

---

### New reproduction-harness script (Wave 0 deliverable)

**Analog:** `~/.local/bin/il-doctor` (full file, 117 lines, read this session).

**Imports/header pattern** (`il-doctor:1-14`):
```sh
#!/bin/sh
# Health check for the two-machine input-leap setup.
#
#   il-doctor           inspect everything, change nothing
#   il-doctor --test    also do a real round trip (Nastralis -> Mac -> back)
#
# Written so that when the screen hop misbehaves there is one thing to run
# instead of remembering where all the moving parts live.

RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
ok=0; bad=0
pass() { printf '  \033[32mok\033[0m    %s\n' "$1"; ok=$((ok+1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; bad=$((bad+1)); }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
head() { printf '\n\033[1m%s\033[0m\n' "$1"; }
```
No `set -u`/`set -e` at all in `il-doctor` — it deliberately tolerates
individual command failures inline (`2>/dev/null`, `|| fail ...`) rather than
aborting, because a health check that dies on the first failed probe defeats
its own purpose. The harness should follow this same tolerant style, not
`il-jump`'s `set -u`, since the harness's job is to run every assertion and
report all of them, not stop at the first one.

**The `--test` live-round-trip block is the exact template for Route 1 + Route
3 combined** (`il-doctor:105-113`):
```sh
if [ "${1:-}" = "--test" ]; then
    head "live round trip"
    start=$(cat "$RUN/il-side" 2>/dev/null)
    [ "$start" = mac ] && { "$HOME/.local/bin/il-jump" right >/dev/null 2>&1; sleep 2; }
    t0=$(date +%s%3N); "$HOME/.local/bin/il-jump" toggle >/dev/null 2>&1; t1=$(date +%s%3N); sleep 2
    [ "$(cat "$RUN/il-side")" = mac ] && pass "hop to the Mac: $((t1-t0))ms" || fail "hop to the Mac did not land"
    ...
fi
```
Copy this shape for: (a) Route 3 state injection — `echo mac > "$RUN/il-side"; il-jump left` then assert `zero ydotool calls / immediate exit 0` (per VALIDATION.md task `1-02-01`); (b) Route 1 stressor — loop invoking `il-jump` directly with varying pre-set `$RUN/il-side` values, reading `$DBGLOG` after each iteration for the exit-path line D-11 adds. **Do not** invoke `il-jump` via the keybind (Pitfall 3) — always call the script by path, exactly as `il-doctor:108-111` already does.

**Summary/exit-code convention** (`il-doctor:115-116`):
```sh
printf '\n%s check(s) ok, %s failed\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
```
Reuse verbatim for the harness's final report and exit code, so it composes
the same way `il-doctor --test` does in CI/manual runs.

**Assert-on-absence-of-ydotool-call pattern (new, not in `il-doctor` today):**
No existing script counts `ydotool` invocations. The harness needs a way to
assert "zero ydotool calls happened." Cheapest option matching the codebase's
existing style (no test framework, POSIX-only, per RESEARCH.md Validation
Architecture "None — packaging is Phase 5"): shadow `ydotool` in `$PATH` with
a counting stub for the duration of the harness's invocation of `il-jump`
(e.g. a temp dir prepended to `PATH`, `ydotool` stub appends to a counter
file), OR simpler — rely on `il-jump`'s own new `ILHOP_DEBUG` log line for the
`:91` exit path firing *before* any `shove()` call, so "the debug log shows
`already-on-side` and no `ydotool mousemove` process ever ran" is provable
indirectly via exit code + log content alone, without a stub. Prefer the
log-content approach — it reuses D-11's mechanism rather than adding a new
PATH-shadowing technique with no precedent in this codebase.

**Reading the side file / debug log — reuse `il-jump`'s own idiom**, not a
new one:
```sh
[ -r "$STATE" ] && { read -r CUR < "$STATE" || CUR=unknown; }
```
(`il-jump:75`) — the harness should read `$RUN/il-side` and the new debug log
the same defensive way, since both are tmpfs files another process can be
mid-write to.

---

### `~/.local/bin/il-doctor` (MODIFIED — replace circular landing check at `:110`)

**Analog:** itself — `il-jump`'s `landed()` helper (`il-jump:99-109`) is the
correct non-circular-retry pattern to adapt, since D-16 requires the harness
and `il-doctor` to "share one truth source rather than each inventing their
own," and `il-doctor`'s round trip already has the `t0`/`t1` timing and
`$RUN/il-side` read this replaces.

**The circular check to remove** (`il-doctor:105-113`, specifically the
assertion lines `:110` and `:112`):
```sh
[ "$(cat "$RUN/il-side")" = mac ] && pass "hop to the Mac: $((t1-t0))ms" || fail "hop to the Mac did not land"
...
[ "$(cat "$RUN/il-side")" = nastralis ] && pass "hop back: $((t1-t0))ms" || fail "hop back did not land"
```
These read the exact file `il-side-watch` writes and `il-jump` itself trusts —
D-16's circularity: a stale-but-unchanged `il-side` can make this pass while
the hop actually did nothing.

**Non-circular oracle — pending Wave 0 A1 falsification (RESEARCH.md Q6),**
but the shape to build toward, once `hyprctl cursorpos` is confirmed to
freeze under capture, mirrors `il-jump`'s `landed()` retry-with-timeout loop
(`il-jump:99-109`):
```sh
landed() { # $1 = how many 100ms ticks to wait for the side file to flip
    n=0
    while [ "$n" -lt "$1" ]; do
        read_side
        [ "$CUR" = "$want" ] && return 0
        [ "$CUR" = unknown ] && return 0     # watcher down: cannot judge, assume ok
        sleep 0.1
        n=$((n + 1))
    done
    return 1
}
```
`il-doctor`'s replacement check should poll `hyprctl cursorpos` (via the same
`hypr()`-style wrapper `il-jump` uses at `:111-114` for
`HYPRLAND_INSTANCE_SIGNATURE` resolution under ssh) rather than `$RUN/il-side`,
with the same bounded-retry shape — not a blocking wait for journald (D-15
explicitly forbids the ~450ms wait pattern in the hot path; `il-doctor --test`
is not hot-path, so a bounded poll there is acceptable, but should not
regress to unbounded waiting).

**`hypr()` wrapper — reuse verbatim for any new `hyprctl cursorpos` call in
`il-doctor`** (`il-jump:111-114`):
```sh
hypr() { # works even from an ssh session, which has no instance signature
    HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -1 "$RUN/hypr" 2>/dev/null | head -n1)}" \
        hyprctl "$@" 2>/dev/null
}
```
`il-doctor` does not currently have this wrapper (it calls `hyprctl binds -j`
directly at `:67` without it) — copy it in if the new landing check needs to
run reliably over ssh, matching why `il-jump` needed it in the first place.

---

## Shared Patterns

### `pass`/`fail`/`warn`/`head` reporting idiom
**Source:** `~/.local/bin/il-doctor:12-15`
**Apply to:** the new harness script, and any new assertions added to
`il-doctor` itself for the D-16 landing-check replacement.
```sh
ok=0; bad=0
pass() { printf '  \033[32mok\033[0m    %s\n' "$1"; ok=$((ok+1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; bad=$((bad+1)); }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
head() { printf '\n\033[1m%s\033[0m\n' "$1"; }
```

### Single-flight lock + detached-subshell fd discipline
**Source:** `~/.local/bin/il-jump:52-55` (acquire), `:164-165` (release in child)
**Apply to:** any new code that forks a detached block inside `il-jump`
(none required by this phase's four call sites, since both `:168`/`:169` are
already inside the existing post-`exec 9>&-` block — but binding for the
planner if a future task adds a new detached block).
```sh
exec 9>"$LOCK" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || exit 0
fi
# ... later, inside any new "( ... ) &" block:
(
    exec 9>&-                        # do not hold the single-flight lock
    ...
) >/dev/null 2>&1 &
```

### `$XDG_RUNTIME_DIR` path construction
**Source:** `~/.local/bin/il-jump:40`, `~/.local/bin/il-doctor:10`
**Apply to:** the harness script and the new `$DBGLOG` var in `il-jump`.
```sh
RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
```
Every runtime-dir file (`il-side`, `il-jump.lock`, `il-mac-width`,
`.ydotool_socket`, and the new debug log) is `"$RUN/<name>"` off this one var
— never hardcode `/run/user/...`.

### Defensive tmpfs-file reads
**Source:** `~/.local/bin/il-jump:73-77` (`read_side()`)
**Apply to:** any new code reading `$RUN/il-side` or the new debug log,
including the harness.
```sh
read_side() {
    CUR=unknown
    [ -r "$STATE" ] && { read -r CUR < "$STATE" || CUR=unknown; }
    [ -n "${CUR:-}" ] || CUR=unknown
}
```

### Append-only, single-`printf`-per-line writes to shared tmpfs files
**Source:** RESEARCH.md Q5 (derived from POSIX `PIPE_BUF`/`O_APPEND`
semantics, applied to this codebase's `il-side-watch:19,28-30,35` `printf >
file` convention) — no existing append-mode writer exists yet in this
codebase to cite directly, so this is a new-but-consistent convention.
**Apply to:** the new `dbg()` function in `il-jump`.
```sh
dbg() { [ -n "${ILHOP_DEBUG:-}" ] && printf '%s %s\n' "$(date +%s%3N)" "$1" >> "$DBGLOG" 2>/dev/null; }
```
One `printf` call per line, `>>` never `>`, so concurrent writers (the
synchronous main path and the detached self-check subshell) cannot truncate
each other's history or interleave partial lines.

## No Analog Found

None — all three files in scope have a strong same-file or same-role/same-flow
analog in the existing `il-*` surface; no file needed a RESEARCH.md-only
pattern.

## Metadata

**Analog search scope:** `~/.local/bin/il-*` (il-jump, il-doctor, il-side-watch,
il-reset, il-focus-jump), `~/.local/src/il-heldmods.c`, and the bare-repo
history at `~/.dotfiles` (commits `849b6ac..9d1f129`) for the diff context
establishing which parts of `il-jump`/`il-doctor` are the suspect-window
additions vs. tested-good baseline.
**Files scanned:** `il-jump` (182 lines, read in full), `il-doctor` (117
lines, read in full); `il-side-watch` and the input-leap `Server.cpp` read
only via RESEARCH.md's existing citations (not re-read this session, per the
no-re-read rule — RESEARCH.md already extracted every needed excerpt).
**Pattern extraction date:** 2026-09-10
