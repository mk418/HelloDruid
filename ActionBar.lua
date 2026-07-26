local _, ns = ...
ns.ActionBar = {}
local AB = ns.ActionBar

local BUTTON, GAP, ROW_GAP, SECTION = 36, 4, 4, 10
local COLS, HEADER = 7, 30
local WIDTH = 356 -- caster + five learned-form buttons plus readable resources
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local RAGE = Enum and Enum.PowerType and Enum.PowerType.Rage or 1
local ENERGY = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local IsSpellInRange = IsSpellInRange or (C_Spell and C_Spell.IsSpellInRange)
local IsCurrentSpell = IsCurrentSpell or (C_Spell and C_Spell.IsCurrentSpell)

local function rowSpan(count)
    return count > 0 and count * BUTTON + (count - 1) * GAP or 0
end

local function known(ability)
    if ability.special == "powershift" then return GetSpellInfo("Cat Form") ~= nil end
    return GetSpellInfo(ability.name) ~= nil
end

local function hidden(ability)
    return not ability or (ability.talentOnly and not known(ability))
end

local function compressedList(mode)
    local result = {}
    for _, ability in ipairs(ns.Abilities:List(mode)) do
        if not hidden(ability) then result[#result + 1] = ability end
    end
    return result
end

local function balanceCancelCondition()
    local indices = {}
    for index = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
        if (ns.FormIndicator.indexToKey or {})[index] ~= "moonkin" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    local strings = {}
    for _, index in ipairs(indices) do strings[#strings + 1] = tostring(index) end
    return #strings > 0 and "[form:" .. table.concat(strings, "/") .. "]" or nil
end

local function macroFor(ability, mode, utility)
    if not ability or hidden(ability) then return "" end
    if ability.special == "powershift" then
        return "#showtooltip Cat Form\n/cancelform\n/cast Cat Form"
    end
    local lines = { "#showtooltip " .. ability.name }
    if utility or ability.requiresCaster then
        lines[#lines + 1] = "/cancelform [form]"
    elseif mode == "balance" then
        local condition = balanceCancelCondition()
        if condition then lines[#lines + 1] = "/cancelform " .. condition end
    end
    if ability.targetMode == "friendly_or_self" then
        lines[#lines + 1] = ("/cast [@target,help,nodead] %s; [@player] %s"):format(
            ability.name, ability.name)
    elseif ability.targetMode == "self" then
        lines[#lines + 1] = "/cast [@player] " .. ability.name
    else
        lines[#lines + 1] = "/cast " .. ability.name
    end
    if not ability.noStartAttack and not utility and mode ~= "balance" then
        lines[#lines + 1] = "/startattack"
    end
    return table.concat(lines, "\n")
end

local function border(button, thickness, r, g, b)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetPoint("CENTER", 0, -1)
    frame:SetSize(BUTTON + 4, BUTTON + 4)
    frame:SetFrameLevel((button:GetFrameLevel() or 0) + 5)
    local function edge()
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetVertexColor(r, g, b, 0.95)
        texture:SetBlendMode("ADD")
        return texture
    end
    local top = edge(); top:SetHeight(thickness); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")
    local bottom = edge(); bottom:SetHeight(thickness); bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT")
    local left = edge(); left:SetWidth(thickness); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
    local right = edge(); right:SetWidth(thickness); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
    frame:Hide()
    return frame
end

local function showRing(frame)
    if frame:IsShown() then return end
    frame._pulseTime = 0
    frame:SetAlpha(frame.pulseFrom)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self._pulseTime = self._pulseTime + elapsed
        local cycle = (self._pulseTime / self.pulsePeriod) % 2
        local progress = cycle <= 1 and cycle or 2 - cycle
        self:SetAlpha(self.pulseFrom + (self.pulseTo - self.pulseFrom) * progress)
    end)
    frame:Show()
end

local function hideRing(frame)
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

local function createButton(parent, suffix)
    local button = CreateFrame("Button", "HelloDruid_" .. suffix, parent, "SecureActionButtonTemplate")
    button:SetSize(BUTTON, BUTTON)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type", "macro")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon
    local frame = button:CreateTexture(nil, "ARTWORK")
    frame:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    frame:SetSize(BUTTON * 1.7, BUTTON * 1.7)
    frame:SetPoint("CENTER", 0, -1)
    local pushed = button:CreateTexture(nil, "ARTWORK")
    pushed:SetColorTexture(0, 0, 0, 0.25)
    pushed:SetAllPoints(icon)
    button:SetPushedTexture(pushed)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    cooldown.noCooldownCount = true
    button.cooldown = cooldown

    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = count:GetFont()
    if font then count:SetFont(font, 22, "OUTLINE") end
    count:SetPoint("CENTER")
    count:Hide()
    button.count = count

    button.hardFlash = border(button, 4, 1, 0.95, 0.4)
    button.hardFlash.pulseFrom = 0.55
    button.hardFlash.pulseTo = 1.0
    button.hardFlash.pulsePeriod = 0.3
    ns:AttachShine(button, BUTTON)

    button:SetScript("OnEnter", function(self)
        local ability = self.currentAbility
        if not ability then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if ability.special == "powershift" then
            GameTooltip:SetText("Powershift", 1, 1, 1)
            GameTooltip:AddLine("Leave and immediately re-enter Cat Form to exchange mana for energy.", 0.7, 0.8, 0.7, true)
        else
            local spellID = select(7, GetSpellInfo(ability.name))
            if spellID then GameTooltip:SetSpellByID(spellID)
            else GameTooltip:SetText(ability.name); GameTooltip:AddLine("Not learned yet", 0.7, 0.7, 0.7) end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- HelloWarrior's recommendation visual: an addon-owned spell-alert frame on
-- current Era clients, Blizzard's legacy pooled overlay on older clients, and
-- a pulsing gold ring only as the final fallback. Never register addon frames
-- with Blizzard's shared alert manager; that would taint protected action bars.
local SQUARE_KEY = "_hdSavedVertex"

local function forEachSquareRegion(overlay, fn)
    if not overlay or not overlay.GetRegions then return end
    for _, region in ipairs({ overlay:GetRegions() }) do
        if region.GetTexture then
            local texture = region:GetTexture()
            if type(texture) == "string" then
                local lower = texture:lower()
                if lower:find("spellactivationoverlay", 1, true)
                    and not lower:find("ants", 1, true) then
                    fn(region)
                end
            end
        end
    end
end

local function suppressOverlaySquare(overlay)
    forEachSquareRegion(overlay, function(region)
        if not region[SQUARE_KEY] then
            local r, g, b, a = region:GetVertexColor()
            region[SQUARE_KEY] = { r or 1, g or 1, b or 1, a or 1 }
        end
        region:SetVertexColor(1, 1, 1, 0)
    end)
end

local function restoreOverlaySquare(overlay)
    forEachSquareRegion(overlay, function(region)
        local saved = region[SQUARE_KEY]
        if saved then
            region:SetVertexColor(saved[1], saved[2], saved[3], saved[4])
            region[SQUARE_KEY] = nil
        end
    end)
end

local function releaseOverlay(button)
    local overlay = button.overlay
    if not overlay then return end
    pcall(restoreOverlaySquare, overlay)
    if overlay.animIn and overlay.animIn:IsPlaying() then overlay.animIn:Stop() end
    if overlay.animOut and overlay.animOut:IsPlaying() then overlay.animOut:Stop() end
    if ActionButton_OverlayGlowAnimOutFinished and overlay.animOut then
        pcall(ActionButton_OverlayGlowAnimOutFinished, overlay.animOut)
    else
        overlay:Hide()
        button.overlay = nil
    end
end

local function acquireSpellAlert(button)
    if not button.hdSpellAlert then
        local alert = CreateFrame("Frame", nil, button, "ActionButtonSpellAlertTemplate")
        local width, height = button:GetSize()
        alert:SetSize(width * 1.4, height * 1.4)
        alert:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.hdSpellAlert = alert
    end
    return button.hdSpellAlert
end

local function showSpellAlert(button)
    local alert = acquireSpellAlert(button)
    alert:Show()
    alert.playingAnimation = true
    alert.ProcStartAnim:Play()
end

local function hideSpellAlert(button)
    local alert = button.hdSpellAlert
    if not alert then return end
    alert:Hide()
    alert.ProcStartAnim:Stop()
    alert.playingAnimation = false
end

local function showHardGlow(button)
    if button.hardGlowOn == "overlay" and not button.overlay then button.hardGlowOn = nil end
    if button.hardGlowOn then return end
    if ActionButtonSpellAlertMixin then
        if pcall(showSpellAlert, button) then
            button.hardGlowOn = "alert"
            return
        end
        pcall(hideSpellAlert, button)
    elseif ActionButton_ShowOverlayGlow then
        local ok = pcall(ActionButton_ShowOverlayGlow, button)
        if ok and button.overlay then
            suppressOverlaySquare(button.overlay)
            button.hardGlowOn = "overlay"
            return
        end
        releaseOverlay(button)
    end
    showRing(button.hardFlash)
    button.hardGlowOn = "fallback"
end

local function hideHardGlow(button)
    if not button.hardGlowOn and not button.overlay then return end
    if button.hardGlowOn == "alert" then pcall(hideSpellAlert, button) end
    if button.hardGlowOn == "fallback" then hideRing(button.hardFlash) end
    releaseOverlay(button)
    button.hardGlowOn = nil
end

local function applyFlash(button, result)
    if result and result.hard and button:IsVisible() then showHardGlow(button)
    else hideHardGlow(button) end
end

local function applyAbility(button, ability)
    button.currentAbility = ability
    if not ability then
        button.icon:SetTexture(nil)
        button.count:Hide()
        return
    end
    local icon
    if ability.special == "powershift" then icon = select(3, GetSpellInfo("Cat Form"))
    else icon = select(3, GetSpellInfo(ability.name)) end
    button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon:SetDesaturated(not known(ability))
end

local function placeRow(buttons, parent, y)
    local start = (parent:GetWidth() - rowSpan(#buttons)) / 2
    for index, button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", start + (index - 1) * (BUTTON + GAP), y)
    end
end

local function placeVisible(buttons, parent, y)
    local visible = {}
    for _, button in ipairs(buttons) do
        if button:IsShown() then visible[#visible + 1] = button end
    end
    placeRow(visible, parent, y)
end

local function createStatus(parent, color)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(color[1], color[2], color[3])
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    bar.label = label
    return bar
end

function AB:Build()
    if self.container then return end
    ns.FormIndicator:RefreshForms()

    local maxRows = 2
    local height = HEADER + SECTION + BUTTON + SECTION + maxRows * BUTTON + (maxRows - 1) * ROW_GAP
    local container = CreateFrame("Frame", "HelloDruidContainer", UIParent)
    container:SetSize(WIDTH, height)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self) if not HelloDruidCharDB.locked then self:StartMoving() end end)
    container:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); AB:SavePosition() end)
    local move = container:CreateTexture(nil, "BACKGROUND")
    move:SetAllPoints()
    move:SetColorTexture(0.2, 0.65, 0.3, 0.15)
    self.container, self.moveBg = container, move
    self:UpdatePosition()
    self:SetLocked(HelloDruidCharDB.locked ~= false)
    if HelloDruidCharDB.showBars == false then container:Hide() end

    local range = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    range:SetPoint("BOTTOM", container, "TOP", 0, SECTION)
    range:SetHeight(18)
    self.rangeText = range

    ns.FormIndicator:Build(container)
    ns.FormIndicator.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -3)

    local mode = CreateFrame("Frame", nil, container)
    mode:SetSize(64, 24)
    mode:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -3)
    local modeBg = mode:CreateTexture(nil, "BACKGROUND"); modeBg:SetAllPoints(); modeBg:SetColorTexture(0, 0, 0, 0.55)
    local modeLabel = mode:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetPoint("CENTER")
    self.modeFrame, self.modeLabel = mode, modeLabel

    local primary = createStatus(container, { 0.95, 0.85, 0.25 })
    primary:SetPoint("LEFT", ns.FormIndicator.frame, "RIGHT", SECTION, 9)
    primary:SetPoint("RIGHT", mode, "LEFT", -SECTION, 9)
    primary:SetHeight(9)
    local mana = createStatus(container, { 0.2, 0.45, 0.9 })
    mana:SetPoint("LEFT", primary, "LEFT", 0, 0)
    mana:SetPoint("RIGHT", primary, "RIGHT", 0, 0)
    mana:SetPoint("TOP", primary, "BOTTOM", 0, -1)
    mana:SetHeight(9)
    self.primaryBar, self.manaBar = primary, mana

    ns.SwingTimer:Build(container, primary)

    local utility = CreateFrame("Frame", "HelloDruid_UtilityBar", container)
    utility:SetSize(WIDTH, BUTTON)
    utility:SetPoint("TOP", container, "TOP", 0, -(HEADER + SECTION))
    self.utilityBar, self.utilityButtons = utility, {}
    local utilityDefs = {}
    for _, ability in ipairs(ns.Abilities.utility) do utilityDefs[#utilityDefs + 1] = ability end
    local _, race = UnitRace("player")
    for _, racial in ipairs(ns.Abilities.racials[race] or {}) do
        utilityDefs[#utilityDefs + 1] = { name = racial, noStartAttack = true }
    end
    for index, ability in ipairs(utilityDefs) do
        local button = createButton(utility, "Utility" .. index)
        local macro = macroFor(ability, "balance", true)
        button:SetAttribute("macrotext", macro)
        applyAbility(button, ability)
        button:SetShown(macro ~= "")
        self.utilityButtons[#self.utilityButtons + 1] = button
    end
    placeVisible(self.utilityButtons, utility, 0)

    local abilityBar = CreateFrame("Frame", "HelloDruid_AbilityBar", container, "SecureHandlerStateTemplate")
    abilityBar:SetSize(WIDTH, maxRows * BUTTON + ROW_GAP)
    abilityBar:SetPoint("TOP", utility, "BOTTOM", 0, -SECTION)
    self.bar = abilityBar
    self.modeLists = {
        cat = compressedList("cat"),
        bear = compressedList("bear"),
        balance = compressedList("balance"),
    }
    local maximum = math.max(#ns.Abilities.cat, #ns.Abilities.bear, #ns.Abilities.balance)
    self.buttons = {}
    for index = 1, maximum do
        local button = createButton(abilityBar, string.format("Slot%02d", index))
        local row, column = math.floor((index - 1) / COLS), (index - 1) % COLS
        button:SetPoint("TOPLEFT", abilityBar, "TOPLEFT",
            (WIDTH - rowSpan(COLS)) / 2 + column * (BUTTON + GAP),
            -row * (BUTTON + ROW_GAP))
        button.abilities = {
            cat = self.modeLists.cat[index],
            bear = self.modeLists.bear[index],
            balance = self.modeLists.balance[index],
        }
        for _, state in ipairs({ "cat", "bear", "balance" }) do
            button:SetAttribute("macrotext-" .. state, macroFor(button.abilities[state], state))
        end
        abilityBar:SetFrameRef("button" .. index, button)
        self.buttons[index] = button
    end
    abilityBar:SetAttribute("buttonCount", maximum)
    abilityBar:SetAttribute("_onstate-mode", [[
        local mode = newstate or "balance"
        local count = self:GetAttribute("buttonCount") or 0
        for i = 1, count do
            local button = self:GetFrameRef("button" .. i)
            local macro = button and button:GetAttribute("macrotext-" .. mode)
            if button then
                if macro and macro ~= "" then button:SetAttribute("macrotext", macro); button:Show()
                else button:Hide() end
            end
        end
        self:SetAttribute("effectiveMode", mode)
    ]])
    abilityBar:HookScript("OnAttributeChanged", function(_, name, value)
        if name and name:lower() == "effectivemode" then AB:OnModeApplied(value) end
    end)
    RegisterStateDriver(abilityBar, "mode", ns.FormIndicator:StateDriver())
    self:ApplyModeOutOfCombat(ns.FormIndicator:CurrentMode())

    ns.CastBar:Build(container)
    self.ticker = C_Timer.NewTicker(0.1, function() AB:Tick() end)
end

function AB:ApplyModeOutOfCombat(mode)
    if InCombatLockdown() or not self.bar then return end
    mode = mode or "balance"
    for _, button in ipairs(self.buttons) do
        local macro = button:GetAttribute("macrotext-" .. mode)
        if macro and macro ~= "" then
            button:SetAttribute("macrotext", macro)
            button:Show()
        else
            button:Hide()
        end
    end
    self.bar:SetAttribute("effectiveMode", mode)
    self:OnModeApplied(mode)
end

function AB:SavePosition()
    local point, _, relativePoint, x, y = self.container:GetPoint()
    HelloDruidCharDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

function AB:UpdatePosition()
    local position = HelloDruidCharDB.position
    self.container:ClearAllPoints()
    if position then self.container:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else self.container:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
end

function AB:ResetPosition()
    if InCombatLockdown() then print("|cff7acb59HelloDruid|r can't move the bars in combat."); return end
    HelloDruidCharDB.position = nil
    self:UpdatePosition()
end

function AB:SetLocked(locked)
    HelloDruidCharDB.locked = locked and true or false
    if not self.container then return end
    self.container:EnableMouse(not HelloDruidCharDB.locked)
    self.moveBg:SetShown(not HelloDruidCharDB.locked)
end

function AB:SetVisible(visible)
    if InCombatLockdown() then print("|cff7acb59HelloDruid|r can't toggle bars in combat."); return end
    HelloDruidCharDB.showBars = visible and true or false
    self.container:SetShown(HelloDruidCharDB.showBars)
    ns.CastBar:SyncBlizzard()
    ns.Keybinds:Apply()
end

function AB:OnModeApplied(mode)
    if not self.buttons then return end
    self.mode = mode or "balance"
    for _, button in ipairs(self.buttons) do applyAbility(button, button.abilities[self.mode]) end
    self:Relayout()
    self:UpdateHeader()
    self:Tick()
end

function AB:Relayout()
    if InCombatLockdown() or not self.buttons then return end
    -- Physical slots never move: form swaps are combat-safe and a key bound to
    -- visible position N always clicks physical slot N. Talent-only abilities
    -- are compressed into these slots when the secure maps are built.
    ns.Keybinds:Apply()
    ns.Keybinds:RefreshLabels()
end

function AB:RefreshSecureState()
    if not self.bar or InCombatLockdown() then return end
    ns.FormIndicator:RefreshForms()
    self.modeLists = {
        cat = compressedList("cat"),
        bear = compressedList("bear"),
        balance = compressedList("balance"),
    }
    for index, button in ipairs(self.buttons) do
        for _, mode in ipairs({ "cat", "bear", "balance" }) do
            button.abilities[mode] = self.modeLists[mode][index]
            button:SetAttribute("macrotext-" .. mode, macroFor(button.abilities[mode], mode))
        end
    end
    for _, button in ipairs(self.utilityButtons) do
        local macro = macroFor(button.currentAbility, "balance", true)
        button:SetAttribute("macrotext", macro)
        button:SetShown(macro ~= "")
        applyAbility(button, button.currentAbility)
    end
    placeVisible(self.utilityButtons, self.utilityBar, 0)
    UnregisterStateDriver(self.bar, "mode")
    RegisterStateDriver(self.bar, "mode", ns.FormIndicator:StateDriver())
    self:ApplyModeOutOfCombat(ns.FormIndicator:CurrentMode())
end

local function setBar(bar, powerType, prefix)
    local value, maximum = UnitPower("player", powerType), UnitPowerMax("player", powerType)
    bar:SetMinMaxValues(0, math.max(1, maximum))
    bar:SetValue(value)
    bar.label:SetText(prefix .. value)
end

function AB:UpdateHeader()
    if not self.primaryBar then return end
    local mode = self.mode or ns.FormIndicator:CurrentMode()
    local proc
    if ns.Helper:HasBuff("Clearcasting") then proc = "CLEAR"
    elseif mode == "balance" and ns.Helper:HasBuff("Nature's Grace") then proc = "GRACE" end
    local displayMode = mode == "balance" and "CASTER" or mode:upper()
    self.modeLabel:SetText(displayMode .. (proc and "\n" .. proc or ""))
    if mode == "cat" then
        self.modeLabel:SetTextColor(1, 0.75, 0.2)
        self.primaryBar:SetStatusBarColor(0.95, 0.85, 0.25)
        setBar(self.primaryBar, ENERGY, "")
        setBar(self.manaBar, MANA, "M ")
        self.manaBar:Show()
    elseif mode == "bear" then
        self.modeLabel:SetTextColor(0.75, 0.45, 0.2)
        if ns.Helper:IsRageCapping() then self.primaryBar:SetStatusBarColor(1, 0.55, 0.1)
        else self.primaryBar:SetStatusBarColor(0.78, 0.25, 0.25) end
        setBar(self.primaryBar, RAGE, "")
        setBar(self.manaBar, MANA, "M ")
        self.manaBar:Show()
    else
        self.modeLabel:SetTextColor(0.45, 0.8, 1)
        self.primaryBar:SetStatusBarColor(0.2, 0.45, 0.9)
        setBar(self.primaryBar, MANA, "")
        self.manaBar:Hide()
    end
    ns.SwingTimer:SetMode(mode)
end

local function spellRange(name)
    if not IsSpellInRange or not UnitExists("target") or not UnitCanAttack("player", "target") then return nil end
    local value = IsSpellInRange(name, "target")
    if value == true then return 1 elseif value == false then return 0 end
    return value
end

local function updateRange(mode)
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return "", 1, 1, 1 end
    local melee = spellRange(mode == "cat" and "Claw" or "Swipe")
    if mode == "cat" then
        if melee == 1 then return "MELEE", 0.2, 1, 0.2 end
        if spellRange("Faerie Fire (Feral)") == 1 then return "FAERIE", 1, 0.8, 0.2 end
    elseif mode == "bear" then
        if melee == 1 then return "MELEE", 0.2, 1, 0.2 end
        if spellRange("Feral Charge") == 1 then return "CHARGE", 1, 0.8, 0.2 end
    elseif spellRange("Wrath") == 1 or spellRange("Starfire") == 1 then
        return "CAST", 0.2, 1, 0.2
    end
    return "OUT", 1, 0.2, 0.2
end

local function cooldown(button, ability)
    if ability.debuff then
        local start, duration = ns.Helper:DebuffTimer(ability.debuff, ability.anySource)
        if start then button.cooldown:SetCooldown(start, duration); return end
    end
    if ability.special then button.cooldown:Clear(); return end
    local start, duration = GetSpellCooldown(ability.name)
    if start and duration and start > 0 then button.cooldown:SetCooldown(start, duration)
    else button.cooldown:Clear() end
end

local function updateButton(button, result, mode)
    local ability = button.currentAbility
    if not ability then return end
    applyFlash(button, result)
    cooldown(button, ability)

    local usable, noPower = true, false
    if not ability.special then usable, noPower = IsUsableSpell(ability.name) end
    if not known(ability) then button.icon:SetVertexColor(0.35, 0.35, 0.35)
    elseif not usable and noPower then button.icon:SetVertexColor(0.55, 0.55, 0.9)
    elseif not usable and mode ~= "balance" then button.icon:SetVertexColor(0.45, 0.45, 0.45)
    elseif not ability.special and spellRange(ability.name) == 0 then button.icon:SetVertexColor(0.9, 0.35, 0.35)
    else button.icon:SetVertexColor(1, 1, 1) end

    local points = mode == "cat" and ns.Helper:ComboPoints() or 0
    if points > 0 and ability.rule == "finisher" then
        button.count:SetText(points)
        button.count:SetTextColor(points == 5 and 0.2 or 1, points == 5 and 1 or 0.85, 0.2)
        button.count:Show()
    else button.count:Hide() end

    local queued = false
    if ability.onNextSwing and IsCurrentSpell then
        local rankID = select(7, GetSpellInfo(ability.name))
        queued = rankID and IsCurrentSpell(rankID) or false
    end
    ns:SetShine(button, queued, 0.95, 0.65, 0.2)
end

function AB:Tick()
    if not self.container or not self.container:IsShown() then return end
    local mode = self.bar:GetAttribute("effectiveMode") or ns.FormIndicator:CurrentMode()
    if mode ~= self.mode then self:OnModeApplied(mode) end
    self:UpdateHeader()
    local results = ns.Helper:Compute(mode)
    for _, button in ipairs(self.buttons) do
        if button:IsShown() and button.currentAbility then
            updateButton(button, results[button.currentAbility.name], mode)
        else
            hideHardGlow(button)
        end
    end
    for _, button in ipairs(self.utilityButtons) do
        updateButton(button, results[button.currentAbility.name], mode)
    end
    local text, r, g, b = updateRange(mode)
    self.rangeText:SetText(text)
    self.rangeText:SetTextColor(r, g, b)
end

ns:On("PLAYER_LOGIN", function() if ns.enabled then AB:Build() end end)
ns:On("UPDATE_SHAPESHIFT_FORM", function() AB:Tick() end)
ns:On("UNIT_POWER_UPDATE", function(unit) if unit == "player" then AB:Tick() end end)
ns:On("PLAYER_TARGET_CHANGED", function() AB:Tick() end)
ns:On("UNIT_AURA", function(unit) if unit == "player" or unit == "target" then AB:Tick() end end)
ns:On("CURRENT_SPELL_CAST_CHANGED", function() AB:Tick() end)
ns:On("SPELLS_CHANGED", function() AB:RefreshSecureState() end)
ns:On("PLAYER_TALENT_UPDATE", function() AB:RefreshSecureState() end)
ns:On("PLAYER_REGEN_ENABLED", function() AB:RefreshSecureState(); AB:Relayout() end)
