-- Plain-Lua tests for recommendation, macro, and combat-log logic. The frame
-- and security layer still requires an in-client test.
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
    auraReads = 0,
    cooldownReads = {},
}

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3 } }
local spellIDs, nextSpellID = {}, 1000
function GetSpellInfo(name)
    if type(name) == "number" then return "Spell" .. name, nil, "icon", nil, nil, nil, name end
    if not spellIDs[name] then nextSpellID = nextSpellID + 1; spellIDs[name] = nextSpellID end
    return name, nil, "icon", nil, nil, nil, spellIDs[name]
end
function GetSpellCooldown(name)
    state.cooldownReads[name] = (state.cooldownReads[name] or 0) + 1
    return 0, 0
end
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
    if unit == "player" then state.auraReads = state.auraReads + 1 end
    local source = unit == "player" and state.buffs or state.debuffs
    local values = {}
    for name, value in pairs(source) do
        if value then
            values[#values + 1] = {
                name = name,
                duration = type(value) == "table" and value.duration or 12,
                expirationTime = type(value) == "table" and value.expirationTime or 112,
            }
        end
    end
    return values[index]
end

local ns = { eventHandlers = {} }
function ns:On(event, handler)
    self.eventHandlers[event] = self.eventHandlers[event] or {}
    self.eventHandlers[event][#self.eventHandlers[event] + 1] = handler
end

assert(loadfile("Abilities.lua"))("HelloDruid", ns)
ns.FormIndicator = {
    CurrentMode = function() return state.mode end,
    indexToKey = { "bear", "moonkin", "travel" },
}
assert(loadfile("Helper.lua"))("HelloDruid", ns)
assert(loadfile("SwingTimer.lua"))("HelloDruid", ns)
assert(loadfile("ActionBar.lua"))("HelloDruid", ns)
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
expect(ns.Abilities.balance[11].name == "Tranquility", "Tranquility should be on the caster layout")
expect(ns.Abilities.utility[3].name == "Omen of Clarity", "Omen should be on shared utility")

local catWithoutFaerie = ns.Abilities:SlotMap("cat", function(ability)
    return ability.name ~= "Faerie Fire (Feral)"
end)
expect(catWithoutFaerie[7] == nil, "a short Cat first row should leave slot 7 empty")
expect(catWithoutFaerie[8] and catWithoutFaerie[8].name == "Powershift",
    "Cat row two should always begin with Powershift")

local bearWithoutCharge = ns.Abilities:SlotMap("bear", function(ability)
    return ability.name ~= "Feral Charge"
end)
expect(bearWithoutCharge[7] == nil, "a short Bear first row should leave slot 7 empty")
expect(bearWithoutCharge[8] and bearWithoutCharge[8].name == "Enrage",
    "Bear row two should always begin with Enrage")

function GetNumShapeshiftForms() return 3 end

expect(ns.ActionBar.MacroFor({ name = "Powershift", special = "powershift" }, "cat") ==
    "#showtooltip Cat Form\n/cancelform\n/cast Cat Form",
    "powershift should cancel and immediately recast Cat Form")
expect(ns.ActionBar.MacroFor({ name = "Claw" }, "cat") ==
    "#showtooltip Claw\n/cast Claw\n/startattack",
    "Cat attacks should start auto-attack without cancelling form")
expect(ns.ActionBar.MacroFor({ name = "Moonfire" }, "balance") ==
    "#showtooltip Moonfire\n/cancelform [form:1/3]\n/cast Moonfire",
    "caster actions should preserve Moonkin while cancelling other forms")
expect(ns.ActionBar.MacroFor({
    name = "Mark of the Wild", targetMode = "friendly_or_self", noStartAttack = true,
}, "balance", true) ==
    "#showtooltip Mark of the Wild\n/cancelform [form]\n" ..
        "/cast [@target,help,nodead] Mark of the Wild; [@player] Mark of the Wild",
    "shared buffs should cancel form and prefer a friendly target")
expect(ns.ActionBar.MacroFor({ name = "Tranquility", requiresCaster = true, noStartAttack = true }, "balance") ==
    "#showtooltip Tranquility\n/cancelform [form]\n/cast Tranquility",
    "caster-only abilities should always cancel form")
expect(ns.ActionBar.MacroFor({ name = "War Stomp", noStartAttack = true }, "balance", true) ==
    "#showtooltip War Stomp\n/cancelform [form]\n/cast War Stomp",
    "Classic Era Druid racials should cancel form")

local originalList, originalUtility = ns.Abilities.List, ns.Abilities.utility
function ns.Abilities:List()
    return {
        { name = "Claw", rule = "builder" },
        { name = "Rake", rule = "builder" },
    }
end
ns.Abilities.utility = {}
state.buffs, state.auraReads = {}, 0
ns.Helper:Compute("cat")
expect(state.auraReads == 1, "Compute should resolve Clearcasting once for all abilities")
ns.Abilities.List, ns.Abilities.utility = originalList, originalUtility

-- With maintenance satisfied, solo/targeted Balance prefers Wrath.
state.debuffs = { ["Faerie Fire"] = true, Moonfire = true, ["Insect Swarm"] = true }
local result = ns.Helper:Compute("balance")
expect(result.Wrath and result.Wrath.hard, "solo Balance should recommend Wrath")
expect(not (result.Starfire and result.Starfire.hard), "solo Balance should not recommend Starfire")
expect(result.Hurricane == nil, "Hurricane availability should not create a recommendation")
expect(result["Omen of Clarity"] and result["Omen of Clarity"].hard,
    "missing Omen of Clarity should create a self-buff reminder")

-- Feral forms get time to refresh their important long buffs before expiry.
state.mode, state.buffs = "cat", {
    ["Mark of the Wild"] = { duration = 1800, expirationTime = 101 },
    Thorns = { duration = 600, expirationTime = 221 },
    ["Omen of Clarity"] = { duration = 1800, expirationTime = 220 },
}
result = ns.Helper:Compute("cat")
expect(not result.Thorns, "Cat should not refresh Thorns with more than two minutes remaining")
expect(result["Omen of Clarity"] and result["Omen of Clarity"].hard,
    "Cat should refresh Omen of Clarity with exactly two minutes remaining")
expect(not result["Mark of the Wild"], "the Feral refresh window should not apply to Mark of the Wild")

state.mode = "bear"
state.buffs.Thorns.expirationTime = 220
result = ns.Helper:Compute("bear")
expect(result.Thorns and result.Thorns.hard,
    "Bear should refresh Thorns with two minutes remaining")

state.mode = "balance"
result = ns.Helper:Compute("balance")
expect(not result.Thorns and not result["Omen of Clarity"],
    "Caster should leave present Feral buffs alone inside the refresh window")
state.buffs = {}

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
state.cooldownReads = {}
result = ns.Helper:Compute("bear")
expect(result.Bash and result.Bash.hard, "Bear should alert Bash during a cast")
expect(result.Growl and result.Growl.hard, "Bear should alert Growl when another unit has the target")
expect(state.cooldownReads.Bash == 1, "interrupt rules should check their cooldown once")
expect(state.cooldownReads.Growl == 1, "taunt rules should check their cooldown once")
expect(state.cooldownReads.Enrage == 1, "resource rules should check their cooldown once")
expect(state.cooldownReads.Innervate == 1, "mana-helper rules should check their cooldown once")

local combatSubtype, combatSource, combatPayload13, combatPayload21
function UnitGUID() return "player-guid" end
function CombatLogGetCurrentEventInfo()
    return 0, combatSubtype, false, combatSource, false, false, false, false, false, false, false,
        false, combatPayload13, false, false, false, false, false, false, false, combatPayload21
end

ns.enabled, ns.SwingTimer.bar = true, true
local starts = 0
function ns.SwingTimer:Start() starts = starts + 1 end
local combatHandler = ns.eventHandlers.COMBAT_LOG_EVENT_UNFILTERED[1]
local function expectSwingStart(subtype, source, payload13, payload21, expected, message)
    combatSubtype, combatSource = subtype, source
    combatPayload13, combatPayload21 = payload13, payload21
    local before = starts
    combatHandler()
    expect(starts - before == expected, message)
end

expectSwingStart("SWING_DAMAGE", "player-guid", false, false, 1,
    "main-hand swing damage should restart the timer")
expectSwingStart("SWING_DAMAGE", "player-guid", false, true, 0,
    "off-hand swing damage should not restart the timer")
expectSwingStart("SWING_MISSED", "player-guid", false, true, 1,
    "main-hand swing misses should use field 13, not field 21")
expectSwingStart("SWING_MISSED", "player-guid", true, false, 0,
    "off-hand swing misses should not restart the timer")
expectSwingStart("SPELL_DAMAGE", "player-guid", "Maul", true, 1,
    "Maul damage should use the spell name in field 13")
expectSwingStart("SPELL_MISSED", "player-guid", "Maul", false, 1,
    "missed Mauls should restart the timer")
expectSwingStart("SPELL_DAMAGE", "player-guid", "Wrath", false, 0,
    "other spell damage should not restart the timer")
expectSwingStart("SWING_DAMAGE", "other-guid", false, false, 0,
    "other units' swings should be ignored")

print("HelloDruid logic tests passed")
