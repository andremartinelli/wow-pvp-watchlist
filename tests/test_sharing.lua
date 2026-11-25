-- Simulation of the WoW API to test PvP Watchlist sharing with friends, guild and Battle.net.
local clock = 1000
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end
local units, secretTargeting = {}, false
local function resolve(u)
  if units[u] then return units[u] end
  local base = u:match("^(.+)target$")
  if base then local b = resolve(base); if b and b.target then return resolve(b.target) end end
end
UnitExists = function(u) return resolve(u) ~= nil end
UnitIsUnit = function(a, b)
  if secretTargeting and a:match("target$") and a ~= "target" then return SECRET end
  local ra, rb = resolve(a), resolve(b); return ra ~= nil and ra == rb end
UnitName = function(u) local r = resolve(u); if r then return r.name, nil end end
UnitGUID = function(u) local r = resolve(u); return r and r.guid end
UnitIsPlayer = function(u) local r = resolve(u); return r and r.isPlayer or false end
UnitCanAttack = function(_, u) local r = resolve(u); return r and r.canAttack or false end
UnitIsEnemy = function(_, u) local r = resolve(u); return r and r.enemy or false end
UnitAffectingCombat = function(u) local r = resolve(u); return r and r.combat or false end
UnitClass = function(u) local r = resolve(u); if r then return r.class, r.classFile end end
UnitLevel = function(u) local r = resolve(u); return r and r.level end
GetGuildInfo = function(u) local r = resolve(u); return r and r.guild end
UnitIsDeadOrGhost = function() return false end
local instance = false
IsInInstance = function() if instance then return true, "party" end return false, "none" end
GetZoneText = function() return "Stranglethorn" end
GetSubZoneText = function() return "" end
GetTime = function() return clock end
time = function() return 1795000000 + math.floor(clock) end
date = os.date
UNKNOWNOBJECT = "Desconhecido"
GetLocale = function() return "ptBR" end
GetNormalizedRealmName = function() return "Reino" end
LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Ladino", MAGE = "Mago", WARRIOR = "Guerreiro" }
SOUNDKIT = { RAID_WARNING = 8959 }
local sounds = 0
PlaySound = function() sounds = sounds + 1 end
C_Spell = { IsSpellHarmful = function() return true end }
local out, centers = {}, {}
local function clean(m) return (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "[icone]")) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) m = clean(m); table.insert(out, m); print("  chat> " .. m) end }
RaidWarningFrame = {}
RaidNotice_AddMessage = function(_, text) table.insert(centers, clean(text)) end

-- addon messages
local sent, bnSent, prefixes, lockdown = {}, {}, {}, false
C_ChatInfo = {
  RegisterAddonMessagePrefix = function(p) prefixes[p] = true return true end,
  SendAddonMessage = function(prefix, text, kind, target)
    table.insert(sent, { prefix = prefix, text = text, kind = kind, target = target }); return 0 end,
  InChatMessagingLockdown = function() return lockdown end,
  PerformEmote = function() return true end,
}
-- guild and friends
local roster = { "Jogador-Reino", "Guildeiro-Reino", "Outro-Reino" }
IsInGuild = function() return true end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) return roster[i] end
C_GuildInfo = { GuildRoster = function() end }
local friends = { { name = "Amigo", connected = true }, { name = "Sumido", connected = false } }
C_FriendList = {
  GetNumFriends = function() return #friends end,
  GetFriendInfoByIndex = function(i) return friends[i] end,
  GetFriendInfo = function(name) for _, f in ipairs(friends) do if f.name == name then return f end end end,
}
-- Battle.net: a friend playing the same game on another realm
BNET_CLIENT_WOW, WOW_PROJECT_ID = "WoW", 99
BNGetNumFriends = function() return 1 end
C_BattleNet = {
  GetFriendNumGameAccounts = function() return 1 end,
  GetFriendGameAccountInfo = function() return { gameAccountID = 77, isOnline = true, clientProgram = "WoW", wowProjectID = 99,
    characterName = "Distante", realmName = "Outro Reino" } end,
  GetGameAccountInfoByID = function(id) if id == 77 then return { characterName = "Distante", realmName = "Outro Reino" } end end,
}
BNSendGameData = function(id, prefix, text) table.insert(bnSent, { id = id, prefix = prefix, text = text }) end

-- nameplates, tooltip and event frame
local plates = {}
local function newPlate()
  local function mk() local t = { shown = false }
      function t:SetTexture(p) self.texture = p end function t:SetSize() end function t:SetPoint() end function t:ClearAllPoints() end
      function t:SetText(s) self.text = s end function t:Show() self.shown = true end function t:Hide() self.shown = false end
      return t end
  return { CreateTexture = function() return mk() end, CreateFontString = function() return mk() end,
    IsForbidden = function() return false end }
end
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
local tooltipHook
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end }
local eventFrame
CreateFrame = function()
  local fr = { scripts = {} }
  function fr:SetScript(k, fn) self.scripts[k] = fn end
  function fr:RegisterEvent() eventFrame = self end
  function fr:RegisterUnitEvent() eventFrame = self end
  return fr
end
SlashCmdList = {}
SetItemRef = function() end
hooksecurefunc = function(name, hook) local orig = _G[name]; _G[name] = function(...) orig(...); hook(...) end end

local function fire(e, ...) eventFrame.scripts.OnEvent(eventFrame, e, ...) end
local function tick(s) local stop = clock + s; while clock < stop do clock = clock + 0.1; eventFrame.scripts.OnUpdate(eventFrame, 0.1) end end
local function slash(msg) SlashCmdList.PVPWATCHLIST(msg) end
local function has(pat, list) for _, m in ipairs(list or out) do if m:find(pat) then return true end end return false end
local fails = 0
local function check(cond, label) print((cond and "OK   " or "FAIL ") .. label); if not cond then fails = fails + 1 end end
local function addPlate(token, data) units[token] = data; plates[token] = newPlate(); fire("NAME_PLATE_UNIT_ADDED", token) end
local function removePlate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end
local function hit() fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1); tick(1) end
local function sentHas(kind, target, pat)
  for _, m in ipairs(sent) do
    if m.prefix == "PvPW" and m.kind == kind and (target == nil or m.target == target) and (pat == nil or m.text:find(pat)) then return true end
  end
  return false
end
local function anySent(word) for _, m in ipairs(sent) do if m.text:find(word, 1, true) then return true end end return false end
local function allShort()
  for _, list in ipairs({ sent, bnSent }) do for _, m in ipairs(list) do if #m.text > 255 then return false end end end
  return true
end
local SEP = "\031"
local function M(name, o)
  o = o or {}
  return table.concat({ "M1", name, o.guid or "", o.class or "", o.classFile or "", tostring(o.level or ""), o.guild or "",
    tostring(o.count or 1), tostring(o.last or time()), o.where or "Vale", o.realm or "Reino" }, SEP)
end
local function U(name, realm) return table.concat({ "U1", name, realm or "Reino" }, SEP) end
local function addonMsg(text, kind, sender) fire("CHAT_MSG_ADDON", "PvPW", text, kind, sender, "Jogador-Reino") end

-- Data that already existed (same fields as the list migrated from killonsight), with non-default settings.
-- No update may lose or change any of it: it is checked right after loading and at the end of the test.
units.player = { name = "Jogador", isPlayer = true, level = 30 }
PvPWatchlistDB = { settings = { icon = 7, iconSize = 40, myAttackMemory = 90, minimap = false, msg = true }, players = {
  velho = { name = "Velho", guid = "Player-1-OLD", class = "Bruxo", level = 33, guild = "Os Antigos", count = 2,
    first = time() - 900, last = time() - 100, where = "Vale", how = "alvo", alertAt = time() - 100, seen = time() - 50 },
  incerto = { name = "Incerto", guid = "Player-1-UNS", class = "Mago", level = 29, count = 1,
    first = time() - 900, last = time() - 100, where = "Vale", how = "unico inimigo por perto", alertAt = time() - 100 },
} }
local function deepcopy(t) if type(t) ~= "table" then return t end local c = {} for k, v in pairs(t) do c[k] = deepcopy(v) end return c end
-- Lists what was in "old" and vanished or changed in "new" (new fields in "new" are allowed).
local function lost(new, old, path, out)
  out = out or {}
  for k, v in pairs(old) do
    local p = path .. "." .. tostring(k)
    if type(v) == "table" then
      if type(new[k]) ~= "table" then table.insert(out, p) else lost(new[k], v, p, out) end
    elseif new[k] ~= v then table.insert(out, p .. " (" .. tostring(v) .. " -> " .. tostring(new[k]) .. ")") end
  end
  return out
end
local before = deepcopy(PvPWatchlistDB)
local ns = {}
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
assert(loadfile("PvPWatchlist.lua"))("PvPWatchlist", ns)
assert(loadfile("Share.lua"))("PvPWatchlist", ns)
fire("ADDON_LOADED", "PvPWatchlist")
local DB, S = PvPWatchlistDB, PvPWatchlistDB.settings
local gone = lost(DB, before, "db")
check(#gone == 0, "loading the new version does not lose or change any saved data" .. (#gone > 0 and (": " .. table.concat(gone, ", ")) or ""))
check(S.shareGuild == true and S.friendsIcon == 7, "and only adds the new settings")
check(prefixes.PvPW, "PvPW message prefix registered")
check(S.icon == 7 and S.friendsIcon == 7 and S.guildIcon == 4, "the X chosen for your list stays; friends X and guild triangle by default")
S.icon = 8
check(DB.shared.friends and DB.shared.guild and DB.blocked, "received lists and blocked list created")
check(S.shareGuild and S.shareFriends and not S.shareBnet and S.sharedAlerts and not S.sharedCenter, "sharing defaults")

print("-- texts in both languages")
local pt, en, miss = ns.LOCALES.ptBR, ns.LOCALES.enUS, 0
for k in pairs(pt) do if en[k] == nil then miss = miss + 1 print("  falta em enUS: " .. k) end end
for k in pairs(en) do if pt[k] == nil then miss = miss + 1 print("  falta em ptBR: " .. k) end end
check(miss == 0 and #pt.HELP == #en.HELP, "same keys in ptBR and enUS")

print("-- login: waits, asks for the lists and sends only the trustworthy marks")
fire("PLAYER_LOGIN")
tick(5)
check(#sent == 0, "nothing sent in the first seconds")
tick(15)
check(sentHas("GUILD", nil, "^H1$") and sentHas("WHISPER", "Amigo", "^H1$"), "asks for the lists in the guild and from the online friend")
check(not sentHas("WHISPER", "Sumido"), "does not send to an offline friend")
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Velho" .. SEP), "sends the trustworthy mark (Velho)")
check(not anySent("Incerto"), "does not send an uncertain mark (only enemy nearby)")
check(#bnSent == 0, "Battle.net off: nothing goes through it")

print("-- marking someone sends right away, one message per second")
sent = {}
addPlate("nameplate1", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = "player",
  combat = true, class = "Ladino", classFile = "ROGUE", level = 32, guild = "Horda" })
hit()
check(#sent == 1, "queued: one goes out per second")
tick(3)
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Ganker" .. SEP .. "Player%-1%-AAA" .. SEP .. "Ladino" .. SEP .. "ROGUE" .. SEP .. "32" .. SEP .. "Horda" .. SEP .. "1" .. SEP),
  "goes to the guild with the class in English (ROGUE) so the receiver translates")
check(sentHas("WHISPER", "Amigo", "^M1" .. SEP .. "Ganker"), "and to the online friend")
removePlate("nameplate1")

print("-- receives from the guild: guild icon, message without sound and without center warning")
sounds, centers, out = 0, {}, {}
addonMsg(M("Rival", { guid = "Player-1-BBB", class = "Rogue", classFile = "ROGUE", level = 31, count = 2, last = time() - 60 }), "GUILD", "Guildeiro-Reino")
local g = DB.shared.guild.rival
check(g and g.by == "Guildeiro" and g.count == 2 and g.class == "Ladino", "stored in the guild list, with the class translated")
addPlate("nameplate2", { name = "Rival", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, level = 31 })
check(plates.nameplate2.kosSkull and plates.nameplate2.kosSkull.texture:find("_4$"), "guild icon (triangle) on the nameplate")
check(plates.nameplate2.kosCount.text == "2", "attack count next to it")
check(has("Apareceu: Rival %(Ladino 31%) %- atacou Guildeiro 2 vezes %(guilda%)") and has("%[ocultar%]"), "message with who marked and the [ocultar] link")
check(sounds == 0 and #centers == 0, "no sound and no center warning")
local tip = { lines = {} }
tip.GetUnit = function() return "Rival", "nameplate2" end
tip.AddLine = function(self, s) table.insert(self.lines, s) end
GameTooltip = tip
tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist %(guilda%): atacou Guildeiro 2 vezes"), "tooltip: " .. tostring(tip.lines[1]))
S.sharedCenter = true; DB.shared.guild.rival.alertAt = 0; removePlate("nameplate2")
addPlate("nameplate2", { name = "Rival", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, level = 31 })
check(has("Rival por perto %- marcado por Guildeiro %(guilda%)", centers), "center warning when on")
S.sharedCenter = false

print("-- receives from a friend: X icon")
addonMsg(M("Cacador", { guid = "Player-1-CCC", class = "Mage", classFile = "MAGE", count = 1 }), "WHISPER", "Amigo-Reino")
check(DB.shared.friends.cacador and DB.shared.friends.cacador.by == "Amigo", "stored in the friends list")
addPlate("nameplate3", { name = "Cacador", guid = "Player-1-CCC", isPlayer = true, enemy = true, canAttack = true })
check(plates.nameplate3.kosSkull.texture:find("_7$"), "friends icon (X) on the nameplate")

print("-- icon chosen for each list, even the same one for all")
S.friendsIcon, S.guildIcon = 2, 5
fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate3.kosSkull.texture:find("_2$") and plates.nameplate2.kosSkull.texture:find("_5$"),
  "friends with Circle and guild with Moon")
S.icon, S.friendsIcon, S.guildIcon = 8, 8, 8
fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate3.kosSkull.texture:find("_8$") and plates.nameplate2.kosSkull.texture:find("_8$"), "all three lists with the skull")
tip.lines = {}; tip.GetUnit = function() return "Cacador", "nameplate3" end; tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("%(amigos%)"), "with the same icon, the tooltip still says where it came from")
tip.GetUnit = function() return "Rival", "nameplate2" end
S.icon, S.friendsIcon, S.guildIcon = 8, 7, 4
fire("PLAYER_ENTERING_WORLD")

print("-- strangers and your own message are ignored")
addonMsg(M("Ninguem"), "WHISPER", "Estranho-Reino")
check(not DB.shared.friends.ninguem and not DB.shared.guild.ninguem, "stranger ignored")
addonMsg(M("Eco"), "GUILD", "Jogador-Reino")
check(not DB.shared.guild.eco, "your own message in the guild is ignored")
addonMsg(M("Falso", { guid = "x" }), "WHISPER", SECRET)
check(not DB.shared.friends.falso and not DB.shared.guild.falso, "secret sender ignored")

print("-- your own mark comes first")
units.target = units.nameplate2
slash("marcar")
check(plates.nameplate2.kosSkull.texture:find("_8$"), "marked by you: your icon in place of the guild one")
tip.lines = {}; tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist: te atacou") and tip.lines[2] and tip.lines[2]:find("%(guilda%)"),
  "tooltip with your line and the guild one")
units.target = nil

print("-- sender unmarks")
addonMsg(U("Rival"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.rival == nil, "U1 deletes his mark")

print("-- hide and come back when marked again")
local lastC = DB.shared.friends.cacador.last
out = {}; SetItemRef("addon:PvPWatchlist:hide:friends:cacador", "[ocultar]", "LeftButton")
check(DB.shared.friends.cacador.hidden and has("Cacador ocultado"), "[ocultar] link hides")
check(plates.nameplate3.kosSkull.shown == false, "X icon disappears from the nameplate")
addonMsg(M("Cacador", { guid = "Player-1-CCC", last = lastC }), "WHISPER", "Amigo-Reino")
check(DB.shared.friends.cacador.hidden, "the same mark again: stays hidden")
addonMsg(M("Cacador", { guid = "Player-1-CCC", last = lastC + 500, count = 2 }), "WHISPER", "Amigo-Reino")
check(not DB.shared.friends.cacador.hidden and plates.nameplate3.kosSkull.shown, "marked again later: shows up again")

print("-- list request (H1)")
tick(15); sent = {}
addonMsg("H1", "WHISPER", "Amigo-Reino"); tick(5)
check(sentHas("WHISPER", "Amigo-Reino", "^M1" .. SEP .. "Velho") and not sentHas("GUILD", nil, "^M1" .. SEP .. "Velho"),
  "replies only to whoever asked, by whisper")

print("-- the queue waits: chat block, combat and instance")
tick(10); sent = {}
lockdown = true; out = {}; slash("compartilhar"); tick(5)
check(has("mensagem%(ns%) na fila") and #sent == 0, "chat block: nothing goes out")
lockdown = false; units.player.combat = true; tick(3)
check(#sent == 0, "in combat: nothing goes out")
units.player.combat = false; instance = true; tick(3)
check(#sent == 0, "in an instance: nothing goes out")
instance = false; tick(0.5)
check(#sent == 1, "otherwise the queue moves, one at a time")
tick(12)
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Ganker") and sentHas("WHISPER", "Amigo", "^M1" .. SEP .. "Rival"), "the whole list went out")

print("-- guild off")
S.shareGuild = false
addonMsg(M("Fantasma"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.fantasma == nil, "does not receive from the guild")
S.shareGuild = true
addonMsg(M("Visto", { guid = "Player-1-EEE" }), "GUILD", "Guildeiro-Reino")
addPlate("nameplate4", { name = "Visto", guid = "Player-1-EEE", isPlayer = true, enemy = true, canAttack = true })
check(plates.nameplate4.kosSkull.shown, "guild icon shows with the guild on")
S.shareGuild = false; fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate4.kosSkull.shown == false, "and disappears when turned off")
S.shareGuild = true; fire("PLAYER_ENTERING_WORLD"); removePlate("nameplate4")
out = {}; S.shareGuild, S.shareFriends = false, false; slash("compartilhar")
check(has("desligado nas configura"), "/pvpw compartilhar with everything off warns")
S.shareGuild, S.shareFriends = true, true

print("-- block and unblock sender")
addonMsg(M("Alvo1"), "GUILD", "Guildeiro-Reino")
out = {}; slash("bloquear Guildeiro")
check(DB.shared.guild.alvo1 == nil and DB.shared.guild.visto == nil and has("Guildeiro bloqueado: 2"), "blocking deletes his marks")
addonMsg(M("Alvo2"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.alvo2 == nil, "blocked: the next ones are ignored")
out = {}; slash("desbloquear Guildeiro")
check(has("Guildeiro desbloqueado"), "unblock")
addonMsg(M("Alvo3"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.alvo3 ~= nil, "unblocked: receives again")
out = {}; slash("bloquear")
check(has("Diga o nome"), "blocking without a name asks for the name")

print("-- lists in chat")
out = {}; slash("lista guilda")
check(has("1 marcado%(s%) %(guilda%), do mais recente:") and has("Alvo3"), "/pvpw lista guilda")
out = {}; slash("list friends")
check(has("Cacador") and has("%[ocultar%]"), "/pvpw list friends")

print("-- Battle.net on")
S.shareBnet = true; bnSent = {}
fire("BN_CHAT_MSG_ADDON", "PvPW", M("Longe", { guid = "Player-2-DDD", realm = "OutroReino" }), "WHISPER", 77)
local longe = DB.shared.friends["longe-outroreino"]
check(longe and longe.by == "Distante-OutroReino", "receives from Battle.net as a friend, with the realm in the name")
slash("compartilhar"); tick(25)
check(#bnSent > 0 and bnSent[1].id == 77 and bnSent[1].prefix == "PvPW", "sends through Battle.net to the account online in WoW")
S.shareBnet = false
fire("BN_CHAT_MSG_ADDON", "PvPW", M("Perto", { guid = "Player-2-FFF" }), "WHISPER", 77)
check(DB.shared.friends.perto == nil, "Battle.net off: ignores")

print("-- expires after 30 days")
DB.shared.guild.antigo = { name = "Antigo", last = time() - 31 * 86400,
  from = { ["guildeiro-reino"] = { n = "Guildeiro", last = time() - 31 * 86400, count = 1 } } }
fire("PLAYER_LOGIN")
check(DB.shared.guild.antigo == nil and DB.shared.guild.alvo3 ~= nil, "login deletes the ones older than 30 days and keeps the new ones")

print("-- unmarking yours warns the others")
sent = {}; slash("apagar Ganker"); tick(3)
check(sentHas("GUILD", nil, "^U1" .. SEP .. "Ganker" .. SEP .. "Reino$"), "U1 to the guild")

print("-- long fields: up to 255 bytes, without breaking accents")
tick(15)
DB.players.longo = { name = string.rep("N", 60), guid = "Player-9", guild = string.rep("g", 80), where = "x" .. string.rep("ã", 40),
  class = "Guerreiro", classFile = "WARRIOR", level = 30, count = 3, last = time(), how = "manual" }
sent = {}; slash("compartilhar"); tick(20)
local longMsg
for _, m in ipairs(sent) do if m.text:find("^M1" .. SEP .. "NNNN") then longMsg = m.text end end
local parts = {}
if longMsg then for p in (longMsg .. SEP):gmatch("(.-)" .. SEP) do table.insert(parts, p) end end
check(longMsg and allShort(), "message with up to 255 bytes")
check(parts[2] == string.rep("N", 40) and parts[10] == "x" .. string.rep("ã", 24), "name cut at 40 and place cut without breaking the ã")

print("-- at the very end, your old list is still intact")
local goneEnd = lost(DB.players, before.players, "players")
check(#goneEnd == 0, "login, switch, block, expiry and sends did not touch your marks" .. (#goneEnd > 0 and (": " .. table.concat(goneEnd, ", ")) or ""))

print(fails == 0 and "ALL OK" or (fails .. " FAIL(S)"))
