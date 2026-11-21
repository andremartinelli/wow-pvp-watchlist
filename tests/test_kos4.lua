-- Simulacao da API do WoW para testar o compartilhamento do PvP Watchlist com amigos, guilda e Battle.net.
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

-- mensagens de addon
local sent, bnSent, prefixes, lockdown = {}, {}, {}, false
C_ChatInfo = {
  RegisterAddonMessagePrefix = function(p) prefixes[p] = true return true end,
  SendAddonMessage = function(prefix, text, kind, target)
    table.insert(sent, { prefix = prefix, text = text, kind = kind, target = target }); return 0 end,
  InChatMessagingLockdown = function() return lockdown end,
  PerformEmote = function() return true end,
}
-- guilda e amigos
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
-- Battle.net: um amigo jogando o mesmo jogo em outro reino
BNET_CLIENT_WOW, WOW_PROJECT_ID = "WoW", 99
BNGetNumFriends = function() return 1 end
C_BattleNet = {
  GetFriendNumGameAccounts = function() return 1 end,
  GetFriendGameAccountInfo = function() return { gameAccountID = 77, isOnline = true, clientProgram = "WoW", wowProjectID = 99,
    characterName = "Distante", realmName = "Outro Reino" } end,
  GetGameAccountInfoByID = function(id) if id == 77 then return { characterName = "Distante", realmName = "Outro Reino" } end end,
}
BNSendGameData = function(id, prefix, text) table.insert(bnSent, { id = id, prefix = prefix, text = text }) end

-- barras de nome, tooltip e quadro de eventos
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
local function check(cond, label) print((cond and "OK   " or "FALHA ") .. label); if not cond then fails = fails + 1 end end
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

-- lista que ja existia antes da 1.5.0 (com o X escolhido como icone da sua lista)
units.player = { name = "Jogador", isPlayer = true, level = 30 }
PvPWatchlistDB = { settings = { icon = 7 }, players = {
  velho = { name = "Velho", count = 2, first = time() - 900, last = time() - 100, where = "Vale", how = "alvo" },
  incerto = { name = "Incerto", count = 1, first = time() - 900, last = time() - 100, where = "Vale", how = "unico inimigo por perto" },
} }
local ns = {}
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
assert(loadfile("PvPWatchlist.lua"))("PvPWatchlist", ns)
assert(loadfile("Share.lua"))("PvPWatchlist", ns)
fire("ADDON_LOADED", "PvPWatchlist")
local DB, S = PvPWatchlistDB, PvPWatchlistDB.settings
check(prefixes.PvPW, "prefixo de mensagens PvPW registrado")
check(S.icon == 7 and S.friendsIcon == 7 and S.guildIcon == 4, "o X escolhido para a sua lista continua; amigos X e guilda triangulo por padrao")
S.icon = 8
check(DB.shared.friends and DB.shared.guild and DB.blocked, "listas recebidas e bloqueados criados")
check(S.shareGuild and S.shareFriends and not S.shareBnet and S.sharedAlerts and not S.sharedCenter, "padroes do compartilhamento")

print("-- textos nos dois idiomas")
local pt, en, miss = ns.LOCALES.ptBR, ns.LOCALES.enUS, 0
for k in pairs(pt) do if en[k] == nil then miss = miss + 1 print("  falta em enUS: " .. k) end end
for k in pairs(en) do if pt[k] == nil then miss = miss + 1 print("  falta em ptBR: " .. k) end end
check(miss == 0 and #pt.HELP == #en.HELP, "mesmas chaves em ptBR e enUS")

print("-- login: espera, pede as listas e manda so as marcacoes confiaveis")
fire("PLAYER_LOGIN")
tick(5)
check(#sent == 0, "nada enviado nos primeiros segundos")
tick(15)
check(sentHas("GUILD", nil, "^H1$") and sentHas("WHISPER", "Amigo", "^H1$"), "pede as listas na guilda e ao amigo online")
check(not sentHas("WHISPER", "Sumido"), "nao manda para amigo offline")
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Velho" .. SEP), "manda a marcacao confiavel (Velho)")
check(not anySent("Incerto"), "nao manda marcacao incerta (unico inimigo por perto)")
check(#bnSent == 0, "Battle.net desligado: nada por la")

print("-- marcar alguem envia logo, uma mensagem por segundo")
sent = {}
addPlate("nameplate1", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = "player",
  combat = true, class = "Ladino", classFile = "ROGUE", level = 32, guild = "Horda" })
hit()
check(#sent == 1, "na fila: sai uma por segundo")
tick(3)
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Ganker" .. SEP .. "Player%-1%-AAA" .. SEP .. "Ladino" .. SEP .. "ROGUE" .. SEP .. "32" .. SEP .. "Horda" .. SEP .. "1" .. SEP),
  "vai para a guilda com classe em ingles (ROGUE) para quem recebe traduzir")
check(sentHas("WHISPER", "Amigo", "^M1" .. SEP .. "Ganker"), "e para o amigo online")
removePlate("nameplate1")

print("-- recebe da guilda: icone da guilda, mensagem sem som e sem aviso no centro")
sounds, centers, out = 0, {}, {}
addonMsg(M("Rival", { guid = "Player-1-BBB", class = "Rogue", classFile = "ROGUE", level = 31, count = 2, last = time() - 60 }), "GUILD", "Guildeiro-Reino")
local g = DB.shared.guild.rival
check(g and g.by == "Guildeiro" and g.count == 2 and g.class == "Ladino", "guardado na lista da guilda, com a classe traduzida")
addPlate("nameplate2", { name = "Rival", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, level = 31 })
check(plates.nameplate2.kosSkull and plates.nameplate2.kosSkull.texture:find("_4$"), "icone da guilda (triangulo) na barra de nome")
check(plates.nameplate2.kosCount.text == "2", "numero de ataques ao lado")
check(has("Apareceu: Rival %(Ladino 31%) %- atacou Guildeiro 2 vezes %(guilda%)") and has("%[ocultar%]"), "mensagem com quem marcou e link [ocultar]")
check(sounds == 0 and #centers == 0, "sem som e sem aviso no centro")
local tip = { lines = {} }
tip.GetUnit = function() return "Rival", "nameplate2" end
tip.AddLine = function(self, s) table.insert(self.lines, s) end
GameTooltip = tip
tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist %(guilda%): atacou Guildeiro 2 vezes"), "tooltip: " .. tostring(tip.lines[1]))
S.sharedCenter = true; DB.shared.guild.rival.alertAt = 0; removePlate("nameplate2")
addPlate("nameplate2", { name = "Rival", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, level = 31 })
check(has("Rival por perto %- marcado por Guildeiro %(guilda%)", centers), "aviso no centro quando ligado")
S.sharedCenter = false

print("-- recebe de amigo: icone X")
addonMsg(M("Cacador", { guid = "Player-1-CCC", class = "Mage", classFile = "MAGE", count = 1 }), "WHISPER", "Amigo-Reino")
check(DB.shared.friends.cacador and DB.shared.friends.cacador.by == "Amigo", "guardado na lista dos amigos")
addPlate("nameplate3", { name = "Cacador", guid = "Player-1-CCC", isPlayer = true, enemy = true, canAttack = true })
check(plates.nameplate3.kosSkull.texture:find("_7$"), "icone dos amigos (X) na barra de nome")

print("-- icone escolhido para cada lista, ate o mesmo para todas")
S.friendsIcon, S.guildIcon = 2, 5
fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate3.kosSkull.texture:find("_2$") and plates.nameplate2.kosSkull.texture:find("_5$"),
  "amigos com Circulo e guilda com Lua")
S.icon, S.friendsIcon, S.guildIcon = 8, 8, 8
fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate3.kosSkull.texture:find("_8$") and plates.nameplate2.kosSkull.texture:find("_8$"), "as tres listas com a caveira")
tip.lines = {}; tip.GetUnit = function() return "Cacador", "nameplate3" end; tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("%(amigos%)"), "com o mesmo icone, o tooltip ainda diz de onde veio")
tip.GetUnit = function() return "Rival", "nameplate2" end
S.icon, S.friendsIcon, S.guildIcon = 8, 7, 4
fire("PLAYER_ENTERING_WORLD")

print("-- estranhos e a propria mensagem sao ignorados")
addonMsg(M("Ninguem"), "WHISPER", "Estranho-Reino")
check(not DB.shared.friends.ninguem and not DB.shared.guild.ninguem, "estranho ignorado")
addonMsg(M("Eco"), "GUILD", "Jogador-Reino")
check(not DB.shared.guild.eco, "a propria mensagem na guilda e ignorada")
addonMsg(M("Falso", { guid = "x" }), "WHISPER", SECRET)
check(not DB.shared.friends.falso and not DB.shared.guild.falso, "remetente secreto ignorado")

print("-- a sua marcacao vem primeiro")
units.target = units.nameplate2
slash("marcar")
check(plates.nameplate2.kosSkull.texture:find("_8$"), "marcado por voce: o seu icone no lugar do da guilda")
tip.lines = {}; tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist: te atacou") and tip.lines[2] and tip.lines[2]:find("%(guilda%)"),
  "tooltip com a sua linha e a da guilda")
units.target = nil

print("-- remetente desmarca")
addonMsg(U("Rival"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.rival == nil, "U1 apaga a marcacao dele")

print("-- ocultar e voltar quando for marcado de novo")
local lastC = DB.shared.friends.cacador.last
out = {}; SetItemRef("addon:PvPWatchlist:hide:friends:cacador", "[ocultar]", "LeftButton")
check(DB.shared.friends.cacador.hidden and has("Cacador ocultado"), "link [ocultar] esconde")
check(plates.nameplate3.kosSkull.shown == false, "icone X some da barra de nome")
addonMsg(M("Cacador", { guid = "Player-1-CCC", last = lastC }), "WHISPER", "Amigo-Reino")
check(DB.shared.friends.cacador.hidden, "a mesma marcacao de novo: continua oculto")
addonMsg(M("Cacador", { guid = "Player-1-CCC", last = lastC + 500, count = 2 }), "WHISPER", "Amigo-Reino")
check(not DB.shared.friends.cacador.hidden and plates.nameplate3.kosSkull.shown, "marcado de novo depois: volta a aparecer")

print("-- pedido de lista (H1)")
tick(15); sent = {}
addonMsg("H1", "WHISPER", "Amigo-Reino"); tick(5)
check(sentHas("WHISPER", "Amigo-Reino", "^M1" .. SEP .. "Velho") and not sentHas("GUILD", nil, "^M1" .. SEP .. "Velho"),
  "responde so para quem pediu, por whisper")

print("-- a fila espera: bloqueio de chat, combate e instancia")
tick(10); sent = {}
lockdown = true; out = {}; slash("compartilhar"); tick(5)
check(has("mensagem%(ns%) na fila") and #sent == 0, "bloqueio de chat: nada sai")
lockdown = false; units.player.combat = true; tick(3)
check(#sent == 0, "em combate: nada sai")
units.player.combat = false; instance = true; tick(3)
check(#sent == 0, "em instancia: nada sai")
instance = false; tick(0.5)
check(#sent == 1, "fora disso a fila anda, uma por vez")
tick(12)
check(sentHas("GUILD", nil, "^M1" .. SEP .. "Ganker") and sentHas("WHISPER", "Amigo", "^M1" .. SEP .. "Rival"), "toda a lista saiu")

print("-- guilda desligada")
S.shareGuild = false
addonMsg(M("Fantasma"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.fantasma == nil, "nao recebe da guilda")
S.shareGuild = true
addonMsg(M("Visto", { guid = "Player-1-EEE" }), "GUILD", "Guildeiro-Reino")
addPlate("nameplate4", { name = "Visto", guid = "Player-1-EEE", isPlayer = true, enemy = true, canAttack = true })
check(plates.nameplate4.kosSkull.shown, "icone da guilda aparece com a guilda ligada")
S.shareGuild = false; fire("PLAYER_ENTERING_WORLD")
check(plates.nameplate4.kosSkull.shown == false, "e some quando desliga")
S.shareGuild = true; fire("PLAYER_ENTERING_WORLD"); removePlate("nameplate4")
out = {}; S.shareGuild, S.shareFriends = false, false; slash("compartilhar")
check(has("desligado nas configura"), "/pvpw compartilhar com tudo desligado avisa")
S.shareGuild, S.shareFriends = true, true

print("-- bloquear e desbloquear remetente")
addonMsg(M("Alvo1"), "GUILD", "Guildeiro-Reino")
out = {}; slash("bloquear Guildeiro")
check(DB.shared.guild.alvo1 == nil and DB.shared.guild.visto == nil and has("Guildeiro bloqueado: 2"), "bloquear apaga as marcacoes dele")
addonMsg(M("Alvo2"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.alvo2 == nil, "bloqueado: as proximas sao ignoradas")
out = {}; slash("desbloquear Guildeiro")
check(has("Guildeiro desbloqueado"), "desbloquear")
addonMsg(M("Alvo3"), "GUILD", "Guildeiro-Reino")
check(DB.shared.guild.alvo3 ~= nil, "desbloqueado: volta a receber")
out = {}; slash("bloquear")
check(has("Diga o nome"), "bloquear sem nome pede o nome")

print("-- listas no chat")
out = {}; slash("lista guilda")
check(has("1 marcado%(s%) %(guilda%), do mais recente:") and has("Alvo3"), "/pvpw lista guilda")
out = {}; slash("list friends")
check(has("Cacador") and has("%[ocultar%]"), "/pvpw list friends")

print("-- Battle.net ligado")
S.shareBnet = true; bnSent = {}
fire("BN_CHAT_MSG_ADDON", "PvPW", M("Longe", { guid = "Player-2-DDD", realm = "OutroReino" }), "WHISPER", 77)
local longe = DB.shared.friends["longe-outroreino"]
check(longe and longe.by == "Distante-OutroReino", "recebe do Battle.net como amigo, com o reino no nome")
slash("compartilhar"); tick(25)
check(#bnSent > 0 and bnSent[1].id == 77 and bnSent[1].prefix == "PvPW", "envia pelo Battle.net para a conta online no WoW")
S.shareBnet = false
fire("BN_CHAT_MSG_ADDON", "PvPW", M("Perto", { guid = "Player-2-FFF" }), "WHISPER", 77)
check(DB.shared.friends.perto == nil, "Battle.net desligado: ignora")

print("-- expira em 30 dias")
DB.shared.guild.antigo = { name = "Antigo", last = time() - 31 * 86400,
  from = { ["guildeiro-reino"] = { n = "Guildeiro", last = time() - 31 * 86400, count = 1 } } }
fire("PLAYER_LOGIN")
check(DB.shared.guild.antigo == nil and DB.shared.guild.alvo3 ~= nil, "login apaga as de mais de 30 dias e mantem as novas")

print("-- desmarcar a sua avisa os outros")
sent = {}; slash("apagar Ganker"); tick(3)
check(sentHas("GUILD", nil, "^U1" .. SEP .. "Ganker" .. SEP .. "Reino$"), "U1 para a guilda")

print("-- campos compridos: ate 255 bytes, sem quebrar acento")
tick(15)
DB.players.longo = { name = string.rep("N", 60), guid = "Player-9", guild = string.rep("g", 80), where = "x" .. string.rep("ã", 40),
  class = "Guerreiro", classFile = "WARRIOR", level = 30, count = 3, last = time(), how = "manual" }
sent = {}; slash("compartilhar"); tick(20)
local longMsg
for _, m in ipairs(sent) do if m.text:find("^M1" .. SEP .. "NNNN") then longMsg = m.text end end
local parts = {}
if longMsg then for p in (longMsg .. SEP):gmatch("(.-)" .. SEP) do table.insert(parts, p) end end
check(longMsg and allShort(), "mensagem com ate 255 bytes")
check(parts[2] == string.rep("N", 40) and parts[10] == "x" .. string.rep("ã", 24), "nome cortado em 40 e lugar cortado sem quebrar o ã")

print(fails == 0 and "TUDO OK" or (fails .. " FALHA(S)"))
