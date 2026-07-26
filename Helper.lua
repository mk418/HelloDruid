local _, ns = ...
ns.Helper = {}
local H = ns.Helper

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local RAGE = Enum and Enum.PowerType and Enum.PowerType.Rage or 1
local ENERGY = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local WOLFSHEAD_ITEM_ID = 8345
local furorRank, catCost = 0, nil

local function aura(unit, filter, name)
    if GetAuraDataByIndex then
        for index = 1, 40 do
            local data = GetAuraDataByIndex(unit, index, filter)
            if not data then break end
            if data.name == name then return data end
        end
        return nil
    end
    local getter = filter:find("HELPFUL") and UnitBuff or UnitDebuff
    for index = 1, 40 do
        local auraName, _, count, _, duration, expiration = getter(unit, index, filter:find("PLAYER") and "PLAYER" or nil)
        if not auraName then break end
        if auraName == name then
            return { name = auraName, applications = count, duration = duration, expirationTime = expiration }
        end
    end
end

function H:HasBuff(name) return aura("player", "HELPFUL", name) ~= nil end

function H:Debuff(name, anySource)
    if not UnitExists("target") then return nil end
    return aura("target", anySource and "HARMFUL" or "HARMFUL|PLAYER", name)
end

function H:DebuffTimer(name, anySource)
    local data = self:Debuff(name, anySource)
    if data and data.expirationTime and data.duration and data.duration > 0 then
        return data.expirationTime - data.duration, data.duration
    end
end

local function offCooldown(name)
    local start, duration = GetSpellCooldown(name)
    return not start or not duration or duration <= 1.5 or start + duration <= GetTime()
end

local function hostileTarget()
    return UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
end

local function targetHealthPercent()
    local maximum = UnitHealthMax("target")
    if not maximum or maximum == 0 then return 100 end
    return UnitHealth("target") / maximum * 100
end

local function targetCasting()
    if not hostileTarget() then return false end
    local name, _, _, _, _, _, _, blocked = UnitCastingInfo("target")
    if name then return not blocked end
    local channel, _, _, _, _, _, channelBlocked = UnitChannelInfo("target")
    return channel and not channelBlocked or false
end

local function isGroupedNuke()
    if not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then return false end
    if UnitExists("targettarget") and UnitIsUnit and UnitIsUnit("targettarget", "player") then return false end
    return true
end

function H:RefreshTalents()
    furorRank = 0
    if not GetNumTalentTabs then return end
    for tab = 1, GetNumTalentTabs() do
        for index = 1, (GetNumTalents(tab) or 0) do
            local name, _, _, _, rank = GetTalentInfo(tab, index)
            if name == "Furor" then furorRank = rank or 0; return end
        end
    end
end

local function wolfsheadEquipped()
    local link = GetInventoryItemLink("player", 1)
    return link and tonumber(link:match("item:(%d+)")) == WOLFSHEAD_ITEM_ID or false
end

local function catFormManaCost()
    if catCost ~= nil then return catCost end
    local _, _, _, _, _, _, spellID = GetSpellInfo("Cat Form")
    if not spellID or not GetSpellPowerCost then return 0 end
    local costs = GetSpellPowerCost(spellID)
    if costs then
        for _, cost in ipairs(costs) do
            if cost.type == MANA then catCost = cost.cost or 0; return catCost end
        end
    end
    catCost = 0
    return catCost
end

local function affordable(name)
    if H:HasBuff("Clearcasting") then return true end
    local spellID = select(7, GetSpellInfo(name))
    if not spellID or not GetSpellPowerCost then return true end
    local costs = GetSpellPowerCost(spellID)
    if not costs then return true end
    for _, cost in ipairs(costs) do
        local amount = cost.cost or 0
        if amount > 0 and UnitPower("player", cost.type) < amount then return false end
    end
    return true
end

function H:CanRecommendPowershift()
    if ns.FormIndicator:CurrentMode() ~= "cat" then return false end
    if self:HasBuff("Clearcasting") then return false end
    if furorRank < 5 then return false end
    local gain = wolfsheadEquipped() and 60 or 40
    local energy = UnitPower("player", ENERGY)
    if energy > 20 or gain <= energy then return false end
    local cost = catFormManaCost()
    return cost > 0 and UnitPower("player", MANA) >= cost
end

function H:IsRageCapping()
    local maximum = UnitPowerMax("player", RAGE)
    return InCombatLockdown() and maximum and maximum > 0 and UnitPower("player", RAGE) / maximum >= 0.8
end

local function ruleMet(self, ability, mode)
    if ability.special == "powershift" then return self:CanRecommendPowershift() end
    if not GetSpellInfo(ability.name) then return false end
    if not offCooldown(ability.name) or not affordable(ability.name) then return false end
    local rule = ability.rule
    if not rule then return false end
    if rule == "cooldown" then
        if ability.minEnergy and UnitPower("player", ENERGY) < ability.minEnergy then return false end
        return offCooldown(ability.name)
    elseif rule == "missing_debuff" then
        return hostileTarget() and not self:Debuff(ability.debuff, ability.anySource)
            and not (ability.altDebuff and self:Debuff(ability.altDebuff, ability.anySource))
    elseif rule == "finisher" then
        if not hostileTarget() or GetComboPoints("player", "target") < (ability.points or 1) then return false end
        if ability.debuff and self:Debuff(ability.debuff) then return false end
        if ability.targetHealthAbove and targetHealthPercent() <= ability.targetHealthAbove then return false end
        return true
    elseif rule == "builder" then
        return hostileTarget()
    elseif rule == "interrupt" then
        return targetCasting() and offCooldown(ability.name)
    elseif rule == "taunt" then
        return hostileTarget() and UnitExists("targettarget") and not (UnitIsUnit and UnitIsUnit("targettarget", "player")) and offCooldown(ability.name)
    elseif rule == "resource" then
        return UnitPower("player", RAGE) < 20 and offCooldown(ability.name)
    elseif rule == "rage_dump" then
        return self:IsRageCapping()
    elseif rule == "nuke" then
        if not hostileTarget() then return false end
        local grouped = isGroupedNuke()
        if ability.nuke == "group" then
            return grouped or not GetSpellInfo("Wrath") or not affordable("Wrath")
        end
        return not grouped or not GetSpellInfo("Starfire") or not affordable("Starfire")
    elseif rule == "buff" then
        return not self:HasBuff(ability.buff) and not (ability.altBuff and self:HasBuff(ability.altBuff))
    elseif rule == "mana_helper" then
        local maximum = UnitPowerMax("player", MANA)
        return maximum > 0 and UnitPower("player", MANA) / maximum <= 0.3 and offCooldown(ability.name)
    elseif rule == "low_health" then
        local maximum = UnitHealthMax("player")
        return maximum > 0 and UnitHealth("player") / maximum * 100 < (ability.healthBelow or 50)
    elseif rule == "targeting_player" then
        return hostileTarget() and UnitExists("targettarget")
            and UnitIsUnit and UnitIsUnit("targettarget", "player")
    end
    return false
end

function H:Compute(mode)
    local results, best, bestPriority = {}, nil, math.huge
    local list = ns.Abilities:List(mode)
    for _, ability in ipairs(list) do
        local met = ruleMet(self, ability, mode)
        if met then
            results[ability.name] = {
                soft = true,
                hard = ability.independent or ability.rule == "missing_debuff" or false,
            }
            if not ability.independent and not ability.onNextSwing and ability.priority and ability.priority < bestPriority then
                best, bestPriority = ability, ability.priority
            end
        end
    end
    if best then results[best.name].hard = true end
    for _, ability in ipairs(ns.Abilities.utility) do
        if ruleMet(self, ability, mode) then results[ability.name] = { soft = true, hard = true } end
    end
    return results
end

function H:ComboPoints()
    if not UnitExists("target") then return 0 end
    return GetComboPoints("player", "target") or 0
end

ns:On("PLAYER_LOGIN", function() if ns.enabled then H:RefreshTalents() end end)
ns:On("PLAYER_TALENT_UPDATE", function() H:RefreshTalents() end)
ns:On("CHARACTER_POINTS_CHANGED", function() H:RefreshTalents() end)
ns:On("SPELLS_CHANGED", function() catCost = nil end)
