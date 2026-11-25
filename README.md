<img src="media/icon.svg" width="96" align="right" alt="PvP Watchlist icon">

# PvP Watchlist

Addon for **WoW: Forever**. It marks with a skull whoever attacks you first in world PvP and warns you when that player shows up again.

**English** | [Português](README.pt-BR.md)

## What it does

- When an enemy player attacks you, the addon marks them and saves their class, level, guild, where it happened and how many times they attacked you.
- Marked players get an icon on their nameplate, with the attack count next to it.
- When a marked player shows up again, you get a warning: a sound, a chat message and an alert in the middle of the screen. Their tooltip shows the history too.
- Players who only fought back because you attacked first are not marked.
- Shares the list with friends and guildmates who also use the addon. Each list (yours, your friends' and your guild's) uses the icon you pick in the settings, and they can all be the same. By default: skull for yours, cross for friends and triangle for the guild.
- Can do an emote at the attacker (`/no`, `/rude`, `/laugh`...).
- Has a minimap button, an entry in the addons menu and a settings screen under **Options > AddOns > PvP Watchlist**.
- Works in English and Portuguese. The language follows the game client, or you can pick one in the settings.

## How it finds out who attacked you

Forever blocks the combat log for addons (`COMBAT_LOG_EVENT_UNFILTERED`), so no addon knows who dealt each hit. When you get hit or enter combat, PvP Watchlist looks for 3 seconds for nearby enemy players who are in combat and targeting you. If the game hides who each of them is targeting, it only marks when there is exactly one possible enemy.

So it can mark the wrong player or let someone slip by. To fix it, use the **[unmark]** link in the chat, the **Marked** list in the settings, or `/pvpw mark` with the player targeted.

## Sharing with friends and guild

- Sharing uses addon messages, which never show up in anyone's chat. The receiver needs PvP Watchlist 1.5.0 or newer.
- Only your reliable marks are sent: the attacker had you targeted, or you marked them by hand. What you received from others is not passed on.
- Messages are only accepted from players in your guild or on your friends list (and Battle.net friends, if turned on in the settings).
- The game blocks addon messages in dungeons, raids and battlegrounds. Outside them, the queue waits until you leave combat and sends one message per second.
- When a player marked by friends or guild shows up, you get a chat message saying who marked them, without sound. The **[hide]** link hides that player until they are marked again. `/pvpw block Name` deletes someone's marks and ignores new ones.
- A received mark expires after 30 days without news.
- In the settings, the **Sharing** section turns guild, friends and Battle.net on or off (the first two start on). The **Marked** page has a filter: my list, friends or guild.

## Installation

- **CurseForge:** search for **PvP Watchlist** in the CurseForge app or website (Forever version).
- **GitHub:** download `PvPWatchlist-*.zip` from **Releases** and extract it to `World of Warcraft\_forever_\Interface\AddOns\`. The folder already has the right name, `PvPWatchlist`.

Then start the game. If it is already open, close it and open it again: `/reload` does not load new addons.

**Coming from killonsight (1.3.0 or older)?** Remove the `Interface\AddOns\killonsight` folder, or both will load together. Your old list is in `WTF\Account\<account>\SavedVariables\killonsight.lua`: with the game closed, copy it to `PvPWatchlist.lua` in the same folder and replace `killonsightDB` with `PvPWatchlistDB` in the copy.

## Commands

Every command works in English and Portuguese. `/kos` works too, if no other addon uses it.

| Command | In Portuguese | What it does |
|---|---|---|
| `/pvpw` | | Shows the help |
| `/pvpw options` | `/pvpw config` | Opens the settings |
| `/pvpw list` | `/pvpw lista` | Lists the marked players, with a link to unmark |
| `/pvpw list friends` or `guild` | `/pvpw lista amigos` ou `guilda` | Lists the players marked by friends or by the guild |
| `/pvpw share` | `/pvpw compartilhar` | Sends your list to friends and guild now |
| `/pvpw block Name` | `/pvpw bloquear Nome` | Deletes someone's marks and ignores new ones |
| `/pvpw unblock Name` | `/pvpw desbloquear Nome` | Accepts that player's marks again |
| `/pvpw mark` | `/pvpw marcar` | Marks your target by hand |
| `/pvpw remove` | `/pvpw tirar` | Unmarks your target |
| `/pvpw delete Name` | `/pvpw apagar Nome` | Unmarks by name |
| `/pvpw sound` | `/pvpw som` | Turns the sound on or off |
| `/pvpw message` | `/pvpw mensagem` | Turns the alert message on or off |
| `/pvpw emote` | `/pvpw emote` | Turns the emote on or off |
| `/pvpw minimap` | `/pvpw minimapa` | Shows or hides the minimap button |
| `/pvpw language auto, pt or en` | `/pvpw idioma auto, pt ou en` | Changes the addon's language |
| `/pvpw test` | `/pvpw teste` | Duel opponents count as enemies, for testing |
| `/pvpw debug` | `/pvpw debug` | Shows in the chat what the addon sees |

**Minimap button:** click to open the settings, right-click to turn automatic marking on or off, drag to move it.

## Tests

The `tests` folder simulates the game API to test the addon outside the game. Run them from the main folder with Lua 5.1 to 5.4:

```
lua tests/test_detection.lua
lua tests/test_settings.lua
lua tests/test_locale.lua
lua tests/test_sharing.lua
```

`test_sharing.lua` covers sharing with friends, guild and Battle.net.

Each test ends with `ALL OK` when everything passes.

**On Linux and in Claude Code cloud sessions:** `bash scripts/cloud-setup.sh` installs Lua 5.1 (the version WoW uses) through apt and can run as many times as you want. Then `bash scripts/test.sh` runs the four tests and exits with an error if any of them does not reach `ALL OK`. The addon has no database, services or `.env`, so there is nothing else to set up.

## License

[MIT](LICENSE). Made by André Martinelli with help from Claude (Anthropic). Up to version 1.3.0 the addon was called killonsight.
