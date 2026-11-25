-- Simulation of the WoW API to test PvP Watchlist (detection + settings screen) outside the game, in Portuguese.
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

-- generic UI objects: CamelCase methods become no-ops; the ones that matter keep state
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
local function slash(msg) SlashCmdList.PVPWATCHLIST(msg) end
local function has(pat, list) for _, m in ipairs(list or out) do if m:find(pat) then return true end end return false end
local fails = 0
local function check(cond, label) print((cond and "OK   " or "FAIL ") .. label); if not cond then fails = fails + 1 end end
local function addPlate(token, data) units[token] = data; plates[token] = stub("Plate"); fire("NAME_PLATE_UNIT_ADDED", token) end
local function removePlate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end
local function click(w, button) w.scripts.OnClick(w, button or "LeftButton") end
local function setBox(w, v) w.checked = v; click(w) end
local function hit() fire("UNIT_COMBAT", "player", "WOUND", "", 50, 1); tick(1) end

units.player = { name = "Jogador", isPlayer = true, level = 30 }
dofile = nil
local ns = {}
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
local chunk = assert(loadfile("PvPWatchlist.lua"))
chunk("PvPWatchlist", ns)
assert(loadfile("Share.lua"))("PvPWatchlist", ns)
fire("ADDON_LOADED", "PvPWatchlist")
local S = PvPWatchlistDB.settings
local main, list = categories[1], categories[2]
check(main and main.name == "PvP Watchlist", "main screen registered in Options > AddOns as PvP Watchlist")
check(list and list.name == "Marcados", "Marcados subpage registered")
local boxes, sliders, buttons = created.CheckButton, created.Slider, created.Button
check(#boxes == 17 and #sliders == 3, "17 checkboxes and 3 sliders")
-- checkbox order: enabled, skipIfIAttacked, ignoreLow, emote, showCount, sound, msg, center, tooltip, minimap,
-- shareGuild, shareFriends, shareBnet, sharedAlerts, sharedCenter, test, debug
local B = { enabled = boxes[1], skip = boxes[2], ignoreLow = boxes[3], emote = boxes[4], showCount = boxes[5], sound = boxes[6], msg = boxes[7], center = boxes[8], tooltip = boxes[9], minimap = boxes[10], shareGuild = boxes[11], shareFriends = boxes[12], shareBnet = boxes[13], sharedAlerts = boxes[14], sharedCenter = boxes[15], test = boxes[16], debug = boxes[17] }
check(B.shareGuild.checked == true and B.shareFriends.checked == true and B.shareBnet.checked == false
  and B.sharedAlerts.checked == true and B.sharedCenter.checked == false, "sharing: guild and friends on, Battle.net and center warning off")
local SL = { memory = sliders[1], levels = sliders[2], size = sliders[3] }
local emoteBtn, emoteTestBtn, iconBtn, friendsIconBtn, guildIconBtn, soundBtn, testBtn =
  buttons[1], buttons[2], buttons[3], buttons[4], buttons[5], buttons[6], buttons[7]
main.panel.scripts.OnShow(main.panel)
check(B.enabled.checked == true and B.ignoreLow.checked == false and B.emote.checked == true and SL.size.value == 26, "default values show on the screen")

print("-- turn off automatic marking")
setBox(B.enabled, false)
addPlate("nameplate1", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, class = "Ladino", level = 32 })
out = {}; hit()
check(not has("Marcado"), "off: does not mark")
setBox(B.enabled, true); clock = clock + 5
out = {}; hit()
check(has("Marcado: Ganker"), "on again: marks")
local p1 = plates.nameplate1
check(p1.kosSkull.texture:find("_8$") and p1.kosSkull.w == 26 and p1.kosCount.text == "1", "size 26 skull with the number 1")
check(#emotes == 1 and emotes[1] == "NO@nameplate1", "did a /no aimed at the attacker: " .. tostring(emotes[1]))
out = {}; hit()
check(#emotes == 1, "does not repeat the emote in the same fight")

print("-- emote: change, test, turn off, game block")
click(emoteBtn)
check(S.emoteToken == "RUDE", "emote changed to /rude")
units.target = units.nameplate1; emotes = {}
click(emoteTestBtn)
check(emotes[1] == "RUDE@target", "Test button on the target")
units.target = nil; emotes = {}; out = {}
click(emoteTestBtn)
check(#emotes == 0 and has("Ponha alguém no alvo"), "no target: does not emote")
click(emoteBtn, "RightButton")
check(S.emoteToken == "NO", "right click goes back to /no")
print("-- icon, size and number")
click(iconBtn)
check(S.icon == 7 and p1.kosSkull.texture:find("_7$"), "icon of your list changed to X on the nameplate")
click(iconBtn, "RightButton")
check(S.icon == 8, "right click goes back to skull")
check(S.friendsIcon == 7 and S.guildIcon == 4 and friendsIconBtn.text == "X" and guildIconBtn.text == "Triângulo",
  "default icons: friends X, guild triangle")
click(friendsIconBtn)
check(S.friendsIcon == 1 and friendsIconBtn.text == "Estrela", "friends icon changed to Star")
click(guildIconBtn, "RightButton")
check(S.guildIcon == 3 and guildIconBtn.text == "Losango", "guild icon changed to Diamond (right click)")
for _ = 1, 6 do click(friendsIconBtn) end -- Star is the 3rd of 8: 6 more clicks wrap around to the Skull
check(S.friendsIcon == 8, "friends can use the skull, the same as your list")
S.friendsIcon, S.guildIcon = 7, 4
SL.size:SetValue(40)
check(S.iconSize == 40 and p1.kosSkull.w == 40, "size 40 applied")
setBox(B.showCount, false)
check(p1.kosCount.shown == false, "number hidden")
setBox(B.showCount, true)

print("-- ignore low level")
setBox(B.ignoreLow, true); SL.levels:SetValue(5)
addPlate("nameplate2", { name = "Baixinho", guid = "G2", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, level = 20 })
clock = clock + 200; out = {}; hit()
check(not has("Marcado: Baixinho"), "level 20 against 30 with limit 5: ignored")
units.nameplate2.level = 27; clock = clock + 5; out = {}; hit()
check(has("Marcado: Baixinho"), "level 27: marked")
check(emotes[#emotes] == "NO@nameplate2", "emote on the new attacker")
setBox(B.ignoreLow, false); removePlate("nameplate2")

print("-- do not mark who I attacked (and turning the option off)")
addPlate("nameplate3", { name = "Vitima", guid = "G3", isPlayer = true, enemy = true, canAttack = true, combat = false, level = 30 })
units.target = units.nameplate3
fire("UNIT_SPELLCAST_SENT", "player", "Vitima", "c1", 172)
units.nameplate3.target = "player"; units.nameplate3.combat = true
clock = clock + 2; out = {}; hit()
check(not has("Marcado: Vitima"), "attacked first: does not mark")
setBox(B.emote, false); emotes = {}
setBox(B.skip, false); clock = clock + 2; out = {}; hit()
check(#emotes == 0, "emote off: does not do it")
setBox(B.emote, true)
check(has("Marcado: Vitima"), "option off: marks anyway")
setBox(B.skip, true); SL.memory:SetValue(30)
check(S.myAttackMemory == 30, "attack memory set to 30 s")
removePlate("nameplate3"); units.target = nil

print("-- warning when he reappears: sound, center and chat")
removePlate("nameplate1"); clock = clock + 400
sounds = {}; centers = {}; out = {}
addPlate("nameplate4", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, level = 32 })
check(#sounds == 1 and sounds[1] == 8959, "raid warning sound")
check(has("Ganker por perto", centers), "warning at the center of the screen")
check(has("Apareceu: Ganker"), "chat message")
click(soundBtn)
check(S.soundId == "ready", "sound changed to ready check")
setBox(B.sound, false); sounds = {}
click(testBtn)
check(#sounds == 1 and sounds[1] == 8960, "Test button plays even with sound off")
setBox(B.center, false); setBox(B.msg, false); setBox(B.sound, true)
removePlate("nameplate4"); clock = clock + 400; centers = {}; out = {}
addPlate("nameplate4", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, level = 32 })
check(#centers == 0 and not has("Apareceu"), "center and message off")

print("-- tooltip")
local tip = stub("Tooltip"); tip.lines = {}
tip.GetUnit = function() return "Ganker", "nameplate4" end
tip.AddLine = function(self, s) table.insert(self.lines, s) end
GameTooltip = tip
tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("PvP Watchlist: te atacou 2 vezes"), "tooltip line: " .. tostring(tip.lines[1]))
setBox(B.tooltip, false); tip.lines = {}; tooltipHook(tip)
check(#tip.lines == 0, "tooltip off")

print("-- list on the subpage and unmark by button")
list.panel.scripts.OnShow(list.panel)
local rowBtn = buttons[9] -- 8 = language
check(rowBtn.shown, "first list row with an Unmark button")
out = {}; click(rowBtn)
check(has("desmarcado"), "Unmark button works")
lockdown = true; emotes = {}
units.target = { name = "Bloqueado", guid = "G9", isPlayer = true, enemy = true, canAttack = true, level = 30 }
addPlate("nameplate9", { name = "Bloqueado", guid = "G9", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, level = 30 })
clock = clock + 300; out = {}; hit()
check(has("Marcado: Bloqueado") and #emotes == 0, "chat blocked by the game: marks without emote")
lockdown = false; emotes = {}
out = {}; slash("marcar")
check(has("Marcado à mão") and #emotes == 0, "marking by hand does not emote")
out = {}; slash("emote")
check(S.emote == false and B.emote.checked == false, "/kos emote turns it off and updates the screen")
out = {}; slash("config")
check(categories.opened == 42, "/kos config opens the screen")
out = {}; slash("debug")
check(B.debug.checked == true, "/kos debug command updates the checkbox on the screen")
print(fails == 0 and "ALL OK" or (fails .. " FAIL(S)"))
