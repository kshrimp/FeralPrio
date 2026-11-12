-- FeralPrio: advisory cat priority, built for the 3.3.5a API.
local addon = CreateFrame("Frame", "FeralPrioFrame", UIParent)
local spells = {
    roar = 52610, rake = 1822, rip = 1079, shred = 5221,
    bite = 22568, fury = 5217, berserk = 50334, mangle = 33876,
    fire = 16857, grasp = 16689, clear = 16870,
}
local names, textures = {}, {}
for key, id in pairs(spells) do
    names[key] = GetSpellInfo(id)
    textures[key] = GetSpellTexture(id)
end
local icons = {}
local furyFrame
local trackedTarget, seenRoar
local energyCost = {roar = 25, rake = 35, rip = 30, shred = 42, bite = 35, mangle = 40}
local defaults = {x = 0, y = -120, size = 48, spacing = 5, count = 3, locked = false, opener = 1, showPadding = true}
local function say(message) DEFAULT_CHAT_FRAME:AddMessage("|cffedae48FeralPrio:|r " .. message) end
local function buff(unit, wanted, harmful)
    local reader = harmful and UnitDebuff or UnitBuff
    for i = 1, 40 do
        local name, _, _, _, _, _, expiration, caster = reader(unit, i)
        if not name then break end
        if name == wanted and (not harmful or caster == "player") then
            return math.max(0, (expiration or 0) - GetTime()), true
        end
    end
    return 0, false
end
local function ready(key)
    if not names[key] or not IsUsableSpell(names[key]) then return false end
    local start, duration, enabled = GetSpellCooldown(names[key])
    if enabled == 0 then return false end
    return not start or duration == 0 or start + duration - GetTime() <= 1.5
end
local function hasSpell(key)
    return names[key] and GetSpellTexture(names[key]) ~= nil
end
local function choose(s)
    -- The selected Warmane 3.3.5a opener: Mangle, Rake, 4-5 CP Roar.
    if s.opening then
        if s.mangle <= 1 and s.canMangle and s.cp < 5 then return "mangle" end
        if s.rake <= 1 and s.cp < 5 then return "rake" end
        if s.cp >= 4 then return "roar" end
        return "shred"
    end
    -- During normal combat, protect Roar and Rip before spending CP on Bite.
    if s.roar <= 1 and s.cp > 0 and (s.rip > 0 or s.cp >= 4) then return "roar" end
    if s.rip <= 1 and s.cp >= 5 then return "rip" end
    if s.berserk and s.roar > 0 and s.energy <= 20 and s.rip > 4 then return "berserk" end
    if s.rake <= 1 and s.cp < 5 then return "rake" end
    if s.mangle <= 1 and s.canMangle and s.cp < 5 then return "mangle" end
    if s.cp == 5 then
        if s.roar <= 3 or s.rip <= 3 then
            return s.roar <= s.rip and "roar" or "rip"
        end
        if s.roar > 12 and s.rip > 8 and s.rake > 2 then return "bite" end
        if s.rake <= 1 and s.roar > 12 and s.rip > 8 then return "bite" end
        return s.roar <= s.rip and "roar" or "rip"
    end
    if s.roar <= 3 and s.cp >= 4 then return "roar" end
    if s.energy >= 42 or s.clear then return "shred" end
    if s.showPadding and s.fire then return "fire" end
    if s.showPadding and s.grasp then return "grasp" end
    return "shred"
end
local function nextDelay(s, key)
    local energy = energyCost[key] or 0
    local energyDelay = s.clear and 0 or math.max(0, (energy - s.energy) / 10)
    local timerDelay = 0
    if key == "roar" then timerDelay = math.max(0, s.roar - 1)
    elseif key == "rip" then timerDelay = math.max(0, s.rip - 1)
    elseif key == "rake" then timerDelay = math.max(0, s.rake - 1)
    elseif key == "mangle" then timerDelay = math.max(0, s.mangle - 1)
    end
    return math.max(energyDelay, timerDelay, (s.cooldowns and s.cooldowns[key]) or 0)
end
local function advance(s, key, delay)
    local n = {}
    for k, v in pairs(s) do n[k] = v end
    local elapsed = delay + 1.5
    n.roar = math.max(0, n.roar - elapsed)
    n.rip = math.max(0, n.rip - elapsed)
    n.rake = math.max(0, n.rake - elapsed)
    n.mangle = math.max(0, n.mangle - elapsed)
    n.energy = math.min(100, n.energy + elapsed * 10)
    n.energy = math.max(0, n.energy - (s.clear and 0 or (energyCost[key] or 0)))
    if n.cooldowns then
        for spell, remaining in pairs(n.cooldowns) do n.cooldowns[spell] = math.max(0, remaining - elapsed) end
    end
    if key == "roar" then n.roar = 9 + 5 * n.cp; n.cp = 0; n.opening = false
    elseif key == "rip" then n.rip = 16; n.cp = 0
    elseif key == "rake" then n.rake = 9; n.cp = math.min(5, n.cp + 1)
    elseif key == "mangle" then n.mangle = 60; n.cp = math.min(5, n.cp + 1)
    elseif key == "shred" then n.cp = math.min(5, n.cp + 1)
    elseif key == "bite" then n.cp = 0
    elseif key == "fury" then n.fury = false; n.energy = math.min(100, n.energy + 60)
    elseif key == "berserk" then n.berserk = false
    elseif key == "fire" then n.fire = false
    elseif key == "grasp" then n.grasp = false
    end
    n.clear = false
    return n
end
local function layout()
    addon:ClearAllPoints()
    addon:SetPoint("CENTER", UIParent, "CENTER", FeralPrioDB.x, FeralPrioDB.y)
    addon:SetWidth(FeralPrioDB.size)
    addon:SetHeight(FeralPrioDB.size)
    if furyFrame then
        furyFrame:SetWidth(FeralPrioDB.size * .8)
        furyFrame:SetHeight(FeralPrioDB.size * .8)
        furyFrame:ClearAllPoints()
        furyFrame:SetPoint("RIGHT", addon, "LEFT", -FeralPrioDB.spacing, 0)
        furyFrame.highlight:SetWidth(FeralPrioDB.size * 1.44)
        furyFrame.highlight:SetHeight(FeralPrioDB.size * 1.44)
    end
    for i, frame in ipairs(icons) do
        frame:ClearAllPoints()
        frame:SetWidth(i == 1 and FeralPrioDB.size or FeralPrioDB.size * .8)
        frame:SetHeight(i == 1 and FeralPrioDB.size or FeralPrioDB.size * .8)
        frame.highlight:SetWidth(frame:GetWidth() * 1.8)
        frame.highlight:SetHeight(frame:GetHeight() * 1.8)
        frame:SetPoint("LEFT", i == 1 and addon or icons[i - 1], i == 1 and "LEFT" or "RIGHT", i == 1 and 0 or FeralPrioDB.spacing, 0)
    end
end
local function update()
    local _, class = UnitClass("player")
    local _, formName = GetShapeshiftFormInfo(GetShapeshiftForm())
    local cat = class == "DRUID" and (UnitPowerType("player") == 3 or formName == GetSpellInfo(768))
    local active = cat and UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDead("target") and not UnitIsDead("player")
    addon:Show()
    if not active then
        furyFrame:Hide()
        for i, frame in ipairs(icons) do
            if i <= FeralPrioDB.count then
                local key = (i == 1 and "shred") or (i == 2 and "rake") or "roar"
                frame.icon:SetTexture(textures[key])
                frame.label:SetText("PREVIEW")
                frame.cdText:SetText("")
                frame.highlight:Hide()
                frame:SetAlpha(.65)
                frame:Show()
            else frame:Hide() end
        end
        return
    end
    local roar = buff("player", names.roar, false)
    local rake = buff("target", names.rake, true)
    local rip = buff("target", names.rip, true)
    local mangle = buff("target", names.mangle, true)
    local guid = UnitGUID("target")
    if guid ~= trackedTarget then trackedTarget, seenRoar = guid, false end
    if roar > 0 then seenRoar = true end
    local s = {
        cp = GetComboPoints("player", "target") or 0, energy = UnitMana("player") or 0,
        roar = roar, rake = rake, rip = rip, mangle = mangle,
        canMangle = hasSpell("mangle"), fury = ready("fury"), berserk = ready("berserk"),
        fire = ready("fire"), grasp = ready("grasp"), showPadding = FeralPrioDB.showPadding,
        clear = select(2, buff("player", names.clear, false)),
        opening = not seenRoar,
        cooldowns = {},
    }
    for key, name in pairs(names) do
        if name then
            local start, duration = GetSpellCooldown(name)
            s.cooldowns[key] = start and duration and math.max(0, start + duration - GetTime()) or 0
        end
    end
    -- Mangle debuff can be supplied by another player; do not insist on our own.
    for i = 1, 40 do
        local name, _, _, _, _, _, expiration = UnitDebuff("target", i)
        if not name then break end
        if name == names.mangle or (name and string.find(name, "Mangle", 1, true)) then
            s.mangle = math.max(s.mangle, (expiration or 0) - GetTime())
        end
    end
    -- Tiger's Fury is off the GCD: show it beside the main row and project
    -- the energy it grants into the simultaneous regular-ability suggestion.
    if s.fury and s.energy <= 40 and s.roar > 0 then
        furyFrame:Show()
        furyFrame.highlight:Show()
        s.energy = math.min(100, s.energy + 60)
        s.fury = false
    else
        furyFrame:Hide()
    end
    for i, frame in ipairs(icons) do
        if i <= FeralPrioDB.count then
            local key = choose(s)
            local delay = nextDelay(s, key)
            local texture = textures[key] or (names[key] and GetSpellTexture(names[key]))
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            frame.icon:SetTexture(texture)
            local actionable = delay <= .1
            frame.label:SetText("")
            if names[key] then
                local start, duration = GetSpellCooldown(names[key])
                local remaining = start and duration and math.max(0, start + duration - GetTime()) or 0
                local shown = math.max(delay, remaining)
                if shown > 0.1 then
                    frame.cdText:SetText(string.format(shown >= 10 and "%.0f" or "%.1f", shown))
                else
                    frame.cdText:SetText("")
                end
            else
                frame.cdText:SetText("")
            end
            frame:SetAlpha(i == 1 and (actionable and 1 or .65) or .65)
            if i == 1 and actionable then frame.highlight:Show() else frame.highlight:Hide() end
            frame:Show()
            s = advance(s, key, delay)
        else frame:Hide() end
    end
end
local lastError
local function safeUpdate()
    local ok, err = pcall(update)
    if ok then return end
    addon:Show()
    furyFrame:Hide()
    for i, frame in ipairs(icons) do
        if i == 1 then
            frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            frame.label:SetText("ERROR")
            frame.cdText:SetText("")
            frame:Show()
        else frame:Hide() end
    end
    if err ~= lastError then
        lastError = err
        say("Lua error: " .. tostring(err))
    end
end
addon:SetMovable(true)
addon:EnableMouse(true)
addon:RegisterForDrag("LeftButton")
addon:SetScript("OnDragStart", function(self) if not FeralPrioDB.locked then self:StartMoving() end end)
addon:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    FeralPrioDB.x, FeralPrioDB.y = x - ux, y - uy
    layout()
end)
for i = 1, 5 do
    local frame = CreateFrame("Frame", nil, addon)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.highlight = frame:CreateTexture(nil, "OVERLAY")
    frame.highlight:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    frame.highlight:SetBlendMode("ADD")
    frame.highlight:SetPoint("CENTER", frame, "CENTER")
    frame.highlight:SetWidth(1.8 * 48)
    frame.highlight:SetHeight(1.8 * 48)
    frame.highlight:Hide()
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("CENTER")
    frame.cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.cdText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    frame.cdText:SetTextColor(1, 1, 1)
    icons[i] = frame
end
furyFrame = CreateFrame("Frame", nil, addon)
furyFrame.icon = furyFrame:CreateTexture(nil, "ARTWORK")
furyFrame.icon:SetAllPoints(furyFrame)
furyFrame.icon:SetTexture(textures.fury or "Interface\\Icons\\Ability_Mount_JungleTiger")
furyFrame.highlight = furyFrame:CreateTexture(nil, "OVERLAY")
furyFrame.highlight:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
furyFrame.highlight:SetBlendMode("ADD")
furyFrame.highlight:SetPoint("CENTER", furyFrame, "CENTER")
furyFrame:Hide()
SLASH_FERALPRIO1 = "/fp"
SLASH_FERALPRIO2 = "/feralprio"
SlashCmdList.FERALPRIO = function(command)
    local key, value = string.match(string.lower(command or ""), "^(%S*)%s*(%S*)")
    if key == "lock" then FeralPrioDB.locked = true; say("Locked.")
    elseif key == "unlock" then FeralPrioDB.locked = false; say("Unlocked. Drag the first icon.")
    elseif key == "size" and tonumber(value) then FeralPrioDB.size = math.max(24, math.min(100, tonumber(value))); layout()
    elseif key == "count" and tonumber(value) then FeralPrioDB.count = math.max(1, math.min(5, tonumber(value)))
    elseif key == "padding" then FeralPrioDB.showPadding = value ~= "off"; say("Padding " .. (FeralPrioDB.showPadding and "on" or "off"))
    elseif key == "reset" then FeralPrioDB.x, FeralPrioDB.y = 0, -120; layout()
    else say("/fp lock, unlock, size 24-100, count 1-5, padding on/off, reset") end
    safeUpdate()
end
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_TARGET_CHANGED")
addon:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_DEAD")
addon:RegisterEvent("PLAYER_ALIVE")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("UNIT_POWER")
addon:RegisterEvent("SPELL_UPDATE_COOLDOWN")
addon:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= "FeralPrio" then return end
        if type(FeralPrioDB) ~= "table" then FeralPrioDB = {} end
        for k, v in pairs(defaults) do if FeralPrioDB[k] == nil then FeralPrioDB[k] = v end end
        layout()
    end
    if FeralPrioDB then safeUpdate() end
end)
local elapsed = 0
addon:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= .15 and FeralPrioDB then elapsed = 0; safeUpdate() end
end)

