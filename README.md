# PageBoy

A World of Warcraft addon: hold **Shift**, **Ctrl** or **Alt** to page your main action bar, without replacing your bars.

- **Default:** hold Shift for page 2. Ctrl and Alt are off until you set them.
- Let go and the game's normal paging returns, including druid form and warrior stance bars.
- Vehicle, possess and override bars are never touched.
- Works in combat. Settings are saved per character.

## Settings

Open the settings page with `/pageboy` or from Options > AddOns > PageBoy. Set a page (or Off) for Shift, Ctrl and Alt, and see any keybinds that would get in the way.

## Commands

| Command | What It Does |
|---|---|
| `/pageboy` | Open the settings page (`/pageboy help` lists commands) |
| `/pageboy shift <page or off>` | Set Shift's page (same for `ctrl` and `alt`) |
| `/pageboy keys` | List keybinds that stop a modifier from reaching your buttons |

By default the game binds Shift+1 to Shift+6 to "Action Page 1-6". Unbind those in Options > Keybindings so Shift reaches your buttons; `/pageboy keys` lists any conflicts.

Pages 7 to 10 are where druid forms, warrior stances and rogue stealth live, so paging to them shows those bars.

## License

MIT. See [LICENSE](LICENSE).
