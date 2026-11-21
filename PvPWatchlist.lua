-- PvP Watchlist 1.5.0 (WoW: Forever). Ate a 1.3.0 se chamava killonsight.
-- Marca quem te ataca primeiro no PvP de mundo e avisa quando ele aparece de novo.
-- Marks whoever attacks you first in world PvP and warns you when they show up again.
-- Textos em Locales.lua (portugues e ingles). Icones em media/ (icon.tga e guild.tga).
-- A troca de marcados com amigos e guilda fica em Share.lua; aqui ficam as listas recebidas (db.shared),
-- os icones por origem (caveira = sua lista, X = amigos, G = guilda), os avisos e a tela.
--
-- O Forever bloqueia COMBAT_LOG_EVENT_UNFILTERED para addons, entao o addon nao sabe quem deu cada golpe.
-- Como funciona: quando voce leva um golpe (UNIT_COMBAT no "player") ou entra em combate, ele procura, por
-- SCAN_WINDOW segundos, jogadores inimigos por perto (barras de nome, alvo, foco, mouseover) que estejam em
-- combate e com VOCE no alvo. Esses sao marcados, a nao ser que voce tenha atacado o jogador antes.
-- No Forever varios valores ficam "secretos" em combate; tudo que pode vir secreto passa por safe().
-- Configuracoes: Opcoes > AddOns > PvP Watchlist (ou /pvpw config). /kos tambem, se nenhum outro addon usar.

local ADDON, ns = ...
ADDON = ADDON or "PvPWatchlist"
ns = ns or {}

local ICON_PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\icon"
local LINK_BASE = "addon:" .. ADDON .. ":"   -- links do chat: "unmark:<chave>" e "hide:<origem>:<chave>"
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local SOURCE_ICONS = { friends = RAID_ICON .. "7", guild = "Interface\\AddOns\\" .. ADDON .. "\\media\\guild" }
local CIRCLES = { "friends", "guild" }        -- listas recebidas, na ordem de prioridade depois da sua
local SCAN_WINDOW = 3        -- segundos procurando o atacante depois de um golpe (pega o ladino que sai da furtividade)
local SCAN_STEP = 0.2        -- intervalo entre as procuras dentro dessa janela
local RECOUNT_GAP = 120      -- um novo ataque do mesmo jogador so soma depois de 2 min
local ALERT_GAP = 300        -- aviso de "apareceu" no maximo a cada 5 min por jogador
local MAX_PLATES = 40
local ATTACK_ACTIONS = {
    WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true,
    ABSORB = true, IMMUNE = true, DEFLECT = true, REFLECT = true, EVADE = true,
}
local DEFAULTS = {
    enabled = true,           -- marcar automaticamente quem te ataca
    skipIfIAttacked = true,   -- nao marcar quem voce atacou primeiro
    myAttackMemory = 60,      -- por quantos segundos lembrar do seu ataque
    ignoreLow = false,        -- ignorar jogadores bem abaixo do seu nivel
    ignoreLowLevels = 10,     -- diferenca de niveis para ignorar
    emote = true,             -- fazer um emote no atacante quando ele e marcado
    emoteToken = "NO",        -- qual emote (/no)
    icon = 8,                 -- icone de raide (8 = caveira)
    iconSize = 26,
    showCount = true,         -- numero de ataques ao lado do icone
    sound = true,
    soundId = "raid",
    msg = true,               -- mensagem no chat quando um marcado aparece
    center = true,            -- aviso grande no centro da tela
    tooltip = true,           -- linha no tooltip do jogador
    test = false,             -- adversario de duelo conta como inimigo
    debug = false,
    minimap = true,           -- botao no minimapa
    minimapAngle = 200,       -- posicao do botao, em graus a partir da direita (sentido anti-horario)
    language = "auto",        -- "auto" (do jogo), "ptBR" ou "enUS"
    shareGuild = true,        -- trocar marcados com a guilda (enviar e receber)
    shareFriends = true,      -- trocar marcados com a lista de amigos
    shareBnet = false,        -- trocar marcados com amigos do Battle.net
    sharedAlerts = true,      -- mensagem no chat quando aparece alguem marcado por amigos ou guilda
    sharedCenter = false,     -- aviso grande no centro tambem para eles
}

-- ---------------------------------------------------------------- idioma

local LOCALES = ns.LOCALES or {}
local lang = "enUS"

-- "auto" segue o cliente: portugues (ptBR/ptPT) ou ingles para todo o resto.
local function pickLanguage(setting)
    if setting == "ptBR" or setting == "enUS" then return setting end
    local ok, loc = pcall(GetLocale)
    if ok and (loc == "ptBR" or loc == "ptPT") then return "ptBR" end
    return "enUS"
end

-- L.CHAVE devolve o texto no idioma atual; o que faltar cai no ingles e, por fim, na propria chave.
local L = setmetatable({}, { __index = function(_, k)
    local t = LOCALES[lang]
    local v = t and t[k]
    if v == nil and LOCALES.enUS then v = LOCALES.enUS[k] end
    if v == nil then v = k end
    return v
end })
lang = pickLanguage("auto")

-- Icones para a sua lista. O X (7) fica reservado para os marcados dos amigos e o G para os da guilda.
local ICONS = {
    { id = 8, labelKey = "ICON_SKULL" }, { id = 1, labelKey = "ICON_STAR" },
    { id = 2, labelKey = "ICON_CIRCLE" }, { id = 3, labelKey = "ICON_DIAMOND" }, { id = 4, labelKey = "ICON_TRIANGLE" },
    { id = 5, labelKey = "ICON_MOON" }, { id = 6, labelKey = "ICON_SQUARE" },
}
for _, e in ipairs(ICONS) do e.icon = RAID_ICON .. e.id end
-- Filtro da pagina "Marcados".
local LIST_SOURCES = {
    { id = "mine", labelKey = "FILTER_MINE" },
    { id = "friends", labelKey = "FILTER_FRIENDS", icon = SOURCE_ICONS.friends },
    { id = "guild", labelKey = "FILTER_GUILD", icon = SOURCE_ICONS.guild },
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
local LANGS = {
    { id = "auto", labelKey = "LANG_AUTO" }, { id = "ptBR", label = "Português" }, { id = "enUS", label = "English" },
}

local db, S                -- PvPWatchlistDB e PvPWatchlistDB.settings
local scanUntil, nextScan = 0, 0
local myAttacks = {}       -- chave do jogador -> GetTime() do seu ultimo ataque a ele
local ui = { refreshers = {} }
local f = CreateFrame("Frame")

-- ---------------------------------------------------------------- utilitarios

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Chama fn protegido. Devolve nil no lugar de erro ou de valor secreto.
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

-- Chave, nome para mostrar e GUID (pode ser nil) de um jogador.
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

-- Jogador da faccao inimiga que voce pode atacar. No modo teste, qualquer jogador atacavel (duelo) conta.
local function isEnemyPlayer(unit)
    if not safe(UnitExists, unit) or not safe(UnitIsPlayer, unit) then return false end
    if safe(UnitIsUnit, unit, "player") then return false end
    if not safe(UnitCanAttack, "player", unit) then return false end
    if safe(UnitIsEnemy, "player", unit) then return true end
    return S.test and true or false
end

-- true/false, ou nil quando o jogo esconde a resposta.
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

-- Jogador bem abaixo do seu nivel (opcao "ignorar"). Nivel desconhecido (??) nunca e ignorado.
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
    if e and e.guid and guid and e.guid ~= guid then return nil end -- mesmo nome, outro personagem
    return e, key, display, guid
end

-- Origem ligada nas configuracoes? Amigos vale para a lista de amigos e para o Battle.net.
local function circleOn(circle)
    if circle == "guild" then return S.shareGuild end
    return S.shareFriends or S.shareBnet
end

local function circleLabel(circle) return circle == "guild" and L.SRC_GUILD or L.SRC_FRIENDS end

-- Marcacao recebida de amigos ou da guilda (nil se oculta, sem dados, desligada ou de outro personagem).
local function sharedEntry(circle, key, guid)
    if not circleOn(circle) then return nil end
    local list = db.shared and db.shared[circle]
    local e = list and list[key]
    if not e or e.hidden or not e.last then return nil end
    if e.guid and guid and e.guid ~= guid then return nil end
    return e
end

-- Todas as marcacoes de um jogador inimigo, da mais importante para a menos: a sua, amigos, guilda.
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

local function iconTexture() return findIn(ICONS, S.icon).icon end

-- Icone de cada origem: o escolhido para a sua lista, X para amigos, G para a guilda.
local function sourceTexture(source) return SOURCE_ICONS[source] or iconTexture() end

local function playAlert(force)
    if not S.sound and not force then return end
    pcall(PlaySound, findIn(SOUNDS, S.soundId).kit(), "Master")
end

-- on = a opcao que liga o aviso (S.center para a sua lista, S.sharedCenter para amigos e guilda).
local function centerWarning(text, on)
    if not on then return end
    if RaidNotice_AddMessage and RaidWarningFrame then
        local color = (ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]) or { r = 1, g = 0.2, b = 0.2 }
        if pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color) then return end
    end
    if UIErrorsFrame then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, text, 1, 0.2, 0.2) end
end

-- Emote direcionado a um jogador (unidade viva: "nameplate3", "target"). Nunca sem alvo: no Forever,
-- PerformEmote(token, nil) cai no seu alvo atual, que pode ser outra pessoa (nota do addon TFTB).
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

-- ---------------------------------------------------------------- icone nas barras de nome

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

-- e = registro do marcado (mostra o icone da origem) ou nil (esconde).
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

-- A marcacao que aparece no jogador (a sua primeiro), de onde ela veio e a chave.
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

-- ---------------------------------------------------------------- marcar / desmarcar

local function unmarkLink(key)
    return "|H" .. LINK_BASE .. "unmark:" .. key .. "|h|cff66bbff[" .. L.UNMARK_LINK .. "]|r|h"
end

local function hideLink(circle, key)
    return "|H" .. LINK_BASE .. "hide:" .. circle .. ":" .. key .. "|h|cff66bbff[" .. L.HIDE_LINK .. "]|r|h"
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
    if type(clsFile) == "string" then e.classFile = clsFile end -- "ROGUE": quem recebe traduz para o idioma dele
    if type(lvl) == "number" and lvl > 0 then e.level = lvl end
    e.guild = guild or e.guild
    e.last = t
    e.where = (sub ~= "" and sub ~= zone) and (sub .. ", " .. zone) or zone
    e.how = how
    e.alertAt = t -- ja esta na sua frente; o aviso de "apareceu" fica para a proxima vez
    if how == "manual" then
        say(string.format(L.MARKED_MANUAL, describe(e)) .. " " .. unmarkLink(key))
    else
        say(string.format(L.MARKED, describe(e), e.where, plural(e.count)) .. " " .. unmarkLink(key))
        doEmote(unit)
    end
    playAlert()
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

-- Links "[desmarcar]" e "[ocultar]" do chat.
local lastLink, lastLinkAt = nil, 0
local function handleLink(link)
    if type(link) ~= "string" or link:sub(1, #LINK_BASE) ~= LINK_BASE then return end
    local t = GetTime()
    if lastLink == link and t - lastLinkAt < 0.5 then return end -- os dois ganchos abaixo podem chamar
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

-- ---------------------------------------------------------------- quem te atacou

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

local function iAttackedFirst(key)
    if not S.skipIfIAttacked then return false end
    local t = myAttacks[key]
    return t and (now() - t) <= (S.myAttackMemory or 60)
end

local function tryMark(u, key, display, guid, how)
    if iAttackedFirst(key) then
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
    -- Se o jogo esconder quem e o alvo de cada um, so marca quando ha exatamente um inimigo possivel.
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

-- Voce atacou alguem: guarda para nao marcar quem so revidou.
local function rememberMyAttack(unit)
    if isEnemyPlayer(unit) then
        local key, display = unitInfo(unit)
        if key then
            myAttacks[key] = now()
            debug(string.format(L.DBG_I_ATTACKED, display))
        end
    end
end

local function onSpellSent(targetName, spellID)
    local tn = (not isSecret(targetName)) and targetName or nil
    if type(tn) == "string" and tn ~= "" then
        for _, u in ipairs({ "target", "focus", "mouseover" }) do
            local name = safe(UnitName, u)
            if name and (name == tn or tn:find("^" .. name .. "%-")) then rememberMyAttack(u) return end
        end
        return
    end
    -- Sem o nome do alvo: so conta se a magia for ofensiva.
    local harmful = false
    if C_Spell and C_Spell.IsSpellHarmful and spellID then
        harmful = safe(C_Spell.IsSpellHarmful, spellID) and true or false
    elseif IsHarmfulSpell and spellID and GetSpellInfo then
        local sname = safe(GetSpellInfo, spellID)
        harmful = sname and safe(IsHarmfulSpell, sname) and true or false
    end
    if harmful then rememberMyAttack("target") end
end

-- ---------------------------------------------------------------- aviso quando um marcado aparece

-- Marcados de amigos e guilda: so mensagem no chat (e, se ligado, o aviso no centro); sem som.
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
        centerWarning("|T" .. iconTexture() .. ":18|t " .. string.format(L.NEARBY, e.name, plural(e.count or 1)), S.center)
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

-- Linhas no tooltip do jogador marcado: a sua e as de amigos e guilda.
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

-- ---------------------------------------------------------------- tela de configuracoes (Opcoes > AddOns)

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

-- Botao que passa pelas opcoes da lista (clique: proxima; botao direito: anterior).
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
    -- Filtro: sua lista, amigos ou guilda (clique: proximo; botao direito: anterior).
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
        content:SetSize(620, 1000)
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

-- Idioma: mensagens mudam na hora; os textos fixos da tela de configuracoes so depois de /reload.
local function setLanguage(id)
    S.language = findIn(LANGS, id).id
    lang = pickLanguage(S.language)
    say(string.format(L.LANG_SET, labelOf(findIn(LANGS, S.language))))
    refreshUI()
end
function ui.languageChanged() setLanguage(S.language) end

-- ---------------------------------------------------------------- botao do minimapa e menu de addons
-- Feito sem biblioteca, com a arte e as medidas que a LibDBIcon usa no cliente moderno.

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

-- Clique esquerdo: configuracoes. Direito: liga/desliga a marcacao automatica.
local function launcherClick(button)
    if not db then return end
    if button == "RightButton" then toggle("enabled", L.T_ENABLED) else openOptions() end
end

-- Menu de addons ao lado do minimapa (linhas AddonCompartmentFunc no .toc). Precisam ser globais.
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

-- ---------------------------------------------------------------- comandos

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

-- source = nil (sua lista), "friends" ou "guild".
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

-- Cada comando aceita o nome em portugues e em ingles.
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

-- /kos vira atalho so se nenhum outro addon (por exemplo o Kill on Sight) ja usar. Roda no PLAYER_LOGIN,
-- quando os outros addons ja registraram os comandos deles.
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

-- ---------------------------------------------------------------- eventos

f:SetScript("OnUpdate", function(_, elapsed)
    if db and ns.share then pcall(ns.share.onUpdate, elapsed) end -- fila de envio do compartilhamento
    if scanUntil == 0 then return end
    local t = now()
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
        if S.icon == 7 then S.icon = 8 end -- o X agora marca quem veio dos amigos
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
        if unit ~= "player" then return end
        if isSecret(action) or ATTACK_ACTIONS[action] then
            startScan(string.format(L.DBG_HIT, isSecret(action) and "?" or tostring(action)))
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        startScan(L.DBG_COMBAT)
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, targetName, _, spellID = ...
        if unit == "player" then onSpellSent(targetName, spellID) end
    elseif event == "PLAYER_ENTER_COMBAT" then -- ataque automatico (corpo a corpo)
        rememberMyAttack("target")
    elseif event == "PET_ATTACK_START" then
        rememberMyAttack("pettarget")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        checkUnit(unit, true)
        if scanUntil > 0 then nextScan = 0 end -- inimigo novo na tela durante a procura: olha logo
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        setIcon(..., nil)
    elseif event == "PLAYER_TARGET_CHANGED" then
        checkUnit("target", false)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        checkUnit("mouseover", false)
    elseif event == "PLAYER_ENTERING_WORLD" then
        refreshPlates()
        ui.showMinimap() -- o minimapa pode mudar de tamanho depois do carregamento
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
if f.RegisterUnitEvent then
    f:RegisterUnitEvent("UNIT_COMBAT", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
else
    f:RegisterEvent("UNIT_COMBAT")
    f:RegisterEvent("UNIT_SPELLCAST_SENT")
end

-- O que o Share.lua (carregado depois deste arquivo) usa daqui.
ns.core = {
    L = L, safe = safe, isSecret = isSecret, say = say, debug = debug, now = now, inWorld = inWorld,
    CIRCLES = CIRCLES,
    db = function() return db end,
    settings = function() return S end,
    refresh = refreshAll,
    registerEvent = function(event) pcall(f.RegisterEvent, f, event) end, -- evento que o cliente nao tem: ignora
}
