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
UnitName = function(u) local r = resolve(u); if r then if r.secretName then return SECRET end return r.name, r.realm end end
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
assert(loadfile("Share.lua"))("PvPWatchlist", ns) -- sem API de mensagens de addon aqui: o compartilhamento fica parado
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

-- Casos reais de 21/11/2026 (registro de combate): voce lancou Ruina da Agonia primeiro e o addon marcou mesmo assim.
-- No Forever o nome do alvo da magia e a magia podem vir secretos ou com reino e sufixo ("Fedrath-Vorn-JxJ-US").
-- Como no jogo: valor secreto entra, valor secreto sai. 99 e uma magia de ajuda (cura/buff).
C_Spell = {
  IsSpellHarmful = function(id) if id == SECRET then return SECRET end return id ~= 99 end,
  IsSpellHelpful = function(id) if id == SECRET then return SECRET end return id == 99 end,
}
-- Auras: so responde para "HARMFUL|PLAYER" quando a unidade tem uma magia sua (myDebuff).
C_UnitAuras = { GetAuraDataByIndex = function(u, i, filter)
  local r = resolve(u)
  if r and r.myDebuff and i == 1 and filter == "HARMFUL|PLAYER" then return { name = r.myDebuff } end
end }
local function enemy(name, realm, guid, extra)
  local t = { name = name, realm = realm, guid = guid, isPlayer = true, enemy = true, canAttack = true, combat = false }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local function marked(name) return has("Marcado: " .. name) end

print("-- 8. Fedrath: sua maldicao com nome do alvo e magia secretos, e voce entra em combate por causa dela")
clock = clock + 400; units.target = nil
addPlate("nameplate8", enemy("Fedrath", "Vorn", "Player-6800-00ABDEB4", { class = "Mago", level = 21 }))
units.target = units.nameplate8
out = {}
fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c8", SECRET)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c8", SECRET)
check(has("você atacou Fedrath%-Vorn"), "magia com dados secretos conta como ataque ao seu alvo")
units.nameplate8.target = "player"; units.nameplate8.combat = true
fire("PLAYER_REGEN_DISABLED"); tick(3)
check(has("entrou em combate por ação sua") and not marked("Fedrath"), "entrar em combate pela sua maldicao nao inicia a procura")
out = {}; clock = clock + 2
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Fedrath") and has("Fedrath%-Vorn revidou"), "um golpe de monstro depois: Fedrath continua sem marca (revidou)")

print("-- 9. Leigong: o jogo da o nome com reino e sufixo, o alvo vem sem reino")
units.target = nil; removePlate("nameplate8"); clock = clock + 400
addPlate("nameplate9", enemy("Leigong", "Tutu", "Player-1-LEI"))
units.target = units.nameplate9
out = {}
fire("UNIT_SPELLCAST_SENT", "player", "Leigong-Tutu-JxJ-US", "c9", 6217)
check(has("você atacou Leigong%-Tutu"), "nome 'Leigong-Tutu-JxJ-US' reconhecido")
units.nameplate9.target = "player"; units.nameplate9.combat = true
clock = clock + 1.5
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Leigong"), "Leigong nao e marcado")
units.target = nil; removePlate("nameplate9")

print("-- 10. Staz: o jogo da o nome do alvo sem reino e o da unidade com reino; ele revida 15 s depois")
clock = clock + 400
addPlate("nameplate10", enemy("Staz", "Exanime", "Player-1-STZ"))
units.target = units.nameplate10
fire("UNIT_SPELLCAST_SENT", "player", "Staz", "c10", 6217)
clock = clock + 15
units.nameplate10.target = "player"; units.nameplate10.combat = true
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Staz"), "revidou depois de 15 s: nao marca")
units.target = nil; removePlate("nameplate10")

print("-- 11. Mesmo GUID com o nome em outro formato")
clock = clock + 400
units.target = enemy("Duplo", nil, "Player-1-DUP")
fire("UNIT_SPELLCAST_SENT", "player", "Duplo", "c11", 6217)
units.target = nil
addPlate("nameplate11", enemy("Duplo", "OutroReino", "Player-1-DUP", { target = "player", combat = true }))
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Duplo"), "reconhece pelo GUID mesmo com a chave diferente")
removePlate("nameplate11")

print("-- 12. Quem ataca de verdade continua sendo marcado")
clock = clock + 400
addPlate("nameplate12", enemy("Fedrath", "Vorn", "Player-6800-00ABDEB4"))
units.target = units.nameplate12
fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c12", SECRET)
units.nameplate12.target = "player"; units.nameplate12.combat = true
addPlate("nameplate13", enemy("Jeskai", "Javi", "Player-1-JES", { target = "player", combat = true }))
out = {}; clock = clock + 0.5
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(marked("Jeskai") and not marked("Fedrath"), "Jeskai te bateu: marcado; Fedrath (voce atacou) nao")
units.target = nil; removePlate("nameplate12"); removePlate("nameplate13")

print("-- 13. Cura ou buff com um inimigo no alvo nao conta como ataque")
clock = clock + 400
addPlate("nameplate14", enemy("Atacante", "Reino", "Player-1-ATK"))
units.target = units.nameplate14
out = {}; fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c14", 99)
check(not has("você atacou Atacante"), "magia de ajuda (99) nao e guardada como ataque")
units.nameplate14.target = "player"; units.nameplate14.combat = true
clock = clock + 3
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(marked("Atacante"), "ele te ataca depois: marcado")
units.target = nil; removePlate("nameplate14")

print("-- 13b. Os eventos de magia nao chegam: a sua maldicao nele basta")
clock = clock + 400
addPlate("nameplate16", enemy("Semevento", "Reino", "Player-1-SEM", { target = "player", combat = true, myDebuff = "Ruína da Agonia" }))
out = {}; fire("PLAYER_REGEN_DISABLED"); tick(1)
check(not marked("Semevento") and has("Semevento%-Reino revidou"), "tem Ruina da Agonia sua: nao marca, mesmo sem nenhum evento de magia")
removePlate("nameplate16")

print("-- 13c. Magia so com o fim (SUCCEEDED) legivel, e o evento de unidade secreto")
clock = clock + 400
addPlate("nameplate17", enemy("Fimdamagia", "Reino", "Player-1-FIM"))
units.target = units.nameplate17
out = {}
fire("UNIT_SPELLCAST_SENT", SECRET, SECRET, "c17", SECRET)
fire("UNIT_SPELLCAST_SUCCEEDED", SECRET, "c17", 6217)
check(has("você atacou Fimdamagia%-Reino"), "o fim da magia ofensiva guarda o ataque")
units.nameplate17.target = "player"; units.nameplate17.combat = true
clock = clock + 3
fire("UNIT_COMBAT", SECRET, "WOUND", "", 30, 1); tick(1)
check(not marked("Fimdamagia"), "golpe com unidade secreta inicia a procura, e ele nao e marcado")
units.target = nil; removePlate("nameplate17")

print("-- 14. Entrar em combate sem acao sua ainda inicia a procura (ex.: atordoado por um ladino)")
clock = clock + 400
addPlate("nameplate15", enemy("Ladino", "Reino", "Player-1-ROG", { target = "player", combat = true }))
out = {}; fire("PLAYER_REGEN_DISABLED"); tick(1)
check(marked("Ladino"), "sem acao sua antes: procura e marca")
removePlate("nameplate15")
print(fails == 0 and "TUDO OK" or (fails .. " FALHA(S)"))
