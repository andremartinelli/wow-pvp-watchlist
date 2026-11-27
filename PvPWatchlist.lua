-- PvP Watchlist 1.7.0 (WoW: Forever). Until 1.3.0 it was called killonsight.
-- Marks whoever attacks you first in world PvP and warns you when they show up again.
-- Also says in the chat when an enemy player you attacked dies (kill alert, no sound), and warns you, like a raid
-- warning, when an enemy starts casting a spell at you (attack warning).
-- Texts live in Locales.lua (Portuguese and English). Addon icon in media/icon.tga.
-- Sharing marks with friends and guild lives in Share.lua; this file keeps the received lists (db.shared),
-- the icon of each list (yours, friends, guild: picked in the settings, can be the same), the alerts and the settings screen.
--
-- Forever blocks COMBAT_LOG_EVENT_UNFILTERED for addons, so the addon cannot tell who dealt each hit.
-- How it works: when you take a hit (UNIT_COMBAT on "player") or enter combat, it looks, for
-- SCAN_WINDOW seconds, for nearby enemy players (nameplates, target, focus, mouseover) who are in
-- combat and targeting YOU. Those get marked, unless you attacked the player first.
-- In Forever many values become "secret" in combat; anything that can be secret goes through safe().
-- Settings: Options > AddOns > PvP Watchlist (or /pvpw config). /kos works too, if no other addon uses it.

local ADDON, ns = ...
ADDON = ADDON or "PvPWatchlist"
ns = ns or {}

local ICON_PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\icon"
local LINK_BASE = "addon:" .. ADDON .. ":"   -- chat links: "unmark:<key>" and "hide:<source>:<key>"
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local ICON_SETTING = { mine = "icon", friends = "friendsIcon", guild = "guildIcon" } -- icon setting of each list
local CIRCLES = { "friends", "guild" }        -- received lists, in priority order after yours
local SCAN_WINDOW = 3        -- seconds looking for the attacker after a hit (catches the rogue leaving stealth)
local SCAN_STEP = 0.2        -- interval between the scans inside that window
local RECOUNT_GAP = 120      -- a new attack by the same player only counts after 2 min
local ALERT_GAP = 300        -- "showed up" alert at most every 5 min per player
local MAX_PLATES = 40
local ATTACK_ACTIONS = {
    WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true,
    ABSORB = true, IMMUNE = true, DEFLECT = true, REFLECT = true, EVADE = true,
}
local DEFAULTS = {
    enabled = true,           -- mark automatically whoever attacks you
    castWarning = true,       -- attack warning: sound and alert when an enemy starts casting a spell at you
    skipIfIAttacked = true,   -- do not mark whoever you attacked first
    myAttackMemory = 60,      -- how many seconds to remember your attack
    ignoreLow = false,        -- ignore players well below your level
    ignoreLowLevels = 10,     -- level difference to ignore
    emote = true,             -- do an emote at the attacker when they are marked
    emoteToken = "NO",        -- which emote (/no)
    icon = 8,                 -- raid icon of your list (8 = skull)
    friendsIcon = 7,          -- icon of the players marked by friends (7 = X)
    guildIcon = 4,            -- icon of the players marked by the guild (4 = green triangle, the guild chat color)
    iconSize = 26,
    showCount = true,         -- attack count next to the icon
    sound = true,
    soundId = "raid",
    msg = true,               -- chat message when a marked player shows up
    center = true,            -- big alert in the middle of the screen
    tooltip = true,           -- line in the player's tooltip
    test = false,             -- duel opponents count as enemies
    debug = false,
    minimap = true,           -- minimap button
    minimapAngle = 200,       -- button position, in degrees from the right (counterclockwise)
    language = "auto",        -- "auto" (from the game), "ptBR" or "enUS"
    shareGuild = true,        -- exchange marks with the guild (send and receive)
    shareFriends = true,      -- exchange marks with the friends list
    shareBnet = false,        -- exchange marks with Battle.net friends
    sharedAlerts = true,      -- chat message when someone marked by friends or guild shows up
    sharedCenter = false,     -- big alert in the middle of the screen for them too
    killAlert = "always",     -- chat line when an enemy you attacked dies: "always", "afterDeath" (yours) or "off"
}

-- ---------------------------------------------------------------- language

local LOCALES = ns.LOCALES or {}
local lang = "enUS"

-- "auto" follows the client: Portuguese (ptBR/ptPT) or English for everything else.
local function pickLanguage(setting)
    if setting == "ptBR" or setting == "enUS" then return setting end
    local ok, loc = pcall(GetLocale)
    if ok and (loc == "ptBR" or loc == "ptPT") then return "ptBR" end
    return "enUS"
end

-- L.KEY returns the text in the current language; what is missing falls back to English and, last, to the key itself.
local L = setmetatable({}, { __index = function(_, k)
    local t = LOCALES[lang]
    local v = t and t[k]
    if v == nil and LOCALES.enUS then v = LOCALES.enUS[k] end
    if v == nil then v = k end
    return v
end })
lang = pickLanguage("auto")

-- The 8 raid icons. Each list (yours, friends, guild) picks its own, and they can be the same.
local ICONS = {
    { id = 8, labelKey = "ICON_SKULL" }, { id = 7, labelKey = "ICON_CROSS" }, { id = 1, labelKey = "ICON_STAR" },
    { id = 2, labelKey = "ICON_CIRCLE" }, { id = 3, labelKey = "ICON_DIAMOND" }, { id = 4, labelKey = "ICON_TRIANGLE" },
    { id = 5, labelKey = "ICON_MOON" }, { id = 6, labelKey = "ICON_SQUARE" },
}
for _, e in ipairs(ICONS) do e.icon = RAID_ICON .. e.id end
-- Filter of the "Marked" page.
local LIST_SOURCES = {
    { id = "mine", labelKey = "FILTER_MINE" },
    { id = "friends", labelKey = "FILTER_FRIENDS" },
    { id = "guild", labelKey = "FILTER_GUILD" },
}
local EMOTES = {
    { id = "NO", label = "/no" }, { id = "RUDE", label = "/rude" }, { id = "LAUGH", label = "/laugh" },
    { id = "CHICKEN", label = "/chicken" }, { id = "SPIT", label = "/spit" }, { id = "POINT", label = "/point" },
}
local SOUNDS = {
    { id = "raid", labelKey = "SOUND_RAID", kit = function() return (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959 end },
    { id = "ready", labelKey = "SOUND_READY", kit = function() return (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960 end },
    { id = "quest", labelKey = "SOUND_QUEST", kit = function() return (SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED) or 847 end },
}
local KILL_ALERTS = {
    { id = "always", labelKey = "KILL_ALWAYS" }, { id = "afterDeath", labelKey = "KILL_AFTER_DEATH" },
    { id = "off", labelKey = "KILL_OFF" },
}
local LANGS = {
    { id = "auto", labelKey = "LANG_AUTO" }, { id = "ptBR", label = "Português" }, { id = "enUS", label = "English" },
}

local db, S                -- PvPWatchlistDB and PvPWatchlistDB.settings
local scanUntil, nextScan = 0, 0
local myAttacks = {}       -- player key -> GetTime() of your last attack on them
local myAttackGuids = {}   -- player GUID -> GetTime() (the name may come with or without realm; the GUID does not change)
local lastOwnAction = 0    -- GetTime() of your last offensive spell, auto attack or pet attack order
local OWN_COMBAT_GAP = 2.5 -- entering combat up to 2.5 s after that was your own action: do not start the scan
local KILL_MEMORY = 30     -- kill alert: enemy you attacked in the last 30 s (Curse of Agony lasts 24 s)
local KILL_STEP = 0.5      -- interval between the checks for dead enemies
local nextKillCheck = 0
local myDebuffSeen = {}    -- player GUID (or key) -> GetTime() when a spell of yours was last seen on them
local killed = {}          -- player GUID (or key) -> true once their death was reported
local castSeen = {}        -- player GUID (or key) -> GetTime() of their last spell at you (attack warning)
local castWarnedAt = {}    -- player GUID (or key) -> GetTime() of the attack warning about them
local CAST_HIT_GAP = 15    -- after an attack warning, the hit marks without a second sound, even if you hit back
local myDeathAt            -- GetTime() of your last death
local ui = { refreshers = {} }
local f = CreateFrame("Frame")

-- ---------------------------------------------------------------- utilities

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Calls fn protected. Returns nil instead of an error or secret value.
local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    if isSecret(a) then a = nil end
    if isSecret(b) then b = nil end
    if isSecret(c) then c = nil end
    return a, b, c
end

local function say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4040[" .. L.TAG .. "]|r " .. msg)
end

local function debug(msg)
    if S and S.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888[" .. L.TAG .. " debug] " .. msg .. "|r")
    end
end

local function now() return GetTime() end

local function findIn(list, id)
    for i, e in ipairs(list) do if e.id == id then return e, i end end
    return list[1], 1
end

local function labelOf(e) return e.labelKey and L[e.labelKey] or e.label end

local function day(t, fmt) return t and date(fmt or L.DATE, t) or "?" end

local function refreshUI()
    for _, r in ipairs(ui.refreshers) do pcall(r) end
    if ui.refreshList then pcall(ui.refreshList) end
end

-- Key, display name and GUID (may be nil) of a player.
local function unitInfo(unit)
    local name, realm = safe(UnitName, unit)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    local hasRealm = type(realm) == "string" and realm ~= ""
    local key = string.lower(name) .. (hasRealm and ("-" .. string.lower(realm)) or "")
    local display = hasRealm and (name .. "-" .. realm) or name
    local guid = safe(UnitGUID, unit)
    if type(guid) ~= "string" then guid = nil end
    return key, display, guid
end

local function inWorld()
    local inInstance, kind = safe(IsInInstance)
    if inInstance and kind and kind ~= "none" then return false end
    return true
end

-- Enemy-faction player you can attack. In test mode, any attackable player (duel) counts.
local function isEnemyPlayer(unit)
    if not safe(UnitExists, unit) or not safe(UnitIsPlayer, unit) then return false end
    if safe(UnitIsUnit, unit, "player") then return false end
    if not safe(UnitCanAttack, "player", unit) then return false end
    if safe(UnitIsEnemy, "player", unit) then return true end
    return S.test and true or false
end

-- true/false, or nil when the game hides the answer.
local function targetsMe(unit)
    local ok, r = pcall(UnitIsUnit, unit .. "target", "player")
    if not ok or isSecret(r) then return nil end
    return r and true or false
end

local function inCombat(unit)
    local ok, r = pcall(UnitAffectingCombat, unit)
    if not ok or isSecret(r) then return nil end
    return r and true or false
end

-- Player well below your level ("ignore" option). Unknown level (??) is never ignored.
local function tooLow(unit)
    if not S.ignoreLow then return false end
    local mine, theirs = safe(UnitLevel, "player"), safe(UnitLevel, unit)
    if type(mine) ~= "number" or type(theirs) ~= "number" or theirs <= 0 then return false end
    return mine - theirs >= (S.ignoreLowLevels or 10)
end

local function findEntry(unit)
    local key, display, guid = unitInfo(unit)
    if not key then return nil end
    local e = db.players[key]
    if e and e.guid and guid and e.guid ~= guid then return nil end -- same name, other character
    return e, key, display, guid
end

-- Source turned on in the settings? Friends covers the friends list and Battle.net.
local function circleOn(circle)
    if circle == "guild" then return S.shareGuild end
    return S.shareFriends or S.shareBnet
end

local function circleLabel(circle) return circle == "guild" and L.SRC_GUILD or L.SRC_FRIENDS end

-- Mark received from friends or guild (nil if hidden, no data, turned off or from another character).
local function sharedEntry(circle, key, guid)
    if not circleOn(circle) then return nil end
    local list = db.shared and db.shared[circle]
    local e = list and list[key]
    if not e or e.hidden or not e.last then return nil end
    if e.guid and guid and e.guid ~= guid then return nil end
    return e
end

-- All marks of an enemy player, from most to least important: yours, friends, guild.
local function marksFor(unit)
    local out = {}
    if not isEnemyPlayer(unit) then return out end
    local key, _, guid = unitInfo(unit)
    if not key then return out end
    local own = db.players[key]
    if own and not (own.guid and guid and own.guid ~= guid) then table.insert(out, { e = own, source = "mine", key = key }) end
    for _, c in ipairs(CIRCLES) do
        local e = sharedEntry(c, key, guid)
        if e then table.insert(out, { e = e, source = c, key = key }) end
    end
    return out
end

local function sharedCount(circle)
    local n = 0
    for key, e in pairs(db.shared and db.shared[circle] or {}) do
        if not e.hidden and e.last then n = n + 1 end
    end
    return n
end

local function describe(e)
    local parts = {}
    if e.class then table.insert(parts, e.class) end
    if e.level then table.insert(parts, tostring(e.level)) end
    local s = "|cffff8080" .. e.name .. "|r"
    if #parts > 0 then s = s .. " (" .. table.concat(parts, " ") .. (e.guild and (", <" .. e.guild .. ">") or "") .. ")"
    elseif e.guild then s = s .. " (<" .. e.guild .. ">)" end
    return s
end

local function plural(n) return n == 1 and L.TIMES_ONE or string.format(L.TIMES_N, n) end

-- Icon chosen for the list the mark came from ("mine", "friends" or "guild").
local function sourceTexture(source) return findIn(ICONS, S[ICON_SETTING[source] or "icon"]).icon end

local function playAlert(force)
    if not S.sound and not force then return end
    pcall(PlaySound, findIn(SOUNDS, S.soundId).kit(), "Master")
end

-- on = the option that turns the alert on (S.center for your list, S.sharedCenter for friends and guild).
local function centerWarning(text, on)
    if not on then return end
    if RaidNotice_AddMessage and RaidWarningFrame then
        local color = (ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]) or { r = 1, g = 0.2, b = 0.2 }
        if pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color) then return end
    end
    if UIErrorsFrame then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, text, 1, 0.2, 0.2) end
end

-- Emote aimed at a player (live unit: "nameplate3", "target"). Never without a target: in Forever,
-- PerformEmote(token, nil) falls back to your current target, which may be someone else (note from the TFTB addon).
local function doEmote(unit, force)
    if not (S.emote or force) or type(unit) ~= "string" or unit == "" then return false end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if not ok or isSecret(locked) or locked then return false end
    end
    local token = findIn(EMOTES, S.emoteToken).id
    if C_ChatInfo and C_ChatInfo.PerformEmote then
        return pcall(C_ChatInfo.PerformEmote, token, unit)
    elseif DoEmote then
        return pcall(DoEmote, token, unit)
    end
    return false
end

-- ---------------------------------------------------------------- icon on the nameplates

local function plateFor(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or isSecret(plate) or type(plate) ~= "table" then return nil end
    if plate.IsForbidden then
        local okF, forbidden = pcall(plate.IsForbidden, plate)
        if not okF or forbidden then return nil end
    end
    return plate
end

-- e = record of the marked player (shows the icon of its source) or nil (hides).
local function setIcon(unit, e, source)
    local plate = plateFor(unit)
    if not plate then return end
    if e then
        if not plate.kosSkull then
            local ok, t = pcall(plate.CreateTexture, plate, nil, "OVERLAY")
            if not ok or not t then return end
            plate.kosSkull = t
            local okC, fs = pcall(plate.CreateFontString, plate, nil, "OVERLAY", "GameFontNormal")
            if okC and fs then plate.kosCount = fs end
        end
        local size = S.iconSize or 26
        local t = plate.kosSkull
        t:SetTexture(sourceTexture(source))
        t:SetSize(size, size)
        t:ClearAllPoints()
        t:SetPoint("BOTTOM", plate, "TOP", 0, 4)
        t:Show()
        if plate.kosCount then
            if S.showCount then
                plate.kosCount:ClearAllPoints()
                plate.kosCount:SetPoint("LEFT", t, "RIGHT", 1, 0)
                plate.kosCount:SetText(tostring(e.count or 1))
                plate.kosCount:Show()
            else
                plate.kosCount:Hide()
            end
        end
    else
        if plate.kosSkull then plate.kosSkull:Hide() end
        if plate.kosCount then plate.kosCount:Hide() end
    end
end

-- The mark shown on the player (yours first), where it came from and the key.
local function markedEnemy(unit)
    local m = marksFor(unit)[1]
    if m then return m.e, m.source, m.key end
end

local function refreshPlates()
    for i = 1, MAX_PLATES do
        local u = "nameplate" .. i
        if safe(UnitExists, u) then
            local e, source = markedEnemy(u)
            setIcon(u, e, source)
        end
    end
end

local function refreshAll()
    refreshPlates()
    if ui.refreshList then pcall(ui.refreshList) end
end

-- ---------------------------------------------------------------- mark / unmark

local function unmarkLink(key)
    return "|H" .. LINK_BASE .. "unmark:" .. key .. "|h|cff66bbff[" .. L.UNMARK_LINK .. "]|r|h"
end

local function hideLink(circle, key)
    return "|H" .. LINK_BASE .. "hide:" .. circle .. ":" .. key .. "|h|cff66bbff[" .. L.HIDE_LINK .. "]|r|h"
end

-- An attack warning about this player went out in the last CAST_HIT_GAP seconds: they started the fight.
local function castWarned(id)
    local t = castWarnedAt[id]
    return t ~= nil and now() - t < CAST_HIT_GAP
end

local function mark(unit, key, display, guid, how)
    local t = time()
    local e = db.players[key]
    if e then
        if how ~= "manual" and t - (e.last or 0) < RECOUNT_GAP then return end
        e.count = (e.count or 1) + 1
    else
        e = { first = t, count = 1 }
        db.players[key] = e
    end
    local zone = safe(GetZoneText) or "?"
    local sub = safe(GetSubZoneText) or ""
    local cls, clsFile = safe(UnitClass, unit)
    local lvl = safe(UnitLevel, unit)
    local guild = safe(GetGuildInfo, unit)
    e.name = display
    e.guid = guid or e.guid
    e.class = cls or e.class
    if type(clsFile) == "string" then e.classFile = clsFile end -- "ROGUE": whoever receives translates it to their language
    if type(lvl) == "number" and lvl > 0 then e.level = lvl end
    e.guild = guild or e.guild
    e.last = t
    e.where = (sub ~= "" and sub ~= zone) and (sub .. ", " .. zone) or zone
    e.how = how
    e.alertAt = t -- already in front of you; the "showed up" alert waits for next time
    if how == "manual" then
        say(string.format(L.MARKED_MANUAL, describe(e)) .. " " .. unmarkLink(key))
    else
        say(string.format(L.MARKED, describe(e), e.where, plural(e.count)) .. " " .. unmarkLink(key))
        doEmote(unit)
    end
    if how == "manual" or not castWarned(guid or key) then playAlert() end -- the attack warning already sounded
    refreshAll()
    if ns.share then pcall(ns.share.onMark, key, e) end
end

local function unmark(key)
    local e = db.players[key]
    if not e then say(L.NOT_MARKED) return end
    db.players[key] = nil
    say(string.format(L.UNMARKED, e.name or key))
    refreshAll()
    if ns.share then pcall(ns.share.onUnmark, key, e) end
end

-- "[unmark]" and "[hide]" links in the chat.
local lastLink, lastLinkAt = nil, 0
local function handleLink(link)
    if type(link) ~= "string" or link:sub(1, #LINK_BASE) ~= LINK_BASE then return end
    local t = GetTime()
    if lastLink == link and t - lastLinkAt < 0.5 then return end -- both hooks below may call
    lastLink, lastLinkAt = link, t
    local rest = link:sub(#LINK_BASE + 1)
    local key = rest:match("^unmark:(.+)$")
    if key then unmark(key) return end
    local circle, hidden = rest:match("^hide:(%a+):(.+)$")
    if circle and ns.share then ns.share.hide(circle, hidden) end
end
if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "SetItemRef", function(_, link) handleLink(link) end, f)
end
if type(SetItemRef) == "function" and type(hooksecurefunc) == "function" then
    pcall(hooksecurefunc, "SetItemRef", function(link) handleLink(link) end)
end

-- ---------------------------------------------------------------- who attacked you

local function candidateUnits()
    local list, seen = {}, {}
    local function add(u)
        if not safe(UnitExists, u) then return end
        local key = unitInfo(u)
        if key and not seen[key] then
            seen[key] = true
            table.insert(list, u)
        end
    end
    for i = 1, MAX_PLATES do add("nameplate" .. i) end
    add("target"); add("focus"); add("mouseover")
    return list
end

local function iAttackedFirst(key, guid)
    if not S.skipIfIAttacked then return false end
    local t = myAttacks[key]
    if guid and myAttackGuids[guid] and (not t or myAttackGuids[guid] > t) then t = myAttackGuids[guid] end
    return t and (now() - t) <= (S.myAttackMemory or 60)
end

local hasMyDebuff -- defined further below, next to the spell events

local function tryMark(u, key, display, guid, how)
    -- a warned spell means they started it: your attack during their cast is a reaction
    if (iAttackedFirst(key, guid) or hasMyDebuff(u)) and not castWarned(guid or key) then
        debug(string.format(L.DBG_FOUGHT_BACK, display))
    elseif tooLow(u) then
        debug(string.format(L.DBG_TOO_LOW, display))
    else
        mark(u, key, display, guid, how)
    end
end

local function scanForAttacker()
    local unknown = {}
    local found = false
    for _, u in ipairs(candidateUnits()) do
        if isEnemyPlayer(u) then
            local key, display, guid = unitInfo(u)
            local tm, ic = targetsMe(u), inCombat(u)
            debug(string.format(L.DBG_UNIT, display or "?", u, tostring(tm), tostring(ic)))
            if key and tm == true and ic ~= false then
                found = true
                tryMark(u, key, display, guid, "alvo")
            elseif key and tm == nil and ic ~= false then
                table.insert(unknown, { u, key, display, guid })
            end
        end
    end
    -- If the game hides who each one is targeting, it only marks when there is exactly one possible enemy.
    if not found and #unknown == 1 then
        local c = unknown[1]
        tryMark(c[1], c[2], c[3], c[4], "unico inimigo por perto")
    elseif not found and #unknown > 1 then
        debug(string.format(L.DBG_HIDDEN, #unknown))
    end
end

local function startScan(reason)
    if not S.enabled then return end
    if not inWorld() then return end
    if safe(UnitIsDeadOrGhost, "player") then return end
    debug(string.format(L.DBG_SCAN, reason))
    scanUntil = now() + SCAN_WINDOW
    nextScan = 0
end

-- You attacked someone: stores it (by key and by GUID) so we do not mark whoever only fought back.
local function rememberMyAttack(unit)
    lastOwnAction = now()
    if isEnemyPlayer(unit) then
        local key, display, guid = unitInfo(unit)
        if key then
            myAttacks[key] = now()
            if guid then myAttackGuids[guid] = now() end
            debug(string.format(L.DBG_I_ATTACKED, display))
        end
    end
end

-- true = offensive spell, false = helpful (heal, buff), nil = could not tell (secret value or missing API).
local function spellIsHarmful(spellID)
    if spellID == nil or isSecret(spellID) then return nil end
    if C_Spell and C_Spell.IsSpellHarmful then
        local h = safe(C_Spell.IsSpellHarmful, spellID)
        if h ~= nil then return h and true or false end
    end
    if C_Spell and C_Spell.IsSpellHelpful and safe(C_Spell.IsSpellHelpful, spellID) == true then return false end
    return nil
end

-- "Fedrath" from "Fedrath", "Fedrath-Vorn" or "Fedrath-Vorn-JxJ-US" (Forever uses all three formats), lowercase.
local function baseName(s) return string.lower(s:match("^([^%-]+)") or s) end

-- You cast a spell. If it is not helpful, it counts as an attack on the enemy player it hit.
-- In Forever the target name and the spell itself may come secret or in another format: with no way to check,
-- the enemy on your target (or mouseover/focus) counts. Better to skip marking someone than to mark whoever you attacked.
local function onSpellSent(targetName, spellID)
    if spellIsHarmful(spellID) == false then return end
    lastOwnAction = now()
    local tn = (type(targetName) == "string" and not isSecret(targetName) and targetName ~= "") and baseName(targetName) or nil
    local fallback
    for _, u in ipairs({ "target", "mouseover", "focus" }) do
        if isEnemyPlayer(u) then
            local name = safe(UnitName, u)
            if tn and type(name) == "string" then
                if baseName(name) == tn then rememberMyAttack(u) return end
            else
                fallback = fallback or u
            end
        end
    end
    if fallback then rememberMyAttack(fallback) return end
    if not tn then debug(L.DBG_CAST_UNKNOWN) end
end

-- End of a spell of yours (the ones with cast time enter combat when they land). Second chance to
-- store the attack if UNIT_SPELLCAST_SENT did not arrive or came unreadable: only when the game confirms the
-- spell is offensive, because there is no target name here.
local function onSpellDone(spellID)
    local harmful = spellIsHarmful(spellID)
    if harmful == false then return end
    lastOwnAction = now()
    if harmful then
        for _, u in ipairs({ "target", "mouseover", "focus" }) do
            if isEnemyPlayer(u) then rememberMyAttack(u) return end
        end
    end
end

-- Does the enemy already have a spell of yours on them (curse, Corruption...)? Then you attacked first.
-- Path independent of the spell events. If the game hides the auras, it decides nothing.
function hasMyDebuff(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    local aura = safe(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HARMFUL|PLAYER")
    return type(aura) == "table"
end

-- Unit events are registered only for "player"; if the game hides the field, it counts as yours.
local function isPlayerUnit(unit) return isSecret(unit) or unit == "player" end

-- ---------------------------------------------------------------- attack warning (an enemy starts a spell at you)

-- Forever hides the spell name and icon from addons (secret values), but text built from them still shows on
-- screen (seen in the chat). Only spells with a cast bar: an instant spell is marked on the hit, as before.
local WARNING_ICON = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:18|t "

local function castText(display, name, icon)
    local spell = L.CAST_SPELL_UNKNOWN
    if isSecret(name) or (type(name) == "string" and name ~= "") then
        spell = name
        if isSecret(icon) or type(icon) == "number" then spell = "|T" .. icon .. ":18|t " .. name end
    end
    return WARNING_ICON .. string.format(L.CAST_BEFORE, "|cffff8080" .. display .. "|r") .. " " .. spell .. " " .. L.CAST_AFTER
end

-- Once per enemy per fight, with the same rules as the mark: not if you attacked first or they are too low.
local function warnCast(unit, channel)
    if not S.castWarning or isSecret(unit) or type(unit) ~= "string" or not inWorld() then return end
    if safe(UnitIsDeadOrGhost, "player") or not isEnemyPlayer(unit) or targetsMe(unit) ~= true then return end
    local key, display, guid = unitInfo(unit)
    if not key then return end
    local id, t = guid or key, now()
    local last = castSeen[id]
    castSeen[id] = t
    if last and t - last < RECOUNT_GAP then return end -- not their first spell at you in this fight
    local e = findEntry(unit)
    if e and e.last and time() - e.last < RECOUNT_GAP then return end -- they already hit you: marked, with sound
    if iAttackedFirst(key, guid) or hasMyDebuff(unit) or tooLow(unit) then return end
    local ok, name, _, icon = pcall(channel and UnitChannelInfo or UnitCastingInfo, unit)
    if not ok then name, icon = nil, nil end
    castWarnedAt[id] = t
    local text = castText(display, name, icon)
    playAlert()
    centerWarning(text, S.center)
    if S.msg then say(text) end
end

-- ---------------------------------------------------------------- kill alert (chat only, no sound)

-- With no combat log, the addon cannot tell who dealt the killing blow. It reports enemy players you attacked
-- (or who had a spell of yours on them) in the last KILL_MEMORY seconds and then died in front of you.
-- shortcut: a hunter's Feign Death may look like a death; add a confirmation delay if that shows up in play.
local function lastHitOn(key, guid)
    local t = myAttacks[key] or 0
    if guid and (myAttackGuids[guid] or 0) > t then t = myAttackGuids[guid] end
    if (myDebuffSeen[guid or key] or 0) > t then t = myDebuffSeen[guid or key] end
    return t
end

local function announceKill(unit, display)
    local meDead = safe(UnitIsDeadOrGhost, "player") and true or false
    if S.killAlert == "afterDeath" and not meDead then return end
    local cls, lvl = safe(UnitClass, unit), safe(UnitLevel, unit)
    local who = describe({ name = display, class = cls, level = (type(lvl) == "number" and lvl > 0) and lvl or nil })
    local skull = "|T" .. RAID_ICON .. "8:14|t"
    if meDead and myDeathAt then
        say(string.format(L.KILLED_AFTER_DEATH, skull, who, math.floor(now() - myDeathAt + 0.5)))
    else
        say(string.format(L.KILLED, skull, who))
    end
end

local function checkKill(unit)
    if S.killAlert == "off" or not inWorld() or not safe(UnitIsPlayer, unit) then return end
    local key, display, guid = unitInfo(unit)
    if not key then return end
    local id = guid or key
    local ok, dead = pcall(UnitIsDead, unit)
    if not ok or isSecret(dead) then return end -- hidden during combat: the next check tries again
    if not dead then
        killed[id] = nil -- alive (or back from the graveyard): can be reported again
        if isEnemyPlayer(unit) and hasMyDebuff(unit) then myDebuffSeen[id] = now() end
        return
    end
    if killed[id] or now() - lastHitOn(key, guid) > KILL_MEMORY then return end
    killed[id] = true
    announceKill(unit, display)
end

local function checkKills()
    if S.killAlert == "off" or not inWorld() then return end
    for _, u in ipairs(candidateUnits()) do checkKill(u) end
end

-- ---------------------------------------------------------------- alert when a marked player shows up

-- Marks from friends and guild: chat message only (and, if on, the center alert); no sound.
local function checkUnit(unit, fromPlate)
    local e, source, key = markedEnemy(unit)
    if fromPlate then setIcon(unit, e, source) end
    if not e then return end
    if source ~= "mine" and not S.sharedAlerts then return end
    local t = time()
    if t - (e.alertAt or 0) < ALERT_GAP then return end
    e.alertAt = t
    e.seen = t
    if source == "mine" then
        playAlert()
        centerWarning("|T" .. sourceTexture("mine") .. ":18|t " .. string.format(L.NEARBY, e.name, plural(e.count or 1)), S.center)
        if S.msg then
            say("|cffffd100" .. L.SPOTTED .. "|r " .. string.format(L.SPOTTED_MSG, describe(e), plural(e.count or 1),
                day(e.last), e.where or "?"))
        end
        return
    end
    local label = circleLabel(source)
    centerWarning("|T" .. sourceTexture(source) .. ":18|t " .. string.format(L.NEARBY_SHARED, e.name, e.by or "?", label),
        S.sharedCenter)
    if S.msg then
        say("|cffffd100" .. L.SPOTTED .. "|r " .. string.format(L.SPOTTED_SHARED_MSG, describe(e), e.by or "?",
            plural(e.count or 1), label, day(e.last), e.where or "?") .. " " .. hideLink(source, key))
    end
end

-- Lines in the marked player's tooltip: yours and the ones from friends and guild.
local function onTooltipUnit(tooltip)
    if not S or not S.tooltip then return end
    if GameTooltip and tooltip ~= GameTooltip then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or type(unit) ~= "string" or isSecret(unit) then return end
    for _, m in ipairs(marksFor(unit)) do
        local e = m.e
        if m.source == "mine" then
            tooltip:AddLine(string.format(L.TOOLTIP_LINE, plural(e.count or 1), day(e.last), e.where or "?"), 1, 0.3, 0.3, true)
        else
            tooltip:AddLine(string.format(L.TOOLTIP_SHARED, circleLabel(m.source), e.by or "?", plural(e.count or 1),
                day(e.last), e.where or "?"), 1, 0.6, 0.3, true)
        end
    end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, onTooltipUnit)
elseif GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", onTooltipUnit)
end

-- ---------------------------------------------------------------- settings screen (Options > AddOns)

local LABEL_X, CONTROL_X, ROW = 20, 330, 26

local function addTooltip(widget, title, text)
    if not text then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function header(parent, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return y - 24
end

local function checkbox(parent, y, label, key, tip, onChange)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", LABEL_X, y)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    text:SetText(label)
    box:SetScript("OnClick", function(self)
        S[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    addTooltip(box, label, tip)
    table.insert(ui.refreshers, function() box:SetChecked(S[key] and true or false) end)
    ui.widgets[key] = box
    return y - ROW
end

local function slider(parent, y, label, key, min, max, step, suffix, onChange)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", LABEL_X + 28, y - 5)
    text:SetText(label)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(170, 18)
    s:SetPoint("TOPLEFT", CONTROL_X, y - 3)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.3, 0.3, 0.32, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(18, 24) end
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", s, "RIGHT", 8, 0)
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        v = math.floor(v / step + 0.5) * step
        value:SetText(v .. suffix)
        S[key] = v
        if onChange then onChange() end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)
    table.insert(ui.refreshers, function()
        updating = true
        s:SetValue(S[key])
        value:SetText(S[key] .. suffix)
        updating = false
    end)
    ui.widgets[key] = s
    return y - ROW
end

-- Button that cycles through the list's options (click: next; right-click: previous).
local function cycler(parent, y, label, key, list, onChange)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", LABEL_X + 28, y - 5)
    text:SetText(label)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(170, 22)
    btn:SetPoint("TOPLEFT", CONTROL_X, y)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 8, 0)
    local function show()
        local e = findIn(list, S[key])
        btn:SetText(labelOf(e))
        if e.icon then icon:SetTexture(e.icon) icon:Show() else icon:Hide() end
    end
    btn:SetScript("OnClick", function(_, button)
        local _, i = findIn(list, S[key])
        i = i + ((button == "RightButton") and -1 or 1)
        if i > #list then i = 1 elseif i < 1 then i = #list end
        S[key] = list[i].id
        show()
        if onChange then onChange() end
    end)
    addTooltip(btn, label, L.CYCLER_TIP)
    table.insert(ui.refreshers, show)
    ui.widgets[key] = btn
    return y - ROW, btn
end

local LIST_PAGE = 12

local function buildListPage(category)
    if not Settings.RegisterCanvasLayoutSubcategory then return end
    local p = CreateFrame("Frame")
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.LIST_TITLE)
    local info = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    ui.page = 1
    local rows = {}
    for i = 1, LIST_PAGE do
        local y = -64 - (i - 1) * 28
        local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 16, y - 4)
        text:SetWidth(480)
        text:SetJustifyH("LEFT")
        local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("TOPLEFT", 510, y)
        btn:SetText(L.BTN_UNMARK)
        rows[i] = { text = text, btn = btn }
    end
    local prev = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    prev:SetSize(90, 22)
    prev:SetPoint("TOPLEFT", 16, -64 - LIST_PAGE * 28 - 6)
    prev:SetText(L.BTN_PREV)
    local nextB = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    nextB:SetSize(90, 22)
    nextB:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    nextB:SetText(L.BTN_NEXT)
    -- Filter: your list, friends or guild (click: next; right-click: previous).
    ui.source = "mine"
    local filter = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    filter:SetSize(170, 22)
    filter:SetPoint("TOPLEFT", 440, -14)
    filter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function showFilter() filter:SetText(labelOf(findIn(LIST_SOURCES, ui.source))) end
    filter:SetScript("OnClick", function(_, button)
        local _, i = findIn(LIST_SOURCES, ui.source)
        i = i + ((button == "RightButton") and -1 or 1)
        if i > #LIST_SOURCES then i = 1 elseif i < 1 then i = #LIST_SOURCES end
        ui.source, ui.page = LIST_SOURCES[i].id, 1
        showFilter()
        ui.refreshList()
    end)
    addTooltip(filter, L.LIST_SHOW, L.CYCLER_TIP)
    ui.filterButton = filter
    function ui.refreshList()
        showFilter()
        local src = ui.source
        local list = (src == "mine") and db.players or (db.shared and db.shared[src]) or {}
        local all = {}
        for key, e in pairs(list) do
            if src == "mine" or (not e.hidden and e.last) then table.insert(all, { key = key, e = e }) end
        end
        table.sort(all, function(a, b) return (a.e.last or 0) > (b.e.last or 0) end)
        local pages = math.max(1, math.ceil(#all / LIST_PAGE))
        if ui.page > pages then ui.page = pages end
        info:SetText(#all == 0 and L.NOBODY or string.format(L.LIST_INFO, #all, ui.page, pages))
        for i = 1, LIST_PAGE do
            local r, item = rows[i], all[(ui.page - 1) * LIST_PAGE + i]
            if item then
                local e = item.e
                if src == "mine" then
                    r.text:SetText(string.format(L.LIST_ROW, describe(e), plural(e.count or 1), day(e.last), e.where or "?"))
                    r.btn:SetText(L.BTN_UNMARK)
                    r.btn:SetScript("OnClick", function() unmark(item.key) end)
                else
                    r.text:SetText(string.format(L.LIST_ROW_SHARED, describe(e), e.by or "?", plural(e.count or 1),
                        day(e.last), e.where or "?"))
                    r.btn:SetText(L.BTN_HIDE)
                    r.btn:SetScript("OnClick", function() if ns.share then ns.share.hide(src, item.key) end end)
                end
                r.text:Show() r.btn:Show()
            else
                r.text:Hide() r.btn:Hide()
            end
        end
        prev:SetShown(ui.page > 1)
        nextB:SetShown(ui.page < pages)
    end
    prev:SetScript("OnClick", function() ui.page = ui.page - 1 ui.refreshList() end)
    nextB:SetScript("OnClick", function() ui.page = ui.page + 1 ui.refreshList() end)
    p:SetScript("OnShow", function() pcall(ui.refreshList) end)
    local ok, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, category, p, L.LIST_CATEGORY)
    if ok then ui.listCategory = sub end
end

local function buildOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    ui.widgets = {}
    local panel = CreateFrame("Frame")
    local content = panel
    local okS, scroll = pcall(CreateFrame, "ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    if okS and scroll then
        scroll:SetPoint("TOPLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        content = CreateFrame("Frame", nil, scroll)
        content:SetSize(620, 1120)
        scroll:SetScrollChild(content)
    end
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|T" .. ICON_PATH .. ":20|t " .. L.TITLE)
    local sub = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText(L.SUBTITLE)
    local y = -64
    y = header(content, y, L.H_DETECTION)
    y = checkbox(content, y, L.OPT_ENABLED, "enabled", L.OPT_ENABLED_TIP)
    y = checkbox(content, y, L.OPT_CAST_WARNING, "castWarning", L.OPT_CAST_WARNING_TIP)
    y = checkbox(content, y, L.OPT_SKIP, "skipIfIAttacked", L.OPT_SKIP_TIP)
    y = slider(content, y, L.OPT_MEMORY, "myAttackMemory", 10, 300, 10, " s")
    y = checkbox(content, y, L.OPT_IGNORE_LOW, "ignoreLow", L.OPT_IGNORE_LOW_TIP)
    y = slider(content, y, L.OPT_LEVELS, "ignoreLowLevels", 1, 30, 1, "")
    y = y - 8
    y = header(content, y, L.H_REACTION)
    y = checkbox(content, y, L.OPT_EMOTE, "emote", L.OPT_EMOTE_TIP)
    local emoteBtn
    y, emoteBtn = cycler(content, y, L.OPT_EMOTE_WHICH, "emoteToken", EMOTES)
    local emoteTest = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    emoteTest:SetSize(110, 22)
    emoteTest:SetPoint("LEFT", emoteBtn, "RIGHT", 8, 0)
    emoteTest:SetText(L.BTN_TEST_TARGET)
    emoteTest:SetScript("OnClick", function()
        if safe(UnitExists, "target") then doEmote("target", true) else say(L.NEED_TARGET_EMOTE) end
    end)
    y = y - 8
    y = header(content, y, L.H_PLATE)
    y = cycler(content, y, L.OPT_ICON, "icon", ICONS, refreshPlates)
    y = cycler(content, y, L.OPT_ICON_FRIENDS, "friendsIcon", ICONS, refreshPlates)
    y = cycler(content, y, L.OPT_ICON_GUILD, "guildIcon", ICONS, refreshPlates)
    y = slider(content, y, L.OPT_ICON_SIZE, "iconSize", 16, 48, 2, "", refreshPlates)
    y = checkbox(content, y, L.OPT_COUNT, "showCount", L.OPT_COUNT_TIP, refreshPlates)
    y = y - 8
    y = header(content, y, L.H_ALERTS)
    y = checkbox(content, y, L.OPT_SOUND, "sound")
    local soundBtn
    y, soundBtn = cycler(content, y, L.OPT_SOUND_WHICH, "soundId", SOUNDS)
    local test = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    test:SetSize(70, 22)
    test:SetPoint("LEFT", soundBtn, "RIGHT", 8, 0)
    test:SetText(L.BTN_TEST)
    test:SetScript("OnClick", function() playAlert(true) end)
    y = checkbox(content, y, L.OPT_MSG, "msg")
    y = checkbox(content, y, L.OPT_CENTER, "center")
    y = checkbox(content, y, L.OPT_TOOLTIP, "tooltip", L.OPT_TOOLTIP_TIP)
    y = y - 8
    y = header(content, y, L.H_INTERFACE)
    y = checkbox(content, y, L.OPT_MINIMAP, "minimap", L.OPT_MINIMAP_TIP, function() ui.showMinimap() end)
    y = cycler(content, y, L.OPT_LANGUAGE, "language", LANGS, function() ui.languageChanged() end)
    y = y - 8
    y = header(content, y, L.H_SHARE)
    local function shareChanged()
        refreshAll()
        if ns.share then pcall(ns.share.settingsChanged) end
    end
    y = checkbox(content, y, L.OPT_SHARE_GUILD, "shareGuild", L.OPT_SHARE_GUILD_TIP, shareChanged)
    y = checkbox(content, y, L.OPT_SHARE_FRIENDS, "shareFriends", L.OPT_SHARE_FRIENDS_TIP, shareChanged)
    y = checkbox(content, y, L.OPT_SHARE_BNET, "shareBnet", L.OPT_SHARE_BNET_TIP, shareChanged)
    y = checkbox(content, y, L.OPT_SHARED_ALERTS, "sharedAlerts", L.OPT_SHARED_ALERTS_TIP)
    y = checkbox(content, y, L.OPT_SHARED_CENTER, "sharedCenter")
    y = y - 8
    y = header(content, y, L.H_KILLS)
    y = cycler(content, y, L.OPT_KILL, "killAlert", KILL_ALERTS)
    y = y - 8
    y = header(content, y, L.H_TEST)
    y = checkbox(content, y, L.OPT_TEST, "test", nil, refreshPlates)
    y = checkbox(content, y, L.OPT_DEBUG, "debug")
    panel:SetScript("OnShow", refreshUI)
    for _, r in ipairs(ui.refreshers) do pcall(r) end
    local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
    Settings.RegisterAddOnCategory(category)
    ui.category = category
    buildListPage(category)
end

local function openOptions()
    if not ui.category then say(L.NO_OPTIONS) return end
    local id = ui.category.GetID and ui.category:GetID() or ui.category.ID
    if not pcall(Settings.OpenToCategory, id) then say(L.OPEN_OPTIONS) end
end

local function onOff(v) return v and L.ON or L.OFF end

local function toggle(key, label)
    S[key] = not S[key]
    say(label .. " " .. onOff(S[key]) .. ".")
    refreshUI()
end

-- Language: messages change right away; the fixed texts of the settings screen only after /reload.
local function setLanguage(id)
    S.language = findIn(LANGS, id).id
    lang = pickLanguage(S.language)
    say(string.format(L.LANG_SET, labelOf(findIn(LANGS, S.language))))
    refreshUI()
end
function ui.languageChanged() setLanguage(S.language) end

-- ---------------------------------------------------------------- minimap button and addons menu
-- Built without a library, with the art and measures LibDBIcon uses on the modern client.

local function markedCount()
    local n = 0
    for _ in pairs(db.players) do n = n + 1 end
    return n
end

local function launcherTooltip(owner, canDrag)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("|T" .. ICON_PATH .. ":16|t " .. L.TITLE, 1, 1, 1)
    GameTooltip:AddLine(string.format(L.TIP_STATUS, onOff(S.enabled)), 1, 0.82, 0)
    GameTooltip:AddLine(string.format(L.TIP_COUNT, markedCount()), 1, 0.82, 0)
    GameTooltip:AddLine(string.format(L.TIP_SHARED_COUNT, sharedCount("friends"), sharedCount("guild")), 1, 0.82, 0)
    GameTooltip:AddLine(L.TIP_LEFT, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.TIP_RIGHT, 0.8, 0.8, 0.8)
    if canDrag then GameTooltip:AddLine(L.TIP_DRAG, 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end

-- Left click: settings. Right: turns automatic marking on/off.
local function launcherClick(button)
    if not db then return end
    if button == "RightButton" then toggle("enabled", L.T_ENABLED) else openOptions() end
end

-- Addons menu next to the minimap (AddonCompartmentFunc lines in the .toc). They must be global.
function PvPWatchlist_OnAddonCompartmentClick(_, button) launcherClick(button) end
function PvPWatchlist_OnAddonCompartmentEnter(_, menuButton) if db then launcherTooltip(menuButton, false) end end
function PvPWatchlist_OnAddonCompartmentLeave() if GameTooltip then GameTooltip:Hide() end end

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function placeMinimap(b, angle)
    local a = math.rad(tonumber(angle) or DEFAULTS.minimapAngle)
    local x, y = math.cos(a), math.sin(a)
    local w = (Minimap:GetWidth() or 140) / 2 + 5
    local h = (Minimap:GetHeight() or 140) / 2 + 5
    local square = type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE"
    if square then
        x = math.max(-w, math.min(x * (math.sqrt(2 * w * w) - 10), w))
        y = math.max(-h, math.min(y * (math.sqrt(2 * h * h) - 10), h))
    else
        x, y = x * w, y * h
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function followCursor(b)
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    if not (mx and my and scale and cx and cy) or isSecret(mx) or isSecret(cx) then return end
    cx, cy = cx / scale, cy / scale
    b.dragAngle = math.deg(atan2(cy - my, cx - mx)) % 360
    placeMinimap(b, b.dragAngle)
end

local function buildMinimapButton()
    if ui.minimapButton or not Minimap then return end
    local b = CreateFrame("Button", "PvPWatchlistMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_PATH)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(_, button) launcherClick(button) end)
    b:SetScript("OnEnter", function(self) if not self.dragging then launcherTooltip(self, true) end end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragAngle = S.minimapAngle
        if GameTooltip then GameTooltip:Hide() end
        self:SetScript("OnUpdate", followCursor)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.dragging = false
        S.minimapAngle = self.dragAngle or S.minimapAngle
        placeMinimap(self, S.minimapAngle)
    end)
    placeMinimap(b, S.minimapAngle)
    b:SetShown(S.minimap and true or false)
    ui.minimapButton = b
end

function ui.showMinimap()
    if ui.minimapButton then
        placeMinimap(ui.minimapButton, S.minimapAngle)
        ui.minimapButton:SetShown(S.minimap and true or false)
    end
end

-- ---------------------------------------------------------------- commands

local function findKeysByName(text)
    local q = string.lower(text)
    local keys = {}
    for key, e in pairs(db.players) do
        if key == q or key:find("^" .. q:gsub("%p", "%%%0") .. "%-") or string.lower(e.name or "") == q then
            table.insert(keys, key)
        end
    end
    return keys
end

-- source = nil (your list), "friends" or "guild".
local function listMarked(source)
    local list = source and (db.shared and db.shared[source] or {}) or db.players
    local rows = {}
    for key, e in pairs(list) do
        if not source or (not e.hidden and e.last) then table.insert(rows, { key = key, e = e }) end
    end
    table.sort(rows, function(a, b) return (a.e.last or 0) > (b.e.last or 0) end)
    if #rows == 0 then say(L.NOBODY) return end
    say(source and string.format(L.LIST_HEADER_SHARED, #rows, circleLabel(source)) or string.format(L.LIST_HEADER, #rows))
    for i, r in ipairs(rows) do
        if i > 40 then say(string.format(L.LIST_MORE, #rows - 40)) break end
        local e = r.e
        if source then
            DEFAULT_CHAT_FRAME:AddMessage("  " .. string.format(L.LIST_ROW_SHARED, describe(e), e.by or "?",
                plural(e.count or 1), day(e.last, L.DATE_TIME), e.where or "?") .. " " .. hideLink(source, r.key))
        else
            DEFAULT_CHAT_FRAME:AddMessage("  " .. string.format(L.LIST_ROW, describe(e), plural(e.count or 1),
                day(e.last, L.DATE_TIME), e.where or "?") .. " " .. unmarkLink(r.key))
        end
    end
end

-- Each command accepts the name in Portuguese and in English.
local COMMANDS = {
    lista = "list", list = "list",
    config = "config", opcoes = "config", ["opções"] = "config", options = "config",
    tirar = "remove", remove = "remove", unmark = "remove",
    apagar = "delete", delete = "delete",
    marcar = "mark", mark = "mark",
    teste = "test", test = "test",
    som = "sound", sound = "sound",
    mensagem = "message", message = "message", msg = "message",
    emote = "emote",
    minimapa = "minimap", minimap = "minimap",
    idioma = "language", language = "language", lang = "language",
    debug = "debug",
    compartilhar = "share", share = "share", enviar = "share", sync = "share",
    bloquear = "block", block = "block",
    desbloquear = "unblock", unblock = "unblock",
}
local LIST_ARGS = { amigos = "friends", friends = "friends", guilda = "guild", guild = "guild" }
local LANG_ARGS = { auto = "auto", pt = "ptBR", ptbr = "ptBR", ["português"] = "ptBR", portugues = "ptBR",
    en = "enUS", enus = "enUS", english = "enUS", ingles = "enUS", ["inglês"] = "enUS" }

-- /kos becomes a shortcut only if no other addon (for example Kill on Sight) already uses it. Runs on PLAYER_LOGIN,
-- when the other addons have already registered their commands.
local function kosOwner()
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and k:find("^SLASH_.+%d$")
            and not k:find("^SLASH_PVPWATCHLIST%d") and string.lower(v) == "/kos" then
            return k
        end
    end
end

local function registerKosAlias()
    local ok, owner = pcall(kosOwner)
    if not ok then return end
    if owner then debug(string.format(L.DBG_KOS_TAKEN, owner)) return end
    SLASH_PVPWATCHLIST2 = "/kos"
end

SLASH_PVPWATCHLIST1 = "/pvpw"
SlashCmdList.PVPWATCHLIST = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = COMMANDS[string.lower(cmd or "")]
    if cmd == "list" then
        listMarked(LIST_ARGS[string.lower(rest)])
    elseif cmd == "share" then
        local n = ns.share and ns.share.syncNow(false)
        if n then say(string.format(L.SHARE_QUEUED, n)) else say(L.SHARE_OFF) end
    elseif cmd == "block" or cmd == "unblock" then
        if rest == "" then say(L.NEED_NAME)
        elseif ns.share then ns.share[cmd](rest) end
    elseif cmd == "config" then
        openOptions()
    elseif cmd == "remove" then
        local e, key = findEntry("target")
        if e then unmark(key) else say(L.TARGET_NOT_MARKED) end
    elseif cmd == "delete" and rest ~= "" then
        local keys = findKeysByName(rest)
        if #keys == 0 then say(string.format(L.NOBODY_NAMED, rest)) end
        for _, k in ipairs(keys) do unmark(k) end
    elseif cmd == "mark" then
        if isEnemyPlayer("target") then
            local key, display, guid = unitInfo("target")
            if key then mark("target", key, display, guid, "manual") end
        else
            say(L.NEED_ENEMY_TARGET)
        end
    elseif cmd == "test" then
        S.test = not S.test
        say(string.format(L.TEST_MODE, onOff(S.test)) .. (S.test and L.TEST_MODE_ON or "."))
        refreshPlates()
        refreshUI()
    elseif cmd == "sound" then
        toggle("sound", L.T_SOUND)
    elseif cmd == "message" then
        toggle("msg", L.T_MSG)
    elseif cmd == "emote" then
        toggle("emote", L.T_EMOTE)
    elseif cmd == "minimap" then
        toggle("minimap", L.T_MINIMAP)
        ui.showMinimap()
    elseif cmd == "language" then
        local id = LANG_ARGS[string.lower(rest)]
        if id then setLanguage(id) else say(L.LANG_USAGE) end
    elseif cmd == "debug" then
        toggle("debug", L.T_DEBUG)
    else
        local help = L.HELP
        say(help[1])
        for i = 2, #help do DEFAULT_CHAT_FRAME:AddMessage(help[i]) end
    end
end

-- ---------------------------------------------------------------- events

f:SetScript("OnUpdate", function(_, elapsed)
    if db and ns.share then pcall(ns.share.onUpdate, elapsed) end -- send queue of the sharing
    local t = now()
    if db and t >= nextKillCheck then
        nextKillCheck = t + KILL_STEP
        checkKills()
    end
    if scanUntil == 0 then return end
    if t > scanUntil then scanUntil = 0 return end
    if t >= nextScan then
        nextScan = t + SCAN_STEP
        scanForAttacker()
    end
end)

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        PvPWatchlistDB = PvPWatchlistDB or {}
        db = PvPWatchlistDB
        db.players = db.players or {}
        db.settings = db.settings or {}
        db.shared = db.shared or {}
        for _, c in ipairs(CIRCLES) do db.shared[c] = db.shared[c] or {} end
        db.blocked = db.blocked or {}
        S = db.settings
        for k, v in pairs(DEFAULTS) do
            if S[k] == nil then S[k] = v end
        end
        lang = pickLanguage(S.language)
        local ok, err = pcall(buildOptions)
        if not ok then debug(string.format(L.DBG_OPTIONS_FAILED, tostring(err))) end
        local okM, errM = pcall(buildMinimapButton)
        if not okM then debug(string.format(L.DBG_MINIMAP_FAILED, tostring(errM))) end
        say(string.format(L.LOADED, markedCount()))
        return
    end
    if not db then return end
    if ns.share and ns.share.events[event] then
        local ok, err = pcall(ns.share.onEvent, event, ...)
        if not ok then debug(string.format(L.DBG_SHARE_FAILED, tostring(err))) end
        return
    end
    if event == "PLAYER_LOGIN" then
        registerKosAlias()
        if ns.share then pcall(ns.share.onLogin) end
    elseif event == "UNIT_COMBAT" then
        local unit, action = ...
        if not isPlayerUnit(unit) then return end
        if isSecret(action) or ATTACK_ACTIONS[action] then
            startScan(string.format(L.DBG_HIT, isSecret(action) and "?" or tostring(action)))
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat right after an action of yours: you started it. Only a hit on you starts the scan.
        if now() - lastOwnAction <= OWN_COMBAT_GAP then debug(L.DBG_COMBAT_MINE) else startScan(L.DBG_COMBAT) end
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, targetName, _, spellID = ...
        if isPlayerUnit(unit) then onSpellSent(targetName, spellID) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if isPlayerUnit(unit) then onSpellDone(spellID) end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        warnCast(..., event == "UNIT_SPELLCAST_CHANNEL_START")
    elseif event == "PLAYER_ENTER_COMBAT" then -- auto attack (melee)
        rememberMyAttack("target")
    elseif event == "PET_ATTACK_START" then
        rememberMyAttack("pettarget")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        checkUnit(unit, true)
        if scanUntil > 0 then nextScan = 0 end -- new enemy on screen during the scan: look right away
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        checkKill(...) -- the nameplate may go away as the enemy dies, before the next check
        setIcon(..., nil)
    elseif event == "PLAYER_DEAD" then
        myDeathAt = now()
    elseif event == "PLAYER_TARGET_CHANGED" then
        checkUnit("target", false)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        checkUnit("mouseover", false)
    elseif event == "PLAYER_ENTERING_WORLD" then
        refreshPlates()
        ui.showMinimap() -- the minimap may change size after loading
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_ENTER_COMBAT")
f:RegisterEvent("PET_ATTACK_START")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("UNIT_SPELLCAST_START")         -- any unit: the attack warning looks at enemy nameplates
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
if f.RegisterUnitEvent then
    f:RegisterUnitEvent("UNIT_COMBAT", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    f:RegisterEvent("UNIT_COMBAT")
    f:RegisterEvent("UNIT_SPELLCAST_SENT")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

-- What Share.lua (loaded after this file) uses from here.
ns.core = {
    L = L, safe = safe, isSecret = isSecret, say = say, debug = debug, now = now, inWorld = inWorld,
    CIRCLES = CIRCLES,
    db = function() return db end,
    settings = function() return S end,
    refresh = refreshAll,
    registerEvent = function(event) pcall(f.RegisterEvent, f, event) end, -- event the client does not have: ignore
}
