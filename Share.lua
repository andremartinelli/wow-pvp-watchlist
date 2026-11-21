-- PvP Watchlist: troca de marcados com amigos e guilda.
-- Usa mensagens de addon, que nao aparecem no chat de ninguem: nada e feito no jogo em nome de ninguem.
-- Envia so as SUAS marcacoes confiaveis (o atacante estava com voce no alvo, ou foi marcado a mao), nunca o que
-- recebeu de outros. Recebe so de quem esta na sua guilda ou na sua lista de amigos (e do Battle.net, se ligado).
-- O jogo bloqueia mensagens de addon em instancias; fora delas a fila espera o fim do combate e do bloqueio de chat.
--
-- Mensagens (campos separados por \031):
--   H1                                                             pede a lista de quem recebe (login)
--   M1 nome guid classe CLASSE nivel guilda vezes ultima onde reino   marcacao nova ou atualizada
--   U1 nome reino                                                  desmarcou
-- Recebidas ficam em db.shared.friends / db.shared.guild [chave] = { nome, classe..., from = { [remetente] = {...} } }.

local _, ns = ...
ns = ns or {}
local core = ns.core
if not core then return end

local PREFIX = "PvPW"
local SEP = "\031"
local SEND_GAP = 1.0          -- segundos entre mensagens (o jogo limita o ritmo por prefixo)
local HELLO_DELAY = 10        -- espera depois do login antes de pedir as listas
local EXPIRE = 30 * 86400     -- marcacao recebida some depois de 30 dias sem novidade
local MAX_QUEUE = 400
local MAX_TRIES = 5
local MAX_LEN = 255           -- tamanho maximo de uma mensagem de addon

local L, safe, isSecret, say, debug = core.L, core.safe, core.isSecret, core.say, core.debug

local share = { events = { CHAT_MSG_ADDON = true, BN_CHAT_MSG_ADDON = true, GUILD_ROSTER_UPDATE = true } }
ns.share = share

local queue = {}              -- { text, kind = "GUILD" | "WHISPER" | "BN", target, tries }
local lastSend, helloAt, roster

local function DB() return core.db() end
local function S() return core.settings() end
local function circleLabel(circle) return circle == "guild" and L.SRC_GUILD or L.SRC_FRIENDS end

-- ---------------------------------------------------------------- textos e nomes

-- Corta em ate n bytes sem quebrar um caractere UTF-8 no meio.
local function cut(s, n)
    if #s <= n then return s end
    s = s:sub(1, n)
    for i = #s, math.max(1, #s - 3), -1 do
        local b = s:byte(i)
        if b < 0x80 then break end
        if b >= 0xC0 then
            local need = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or 2
            if #s - i + 1 < need then s = s:sub(1, i - 1) end
            break
        end
    end
    return s
end

local function field(v, n) return cut((tostring(v or ""):gsub(SEP, "")), n) end

local function split(text)
    local out = {}
    for part in (text .. SEP):gmatch("(.-)" .. SEP) do table.insert(out, part) end
    return out
end

local function myRealm()
    local r = safe(GetNormalizedRealmName)
    if type(r) ~= "string" or r == "" then r = safe(GetRealmName) end
    if type(r) ~= "string" or r == "" then return "?" end
    return (r:gsub("[%s%-]", ""))
end

-- "Nome-Reino" em minusculas, para comparar remetentes.
local function fullName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not name:find("-", 1, true) then name = name .. "-" .. myRealm() end
    return string.lower(name)
end

-- Tira o "-SeuReino" do fim para mostrar.
local function shortName(name)
    local n, r = name:match("^([^%-]+)%-(.+)$")
    if n and string.lower(r) == string.lower(myRealm()) then return n end
    return name
end

local function me() return fullName((safe(UnitName, "player"))) end

-- Nome do alvo como ele aparece para voce: sem reino se for do seu reino.
local function localTarget(display, senderRealm)
    local name, realm = display:match("^([^%-]+)%-(.+)$")
    if not name then name, realm = display, senderRealm end
    if realm and realm ~= "" and realm ~= "?" and string.lower(realm) ~= string.lower(myRealm()) then
        return name .. "-" .. realm
    end
    return name
end

-- ---------------------------------------------------------------- quem e amigo ou da guilda

local function inGuild(senderKey)
    if not senderKey or not safe(IsInGuild) then return false end
    if not roster then
        roster = {}
        local n = safe(GetNumGuildMembers) or 0
        for i = 1, n do
            local k = fullName((safe(GetGuildRosterInfo, i)))
            if k then roster[k] = true end
        end
    end
    return roster[senderKey] or false
end

local function isFriend(sender)
    if not (C_FriendList and C_FriendList.GetFriendInfo) then return false end
    local names = { sender }
    local n, r = sender:match("^([^%-]+)%-(.+)$")
    if n and string.lower(r) == string.lower(myRealm()) then table.insert(names, n) end
    for _, name in ipairs(names) do
        if type(safe(C_FriendList.GetFriendInfo, name)) == "table" then return true end
    end
    return false
end

local function onlineFriends()
    local out = {}
    if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return out end
    for i = 1, safe(C_FriendList.GetNumFriends) or 0 do
        local info = safe(C_FriendList.GetFriendInfoByIndex, i)
        if type(info) == "table" and info.connected and type(info.name) == "string" then table.insert(out, info.name) end
    end
    return out
end

-- Contas do Battle.net online no mesmo jogo (WoW: Forever).
local function bnetAccounts()
    local out = {}
    if not (BNGetNumFriends and BNSendGameData and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts
        and C_BattleNet.GetFriendGameAccountInfo) then return out end
    for i = 1, safe(BNGetNumFriends) or 0 do
        for j = 1, safe(C_BattleNet.GetFriendNumGameAccounts, i) or 0 do
            local info = safe(C_BattleNet.GetFriendGameAccountInfo, i, j)
            if type(info) == "table" and info.isOnline and info.gameAccountID
                and info.clientProgram == (BNET_CLIENT_WOW or "WoW")
                and (not WOW_PROJECT_ID or not info.wowProjectID or info.wowProjectID == WOW_PROJECT_ID) then
                table.insert(out, info.gameAccountID)
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------- fila de envio

local function enqueue(text, kind, target)
    if #text > MAX_LEN then return end
    for _, q in ipairs(queue) do
        if q.text == text and q.kind == kind and q.target == target then return end
    end
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    table.insert(queue, { text = text, kind = kind, target = target })
end

-- Para todos os circulos ligados. Quem e da guilda ja recebe pelo canal da guilda.
local function broadcast(text)
    local s = S()
    local guildOn = s.shareGuild and safe(IsInGuild)
    if guildOn then enqueue(text, "GUILD") end
    if s.shareFriends then
        for _, name in ipairs(onlineFriends()) do
            if not (guildOn and inGuild(fullName(name))) then enqueue(text, "WHISPER", name) end
        end
    end
    if s.shareBnet then
        for _, id in ipairs(bnetAccounts()) do enqueue(text, "BN", id) end
    end
end

local function canSend()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    if not core.inWorld() then return false end                 -- o jogo bloqueia em instancias
    if safe(UnitAffectingCombat, "player") then return false end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if not ok or isSecret(locked) or locked then return false end
    end
    return true
end

-- true = pode tirar da fila (enviada ou erro sem volta); false = tentar de novo depois (limite de ritmo).
local function sendOne(q)
    local ok, res
    if q.kind == "BN" then
        ok, res = pcall(BNSendGameData, q.target, PREFIX, q.text)
    else
        ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, q.text, q.kind, q.target)
    end
    if not ok then return true end
    if res == nil or res == true or res == 0 then return true end
    if type(Enum) == "table" and Enum.SendAddonMessageResult and res == Enum.SendAddonMessageResult.Success then return true end
    return false
end

function share.onUpdate()
    local t = core.now()
    if helloAt and t >= helloAt and canSend() then
        helloAt = nil
        share.syncNow(true)
    end
    if #queue == 0 or (lastSend and t - lastSend < SEND_GAP) or not canSend() then return end
    lastSend = t
    local q = queue[1]
    if sendOne(q) then
        table.remove(queue, 1)
    else
        q.tries = (q.tries or 0) + 1
        if q.tries >= MAX_TRIES then table.remove(queue, 1) end
    end
end

function share.pending() return #queue end

-- ---------------------------------------------------------------- o que sai

local function shareable(e) return e.shareable or e.how == "alvo" or e.how == "manual" end

local function packMark(e)
    return table.concat({ "M1", field(e.name, 40), field(e.guid, 32), field(e.class, 16), field(e.classFile, 12),
        field(e.level, 3), field(e.guild, 30), field(e.count or 1, 4), field(e.last, 11), field(e.where, 50),
        field(myRealm(), 24) }, SEP)
end

local function packUnmark(e) return table.concat({ "U1", field(e.name, 40), field(myRealm(), 24) }, SEP) end

local function sendListTo(kind, target)
    for _, e in pairs(DB().players) do
        if shareable(e) then enqueue(packMark(e), kind, target) end
    end
end

-- Manda a sua lista (e, no login, pede a dos outros). Devolve quantas mensagens foram para a fila, ou nil se desligado.
function share.syncNow(withHello)
    local s = S()
    if not (s.shareGuild or s.shareFriends or s.shareBnet) then return nil end
    local before = #queue
    if withHello then broadcast("H1") end
    for _, e in pairs(DB().players) do
        if shareable(e) then
            e.shareable = true
            broadcast(packMark(e))
        end
    end
    return #queue - before
end

function share.onMark(key, e)
    if not shareable(e) then return end
    e.shareable = true
    broadcast(packMark(e))
end

function share.onUnmark(key, e)
    if e and shareable(e) then broadcast(packUnmark(e)) end
end

-- ---------------------------------------------------------------- o que chega

-- Os dados que aparecem vem do remetente com a marcacao mais recente.
local function recompute(e)
    local best
    for _, r in pairs(e.from or {}) do
        if not best or (r.last or 0) > (best.last or 0) then best = r end
    end
    if not best then return false end
    e.count, e.last, e.where, e.by = best.count, best.last, best.where, best.n
    return true
end

local function upsert(circle, senderKey, senderName, f)
    if f[2] == "" then return end
    local list = DB().shared[circle]
    local tname = localTarget(f[2], f[11])
    local key = string.lower(tname)
    local guid = (f[3] ~= "" and f[3]) or nil
    local e = list[key]
    if e and e.guid and guid and e.guid ~= guid then e = nil end -- outro personagem com o mesmo nome
    e = e or {}
    e.from = e.from or {}
    local last = tonumber(f[9]) or 0
    local classFile = (f[5] ~= "" and f[5]) or nil
    local names = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE or nil
    e.name = tname
    e.guid = guid or e.guid
    e.classFile = classFile or e.classFile
    e.class = (classFile and names and names[classFile]) or (f[4] ~= "" and f[4]) or e.class
    e.level = tonumber(f[6]) or e.level
    e.guild = (f[7] ~= "" and f[7]) or e.guild
    e.from[senderKey] = { n = senderName, count = tonumber(f[8]) or 1, last = last, where = (f[10] ~= "" and f[10]) or nil }
    if e.hidden and last > (e.hiddenLast or 0) then e.hidden, e.hiddenLast = nil, nil end -- atacou de novo
    recompute(e)
    list[key] = e
    debug(string.format(L.DBG_SHARE_GOT, senderName, tname, circleLabel(circle)))
    core.refresh()
end

local function removeFrom(senderKey, f)
    local key = string.lower(localTarget(f[2], f[3]))
    local changed = false
    for _, c in ipairs(core.CIRCLES) do
        local list = DB().shared[c]
        local e = list[key]
        if e and e.from and e.from[senderKey] then
            e.from[senderKey] = nil
            if not recompute(e) then list[key] = nil end
            changed = true
        end
    end
    if changed then core.refresh() end
end

local function handle(text, circle, senderName, senderKey, kind, target)
    local f = split(text)
    for i = 1, 11 do f[i] = f[i] or "" end
    if f[1] == "H1" then
        debug(string.format(L.DBG_SHARE_HELLO, senderName))
        sendListTo(kind, target)
    elseif f[1] == "M1" then
        upsert(circle, senderKey, senderName, f)
    elseif f[1] == "U1" then
        removeFrom(senderKey, f)
    end
end

local function onAddonMessage(prefix, text, channel, sender)
    if isSecret(prefix) or isSecret(text) or isSecret(channel) or isSecret(sender) then return end
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local senderKey = fullName(sender)
    if senderKey == me() or DB().blocked[senderKey] then return end
    local s = S()
    local circle
    if s.shareFriends and isFriend(sender) then
        circle = "friends"
    elseif s.shareGuild and (channel == "GUILD" or inGuild(senderKey)) then
        circle = "guild"
    end
    if not circle then debug(string.format(L.DBG_SHARE_IGNORED, sender)) return end
    handle(text, circle, shortName(sender), senderKey, "WHISPER", sender)
end

local function onBnMessage(prefix, text, channel, gameAccountID)
    if isSecret(prefix) or isSecret(text) or isSecret(gameAccountID) then return end
    if prefix ~= PREFIX or type(text) ~= "string" or not S().shareBnet then return end
    if not (C_BattleNet and C_BattleNet.GetGameAccountInfoByID) then return end
    local info = safe(C_BattleNet.GetGameAccountInfoByID, gameAccountID)
    if type(info) ~= "table" or type(info.characterName) ~= "string" or info.characterName == "" then return end
    local realm = type(info.realmName) == "string" and (info.realmName:gsub("[%s%-]", "")) or ""
    local display = realm ~= "" and (info.characterName .. "-" .. realm) or info.characterName
    local senderKey = fullName(display)
    if senderKey == me() or DB().blocked[senderKey] then return end
    handle(text, "friends", shortName(display), senderKey, "BN", gameAccountID)
end

function share.onEvent(event, ...)
    if event == "CHAT_MSG_ADDON" then
        onAddonMessage(...)
    elseif event == "BN_CHAT_MSG_ADDON" then
        onBnMessage(...)
    elseif event == "GUILD_ROSTER_UPDATE" then
        roster = nil
    end
end

-- ---------------------------------------------------------------- ocultar, bloquear, limpar

-- Some da tela ate o mesmo jogador ser marcado de novo depois disso.
function share.hide(circle, key)
    local list = DB().shared[circle]
    local e = list and list[key]
    if not e then return end
    e.hidden, e.hiddenLast = true, e.last
    say(string.format(L.HIDDEN, e.name or key))
    core.refresh()
end

-- Remetentes que batem com o nome digitado (com ou sem reino).
local function matchingSenders(text)
    local q = string.lower(text)
    local keys = {}
    keys[fullName(text)] = text
    for _, c in ipairs(core.CIRCLES) do
        for _, e in pairs(DB().shared[c]) do
            for sk, r in pairs(e.from or {}) do
                if string.lower(r.n or "") == q or sk:match("^([^%-]+)") == q then keys[sk] = r.n or text end
            end
        end
    end
    return keys
end

local function dropSender(sk)
    local removed = 0
    for _, c in ipairs(core.CIRCLES) do
        local list = DB().shared[c]
        for key, e in pairs(list) do
            if e.from and e.from[sk] then
                e.from[sk] = nil
                removed = removed + 1
                if not recompute(e) then list[key] = nil end
            end
        end
    end
    return removed
end

function share.block(text)
    local removed = 0
    for sk, name in pairs(matchingSenders(text)) do
        DB().blocked[sk] = name
        removed = removed + dropSender(sk)
    end
    say(string.format(L.BLOCKED, text, removed))
    core.refresh()
end

function share.unblock(text)
    local q, full, found = string.lower(text), fullName(text), false
    for sk, name in pairs(DB().blocked) do
        if sk == full or string.lower(name or "") == q or sk:match("^([^%-]+)") == q then
            DB().blocked[sk] = nil
            found = true
        end
    end
    say(string.format(found and L.UNBLOCKED or L.NOT_BLOCKED, text))
end

local function prune()
    local limit, blocked = time() - EXPIRE, DB().blocked
    for _, c in ipairs(core.CIRCLES) do
        local list = DB().shared[c]
        for key, e in pairs(list) do
            for sk, r in pairs(e.from or {}) do
                if (r.last or 0) < limit or blocked[sk] then e.from[sk] = nil end
            end
            if not recompute(e) then list[key] = nil end
        end
    end
end

function share.onLogin()
    prune()
    roster = nil
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then pcall(GuildRoster) end
    helloAt = core.now() + HELLO_DELAY
    core.refresh()
end

-- Mudou algo na tela: esquece a fila antiga e manda de novo para quem ficou ligado.
function share.settingsChanged()
    queue, roster = {}, nil
    helloAt = core.now() + 2
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
for event in pairs(share.events) do core.registerEvent(event) end
