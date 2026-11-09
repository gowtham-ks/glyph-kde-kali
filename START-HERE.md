# Start here (no experience needed)

Glyph Lite gives your desktop a black, white-dots and red look. You do not need to understand anything
below the "Install" step; the setup asks simple questions and explains what it does.

## 1. Open a terminal
In Kali: click the terminal icon, or press `Ctrl + Alt + T`.

## 2. Unpack and start
```bash
unzip glyph-lite-*.zip
cd glyph-lite
./setup.sh
```
It shows what it found on your computer, then asks a few yes/no questions. Press **Enter** to accept
the suggested answer (the capital letter). Nothing is changed until you confirm at the end.

Want to look first? `./setup.sh --check` changes nothing.

## 3. What you get on each desktop

| Your desktop | What works |
|---|---|
| **KDE Plasma 6** (any session: X11, Wayland, VNC) | Everything: colors, wallpapers, 2 widgets, terminal, launcher, fastfetch |
| **KDE Plasma 5** | Colors, wallpapers, terminal, launcher, fastfetch (no widgets) |
| **XFCE** (Kali's default) | Wallpaper, xfce4-terminal and kitty colors, launcher, fastfetch |
| **GNOME** | Wallpaper, dark/light, kitty, launcher, fastfetch |
| **Anything else** | Terminal, launcher, fastfetch; wallpapers saved for you to set by hand |

Not sure which desktop you have? Run `echo $XDG_CURRENT_DESKTOP`.

## 4. Daily use
```bash
glyph-lite-mode toggle        # dark <-> light
rofi -show drun -theme glyph  # app launcher (set it to a keyboard shortcut)
fastfetch                     # system info with a dot-ring logo
```
On KDE: right-click the desktop, **Add Widgets**, search "Glyph".

## 5. Make it yours
```bash
glyph-lite-customize wizard     # pick accent color, wallpaper style, font, corners
glyph-lite-customize preset amber
```
Change anything, then it rebuilds all the theme files for you. Presets: ice, mint, amber, orange, violet, pink, oled, soft.

## 6. Change the top bar and dock
```bash
glyph-lite-customize layout compact   # or classic, side-dock, minimal ...
glyph-lite-layout reapply
```
Right-click the island on your bar and choose Configure for its own options.

## 7. Undo
```bash
./uninstall.sh
```
Puts back everything that was changed. Your wallpaper is the one thing you re-pick yourself.

## Using KDE on Kali (optional)
Kali uses XFCE by default. To try KDE Plasma: `sudo apt update && sudo apt install kali-desktop-kde`,
log out, click the small gear/session icon on the login screen, choose **Plasma**, and log in. Then run `./setup.sh` again.

## If something looks wrong

| Problem | Fix |
|---|---|
| `glyph-lite-mode: command not found` | Log out and in once, or run `~/.local/bin/glyph-lite-mode toggle` |
| Colors look half-changed | Log out and in once |
| A theme is missing (rofi, kitty, fastfetch) | Install it: `sudo apt install rofi kitty fastfetch`, then run `./setup.sh` again |
| Screen feels slow over remote desktop | Run `./install.sh --vnc-tune` |
| You want it all gone | `./uninstall.sh` |

Found a bug? Note the command you ran and the last lines it printed; that is enough to fix it.
