# PvP Watchlist: instructions for Claude

WoW: Forever addon in Lua 5.1 (the game's version). The `.toc` loads `Locales.lua`, `PvPWatchlist.lua` and `Share.lua`. The tests in the `tests` folder simulate the game API.

## Language

- Code, comments, names, documentation, commits and PRs are in English. Do not rewrite git history.
- Player-facing text stays Portuguese where it is interface: the `ptBR` block of `Locales.lua`, `Notes-ptBR` in the `.toc` and the Portuguese slash commands. So do the messages only the owner reads (output of the command-line scripts).
- `README.md` is the English one and `README.pt-BR.md` the Portuguese one; each links to the other at the top. Keep both up to date.
- Do not rename the message prefix (`PREFIX = "PvPW"`), the SavedVariables or the locale codes: other players and saved data depend on them.

## Setup and tests

- `bash scripts/cloud-setup.sh` installs Lua 5.1 through apt. It is idempotent; run it if `lua5.1` is missing.
- `bash scripts/test.sh` runs the four tests and fails if any of them does not end with `ALL OK`. Run it before every commit that touches the addon.
- There is no database, no services, no `.env` and no development secrets.
- Every new addon text goes into `Locales.lua` in both Portuguese and English (`test_sharing.lua` checks it).
- A new file that is not part of the addon (script, documentation) goes into the `ignore` list of `.pkgmeta`, otherwise it ships in the published zip.

## Publishing (production)

- A `v*` tag triggers `.github/workflows/release.yml`, which publishes to GitHub Releases and CurseForge. Never create or push a tag, and never run the packager with upload.
- `CF_API_KEY` and `GITHUB_TOKEN` are CI secrets. Never ask for, print or write these values.
- No merging: open the PR and stop.
