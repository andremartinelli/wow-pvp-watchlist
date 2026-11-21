# PvP Watchlist on CurseForge

Text and settings for the CurseForge project page. This file is not packaged.

- Game: World of Warcraft, flavor **Forever**, game version **1.60.1** (Interface 16001)
- Name: PvP Watchlist (folder `PvPWatchlist`)
- License: MIT
- Source: https://github.com/andremartinelli/wow-pvp-watchlist

## Summary

Automatically marks whoever attacks you first in world PvP, and shows on your nameplates the players your guild and friends marked.

## Description

Paste everything between the lines into the CurseForge description editor (Markdown).

---

**PvP Watchlist** builds your kill-on-sight list for you. Whoever attacks you first in world PvP is marked automatically, with no clicks, and the players your guild and friends marked show up on your own nameplates. Made for **WoW: Forever**.

### Why PvP Watchlist

- **No clicks.** The moment an enemy player attacks you, they are on your list, even if you survive the fight. Players who only fought back because you attacked them first are left out.
- **Your guild's list on your screen.** Players marked by guildmates and friends who also use PvP Watchlist get their own icon above the nameplate and a chat alert when they show up, so you see who has been ganking your guild before they get to you.

### What it does

- Each marked player is saved with their class, level, guild, where it happened and how many times they attacked you.
- A raid icon above the nameplate, with the attack count next to it. Your list, your friends' and your guild's each get the icon you pick in the settings (skull, cross and triangle by default), and they can all be the same.
- When a marked player shows up again (nameplate, target or mouseover), you get a sound, a chat message and a warning in the middle of the screen, at most once every 5 minutes per player. Their tooltip shows the history too.
- Optional emote at the attacker when they are marked (`/no` by default). You can pick another one or turn it off.
- Minimap button, an entry in the AddOns menu next to the minimap, and a settings screen.
- No libraries and no other addons needed.

### How it works, and Forever's limits

WoW: Forever blocks the combat log for addons (`COMBAT_LOG_EVENT_UNFILTERED`), so no addon can know who dealt each hit, and some unit information is hidden from addons during combat.

When you take a hit or enter combat, PvP Watchlist looks for 3 seconds for nearby enemy players (nameplates, target, focus and mouseover) who are in combat and targeting you. If the game hides who each of them is targeting, it only marks someone when there is exactly one possible enemy. It does not look for attackers inside dungeons, raids or battlegrounds.

So it can miss an attacker or mark the wrong player. Fix it with the **[unmark]** link in the chat, the **Marked** list in the settings, or `/pvpw mark` with the player targeted.

Apart from the optional emote, it never does anything in the game for you: it only watches and warns.

### Sharing with friends and guild

- Uses addon messages, which never show up in anyone's chat. The people you share with need PvP Watchlist 1.5.0 or newer.
- Only your reliable marks are sent: the attacker had you targeted, or you marked them by hand. What you received from others is never passed on.
- Messages are accepted only from your guild, your friends list and, if you turn it on, your Battle.net friends. Messages from strangers are ignored.
- The game blocks addon messages in dungeons, raids and battlegrounds, so sharing works in the open world. Messages wait until you leave combat and go out one per second.
- When a player marked by a friend or guildmate shows up, you get a chat message saying who marked them, without sound. The **[hide]** link hides that player until they are marked again, and `/pvpw block Name` removes and ignores someone's marks.
- Shared marks expire after 30 days without news.

### Commands

`/kos` also works as a shortcut when no other addon uses it. Every command also works in Portuguese.

| Command | What it does |
|---|---|
| `/pvpw` | Shows the help |
| `/pvpw options` | Opens the settings |
| `/pvpw list` | Lists the marked players, with a link to unmark each one |
| `/pvpw list friends` or `guild` | Lists the players marked by your friends or your guild |
| `/pvpw share` | Sends your list to friends and guild now |
| `/pvpw block Name` | Removes and ignores someone's marks |
| `/pvpw unblock Name` | Accepts that player's marks again |
| `/pvpw mark` | Marks your target by hand |
| `/pvpw remove` | Unmarks your target |
| `/pvpw delete Name` | Unmarks a player by name |
| `/pvpw sound`, `message`, `emote` | Turns the sound, the alert message or the emote on or off |
| `/pvpw minimap` | Shows or hides the minimap button |
| `/pvpw language auto`, `pt` or `en` | Changes the addon's language |
| `/pvpw test` | Duel opponents count as enemies, for testing |
| `/pvpw debug` | Shows in the chat what the addon sees |

**Minimap button:** click to open the settings, right-click to turn automatic marking on or off, drag to move it.

### Settings

Open **Options > AddOns > PvP Watchlist**, or type `/pvpw options`.

- **Detection:** automatic marking on or off; don't mark players you attacked first, and for how long to remember your attack; ignore players far below your level.
- **Reaction:** the emote at the attacker, and which one (`/no`, `/rude`, `/laugh`, `/chicken`, `/spit` or `/point`).
- **Nameplate marker:** which raid icon for your list, for players marked by friends and for players marked by the guild (they can be the same), its size, and whether to show the attack count.
- **Alerts:** sound (three choices, with a test button), chat message, big warning on the screen, and the line in the player's tooltip.
- **Interface:** minimap button and language.
- **Sharing:** share with your guild and with your friends list (both on by default) and with Battle.net friends (off by default); chat alert for players marked by them, and optionally the big warning on the screen too.
- **Marked:** a sub-page with every marked player, newest first, filtered by your list, friends or guild, with an Unmark or Hide button for each one.

### Languages

English and Brazilian Portuguese. The addon follows the game client (Portuguese clients get Portuguese, every other client gets English), or you can pick a language in the settings or with `/pvpw language`.

### Source code and bug reports

https://github.com/andremartinelli/wow-pvp-watchlist (MIT license). Up to version 1.3.0 the addon was called killonsight and was only on GitHub.

---

## Categories

- Main: **PvP**
- Extra (up to 4): **Guild** (sharing with the guild), **Combat**, **Unit Frames** (the nameplate marker), **Tooltip**
