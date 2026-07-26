-- Plain-Lua smoke tests for the recommendation engine. The frame/security layer
-- still requires an in-client test, but these lock the form-specific priorities.
local state = {
    mode = "balance",
    grouped = false,
    targetTargetsPlayer = false,
    targetTargetExists = true,
    targetHealth = 100,
    combo = 0,
    energy = 100,
    rage = 0,
    mana = 1000,
    buffs = {},
    debuffs = {},
    casting = false,
    wolfshead = true,
}

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3 } }
local spellIDs, nextSpellID = {}, 1000
function GetSpellInfo(name)
    if type(name) == "number" then return "Spell" .. name, nil, "icon", nil, nil, nil, name end
    if not spellIDs[name] then nextSpellID = nextSpellID + 1; spellIDs[name] = nextSpellID end
    return name, nil, "icon", nil, nil, nil, spellIDs[name]
end
function GetSpellCooldown() return 0, 0 end
function GetSpellPowerCost(id)
    if id == spellIDs["Cat Form"] then return { { type = 0, cost = 100 } } end
    return {}
end
function UnitPower(_, power)
    return power == 0 and state.mana or (power == 1 and state.rage or state.energy)
end
function UnitPowerMax(_, power) return power == 0 and 1000 or 100 end
function UnitExists(unit) return unit == "target" or (unit == "targettarget" and state.targetTargetExists) end
function UnitIsDead() return false end
function UnitCanAttack() return true end
function UnitHealth() return state.targetHealth end
function UnitHealthMax() return 100 end
function UnitIsUnit(a, b) return a == "targettarget" and b == "player" and state.targetTargetsPlayer end
function UnitCastingInfo() if state.casting then return "Fireball", nil, nil, 0, 1000, nil, nil, false end end
function UnitChannelInfo() end
function GetComboPoints() return state.combo end
function GetInventoryItemLink() return state.wolfshead and "|Hitem:8345:0:0:0|h[Wolfshead Helm]|h" or nil end
function GetNumTalentTabs() return 1 end
function GetNumTalents() return 1 end
function GetTalentInfo() return "Furor", nil, nil, nil, 5 end
function IsInGroup() return state.grouped end
function IsInRaid() return false end
function InCombatLockdown() return true end
function GetTime() return 100 end
function UnitBuff() end
function UnitDebuff() end

C_UnitAuras = {}
function C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    local source = unit == "player" and state.buffs or state.debuffs
    local values = {}
    for name, enabled in pairs(source) do
        if enabled then values[#values + 1] = { name = name, duration = 12, expirationTime = 112 } end
    end
    return values[index]
end

local ns = { eventHandlers = {} }
function ns:On(event, handler)
    self.eventHandlers[event] = self.eventHandlers[event] or {}
    self.eventHandlers[event][#self.eventHandlers[event] + 1] = handler
end

assert(loadfile("Abilities.lua"))("HelloDruid", ns)
ns.FormIndicator = { CurrentMode = function() return state.mode end }
assert(loadfile("Helper.lua"))("HelloDruid", ns)
ns.Helper:RefreshTalents()

local function expect(value, message)
    if not value then error(message, 2) end
end

local function expectOrder(list, names, label)
    for index, name in ipairs(names) do
        expect(list[index] and list[index].name == name,
            ("%s slot %d should be %s"):format(label, index, name))
    end
end

expectOrder(ns.Abilities.cat,
    { "Faerie Fire (Feral)", "Shred", "Claw", "Rake", "Rip", "Ferocious Bite", "Tiger's Fury" },
    "Cat")
expectOrder(ns.Abilities.bear,
    { "Faerie Fire (Feral)", "Maul", "Swipe", "Demoralizing Roar", "Growl", "Feral Charge", "Bash" },
    "Bear")

-- With maintenance satisfied, solo/targeted Balance prefers Wrath.
state.debuffs = { ["Faerie Fire"] = true, Moonfire = true, ["Insect Swarm"] = true }
local result = ns.Helper:Compute("balance")
expect(result.Wrath and result.Wrath.hard, "solo Balance should recommend Wrath")
expect(not (result.Starfire and result.Starfire.hard), "solo Balance should not recommend Starfire")
expect(result.Hurricane == nil, "Hurricane availability should not create a recommendation")

state.debuffs.Moonfire = nil
result = ns.Helper:Compute("balance")
expect(result.Moonfire and result.Moonfire.hard, "missing maintenance dots should be hard cues")
state.debuffs.Moonfire = true

state.grouped = true
result = ns.Helper:Compute("balance")
expect(result.Starfire and result.Starfire.hard, "grouped Balance should recommend Starfire")

state.targetTargetsPlayer = true
result = ns.Helper:Compute("balance")
expect(result.Wrath and result.Wrath.hard, "a target attacking the player should switch back to Wrath")

-- Five points with Rip already active chooses Ferocious Bite.
state.mode, state.grouped, state.targetTargetsPlayer = "cat", false, false
state.combo, state.energy = 5, 100
state.debuffs = { ["Faerie Fire (Feral)"] = true, Rake = true, Rip = true }
result = ns.Helper:Compute("cat")
expect(result["Ferocious Bite"] and result["Ferocious Bite"].hard, "Cat should Bite when five-point Rip is active")

-- Deterministic Furor 5 + Wolfshead powershift at low energy, unless Clearcasting.
state.energy, state.mana, state.buffs = 10, 1000, {}
expect(ns.Helper:CanRecommendPowershift(), "low-energy Cat should recommend a funded powershift")
state.buffs.Clearcasting = true
expect(not ns.Helper:CanRecommendPowershift(), "Clearcasting should suppress powershift")

-- Bear interrupt and lost-aggro cues are independent hard alerts.
state.mode, state.buffs, state.casting, state.targetTargetsPlayer = "bear", {}, true, false
state.debuffs = { ["Faerie Fire (Feral)"] = true, ["Demoralizing Roar"] = true }
result = ns.Helper:Compute("bear")
expect(result.Bash and result.Bash.hard, "Bear should alert Bash during a cast")
expect(result.Growl and result.Growl.hard, "Bear should alert Growl when another unit has the target")

print("HelloDruid recommendation tests passed")
