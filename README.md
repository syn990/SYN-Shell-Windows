# SYN-OS-WINDOWS

A **taskbar replacement for Windows 11**, styled to be a close visual match for [SYN-OS](https://github.com/syn990/SYN-OS)'s Waybar setup — same red-and-black look, same layout philosophy, same keyboard-first workflow. It sits alongside Windows, not underneath it: no system files touched, no driver-level or admin-only tricks, nothing running with elevated permissions it doesn't need. Everything it does is the kind of thing a normal desktop app is allowed to do — draw a bar, register some keyboard shortcuts, change your wallpaper and color scheme the same way Windows' own Settings app would.

## What you actually get

- **A thin bar across the top of your screen**, replacing the need to look at the Windows taskbar — a menu button, an icon for each open window (click to jump to it), the focused window's title in the middle, then wifi/volume/clock/power on the right. The volume widget doubles as a quick audio-device switcher: click it to change your sound output/input source directly, no need to dig into `pavucontrol` or a right-click menu the way you would on SYN-OS.
- **One button (or `Win+Space`) opens a menu** with your terminal, file manager, every installed app, system controls, and theme switching — all in one place, no digging through Start.
- **Keyboard shortcuts for everything** — new terminal, close window, switch virtual desktop, snap windows to edges, screenshot a region. See the table below.
- **Four color themes** (red, blue, green, purple) that you can flip between live. Switching a theme changes the bar's colors, your Windows Terminal color scheme, your desktop wallpaper, and even Windows' own accent color (Start menu, taskbar highlights) — all in one click.

It does **not** replace Windows' window manager, and it doesn't fight Windows for control of anything — floating windows, Alt+drag, Aero Snap all still work exactly as before. This just adds a bar and a menu on top.

## Get it running

**First**, on a machine that's never run a local PowerShell script before, Windows blocks it by default. One-time fix, no admin needed:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

(If you skip this, you'll see an error like *"File ... cannot be loaded ... not digitally signed"* the moment you try to run anything below.)

Then, one command installs everything (AutoHotkey, the status bar, a launcher, and so on — assumes none of it is on your machine yet):

```powershell
& ".\scripts\Setup.ps1"
```

Then start it:

```powershell
& ".\scripts\Start-SynSession.ps1"
```

That's it — the bar appears, the keyboard shortcuts work. To make it start automatically every time you log in:

```powershell
Enable-ScheduledTask -TaskName SynOsSession
```

(It's off by default on purpose, so nothing runs without you deciding it should — see "How to undo any of this" below if you ever want it gone.)

## Technical stack

| Piece | Tool | Role |
|---|---|---|
| Status bar | [yasb](https://github.com/amnweb/yasb) | Renders the bar and its widgets |
| Keybinds + menu | [AutoHotkey v2](https://www.autohotkey.com/) | Global shortcuts, the `Win+Space` menu, window-edge snapping |
| App launcher | [Flow Launcher](https://www.flowlauncher.com/) | `Win+A` |
| Move/resize | [AltSnap](https://github.com/RamonUnch/AltSnap) | Alt+drag (assumed already installed, not installed by this project) |
| Virtual desktops | [VirtualDesktop](https://github.com/MScholtes/PSVirtualDesktop) PowerShell module | Named desktops, `Win+1..4` switching |
| Theming engine | This project's own PowerShell scripts | One palette file drives bar colors, Windows Terminal scheme, wallpaper, and Windows' accent color together |
| Font | Terminus (Nerd Font build) | Matches SYN-OS's font |

### What this project adds on top of those tools

- `themes/*.theme` — the four color palettes
- `scripts/Apply-SynTheme.ps1` — applies a palette everywhere at once
- `scripts/Setup.ps1` / `scripts/Undo-SynOsWindows.ps1` — install and rollback
- `ahk/syn-wm.ahk` / `ahk/syn-menu.ahk` — the keybinds and the menu
- `templates/yasb-*.tmpl` — the bar's layout and styling

## Keyboard shortcuts

| Press | Does this | Replaces (native Windows shortcut) |
|---|---|---|
| `Win+Space` | Open the menu | -- |
| `Win+Enter` | Open a terminal | -- |
| `Win+A` | Open the app launcher | Quick Settings flyout |
| `Win+Q` | Close the current window | Search |
| `Win+Tab` | Maximize/restore the current window | Task View (still on the taskbar) |
| `Win+1..4` | Jump to virtual desktop 1-4 | Switching to taskbar-pinned apps |
| `Ctrl+Alt+←/→` | Switch virtual desktop | -- |
| `Win+Shift+←/→/↑/↓` | Snap the window to a screen edge | -- |
| `Win+P` | Screenshot a region of the screen | Display/projector switch panel (still available from the menu) |
| `Win+Escape` | Reload the keyboard shortcuts | -- |

Alt+drag to move/resize windows is handled by **AltSnap**, which this project assumes you already have — it's not something this installs.

## The menu

Click the bar's leftmost button, or press `Win+Space`:

- **Terminal** / **File manager**
- **All Applications** — everything installed, pulled live from your Start Menu
- **Tools** — jump straight to the config files if you want to tweak something
- **System Control** — volume mixer, screenshot, switch display, Task Manager
- **Bar & Keybinds** — restart or stop the bar/shortcuts independently, if either misbehaves
- **Power Options** — lock, sign out, restart, shut down
- **Themes** — pick a color theme, applies instantly

## Switching themes

```powershell
& ".\scripts\Apply-SynTheme.ps1" -Name SYN-OS-GREEN
```

Same thing happens from the menu (`Win+Space` → Themes) without touching PowerShell at all. Four themes ship out of the box: `SYN-OS-RED`, `SYN-OS-BLUE`, `SYN-OS-GREEN`, `SYN-OS-PURPLE` — matching SYN-OS's own palettes, wallpapers included.

## How to undo any of this

```powershell
& ".\scripts\Undo-SynOsWindows.ps1"                 # stop everything, undo the color/wallpaper/terminal changes
& ".\scripts\Undo-SynOsWindows.ps1" -UninstallApps   # also remove every app this installed
```

Safe to run at any point, even if nothing's currently running.

---

## Technical reference

The rest of this document is for anyone modifying the project, not for day-to-day use.

### Differences from SYN-OS

- **No custom lock screen.** `Win+L` locks using Windows' own unmodified lock screen.
- **The menu's appearance is standard Windows, not a themed skin.** AutoHotkey's menu popup can't be recolored to match the theme palette — same structure and behavior as SYN-OS's version, but plain Windows fonts/colors/borders.
- **The menu opens from a button or `Win+Space`, not a desktop right-click.** On SYN-OS, `labwc` *is* the window manager, so it owns the desktop and can bind its root menu straight to a right-click there. On Windows, right-clicking the desktop is Explorer's territory, not something a normal app is allowed to take over — doing it anyway would mean an invasive shell extension hooking into Explorer itself. A button/keyboard shortcut avoids that, at the cost of matching labwc's exact trigger.
- **CPU/memory/disk/battery/current-desktop widgets aren't on the bar.** They exist as scripts (`scripts/Get-Cpu.ps1` etc.) and config entries (in `templates/yasb-config.yaml.tmpl`, just not referenced by the bar's widget list) and are individually verified to work standalone, but getting them to reliably render live on the bar turned into a long, inconclusive debugging chase that stopped being worth the cost. The window-icon widget on the left uses a native, non-scripted yasb widget instead, and has been reliable.
- **The old Windows taskbar at the bottom of your screen doesn't auto-hide itself.** That's a deliberately manual step, not an oversight — the registry tweak involved can visually glitch the taskbar, so it's left to you: open **Settings**, search for **"Automatically hide the taskbar"**, and switch it on.

### Architecture

```
themes/*.theme            9-key palette files (same shape as SYN-OS's)
        |
        v
scripts/Apply-SynTheme.ps1   the syn-theme-apply equivalent
        |
        +--> templates/*.tmpl  rendered (SYN_* + PROJECT_ROOT + tool-path
        |                      tokens substituted) into:
        |       - %USERPROFILE%\.config\yasb\{config.yaml,styles.css}
        |       - Windows Terminal settings.json (a "SYN-OS-<name>" scheme)
        |
        +--> Windows accent color (registry: DWM + Explorer\Accent)
        +--> Wallpaper (SystemParametersInfo)

ahk/syn-wm.ahk             persistent keybind daemon
ahk/syn-menu.ahk           the menu (+ power submenu)

scripts/Start-SynSession.ps1   logon entry point: applies the last-used
                                theme, launches the bar and the keybind
                                daemon

scripts/Setup.ps1          one-shot installer -- assumes nothing is
                            installed, verifies what actually landed
scripts/Resolve-Tools.ps1  finds real AutoHotkey/yasb/PowerShell-7 install
                            paths, writes .state\tool-paths.env
scripts/Undo-SynOsWindows.ps1  full rollback
```

Nothing hardcodes a username or a fixed install path. `Apply-SynTheme.ps1` resolves its own location via `$PSScriptRoot`, the AHK scripts resolve theirs via `A_ScriptDir`, and tool paths (AutoHotkey/yasb/pwsh) are discovered once by `Resolve-Tools.ps1` and cached in `.state\tool-paths.env`. Move the folder anywhere, or run it as a different user, and it still finds itself.

### Porting to another machine

Copy the folder anywhere, as any user, and run `Setup.ps1`. One thing is deliberately **not** portable:

- **`.state\`** — generated, gitignored. Holds this machine's actual tool install paths and its *original* Windows accent color (so `Undo-SynOsWindows.ps1` can restore it). Copying this to another machine would make that script restore the *wrong* machine's original colors there.
