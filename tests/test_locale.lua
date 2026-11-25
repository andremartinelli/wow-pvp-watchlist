-- Simulation of the WoW API to test PvP Watchlist in English, the minimap button, the addons menu, the language switch
-- and the /kos shortcut when another addon already uses that command.
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
GetLocale = function() return "enUS" end
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
TEXTS = {}
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
    SetText = function(self, s) self.text = s; table.insert(TEXTS, s) end,
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
  o.name, o.parent = name, parent
  o.SetPoint = function(self, p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
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

-- minimap and tooltip that keep what they receive
Minimap = stub("Minimap")
Minimap.GetWidth = function() return 140 end
Minimap.GetHeight = function() return 140 end
Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 1 end
local cursorX, cursorY = 0, 0
GetCursorPosition = function() return cursorX, cursorY end
local tipLines = {}
GameTooltip = stub("GameTooltip")
GameTooltip.SetText = function(_, s) tipLines = { s } end
GameTooltip.AddLine = function(_, s) table.insert(tipLines, s) end
local function tipHas(pat) for _, l in ipairs(tipLines) do if l:find(pat) then return true end end return false end
local function textHas(pat) for _, s in ipairs(TEXTS) do if type(s) == "string" and s:find(pat) then return true end end return false end

units.player = { name = "Jogador", isPlayer = true, level = 30 }
local ns = {}
SLASH_KILLONSIGHT1 = "/kos" -- another addon (the old killonsight or Kill on Sight) already uses /kos
assert(loadfile("Locales.lua"))("PvPWatchlist", ns)
local chunk = assert(loadfile("PvPWatchlist.lua"))
chunk("PvPWatchlist", ns)
assert(loadfile("Share.lua"))("PvPWatchlist", ns)
fire("ADDON_LOADED", "PvPWatchlist")
local S = PvPWatchlistDB.settings
check(has("^%[PvPW%] loaded: 0 marked"), "English client: loading message in English")
local main, list = categories[1], categories[2]
check(main and main.name == "PvP Watchlist" and list and list.name == "Marked", "PvP Watchlist screen and subpage in English: Marked")
check(textHas("^Detection$") and textHas("^Automatically mark whoever attacks me$"), "settings screen in English")
check(textHas("AddOns\\PvPWatchlist\\media\\icon") and textHas("PvP Watchlist$"), "PvP Watchlist icon and name in the screen title")
S.debug = true; out = {}
fire("PLAYER_LOGIN")
check(SLASH_PVPWATCHLIST1 == "/pvpw" and SLASH_PVPWATCHLIST2 == nil, "/kos taken: does not register the shortcut")
check(has("/kos is already used by another addon %(SLASH_KILLONSIGHT1%): use /pvpw"), "debug explains that /kos is taken")
S.debug = false
check(#created.CheckButton == 17, "17 checkboxes (with the minimap one and the 5 sharing ones)")

print("-- minimap button")
local mm
for _, b in ipairs(created.Button) do if b.name == "PvPWatchlistMinimapButton" then mm = b end end
check(mm and mm.parent == Minimap and mm.shown, "button created on the minimap and visible")
check(mm.point and mm.point[2] == Minimap, "button positioned around the minimap")
-- 200 degrees: x = cos(200)*75, y = sin(200)*75
check(math.abs(mm.point[4] - math.cos(math.rad(200)) * 75) < 0.01 and math.abs(mm.point[5] - math.sin(math.rad(200)) * 75) < 0.01, "default position 200 degrees")

print("-- attack in English")
addPlate("nameplate1", { name = "Ganker", guid = "G1", isPlayer = true, enemy = true, canAttack = true, target = "player", combat = true, class = "Rogue", level = 32 })
out = {}; hit()
check(has("Marked: Ganker %(Rogue 32%) attacked you at Acampamento de Nesingwary, Stranglethorn %(once%)%. %[unmark%]"), "mark message in English")

print("-- click, tooltip and drag")
categories.opened = nil
click(mm, "LeftButton")
check(categories.opened == 42, "left click opens the settings")
out = {}
click(mm, "RightButton")
check(S.enabled == false and has("Automatic marking off%."), "right click turns marking off")
mm.scripts.OnEnter(mm)
check(tipHas("Automatic marking: off") and tipHas("1 player%(s%) marked") and tipHas("Drag"), "button tooltip: state, how many marked and hints")
click(mm, "RightButton")
check(S.enabled == true, "right click turns it on again")
mm.scripts.OnDragStart(mm)
cursorX, cursorY = 100, 200 -- above the minimap center: 90 degrees
mm.scripts.OnUpdate(mm)
mm.scripts.OnDragStop(mm)
check(S.minimapAngle == 90, "dragging up stores 90 degrees: " .. tostring(S.minimapAngle))
check(math.abs(mm.point[4]) < 0.01 and math.abs(mm.point[5] - 75) < 0.01, "button moved to the top of the minimap")

print("-- addons menu (compartment)")
categories.opened = nil
PvPWatchlist_OnAddonCompartmentClick("PvPWatchlist", "LeftButton")
check(categories.opened == 42, "addons menu: click opens the settings")
tipLines = {}
PvPWatchlist_OnAddonCompartmentEnter("PvPWatchlist", stub("MenuButton"))
check(tipHas("PvP Watchlist") and tipHas("Automatic marking: on") and not tipHas("Drag"), "addons menu: tooltip without the drag hint")
PvPWatchlist_OnAddonCompartmentLeave()

print("-- hide the button")
out = {}; slash("minimap")
check(S.minimap == false and mm.shown == false and has("Minimap button off%."), "/kos minimap hides the button")
local box = created.CheckButton[10]
box.checked = true; click(box)
check(S.minimap == true and mm.shown == true, "Show minimap button checkbox shows it again")

print("-- commands in both languages")
out = {}; slash("list"); check(has("1 marked, newest first:"), "/kos list")
out = {}; slash("lista"); check(has("1 marked, newest first:"), "/kos lista also works in English")
out = {}; slash(""); check(has("Commands") and has("/pvpw language auto | pt | en"), "help in English")
out = {}; slash("language xx"); check(has("Use /pvpw language auto | pt | en"), "invalid language shows the usage")

print("-- language switch")
out = {}; slash("language pt")
check(S.language == "ptBR" and has("Idioma: Português%. Use /reload"), "/kos language pt switches to Portuguese")
out = {}; slash("lista"); check(has("1 marcado%(s%), do mais recente:"), "messages now in Portuguese")
local tip = stub("Tooltip"); tip.lines = {}
tip.GetUnit = function() return "Ganker", "nameplate1" end
tip.AddLine = function(self, s) table.insert(self.lines, s) end
GameTooltip = tip
tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist: te atacou 1 vez"), "player tooltip in Portuguese: " .. tostring(tip.lines[1]))
out = {}; slash("idioma auto")
check(S.language == "auto" and has("Language: Automatic"), "/kos idioma auto goes back to the game language (English)")
tip.lines = {}; tooltipHook(tip)
check(tip.lines[1] and tip.lines[1]:find("^PvP Watchlist: attacked you once, last time on %a%a%a %d%d"), "tooltip in English with spelled-out date: " .. tostring(tip.lines[1]))
-- language button on the screen: auto -> Português
local langBtn = created.Button[8] -- after the 3 icons (your list, friends, guild)
out = {}; click(langBtn)
check(S.language == "ptBR" and langBtn.text == "Português" and has("Idioma: Português"), "Language button on the screen switches to Portuguese")
click(langBtn); click(langBtn)
check(S.language == "auto" and langBtn.text == "Automatic (game's)", "Language button goes back to automatic")

print("-- European Portuguese client falls back to Portuguese")
GetLocale = function() return "ptPT" end
out = {}; slash("idioma auto"); out = {}; slash("lista")
check(has("marcado%(s%)"), "ptPT uses Portuguese")
print(fails == 0 and "ALL OK" or (fails .. " FAIL(S)"))
