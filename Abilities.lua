local _, ns = ...
ns.Abilities = {}
local A = ns.Abilities

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
    { name = "Faerie Fire (Feral)", talentOnly = true, rule = "missing_debuff", debuff = "Faerie Fire (Feral)", altDebuff = "Faerie Fire", anySource = true, priority = 1 },
    { name = "Rip", rule = "finisher", points = 5, debuff = "Rip", targetHealthAbove = 25, priority = 3 },
    { name = "Ferocious Bite", rule = "finisher", points = 5, priority = 4 },
    { name = "Rake", rule = "missing_debuff", debuff = "Rake", priority = 5 },
    { name = "Tiger's Fury", rule = "cooldown", minEnergy = 60, priority = 6, noStartAttack = true },
    { name = "Shred", rule = "builder", priority = 7 },
    { name = "Claw", rule = "builder", priority = 8 },
    { name = "Powershift", special = "powershift", rule = "powershift", priority = 9, talentOnly = true, noStartAttack = true },
    { name = "Prowl", rule = "cooldown", independent = true, noStartAttack = true },
    { name = "Ravage", rule = "builder" },
    { name = "Pounce", rule = "builder" },
    { name = "Cower", noStartAttack = true },
    { name = "Dash", rule = "cooldown", independent = true, noStartAttack = true },
    { name = "Track Humanoids", noStartAttack = true },
}
A.catRows = { 7, 7 }

A.bear = {
    { name = "Faerie Fire (Feral)", talentOnly = true, rule = "missing_debuff", debuff = "Faerie Fire (Feral)", altDebuff = "Faerie Fire", anySource = true, priority = 1 },
    { name = "Demoralizing Roar", rule = "missing_debuff", debuff = "Demoralizing Roar", anySource = true, priority = 2 },
    { name = "Swipe", rule = "builder", priority = 3 },
    { name = "Maul", rule = "rage_dump", onNextSwing = true },
    { name = "Growl", rule = "taunt", independent = true },
    { name = "Feral Charge", talentOnly = true, rule = "interrupt", independent = true, noStartAttack = true },
    { name = "Bash", rule = "interrupt", independent = true },
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
    { name = "Hurricane", rule = "cooldown" },
    { name = "Entangling Roots" },
    { name = "Nature's Grasp", talentOnly = true, rule = "targeting_player", independent = true, noStartAttack = true },
    { name = "Hibernate", noStartAttack = true },
    { name = "Soothe Animal", noStartAttack = true },
}
A.balanceRows = { 7, 3 }

A.utility = {
    { name = "Mark of the Wild", rule = "buff", buff = "Mark of the Wild", altBuff = "Gift of the Wild", noStartAttack = true },
    { name = "Thorns", rule = "buff", buff = "Thorns", noStartAttack = true },
    { name = "Barkskin", rule = "low_health", healthBelow = 50, independent = true, noStartAttack = true },
    { name = "Innervate", rule = "mana_helper", independent = true, noStartAttack = true },
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
