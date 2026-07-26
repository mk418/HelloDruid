local _, ns = ...
ns.FormIndicator = {}
local FI = ns.FormIndicator
local SIZE, GAP = 24, 4

local function learnedName(def)
    if def.special == "cancel" then return "Caster Form" end
    for _, name in ipairs(def.names) do
        if GetSpellInfo(name) then return name end
    end
end

function FI:RefreshForms()
    self.indexToMode, self.indexToKey, self.keyToIndex = {}, {}, {}
    if not GetNumShapeshiftForms then return end
    for index = 1, GetNumShapeshiftForms() do
        local _, _, _, spellID = GetShapeshiftFormInfo(index)
        local name = spellID and GetSpellInfo(spellID)
        for _, def in ipairs(ns.Abilities.forms) do
            for _, candidate in ipairs(def.names) do
                if name == candidate then
                    self.indexToKey[index] = def.key
                    self.keyToIndex[def.key] = index
                    self.indexToMode[index] = def.key == "cat" and "cat" or (def.key == "bear" and "bear" or "balance")
                end
            end
        end
    end
end

function FI:CurrentMode()
    local index = GetShapeshiftForm()
    return self.indexToMode and self.indexToMode[index] or "balance"
end

function FI:StateDriver()
    local parts = {}
    if self.keyToIndex.cat then parts[#parts + 1] = "[form:" .. self.keyToIndex.cat .. "] cat" end
    if self.keyToIndex.bear then parts[#parts + 1] = "[form:" .. self.keyToIndex.bear .. "] bear" end
    parts[#parts + 1] = "balance"
    return table.concat(parts, "; ")
end

local function formButton(parent, def, position)
    local name = learnedName(def)
    if not name then return end
    local button = CreateFrame("Button", "HelloDruidForm" .. position, parent, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    if def.special == "cancel" then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/cancelform")
    else
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", name)
    end
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(select(3, GetSpellInfo(def.special == "cancel" and def.iconSpell or name)))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon, button.formKey, button.spellName = icon, def.key, name
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.spellName)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    ns:AttachShine(button, SIZE)
    return button
end

function FI:Build(parent)
    if self.frame then return end
    self:RefreshForms()
    local frame = CreateFrame("Frame", "HelloDruidFormIndicator", parent)
    frame:SetSize(5 * SIZE + 4 * GAP, SIZE)
    self.frame, self.buttons, self.buttonsByKey = frame, {}, {}
    self:SyncButtons()
    self:Refresh()
end

function FI:SyncButtons()
    if not self.frame or InCombatLockdown() then return end
    local visible = {}
    for _, def in ipairs(ns.Abilities.forms) do
        local name = learnedName(def)
        local button = self.buttonsByKey[def.key]
        if name and not button then
            button = formButton(self.frame, def, #self.buttons + 1)
            self.buttons[#self.buttons + 1] = button
            self.buttonsByKey[def.key] = button
        end
        if button then
            if name then
                button.spellName = name
                if def.special ~= "cancel" then button:SetAttribute("spell", name) end
                button.icon:SetTexture(select(3, GetSpellInfo(def.special == "cancel" and def.iconSpell or name)))
                button:Show()
                visible[#visible + 1] = button
            else
                button:Hide()
            end
        end
    end
    for index, button in ipairs(visible) do
        button:ClearAllPoints()
        if index == 1 then button:SetPoint("LEFT")
        else button:SetPoint("LEFT", visible[index - 1], "RIGHT", GAP, 0) end
    end
    self.frame:SetWidth(math.max(SIZE, #visible * SIZE + math.max(0, #visible - 1) * GAP))
end

function FI:Refresh()
    if not self.frame then return end
    local current = GetShapeshiftForm()
    for _, button in ipairs(self.buttons) do
        local index = self.keyToIndex[button.formKey]
        local active = button.formKey == "caster" and current == 0 or (index and index == current)
        button.icon:SetVertexColor(active and 1 or 0.55, active and 1 or 0.55, active and 1 or 0.55)
        ns:SetShine(button, active, 0.45, 0.9, 0.55)
    end
end

ns:On("UPDATE_SHAPESHIFT_FORM", function() FI:Refresh() end)
ns:On("SPELLS_CHANGED", function()
    FI:RefreshForms()
    FI:SyncButtons()
    FI:Refresh()
end)
