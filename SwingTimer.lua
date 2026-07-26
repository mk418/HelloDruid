local _, ns = ...
ns.SwingTimer = {}
local ST = ns.SwingTimer

function ST:Build(parent, resourceBar)
    if self.bar then return end
    local bar = CreateFrame("StatusBar", "HelloDruid_SwingTimer", parent)
    bar:SetHeight(9)
    bar:SetPoint("LEFT", resourceBar, "LEFT", 0, 0)
    bar:SetPoint("RIGHT", resourceBar, "RIGHT", 0, 0)
    bar:SetPoint("TOP", resourceBar, "BOTTOM", 0, -11)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.45, 0.8, 0.35)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.55)
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    self.bar, self.label = bar, label
    bar:SetScript("OnUpdate", function(self)
        if not ST.started then return end
        local elapsed = GetTime() - ST.started
        if elapsed >= ST.duration then self:SetValue(ST.duration); ST.label:SetText("")
        else self:SetValue(elapsed); ST.label:SetText(("%.1f"):format(ST.duration - elapsed)) end
    end)
    bar:Hide()
end

function ST:SetMode(mode)
    self.mode = mode
    if not self.bar then return end
    if mode == "balance" or not self.started then self.bar:Hide() else self.bar:Show() end
end

function ST:Start()
    if not self.bar or self.mode == "balance" then return end
    local speed = UnitAttackSpeed("player")
    if not speed or speed <= 0 then return end
    self.started, self.duration = GetTime(), speed
    self.bar:SetMinMaxValues(0, speed)
    self.bar:SetValue(0)
    self.bar:Show()
end

ns:On("COMBAT_LOG_EVENT_UNFILTERED", function()
    if not ns.enabled or not ST.bar then return end
    local event = { CombatLogGetCurrentEventInfo() }
    if event[4] ~= UnitGUID("player") then return end
    if event[2] == "SWING_DAMAGE" and not event[21] then ST:Start()
    elseif event[2] == "SWING_MISSED" and not event[13] then ST:Start()
    elseif (event[2] == "SPELL_DAMAGE" or event[2] == "SPELL_MISSED") and event[13] == "Maul" then ST:Start() end
end)

ns:On("UNIT_ATTACK_SPEED", function(unit)
    if unit ~= "player" or not ST.started then return end
    local speed = UnitAttackSpeed("player")
    if not speed or speed <= 0 then return end
    local fraction = math.min(1, (GetTime() - ST.started) / ST.duration)
    ST.duration, ST.started = speed, GetTime() - fraction * speed
    ST.bar:SetMinMaxValues(0, speed)
end)

ns:On("PLAYER_REGEN_ENABLED", function()
    ST.started = nil
    if ST.bar then ST.bar:Hide() end
end)

