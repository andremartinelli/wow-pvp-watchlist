-- Simulacao minima da API do WoW para testar o PvP Watchlist fora do jogo.
local clock = 1000
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end
local units = {}
local secretTargeting = false
local function resolve(u)
  if units[u] then return units[u] end
  local base = u:match("^(.+)target$")
  if base then local b = resolve(base); if b and b.target then return resolve(b.target) end end
  return nil
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
UnitClass = function(u) local r = resolve(u); return r and r.class end
UnitLevel = function(u) local r = resolve(u); return r and r.level end
GetGuildInfo = function(u) local r = resolve(u); return r and r.guild end
UnitIsDeadOrGhost = function() return false end
IsInInstance = function() return false, "none" end
GetZoneText = function() return "Stranglethorn" end
GetSubZoneText = function() return "Acampamento de Nesingwary" end
GetTime = function() return clock end
time = function() return 1795000000 + math.floor(clock) end
date = os.date
UNKNOWNOBJECT = "Desconhecido"
GetLocale = function() return "ptBR" end
SOUNDKIT = { RAID_WARNING = 8959 }
local sounds = 0
PlaySound = function() sounds = sounds + 1 end
C_Spell = { IsSpellHarmful = function() return true end }
local out = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) m = m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"); table.insert(out, m); print("  chat> " .. m) end }
local plates = {}
local function newPlate()
  local function mk() local t = { shown = false }
      function t:SetTexture() end function t:SetSize() end function t:SetPoint() end function t:ClearAllPoints() end function t:SetText() end
      function t:Show() self.shown = true end function t:Hide() self.shown = false end
      return t end
  return { CreateTexture = function() return mk() end, CreateFontString = function() return mk() end,
    IsForbidden = function() return false end }
end
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
local frame
CreateFrame = function()
  frame = { scripts = {}, events = {} }
  function frame:SetScript(k, fn) self.scripts[k] = fn end
  function frame:RegisterEvent(e) self.events[e] = true end
  function frame:RegisterUnitEvent(e) self.events[e] = true end
  return frame
end
SlashCmdList = {}
local origSetItemRef = function() end
SetItemRef = function(...) origSetItemRef(...) end
hooksecurefunc = function(name, hook) local orig = _G[name]; _G[name] = function(...) orig(...); hook(...) end end

local function fire(e, ...) frame.scripts.OnEvent(frame, e, ...) end
local function tick(seconds) local stop = clock + seconds; while clock < stop do clock = clock + 0.1; frame.scripts.OnUpdate(frame, 0.1) end end
local function slash(msg) SlashCmdList.PVPWATCHLIST(msg) end
local function has(pat) for _, m in ipairs(out) do if m:find(pat) then return true end end return false end
local fails = 0
local function check(cond, label) print((cond and "OK   " or "FALHA ") .. label); if not cond then fails = fails + 1 end end
local function addPlate(token, data) units[token] = data; plates[token] = newPlate(); fire("NAME_PLATE_UNIT_ADDED", token) end
local function removePlate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end

units.player = { name = "Jogador", isPlayer = true }
local ns = {}
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
local chunk = assert(loadfile("PvPWatchlist.lua"))
chunk("PvPWatchlist", ns)
fire("ADDON_LOADED", "killonsight")
check(not PvPWatchlistDB, "ignora o ADDON_LOADED de outro addon (killonsight)")
fire("ADDON_LOADED", "PvPWatchlist")
check(has("^%[PvPW%] carregado: 0"), "carrega com 0 marcados e prefixo [PvPW]")
check(SLASH_PVPWATCHLIST1 == "/pvpw" and SLASH_PVPWATCHLIST2 == nil, "/pvpw registrado; /kos so depois do login")
fire("PLAYER_LOGIN")
check(SLASH_PVPWATCHLIST2 == "/kos", "/kos livre: vira atalho no login")

print("-- 1. Horda te ataca primeiro")
addPlate("nameplate1", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, class = "Ladino", level = 32, guild = "Horda Malvada" })
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1); tick(1)
check(has("Marcado: Ganker %(Ladino 32, <Horda Malvada>%) te atacou em Acampamento de Nesingwary, Stranglethorn %(1 vez%)"), "marca o atacante")
check(plates.nameplate1.kosSkull and plates.nameplate1.kosSkull.shown, "caveira na barra de nome")
check(sounds == 1, "tocou som ao marcar")
out = {}; tick(3)
check(not has("Marcado"), "nao repete a marcacao na mesma luta")

print("-- 2. Ele some e volta 7 minutos depois")
removePlate("nameplate1"); clock = clock + 420
units.nameplate1 = nil
out = {}
addPlate("nameplate3", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = nil, combat = false, class = "Ladino", level = 32, guild = "Horda Malvada" })
check(has("Apareceu: Ganker"), "avisa quando aparece")
check(plates.nameplate3.kosSkull and plates.nameplate3.kosSkull.shown, "caveira na nova barra de nome")
out = {}; removePlate("nameplate3"); addPlate("nameplate3", units.nameplate3 or { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true })
check(not has("Apareceu"), "nao repete o aviso em menos de 5 min")
removePlate("nameplate3")

print("-- 3. Voce ataca primeiro e ele revida")
slash("debug")
addPlate("nameplate2", { name = "Vitima", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, target = nil, combat = false, class = "Mago", level = 30 })
units.target = units.nameplate2
fire("UNIT_SPELLCAST_SENT", "player", "Vitima", "cast-1", 172)
clock = clock + 2
units.nameplate2.target = "player"; units.nameplate2.combat = true
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 80, 1); tick(1)
check(not has("Marcado: Vitima"), "nao marca quem so revidou")
check(has("revidou"), "debug explica por que nao marcou")
removePlate("nameplate2"); units.target = nil

print("-- 4. Monstro te bate e um Horda so esta olhando")
addPlate("nameplate4", { name = "Curioso", guid = "Player-1-CCC", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = false })
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Curioso"), "nao marca Horda fora de combate")
removePlate("nameplate4")

print("-- 5. Duelo com amigo da Alianca")
addPlate("nameplate5", { name = "Amigo", guid = "Player-1-DDD", isPlayer = true, enemy = false, canAttack = true, target = "player", combat = true })
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Amigo"), "sem modo teste, duelo nao marca")
slash("teste"); clock = clock + 10
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(has("Marcado: Amigo"), "com modo teste, duelo marca")
slash("teste"); removePlate("nameplate5")

print("-- 6. Jogo esconde quem te mira (valor secreto)")
secretTargeting = true
addPlate("nameplate6", { name = "Sombra", guid = "Player-1-EEE", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true })
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(has("Marcado: Sombra"), "um inimigo so: marca mesmo sem saber o alvo")
addPlate("nameplate7", { name = "Outro", guid = "Player-1-FFF", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true })
clock = clock + 200
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Outro"), "dois inimigos e alvo secreto: nao marca ninguem")
secretTargeting = false; removePlate("nameplate6"); removePlate("nameplate7")

print("-- 7. Comandos")
out = {}; slash("lista"); check(has("3 marcado"), "lista mostra 3 marcados")
units.target = { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true }
out = {}; slash("tirar"); check(has("Ganker desmarcado"), "/kos tirar desmarca o alvo")
out = {}; SetItemRef("addon:killonsight:unmark:sombra", "[desmarcar]", "LeftButton")
check(not has("desmarcado"), "link do addon antigo (killonsight) e ignorado")
out = {}; SetItemRef("addon:PvPWatchlist:unmark:sombra", "[desmarcar]", "LeftButton")
check(has("Sombra desmarcado"), "link [desmarcar] funciona")
out = {}; slash("apagar amigo"); check(has("Amigo desmarcado"), "/kos apagar Nome")
out = {}; slash("lista"); check(has("Ninguém marcado"), "lista vazia no fim")
units.target = { name = "Novo", guid = "Player-1-GGG", isPlayer = true, enemy = true, canAttack = true, class = "Guerreiro", level = 34 }
out = {}; slash("marcar"); check(has("Marcado à mão: Novo"), "/kos marcar")
out = {}; slash(""); check(has("Comandos"), "ajuda")
print(fails == 0 and "TUDO OK" or (fails .. " FALHA(S)"))
