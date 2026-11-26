-- Minimal simulation of the WoW API to test PvP Watchlist outside the game.
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
UnitIsDeadOrGhost = function(u) local r = resolve(u); return r and r.dead or false end
UnitIsDead = function(u) local r = resolve(u); if r and r.secretDead then return SECRET end return r and r.dead or false end
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
local function check(cond, label) print((cond and "OK   " or "FAIL ") .. label); if not cond then fails = fails + 1 end end
local function addPlate(token, data) units[token] = data; plates[token] = newPlate(); fire("NAME_PLATE_UNIT_ADDED", token) end
local function removePlate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end

units.player = { name = "Jogador", isPlayer = true }
local ns = {}
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
local chunk = assert(loadfile("PvPWatchlist.lua"))
chunk("PvPWatchlist", ns)
assert(loadfile("Share.lua"))("PvPWatchlist", ns) -- no addon message API here: sharing stays idle
fire("ADDON_LOADED", "killonsight")
check(not PvPWatchlistDB, "ignores ADDON_LOADED from another addon (killonsight)")
fire("ADDON_LOADED", "PvPWatchlist")
check(has("^%[PvPW%] carregado: 0"), "loads with 0 marked and the [PvPW] prefix")
check(SLASH_PVPWATCHLIST1 == "/pvpw" and SLASH_PVPWATCHLIST2 == nil, "/pvpw registered; /kos only after login")
fire("PLAYER_LOGIN")
check(SLASH_PVPWATCHLIST2 == "/kos", "/kos is free: becomes a shortcut on login")

print("-- 1. Horde attacks you first")
addPlate("nameplate1", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, class = "Ladino", level = 32, guild = "Horda Malvada" })
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1); tick(1)
check(has("Marcado: Ganker %(Ladino 32, <Horda Malvada>%) te atacou em Acampamento de Nesingwary, Stranglethorn %(1 vez%)"), "marks the attacker")
check(plates.nameplate1.kosSkull and plates.nameplate1.kosSkull.shown, "skull on the nameplate")
check(sounds == 1, "played a sound when marking")
out = {}; tick(3)
check(not has("Marcado"), "does not repeat the mark in the same fight")

print("-- 2. He disappears and comes back 7 minutes later")
removePlate("nameplate1"); clock = clock + 420
units.nameplate1 = nil
out = {}
addPlate("nameplate3", { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true, target = nil, combat = false, class = "Ladino", level = 32, guild = "Horda Malvada" })
check(has("Apareceu: Ganker"), "warns when he shows up")
check(plates.nameplate3.kosSkull and plates.nameplate3.kosSkull.shown, "skull on the new nameplate")
out = {}; removePlate("nameplate3"); addPlate("nameplate3", units.nameplate3 or { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true })
check(not has("Apareceu"), "does not repeat the warning within 5 min")
removePlate("nameplate3")

print("-- 3. You attack first and he fights back")
slash("debug")
addPlate("nameplate2", { name = "Vitima", guid = "Player-1-BBB", isPlayer = true, enemy = true, canAttack = true, target = nil, combat = false, class = "Mago", level = 30 })
units.target = units.nameplate2
fire("UNIT_SPELLCAST_SENT", "player", "Vitima", "cast-1", 172)
clock = clock + 2
units.nameplate2.target = "player"; units.nameplate2.combat = true
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 80, 1); tick(1)
check(not has("Marcado: Vitima"), "does not mark someone who only fought back")
check(has("revidou"), "debug explains why it did not mark")
removePlate("nameplate2"); units.target = nil

print("-- 4. A monster hits you and a Horde player is just watching")
addPlate("nameplate4", { name = "Curioso", guid = "Player-1-CCC", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = false })
out = {}
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Curioso"), "does not mark a Horde player out of combat")
removePlate("nameplate4")

print("-- 5. Duel with an Alliance friend")
addPlate("nameplate5", { name = "Amigo", guid = "Player-1-DDD", isPlayer = true, enemy = false, canAttack = true, target = "player", combat = true })
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Amigo"), "without test mode, a duel does not mark")
slash("teste"); clock = clock + 10
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(has("Marcado: Amigo"), "with test mode, a duel marks")
slash("teste"); removePlate("nameplate5")

print("-- 6. The game hides who is targeting you (secret value)")
secretTargeting = true
addPlate("nameplate6", { name = "Sombra", guid = "Player-1-EEE", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true })
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(has("Marcado: Sombra"), "a single enemy: marks even without knowing the target")
addPlate("nameplate7", { name = "Outro", guid = "Player-1-FFF", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true })
clock = clock + 200
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not has("Marcado: Outro"), "two enemies and a secret target: marks nobody")
secretTargeting = false; removePlate("nameplate6"); removePlate("nameplate7")

print("-- 7. Commands")
out = {}; slash("lista"); check(has("3 marcado"), "list shows 3 marked")
units.target = { name = "Ganker", guid = "Player-1-AAA", isPlayer = true, enemy = true, canAttack = true }
out = {}; slash("tirar"); check(has("Ganker desmarcado"), "/kos tirar unmarks the target")
out = {}; SetItemRef("addon:killonsight:unmark:sombra", "[desmarcar]", "LeftButton")
check(not has("desmarcado"), "link from the old addon (killonsight) is ignored")
out = {}; SetItemRef("addon:PvPWatchlist:unmark:sombra", "[desmarcar]", "LeftButton")
check(has("Sombra desmarcado"), "[desmarcar] link works")
out = {}; slash("apagar amigo"); check(has("Amigo desmarcado"), "/kos apagar Name")
out = {}; slash("lista"); check(has("Ninguém marcado"), "empty list at the end")
units.target = { name = "Novo", guid = "Player-1-GGG", isPlayer = true, enemy = true, canAttack = true, class = "Guerreiro", level = 34 }
out = {}; slash("marcar"); check(has("Marcado à mão: Novo"), "/kos marcar")
out = {}; slash(""); check(has("Comandos"), "help")

-- Real cases from 11/21/2026 (combat log): you cast Curse of Agony first and the addon marked them anyway.
-- In Forever the spell target name and the spell can come secret or with realm and suffix ("Fedrath-Vorn-JxJ-US").
-- As in the game: secret value in, secret value out. 99 is a helpful spell (heal/buff).
C_Spell = {
  IsSpellHarmful = function(id) if id == SECRET then return SECRET end return id ~= 99 end,
  IsSpellHelpful = function(id) if id == SECRET then return SECRET end return id == 99 end,
}
-- Auras: only answers for "HARMFUL|PLAYER" when the unit has a spell of yours (myDebuff).
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

print("-- 8. Fedrath: your curse with secret target name and spell, and you enter combat because of it")
clock = clock + 400; units.target = nil
addPlate("nameplate8", enemy("Fedrath", "Vorn", "Player-6800-00ABDEB4", { class = "Mago", level = 21 }))
units.target = units.nameplate8
out = {}
fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c8", SECRET)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c8", SECRET)
check(has("você atacou Fedrath%-Vorn"), "a spell with secret data counts as an attack on your target")
units.nameplate8.target = "player"; units.nameplate8.combat = true
fire("PLAYER_REGEN_DISABLED"); tick(3)
check(has("entrou em combate por ação sua") and not marked("Fedrath"), "entering combat through your own curse does not start the search")
out = {}; clock = clock + 2
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Fedrath") and has("Fedrath%-Vorn revidou"), "a monster hit afterwards: Fedrath stays unmarked (fought back)")

print("-- 9. Leigong: the game gives the name with realm and suffix, the target comes without realm")
units.target = nil; removePlate("nameplate8"); clock = clock + 400
addPlate("nameplate9", enemy("Leigong", "Tutu", "Player-1-LEI"))
units.target = units.nameplate9
out = {}
fire("UNIT_SPELLCAST_SENT", "player", "Leigong-Tutu-JxJ-US", "c9", 6217)
check(has("você atacou Leigong%-Tutu"), "name 'Leigong-Tutu-JxJ-US' recognized")
units.nameplate9.target = "player"; units.nameplate9.combat = true
clock = clock + 1.5
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Leigong"), "Leigong is not marked")
units.target = nil; removePlate("nameplate9")

print("-- 10. Staz: the game gives the target name without realm and the unit name with realm; he fights back 15 s later")
clock = clock + 400
addPlate("nameplate10", enemy("Staz", "Exanime", "Player-1-STZ"))
units.target = units.nameplate10
fire("UNIT_SPELLCAST_SENT", "player", "Staz", "c10", 6217)
clock = clock + 15
units.nameplate10.target = "player"; units.nameplate10.combat = true
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Staz"), "fought back after 15 s: does not mark")
units.target = nil; removePlate("nameplate10")

print("-- 11. Same GUID with the name in another format")
clock = clock + 400
units.target = enemy("Duplo", nil, "Player-1-DUP")
fire("UNIT_SPELLCAST_SENT", "player", "Duplo", "c11", 6217)
units.target = nil
addPlate("nameplate11", enemy("Duplo", "OutroReino", "Player-1-DUP", { target = "player", combat = true }))
out = {}; fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(not marked("Duplo"), "recognizes by GUID even with a different key")
removePlate("nameplate11")

print("-- 12. Whoever really attacks is still marked")
clock = clock + 400
addPlate("nameplate12", enemy("Fedrath", "Vorn", "Player-6800-00ABDEB4"))
units.target = units.nameplate12
fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c12", SECRET)
units.nameplate12.target = "player"; units.nameplate12.combat = true
addPlate("nameplate13", enemy("Jeskai", "Javi", "Player-1-JES", { target = "player", combat = true }))
out = {}; clock = clock + 0.5
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(marked("Jeskai") and not marked("Fedrath"), "Jeskai hit you: marked; Fedrath (you attacked) not")
units.target = nil; removePlate("nameplate12"); removePlate("nameplate13")

print("-- 13. A heal or buff with an enemy targeted does not count as an attack")
clock = clock + 400
addPlate("nameplate14", enemy("Atacante", "Reino", "Player-1-ATK"))
units.target = units.nameplate14
out = {}; fire("UNIT_SPELLCAST_SENT", "player", SECRET, "c14", 99)
check(not has("você atacou Atacante"), "helpful spell (99) is not stored as an attack")
units.nameplate14.target = "player"; units.nameplate14.combat = true
clock = clock + 3
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1); tick(1)
check(marked("Atacante"), "he attacks you afterwards: marked")
units.target = nil; removePlate("nameplate14")

print("-- 13b. The spell events never arrive: your curse on him is enough")
clock = clock + 400
addPlate("nameplate16", enemy("Semevento", "Reino", "Player-1-SEM", { target = "player", combat = true, myDebuff = "Ruína da Agonia" }))
out = {}; fire("PLAYER_REGEN_DISABLED"); tick(1)
check(not marked("Semevento") and has("Semevento%-Reino revidou"), "has your Curse of Agony: does not mark, even with no spell event")
removePlate("nameplate16")

print("-- 13c. Spell with only the end (SUCCEEDED) readable, and the unit event secret")
clock = clock + 400
addPlate("nameplate17", enemy("Fimdamagia", "Reino", "Player-1-FIM"))
units.target = units.nameplate17
out = {}
fire("UNIT_SPELLCAST_SENT", SECRET, SECRET, "c17", SECRET)
fire("UNIT_SPELLCAST_SUCCEEDED", SECRET, "c17", 6217)
check(has("você atacou Fimdamagia%-Reino"), "the end of the offensive spell stores the attack")
units.nameplate17.target = "player"; units.nameplate17.combat = true
clock = clock + 3
fire("UNIT_COMBAT", SECRET, "WOUND", "", 30, 1); tick(1)
check(not marked("Fimdamagia"), "a hit with a secret unit starts the search, and he is not marked")
units.target = nil; removePlate("nameplate17")

print("-- 14. Entering combat without any action of yours still starts the search (e.g. stunned by a rogue)")
clock = clock + 400
addPlate("nameplate15", enemy("Ladino", "Reino", "Player-1-ROG", { target = "player", combat = true }))
out = {}; fire("PLAYER_REGEN_DISABLED"); tick(1)
check(marked("Ladino"), "no action of yours before: searches and marks")
removePlate("nameplate15")

print("-- 15. Kill alert: chat line when an enemy you attacked dies")
local S = PvPWatchlistDB.settings
check(S.killAlert == "always", "default: always")
local function attack(token, data)
  addPlate(token, data); units.target = units[token]
  fire("UNIT_SPELLCAST_SENT", "player", data.name, "k-" .. token, 172)
  units.target = nil
end
clock = clock + 400
attack("nameplate20", enemy("Presa", "Reino", "Player-1-PRE", { class = "Mago", level = 30 }))
local soundsBefore = sounds
out = {}; units.nameplate20.dead = true; tick(1)
check(has("Presa%-Reino %(Mago 30%) morreu%.$"), "an enemy you attacked dies: one chat line")
check(sounds == soundsBefore, "the kill line plays no sound")
out = {}; tick(2); removePlate("nameplate20")
check(not has("morreu"), "does not repeat the same death")

addPlate("nameplate21", enemy("Estranho", "Reino", "Player-1-EST"))
out = {}; units.nameplate21.dead = true; tick(1)
check(not has("morreu"), "an enemy you never attacked dies: nothing")
removePlate("nameplate21")

addPlate("nameplate22", enemy("Amaldicoado", "Reino", "Player-1-AMA", { myDebuff = "Ruína da Agonia" }))
tick(1); units.nameplate22.myDebuff = nil
out = {}; units.nameplate22.dead = true; tick(1)
check(has("Amaldicoado%-Reino morreu%."), "only your curse on him (no spell event): still reported")
removePlate("nameplate22")

attack("nameplate23", enemy("Antigo", "Reino", "Player-1-ANT"))
clock = clock + 31
out = {}; units.nameplate23.dead = true; tick(1)
check(not has("morreu"), "attack older than 30 s: nothing")
removePlate("nameplate23")

print("-- 15b. You die and your DoTs finish him")
attack("nameplate24", enemy("Xama", "Reino", "Player-1-XAM", { class = "Xamã", level = 38 }))
units.player.dead = true; fire("PLAYER_DEAD")
clock = clock + 8
out = {}; units.nameplate24.dead = true; tick(0.5)
check(has("Xama%-Reino %(Xamã 38%) morreu 8 s depois de você%."), "died 8 s after you")
check(not has("Marcado"), "being dead does not start the attacker search")
units.player.dead = false; removePlate("nameplate24")

print("-- 15c. Only after my death / off")
S.killAlert = "afterDeath"
attack("nameplate25", enemy("Vivo", "Reino", "Player-1-VIV"))
out = {}; units.nameplate25.dead = true; tick(1)
check(not has("morreu"), "after-death mode: a kill while you are alive says nothing")
removePlate("nameplate25")
attack("nameplate26", enemy("Morto", "Reino", "Player-1-MOR"))
units.player.dead = true; fire("PLAYER_DEAD"); clock = clock + 3
out = {}; units.nameplate26.dead = true; tick(0.5)
check(has("Morto%-Reino morreu 3 s depois de você%."), "after-death mode: a kill after your death is reported")
units.player.dead = false; removePlate("nameplate26")
S.killAlert = "off"
attack("nameplate27", enemy("Desligado", "Reino", "Player-1-DES"))
out = {}; units.nameplate27.dead = true; tick(1)
check(not has("morreu"), "off: nothing")
removePlate("nameplate27")
S.killAlert = "always"

print("-- 15d. The game hides the death during combat, the nameplate goes away, he comes back")
attack("nameplate28", enemy("Escondido", "Reino", "Player-1-ESC"))
out = {}; units.nameplate28.dead = true; units.nameplate28.secretDead = true; tick(1)
check(not has("morreu"), "death hidden during combat: waits")
units.nameplate28.secretDead = false; tick(1)
check(has("Escondido%-Reino morreu%."), "reported as soon as the game shows it")
removePlate("nameplate28")
attack("nameplate29", enemy("Sumiu", "Reino", "Player-1-SUM"))
out = {}; units.nameplate29.dead = true; removePlate("nameplate29")
check(has("Sumiu%-Reino morreu%."), "nameplate removed as he dies: still reported")
attack("nameplate30", enemy("Volta", "Reino", "Player-1-VOL"))
units.nameplate30.dead = true; tick(1)
units.nameplate30.dead = false; tick(1)
units.target = units.nameplate30; fire("UNIT_SPELLCAST_SENT", "player", "Volta", "k-volta", 172); units.target = nil
out = {}; units.nameplate30.dead = true; tick(1)
check(has("Volta%-Reino morreu%."), "came back to life and died again: reported again")
removePlate("nameplate30")
print(fails == 0 and "ALL OK" or (fails .. " FAIL(S)"))
