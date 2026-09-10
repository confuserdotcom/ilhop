# Stack Research

**Domain:** Packaging and hardening a small POSIX-shell + C input-automation CLI (Linux server side) with an ssh-driven macOS peer adapter
**Researched:** 2026-09-10
**Confidence:** HIGH for versioned facts (pulled directly from GitHub API / package trackers, cross-checked); MEDIUM for synthesized ecosystem claims (WebSearch, cross-checked against a second source); explicitly flagged where LOW/unknown.

This file answers the packaging question, not the "should we migrate" question. Per `PROJECT.md`, staying on input-leap and driving hops from the server via `ydotool` is **settled and closed**. Everything below is about how to ship what already works, not what to replace it with.

## Recommended Stack

### Core Technologies (already chosen, confirmed still correct)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `ydotool` + `ydotoold` | **1.0.4** (last tag 2023-01-30; repo is alive — last merged commit 2025-12-22, 2352★, not archived) | Synthetic pointer/keyboard injection via `/dev/uinput` on the input-leap **server** | It is the only thing on this stack that input-leap's Wayland (`--use-ei`) server backend actually honours as real motion. Everything Mac-side (cliclick, `CGEventPost`) was already tried and rejected in this project. No newer tool removes this dependency today (see Q1/Q2 below). |
| POSIX `sh` + one C helper | n/a | Implementation language | Confirmed correct for the "installs on a stranger's box without a language runtime" constraint. Do not introduce bash-only syntax if you also adopt bats-core for tests (see Q5) — keep scripts POSIX, keep bats/bash-isms confined to the test harness only if you pick bats. |
| `systemd --user` | any systemd ≥ 245 (near-universal on 2026 distros) | `il-side-watch.service`, `ydotool.service` supervision | Standard for per-user daemons since ~2020; both Arch's and (recent) Debian/Fedora's `ydotool` packages already ship a `--user` unit, so this matches upstream convention rather than fighting it. |
| `ssh` (OpenSSH) + a warm `ControlMaster` | OpenSSH ≥ 8.x (ships everywhere) | Mac→Linux return leg | Already the mechanism; the 40–110ms warm / 1.6s cold asymmetry (Active defect #4) is a `ControlPersist`/keepalive tuning problem, not a tooling choice — do not swap transports. |

### Supporting Libraries / Daemons Investigated (verdict: not ready, do not adopt this milestone)

| Candidate | Status as of 2026-09 | Verdict |
|-----------|----------------------|---------|
| `wdotool` (github.com/cushycush/wdotool) | 33★, "early but usable," wlroots backend is the only one smoke-tested; KDE/GNOME backends compile but are untested; no tagged release found | **Do not adopt.** Too immature for a project whose hardest constraint is "no input-path change ships without physical verification" — swapping the injection layer to a 33-star project with no release history reopens exactly the risk this milestone exists to close. Revisit in a future milestone if it reaches a tagged 1.0 and gets real-world Hyprland mileage. |
| `wtype` | Mature, widely packaged, keyboard-only (no mouse) | Not a candidate — `ilhop`'s core mechanism is pointer motion (`mousemove` overshoot), which `wtype` does not do at all. |
| `dotool` | Exists, similar architecture to ydotool (uinput + daemon), smaller community | No functional advantage over `ydotool` for this project; would trade a known-quantity daemon (2352★, active) for a smaller one with no clear upside. Not worth the churn. |
| libei-native injection (bypass `ydotoold`, talk EIS directly) | **Not viable on Hyprland today.** Direct libei injection needs an EIS acceptor; the only one available on Hyprland is behind the compositor's `RemoteDesktop` portal implementation, and that is **unmerged** (see Q2 below, PR #402, open as of 2026-09-05). | Not ready. This is the option that would let you delete `ydotool`/`ydotoold` entirely — track it, don't build against it yet. |

### Development / Packaging Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| ShellCheck | Static analysis for the POSIX shell code | v0.11.0 (2025-08-04) is current. Run in CI on every `.sh`/`il-*` file; catches the class of bug that is otherwise only caught by hands-on keyboard testing. |
| ShellSpec | Automated test harness (see Q5) | v0.28.1 tagged, but repo is not abandoned (commits through 2024-09, last push 2025-11-24, 1396★). Slow-moving because a shell-test DSL doesn't need much churn — not a red flag here. |
| `make` (plain Makefile) + a POSIX `install.sh` | Cross-distro install/uninstall | See Q4 — this is the 2026-idiomatic baseline; AUR PKGBUILD wraps it, it does not replace it. |
| `pandoc` or plain markdown | README/man page | Optional; not required. Do not add a doc-generation toolchain — contradicts the "no runtime beyond ydotool/systemd/ssh" constraint if it leaks into the install path. |

## Installation

```bash
# Arch (official repo, not AUR — ydotool graduated out of AUR already)
sudo pacman -S ydotool          # 1.0.4-2, extra repo, ships /usr/lib/systemd/user/ydotool.service

# Fedora
sudo dnf install ydotool        # 1.0.4-8.fc44 (Rawhide/45/44); 1.0.4-7.fc43 on F43
sudo systemctl enable --now ydotool     # Fedora's unit is documented as a SYSTEM unit, not --user — see pitfall below

# Debian/Ubuntu — READ THIS BEFORE ASSUMING apt JUST WORKS
sudo apt install ydotool         # bookworm/bullseye ship 0.1.8-3 — pre-1.0, ydotoold NOT mandatory, different CLI behavior
# For the 1.0.x line (mandatory ydotoold, the behavior ilhop is built against):
#   trixie main does not carry it — only trixie-backports has 1.0.4-2~bpo13+1
#   forky/sid have 1.0.4-3
sudo apt -t trixie-backports install ydotool   # on Debian trixie
```

`ilhop` itself installs via a plain `make install` / `install.sh` (see Q4) — it should **not** attempt to vendor or build `ydotool` from source. Document the version floor (1.0.x, i.e. the `ydotoold`-mandatory generation) and have `ilhop doctor` check for it explicitly, because the 0.1.8 generation on Debian stable is a real, current trap (confirmed via Debian's package tracker 2026-09-10).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `ydotool`/`ydotoold` (uinput) | `wdotool` (wlr-virtual-pointer/libei) | Once `wdotool` ships a tagged release and has real Hyprland-hours on it, or once Hyprland's `RemoteDesktop` portal (PR #402) merges and a tool built on it exists. Not this milestone. |
| ShellSpec for tests | bats-core | If the team strongly prefers bash-flavored test DSL and is willing to accept bash-only test *harness* code (the SUT can still be POSIX `sh`) — see Q5 for the actual tradeoff, which is about shell coverage and mocking, not popularity. |
| Plain `make install` + AUR PKGBUILD wrapper | A single `curl \| sh` installer | Only if you deliberately want a "one-liner for people who don't read READMEs" onboarding path — this project's own constraint ("stranger can follow README") argues against pipe-to-shell as the primary path; keep it as an optional convenience at most. |
| Stay on input-leap 3.0.3 | deskflow 1.26.0 / continuous | Never for this milestone (closed decision). Kept here only as the Q3 factual record below. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Assuming `ydotool` version parity across distros | Debian stable ships the pre-rewrite 0.1.8 line (no mandatory daemon, different flags); Fedora's default unit is system-scoped, Arch's is `--user`. Treating these as interchangeable is exactly the kind of assumption that produces a silently-broken install for a stranger. | Version-gate in `ilhop doctor`: require ydotool ≥ 1.0.0, check whether `ydotool.service` is a user or system unit before assuming `systemctl --user status ydotool` is meaningful. |
| Relying on `ydotool`'s upstream-shipped systemd unit as-is | Upstream issue #311 (closed, fix in repo but **not** in any tagged release as of 2026-09) shows the shipped unit lacks `RestartSec=`/`ExecStartPre=sleep`, so a daemon that fails at boot rate-limits itself into a dead service — exactly the failure class `ilhop`'s own liveness-probe-and-revive logic already works around at the client layer. | Ship an `ilhop`-owned systemd **override** (`systemctl --user edit ydotool`) rather than patching the vendored unit, so it survives package upgrades. Document this as a known upstream gap, not a bug in `ilhop`. |
| Building against libportal's `GlobalShortcuts` portal to fix input-leap's own hotkeys | Out of scope per PROJECT.md, but factually: `GlobalShortcuts` has existed on Hyprland since `xdg-desktop-portal-hyprland` v0.2.0 (Hyprland ≈0.24.1 era, long-shipped) — input-leap simply doesn't call it from the `EiScreen`/Wayland backend. That's an input-leap code gap, not a missing portal, and re-litigating it is explicitly closed. | N/A — this is context only, confirming the closed decision was correctly reasoned, not overturning it. |
| `wdotool`, `dotool`, or any uinput-bypass tool, this milestone | Immature (wdotool) or offers no measurable advantage (dotool) against the project's actual bottleneck, which is bugs + packaging, not the injection layer | Keep `ydotool`. Revisit only if Hyprland's `RemoteDesktop` portal (PR #402) merges *and* input-leap itself grows a libei-injection path — that is a v2/v3-scale rebuild, not a packaging task. |
| AUR-only distribution | AUR doesn't reach Fedora/Debian users, and the project explicitly targets "a stranger" generically, not just Arch | `make install`/`install.sh` as the portable core; AUR `PKGBUILD` as a thin, optional wrapper for Arch convenience (see Q4). |

## Stack Patterns by Variant

**If packaging for Arch specifically (in addition to the generic installer):**
- Ship a `PKGBUILD` that calls the same `make install` targets the generic installer uses — don't duplicate install logic in `package()`.
- Systemd user units go to `/usr/lib/systemd/user/` (package-owned), never `~/.config/systemd/user/` (that's the user's own override territory) — this matches how Arch's own `ydotool` package is laid out.
- Do not install to `/usr/local/` from a PKGBUILD (Arch packaging guideline); that path is only correct for the non-package `make install` fallback.

**If packaging for Fedora/Debian without a native package:**
- `install.sh` with `PREFIX`/`DESTDIR` support, defaulting to `/usr/local` for source installs, is the idiomatic 2026 baseline for a tool with no native package yet.
- Document (don't automate) enabling the `ydotool` dependency, because its unit scope (system vs. `--user`) genuinely differs by distro today (Fedora system-scoped by documentation, Arch user-scoped by package layout) — auto-detect in `ilhop doctor` rather than assuming one.

**If/when Hyprland's `RemoteDesktop` portal (PR #402) merges:**
- Re-open the "can we delete `ydotool`" question as its own future milestone. Do not pre-build against an unmerged PR.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `ydotool` ≥ 1.0.0 | `ydotoold` mandatory pairing | Anything below 1.0.0 (Debian bookworm's 0.1.8-3) does not require/use `ydotoold` the same way — scripts assuming the 1.0.x liveness/socket model will misbehave silently on that version. |
| Hyprland (Ryoku fork, 0.56.2 base) | `xdg-desktop-portal-hyprland` v1.4.0+ (2026-07-18) | This is the release that first carries the merged `InputCapture` portal (PR #268, merged 2026-07-14). It does **not** carry `RemoteDesktop` (PR #402 still open as of 2026-09-05) — do not assume synthetic-input-via-portal is available even on the newest Hyprland portal build. |
| input-leap 3.0.3 (2025-06-13, current) | GNOME 46+ / KDE Plasma 6.1+ (portal-complete) vs. Hyprland (portal-incomplete) | Confirms PROJECT.md's framing still holds as of today: input-leap's Wayland story is compositor-dependent, and Hyprland remains the unfinished case even after the July 2026 `InputCapture` merge, because `RemoteDesktop` (needed for hotkey-triggered *injection*, as opposed to capture) is still missing. |
| AeroSpace v0.21.3-Beta (2026-07-16) | macOS, no SIP changes needed | Still pre-1.0/Beta — expect occasional breaking CLI changes across minor versions; pin a tested version in `il-doctor`'s Mac-side check rather than assuming CLI stability. |

## Answers to the Six Specific Questions

**1. ydotool/ydotoold — version, packaging, permission model, alternatives.**
Current: v1.0.4 (tag 2023-01-30), repo actively maintained (last merged commit 2025-12-22, includes a `mousemove` buffer-overflow fix — not relevant to ilhop's normal `-x/-y` usage since it only triggers when both flag-style and positional args are mixed). Since v1.0.0, `ydotoold` is mandatory (writes to `/dev/uinput`, needs the `input` group + udev rule `KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"`, sometimes needing a `TAG+="uaccess"` addendum on some setups per open upstream issues — treat as environment-specific, verify with `il-doctor`, don't hardcode one rule as universally sufficient). Packaged in Arch `extra` (not AUR), Fedora (official), and Debian (with the version caveat above) — **don't vendor it.** Newer alternatives (`wdotool`, `dotool`) exist but are either too immature (`wdotool`: 33★, no release) or offer no advantage (`dotool`). **Confidence: HIGH** for version/packaging facts (GitHub API + distro package trackers, cross-checked); **MEDIUM** for the udev-rule specifics (community-sourced, environment-dependent).

**2. libei/libportal global-shortcuts — has it shipped? Does this let most of `ilhop` be deleted?**
Two *different* portals matter here and conflating them is the most common mistake in this space:
- `GlobalShortcuts` portal (app-registers-a-hotkey): shipped on Hyprland since `xdg-desktop-portal-hyprland` **v0.2.0**, i.e. years ago. Not the blocker — input-leap simply doesn't use it.
- `InputCapture` portal (pointer-barrier-triggered capture, what input-leap's own Wayland backend needs): merged into `xdg-desktop-portal-hyprland` **PR #268 on 2026-07-14**, shipped in **v1.4.0 (2026-07-18)**. This is brand new — about 8 weeks old as of this research date.
- `RemoteDesktop` portal (needed for *synthetic input injection* — the thing that would let you delete `ydotool`): **still unmerged**, PR #402, last activity **2026-09-05**, open blockers include adding `libeis` to Nix build inputs and an AI-disclosure requirement from the maintainer.
**Verdict: no, you cannot delete `ilhop`'s injection layer yet.** `InputCapture` landing doesn't touch the injection path this project depends on; `RemoteDesktop` is the one that would, and it isn't merged. **Confidence: HIGH** (PR merge status and release dates pulled directly from GitHub).

**3. input-leap vs. deskflow current releases; is the modifiers bug fixed? (context only)**
input-leap: latest tagged release **3.0.3 (2025-06-13)**. deskflow: latest stable **1.26.0 (2026-02-16)**, plus a rolling `continuous` build (2026-09-04). The "modifiers not sent to clients while pointer is on host screen" bug is **still open upstream** in both projects as of this research (tracked in input-leap discussion #1976 and deskflow discussion #7499) — it requires compositor-side portal work (the same `RemoteDesktop` gap from Q2), not an application-layer fix. This reconfirms, it does not overturn, PROJECT.md's closed migration decision. **Confidence: MEDIUM** (cross-referenced two maintained community threads; no upstream issue was found explicitly marked "fixed").

**4. Packaging for strangers — what's idiomatic in 2026?**
For a POSIX-shell + small-C tool installing `systemd --user` units: a plain **`make install` (or `install.sh`) honoring `PREFIX`/`DESTDIR`/XDG paths** is the portable core — this is what every distro-specific package (including an AUR `PKGBUILD`) should wrap, not duplicate. Ship systemd unit files to the package-owned location (`/usr/lib/systemd/user/` on Arch-style layouts, or `$PREFIX/lib/systemd/user/` for source installs) and let `ilhop doctor`/`install.sh` message the user to run `systemctl --user daemon-reload && systemctl --user enable --now <unit>` — do not have the installer silently enable services system-wide. An **AUR `PKGBUILD`** is worth shipping in addition (this machine's own OS is Arch-based, and it's the lowest-effort distro-native option), built from the standard `/usr/share/pacman/PKGBUILD.proto` template. Full `.deb`/`.rpm` packaging is not warranted yet — no evidence this project needs it before it has non-Arch users. **Confidence: HIGH** for the Arch-specific guidance (ArchWiki, current); **MEDIUM** for the general "make install as core" framing (synthesized best practice, not a single canonical spec).

**5. Shell testing — bats-core vs. shellspec vs. shunit2, and which handles untestable critical paths?**
- **bats-core** v1.14.0 (2026-07-21, active): bash-only test *harness* (system-under-test can still be POSIX). Widest adoption, simplest syntax, no built-in mocking (needs an extension), skip-only (no rich pending semantics).
- **shellspec** (latest tag 0.28.1, but repo alive — commits through 2024, pushed 2025-11-24, 1396★): explicitly supports **dash/POSIX-mode execution**, not just bash — directly relevant since `ilhop` is POSIX shell and may run under `dash` as `/bin/sh` on Debian-family boxes. Built-in mocking/stubbing, richer pending/skip semantics, parallel execution.
- **shunit2**: POSIX-shell compatible like shellspec, but no mocking, no parallelism — weakest of the three on features.
**Recommendation: ShellSpec.** The project's own stated constraint is that keybind-triggered paths "cannot be simulated at all" and must be tested by "calling scripts directly... reading Mac modifier flags... driving real `aerospace workspace` switches" plus mandatory human-at-keyboard verification. ShellSpec's built-in mocking lets you stub `ydotool`/`hyprctl`/`ssh` calls to unit-test the *deterministic* logic around them (side-file state, flock behavior, geometry math) in CI, while its `pending` semantics let you mark the physically-unverifiable paths as explicitly pending-human-verification in the test report rather than silently skipping or (worse) fake-mocking them into false confidence. Its dash compatibility also directly matches the cross-distro shell constraint. **Confidence: MEDIUM** (feature comparison synthesized from the project's own comparison page — a primary but non-neutral source; cross-check the mocking/pending claims against the ShellSpec docs before committing test architecture around them).

**6. macOS side — AeroSpace CLI/config vs. yabai/skhd as a future adapter target.**
AeroSpace: latest is **v0.21.3-Beta (2026-07-16)** — still pre-1.0/public-beta, TOML config (now TOML 1.1.0), CLI includes `focus <direction>` with `--boundaries`/`--boundaries-action` flags that directly express "hop at the edge, fail if not at the edge" semantics (potentially simplifying the Mac-side mirror of `il-focus-jump` in a future phase — an implementation note, not a packaging decision). No SIP changes required. yabai: still actively maintained and arguably more feature-complete (native Spaces scripting, `SketchyBar` integration) but **requires disabling SIP** for full functionality, paired with `skhd` for keybinds (two daemons instead of AeroSpace's one). Given this project's "adapters deferred to v2, and only for hardware the author can test on" constraint, this is informational only: if a `yabai`/`skhd` adapter is ever built, budget for the SIP-disable requirement as a real adoption barrier for any future stranger-user, not just an implementation detail. **Confidence: MEDIUM** (WebSearch-synthesized comparison, cross-checked across three independent comparison sources; AeroSpace version/date confirmed directly via GitHub API — HIGH for that specific fact).

## Sources

- GitHub API (`api.github.com`) direct queries — release tags/dates for `ReimuNotMoe/ydotool`, `input-leap/input-leap`, `deskflow/deskflow`, `flatpak/libportal`, `hyprwm/xdg-desktop-portal-hyprland`, `nikitabobko/AeroSpace`, `bats-core/bats-core`, `shellspec/shellspec`, `koalaman/shellcheck` — HIGH confidence, primary source, fetched 2026-09-10.
- `hyprwm/xdg-desktop-portal-hyprland` PR #268 (InputCapture, merged 2026-07-14) and PR #402 (RemoteDesktop, open, last activity 2026-09-05) — HIGH confidence, primary source.
- `ReimuNotMoe/ydotool` issues #306, #307, #311 — HIGH confidence, primary source (buffer overflow scope and unreleased systemd-unit reliability fixes).
- Debian package tracker (`sources.debian.org`, `qa.debian.org/madison.php`) and Arch package/file listings (`archlinux.org/packages`) — HIGH confidence, primary source, fetched 2026-09-10.
- Fedora Packages (`packages.fedoraproject.org`) — MEDIUM confidence (WebFetch-summarized page content).
- `deskflow/deskflow` Discussion #7499 and `input-leap/input-leap` Discussion #1976 — MEDIUM confidence, community-maintained living documents, cross-checked against each other.
- ShellSpec comparison page (`shellspec.info/comparison.html`) — MEDIUM confidence (vendor's own comparison, but factual claims about shell support are independently verifiable and match its documented architecture).
- WebSearch (general ecosystem queries: wdotool, AeroSpace vs. yabai/skhd, AUR packaging guidelines) — MEDIUM confidence, cross-checked across 2–3 independent results per claim.

---
*Stack research for: ilhop packaging/hardening milestone*
*Researched: 2026-09-10*
