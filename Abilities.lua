local _, ns = ...
ns.Abilities = {}
local A = ns.Abilities
A.COLUMNS = 7

-- Names intentionally match the English Classic Era spellbook, as does
-- HelloWarrior. Form indices are discovered at runtime in FormIndicator.
A.forms = {
    { key = "caster",  names = {},                              iconSpell = 1126, special = "cancel" },
    { key = "bear",    names = { "Dire Bear Form", "Bear Form" }, iconSpell = 5487 },
    { key = "cat",     names = { "Cat Form" },                  iconSpell = 768 },
    { key = "travel",  names = { "Travel Form" },               iconSpell = 783 },
    { key = "aquatic", names = { "Aquatic Form" },              iconSpell = 1066 },
    { key = "moonkin", names = { "Moonkin Form" },              iconSpell = 24858, talentOnly = true },
}

-- rule: cooldown, missing_debuff, finisher, builder, interrupt, taunt,
-- powershift, rage_dump, execute, or buff. Lower priority wins the gold ring.
A.cat = {
    -- Row 1: core rotation, from pull/debuff through builders and finishers.
    { name = "Faerie Fire (Feral)", talentOnly = true, rule = "missing_debuff", debuff = "Faerie Fire (Feral)", altDebuff = "Faerie Fire", anySource = true, priority = 1 },
    { name = "Shred", rule = "builder", priority = 7 },
    { name = "Claw", rule = "builder", priority = 8 },
    { name = "Rake", rule = "missing_debuff", debuff = "Rake", priority = 5 },
    { name = "Rip", rule = "finisher", points = 5, debuff = "Rip", targetHealthAbove = 25, priority = 3 },
    { name = "Ferocious Bite", rule = "finisher", points = 5, priority = 4 },
    { name = "Tiger's Fury", rule = "cooldown", minEnergy = 60, priority = 6, noStartAttack = true },
    -- Row 2: powershifting, stealth/openers, and situational utility.
    { name = "Powershift", special = "powershift", rule = "powershift", priority = 9, talentOnly = true, noStartAttack = true },
    { name = "Prowl", rule = "cooldown", independent = true, noStartAttack = true },
    { name = "Ravage", rule = "builder" },
    { name = "Pounce", rule = "builder" },
    { name = "Dash", rule = "cooldown", independent = true, noStartAttack = true },
    { name = "Cower", noStartAttack = true },
    { name = "Track Humanoids", noStartAttack = true },
}
A.catRows = { 7, 7 }

A.bear = {
    -- Row 1: core threat, then the controls used reactively during a pull.
    { name = "Faerie Fire (Feral)", talentOnly = true, rule = "missing_debuff", debuff = "Faerie Fire (Feral)", altDebuff = "Faerie Fire", anySource = true, priority = 1 },
    { name = "Maul", rule = "rage_dump", onNextSwing = true },
    { name = "Swipe", rule = "builder", priority = 3 },
    { name = "Demoralizing Roar", rule = "missing_debuff", debuff = "Demoralizing Roar", anySource = true, priority = 2 },
    { name = "Growl", rule = "taunt", independent = true },
    { name = "Feral Charge", talentOnly = true, rule = "interrupt", independent = true, noStartAttack = true },
    { name = "Bash", rule = "interrupt", independent = true },
    -- Row 2: rage generation, survival, and the long-cooldown AoE taunt.
    { name = "Enrage", rule = "resource", independent = true, noStartAttack = true },
    { name = "Frenzied Regeneration", rule = "low_health", healthBelow = 40, independent = true, noStartAttack = true },
    { name = "Challenging Roar", noStartAttack = true },
}
A.bearRows = { 7, 3 }

A.balance = {
    { name = "Faerie Fire", rule = "missing_debuff", debuff = "Faerie Fire", altDebuff = "Faerie Fire (Feral)", anySource = true, priority = 1 },
    { name = "Moonfire", rule = "missing_debuff", debuff = "Moonfire", priority = 2 },
    { name = "Insect Swarm", talentOnly = true, rule = "missing_debuff", debuff = "Insect Swarm", priority = 3 },
    { name = "Wrath", rule = "nuke", nuke = "solo", priority = 4 },
    { name = "Starfire", rule = "nuke", nuke = "group", priority = 4 },
    { name = "Hurricane" },
    { name = "Entangling Roots" },
    { name = "Nature's Grasp", talentOnly = true, rule = "targeting_player", independent = true, noStartAttack = true },
    { name = "Hibernate", noStartAttack = true },
    { name = "Soothe Animal", noStartAttack = true },
    { name = "Tranquility", requiresCaster = true, noStartAttack = true },
}
A.balanceRows = { 7, 4 }

A.utility = {
    { name = "Mark of the Wild", rule = "buff", buff = "Mark of the Wild", altBuff = "Gift of the Wild", targetMode = "friendly_or_self", noStartAttack = true },
    { name = "Thorns", rule = "buff", buff = "Thorns", targetMode = "friendly_or_self", noStartAttack = true },
    { name = "Omen of Clarity", talentOnly = true, rule = "buff", buff = "Omen of Clarity", targetMode = "self", noStartAttack = true },
    { name = "Barkskin", rule = "low_health", healthBelow = 50, independent = true, targetMode = "self", noStartAttack = true },
    { name = "Innervate", rule = "mana_helper", independent = true, targetMode = "friendly_or_self", noStartAttack = true },
    { name = "Rebirth", noStartAttack = true },
}

A.racials = {
    Human    = { "Perception" },
    Dwarf    = { "Stoneform" },
    Gnome    = { "Escape Artist" },
    NightElf = { "Shadowmeld" },
    Orc      = { "Blood Fury" },
    Scourge  = { "Will of the Forsaken", "Cannibalize" },
    Tauren   = { "War Stomp" },
    Troll    = { "Berserking" },
}

function A:List(mode)
    return self[mode] or self.balance
end

-- Compress unavailable talents within their declared row, never across the row
-- boundary. The result is deliberately sparse: an incomplete first row leaves
-- its trailing physical slots empty, while row two still begins at slot 8.
function A:SlotMap(mode, include)
    local list = self:List(mode)
    local rows = self[mode .. "Rows"] or { #list }
    local slots, dataIndex = {}, 1
    for rowIndex, rowSize in ipairs(rows) do
        local slotIndex = (rowIndex - 1) * self.COLUMNS + 1
        for index = dataIndex, dataIndex + rowSize - 1 do
            local ability = list[index]
            if ability and (not include or include(ability)) then
                slots[slotIndex] = ability
                slotIndex = slotIndex + 1
            end
        end
        dataIndex = dataIndex + rowSize
    end
    return slots
end
