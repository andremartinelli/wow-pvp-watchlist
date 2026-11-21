-- Simulacao da API do WoW para testar o killonsight (deteccao + tela de configuracoes) fora do jogo, em portugues.
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
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960 }
local sounds = {}
PlaySound = function(id) table.insert(sounds, id) end
C_Spell = { IsSpellHarmful = function() return true end }
local emotes, lockdown = {}, false
C_ChatInfo = { PerformEmote = function(token, unit) table.insert(emotes, token .. "@" .. tostring(unit)) return true end,
  InChatMessagingLockdown = function() return lockdown end }
local out = {}
local function clean(m) return (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "[icone]")) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) m = clean(m); table.insert(out, m); print("  chat> " .. m) end }
local centers = {}
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0.1 } }
RaidNotice_AddMessage = function(_, text) table.insert(centers, clean(text)); print("  centro> " .. clean(text)) end

-- objetos de UI genericos: metodos CamelCase viram no-op; os que importam guardam estado
local created = { CheckButton = {}, Slider = {}, Button = {}, Frame = {} }
local function stub(kind)
  local o = { kind = kind, scripts = {}, shown = true }
  local m = {
    SetScript = function(self, n, fn) self.scripts[n] = fn end,
    GetScript = function(self, n) return self.scripts[n] end,
    HookScript = function(self, n, fn) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end fn(...) end end,
    CreateTexture = function() return stub("Texture") end,
    CreateFontString = function() return stub("FontString") end,
    SetTexture = function(self, p) self.texture = p end,
    SetSize = function(self, w, h) self.w, self.h = w, h end,
    SetText = function(self, s) self.text = s end,
    GetText = function(self) return self.text end,
    Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown end, SetShown = function(self, v) self.shown = v and true or false end,
    SetChecked = function(self, v) self.checked = v end, GetChecked = function(self) return self.checked end,
    SetValue = function(self, v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end,
    GetValue = function(self) return self.value or 0 end,
    GetThumbTexture = function() return stub("Texture") end,
    IsForbidden = function() return false end,
    GetID = function() return 42 end,
  }
  return setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
    return nil
  end })
end
local eventFrame
CreateFrame = function(kind, name, parent, template)
  local o = stub(kind)
  o.template = template
  o.RegisterEvent = function(self, e) eventFrame = self end
  o.RegisterUnitEvent = function(self, e) eventFrame = self end
  table.insert(created[kind] or {}, o)
  return o
end
local categories = {}
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name) local c = stub("Category"); c.panel, c.name = panel, name; table.insert(categories, c); return c end,
  RegisterCanvasLayoutSubcategory = function(parent, panel, name) local c = stub("Category"); c.panel, c.name = panel, name; table.insert(categories, c); return c end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function(id) categories.opened = id end,
}
GameTooltip = stub("GameTooltip")
local tooltipHook
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end }
local plates = {}
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
SlashCmdList = {}
SetItemRef = function() end
hooksecurefunc = function(name, hook) local orig = _G[name]; _G[name] = function(...) orig(...); hook(...) end end

local function fire(e, ...) eventFrame.scripts.OnEvent(eventFrame, e, ...) end
local function tick(s) local stop = clock + s; while clock < stop do clock = clock + 0.1; eventFrame.scripts.OnUpdate(eventFrame, 0.1) end end
local function slash(msg) SlashCmdList.KILLONSIGHT(msg) end
local function has(pat, list) for _, m in ipairs(list or out) do if m:find(pat) then return true end end return false end
local fails = 0
local function check(cond, label) print((cond and "OK   " or "FALHA ") .. label); if not cond then fails = fails + 1 end end
local function addPlate(token, data) units[token] = data; plates[token] = stub("Plate"); fire("NAME_PLATE_UNIT_ADDED", token) end
local function removePlate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end
local function click(w, button) w.scripts.OnClick(w, button or "LeftButton") end
local function setBox(w, v) w.checked = v; click(w) end
local function hit() fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1); tick(1) end

units.player = { name = "Jogador", isPlayer = true, level = 30 }
dofile = nil
local ns = {}
assert(loadfile("Locales.lua"))("killonsight", ns)
local chunk = assert(loadfile("killonsight.lua"))
chunk("killonsight", ns)
fire("ADDON_LOADED", "killonsight")
local S = killonsightDB.settings
local main, list = categories[1], categories[2]
check(main and main.name == "killonsight", "tela principal registrada em Opcoes > AddOns")
check(list and list.name == "Marcados", "subpagina Marcados registrada")
local boxes, sliders, buttons = created.CheckButton, created.Slider, created.Button
check(#boxes == 12 and #sliders == 3, "12 caixas e 3 controles deslizantes")
-- ordem das caixas: enabled, skipIfIAttacked, ignoreLow, emote, showCount, sound, msg, center, tooltip, minimap, test, debug
local B = { enabled = boxes[1], skip = boxes[2], ignoreLow = boxes[3], emote = boxes[4], showCount = boxes[5], sound = boxes[6], msg = boxes[7], center = boxes[8], tooltip = boxes[9], minimap = boxes[10], test = boxes[11], debug = boxes[12] }
local SL = { memory = sliders[1], levels = sliders[2], size = sliders[3] }
local emoteBtn, emoteTestBtn, iconBtn, soundBtn, testBtn = buttons[1], buttons[2], buttons[3], buttons[4], buttons[5]
main.panel.scripts.OnShow(main.panel)
check(B.enabled.checked == true and B.ignoreLow.checked == false and B.emote.checked == true and SL.size.value == 26, "valores padrao aparecem na tela")

print("-- desligar a marcacao automatica")
setBox(B.enabled, false)
addPlate("nameplate1", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, class = "Ladino", level = 32 })
out = {}; hit()
check(not has("Marcado"), "desligado: nao marca")
setBox(B.enabled, true); clock = clock + 5
out = {}; hit()
check(has("Marcado: Ganker"), "ligado de novo: marca")
local p1 = plates.nameplate1
check(p1.kosSkull.texture:find("_8$") and p1.kosSkull.w == 26 and p1.kosCount.text == "1", "caveira 26 com o numero 1")
check(#emotes == 1 and emotes[1] == "NO@nameplate1", "fez /no direcionado ao atacante: " .. tostring(emotes[1]))
out = {}; hit()
check(#emotes == 1, "nao repete o emote na mesma luta")

print("-- emote: trocar, testar, desligar, bloqueio do jogo")
click(emoteBtn)
check(S.emoteToken == "RUDE", "emote trocado para /rude")
units.target = units.nameplate1; emotes = {}
click(emoteTestBtn)
check(emotes[1] == "RUDE@target", "botao Testar no alvo")
units.target = nil; emotes = {}; out = {}
click(emoteTestBtn)
check(#emotes == 0 and has("Ponha alguém no alvo"), "sem alvo: nao faz emote")
click(emoteBtn, "RightButton")
check(S.emoteToken == "NO", "botao direito volta para /no")
print("-- icone, tamanho e numero")
click(iconBtn)
check(S.icon == 7 and p1.kosSkull.texture:find("_7$"), "icone trocado para X na barra de nome")
click(iconBtn, "RightButton")
check(S.icon == 8, "botao direito volta para caveira")
SL.size:SetValue(40)
check(S.iconSize == 40 and p1.kosSkull.w == 40, "tamanho 40 aplicado")
setBox(B.showCount, false)
check(p1.kosCount.shown == false, "numero escondido")
setBox(B.showCount, true)

print("-- ignorar nivel baixo")
setBox(B.ignoreLow, true); SL.levels:SetValue(5)
addPlate("nameplate2", { name = "Baixinho", guid = "G2", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, level = 20 })
clock = clock + 200; out = {}; hit()
check(not has("Marcado: Baixinho"), "nivel 20 contra 30 com limite 5: ignorado")
units.nameplate2.level = 27; clock = clock + 5; out = {}; hit()
check(has("Marcado: Baixinho"), "nivel 27: marcado")
check(emotes[#emotes] == "NO@nameplate2", "emote no novo atacante")
setBox(B.ignoreLow, false); removePlate("nameplate2")

print("-- nao marcar quem eu ataquei (e desligando a opcao)")
addPlate("nameplate3", { name = "Vitima", guid = "G3", isPlayer = true, enemy = true, canAttack = true, combat = false, level = 30 })
units.target = units.nameplate3
fire("UNIT_SPELLCAST_SENT", "player", "Vitima", "c1", 172)
units.nameplate3.target = "player"; units.nameplate3.combat = true
clock = clock + 2; out = {}; hit()
check(not has("Marcado: Vitima"), "atacou primeiro: nao marca")
setBox(B.emote, false); emotes = {}
setBox(B.skip, false); clock = clock + 2; out = {}; hit()
check(#emotes == 0, "emote desligado: nao faz")
setBox(B.emote, true)
check(has("Marcado: Vitima"), "opcao desligada: marca mesmo assim")
setBox(B.skip, true); SL.memory:SetValue(30)
check(S.myAttackMemory == 30, "memoria do ataque ajustada para 30 s")
removePlate("nameplate3"); units.target = nil

print("-- aviso quando reaparece: som, centro e chat")
removePlate("nameplate1"); clock = clock + 400
sounds = {}; centers = {}; out = {}
addPlate("nameplate4", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, level = 32 })
check(#sounds == 1 and sounds[1] == 8959, "som de alerta de raide")
check(has("Ganker por perto", centers), "aviso no centro da tela")
check(has("Apareceu: Ganker"), "mensagem no chat")
click(soundBtn)
check(S.soundId == "ready", "som trocado para checagem de prontidao")
setBox(B.sound, false); sounds = {}
click(testBtn)
check(#sounds == 1 and sounds[1] == 8960, "botao Testar toca mesmo com som desligado")
setBox(B.center, false); setBox(B.msg, false); setBox(B.sound, true)
removePlate("nameplate4"); clock = clock + 400; centers = {}; out = {}
addPlate("nameplate4", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, level = 32 })
check(#centers == 0 and not has("Apareceu"), "centro e mensagem desligados")

print("-- tooltip")
local tip = stub("Tooltip"); tip.lines = {}
tip.GetUnit = function() return "Ganker", "nameplate4" end
tip.AddLine = function(self, s) table.insert(self.lines, s) end
GameTooltip = tip
tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("KoS: te atacou 2 vezes"), "linha no tooltip: " .. tostring(tip.lines[1]))
setBox(B.tooltip, false); tip.lines = {}; tooltipHook(tip)
check(#tip.lines == 0, "tooltip desligado")

print("-- lista na subpagina e desmarcar por botao")
list.panel.scripts.OnShow(list.panel)
local rowBtn = buttons[7] -- 6 = idioma
check(rowBtn.shown, "primeira linha da lista com botao Desmarcar")
out = {}; click(rowBtn)
check(has("desmarcado"), "botao Desmarcar funciona")
lockdown = true; emotes = {}
units.target = { name = "Bloqueado", guid = "G9", isPlayer = true, enemy = true, canAttack = true, level = 30 }
addPlate("nameplate9", { name = "Bloqueado", guid = "G9", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, level = 30 })
clock = clock + 300; out = {}; hit()
check(has("Marcado: Bloqueado") and #emotes == 0, "chat bloqueado pelo jogo: marca sem emote")
lockdown = false; emotes = {}
out = {}; slash("marcar")
check(has("Marcado à mão") and #emotes == 0, "marcar a mao nao faz emote")
out = {}; slash("emote")
check(S.emote == false and B.emote.checked == false, "/kos emote desliga e atualiza a tela")
out = {}; slash("config")
check(categories.opened == 42, "/kos config abre a tela")
out = {}; slash("debug")
check(B.debug.checked == true, "comando /kos debug atualiza a caixa na tela")
print(fails == 0 and "TUDO OK" or (fails .. " FALHA(S)"))
