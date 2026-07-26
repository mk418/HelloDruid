local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

ns.eventFrame = CreateFrame("Frame")
ns.eventHandlers = {}

ns.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" and not ns.enabled then return end
    local handlers = ns.eventHandlers[event]
    if not handlers then return end
    for i = 1, #handlers do handlers[i](...) end
end)

function ns:On(event, fn)
    if not self.eventHandlers[event] then
        self.eventHandlers[event] = {}
        self.eventFrame:RegisterEvent(event)
    end
    table.insert(self.eventHandlers[event], fn)
end

-- Local pet-autocast shine. On modern Era clients we deliberately avoid
-- AutoCastOverlayManager: putting addon frames in its shared list taints the
-- protected pet bar. Older clients use the legacy shine helpers.
local SPEEDS = { 2, 4, 6, 8 }
local function shineUpdate(self, elapsed)
    local d = self:GetWidth()
    for i = 1, 4 do
        local speed = SPEEDS[i]
        local t = (self._timers[i] + elapsed) % (speed * 4)
        self._timers[i] = t
        local phase, p = math.floor(t / speed), (t % speed) / speed * d
        local a, b, c, e = self.sparkles[i], self.sparkles[4+i], self.sparkles[8+i], self.sparkles[12+i]
        if phase == 0 then
            a:SetPoint("CENTER", self, "TOPLEFT", p, 0); b:SetPoint("CENTER", self, "BOTTOMRIGHT", -p, 0)
            c:SetPoint("CENTER", self, "TOPRIGHT", 0, -p); e:SetPoint("CENTER", self, "BOTTOMLEFT", 0, p)
        elseif phase == 1 then
            a:SetPoint("CENTER", self, "TOPRIGHT", 0, -p); b:SetPoint("CENTER", self, "BOTTOMLEFT", 0, p)
            c:SetPoint("CENTER", self, "BOTTOMRIGHT", -p, 0); e:SetPoint("CENTER", self, "TOPLEFT", p, 0)
        elseif phase == 2 then
            a:SetPoint("CENTER", self, "BOTTOMRIGHT", -p, 0); b:SetPoint("CENTER", self, "TOPLEFT", p, 0)
            c:SetPoint("CENTER", self, "BOTTOMLEFT", 0, p); e:SetPoint("CENTER", self, "TOPRIGHT", 0, -p)
        else
            a:SetPoint("CENTER", self, "BOTTOMLEFT", 0, p); b:SetPoint("CENTER", self, "TOPRIGHT", 0, -p)
            c:SetPoint("CENTER", self, "TOPLEFT", p, 0); e:SetPoint("CENTER", self, "BOTTOMRIGHT", -p, 0)
        end
    end
end

function ns:AttachShine(button, size)
    local shine
    if AutoCastOverlayMixin then
        shine = CreateFrame("Frame", nil, button, "AutoCastOverlayTemplate")
        if shine.Corners then shine.Corners:Hide() end
        shine._localAnim = shine.sparkles and #shine.sparkles == 16
    elseif AutoCastShine_AutoCastStart then
        shine = CreateFrame("Frame", button:GetName() .. "Shine", button, "AutoCastShineTemplate")
    else
        return
    end
    shine:SetSize(size, size)
    shine:SetPoint("CENTER")
    shine:SetFrameLevel((button:GetFrameLevel() or 0) + 4)
    shine:Hide()
    button._shine, button._shineOn = shine, false
end

function ns:SetShine(button, enabled, r, g, b)
    local shine = button and button._shine
    if not shine then return end
    enabled = enabled and true or false
    if button._shineOn == enabled then return end
    if enabled then
        shine:Show()
        if shine._localAnim then
            for _, sparkle in ipairs(shine.sparkles) do
                if r then sparkle:SetVertexColor(r, g, b) end
                sparkle:Show()
            end
            shine._timers = { 0, 0, 0, 0 }
            shine:SetScript("OnUpdate", shineUpdate)
        elseif AutoCastShine_AutoCastStart then
            AutoCastShine_AutoCastStart(shine, r, g, b)
        end
    else
        if shine._localAnim then
            shine:SetScript("OnUpdate", nil)
            for _, sparkle in ipairs(shine.sparkles) do sparkle:Hide() end
        elseif AutoCastShine_AutoCastStop then
            AutoCastShine_AutoCastStop(shine)
        end
        shine:Hide()
    end
    button._shineOn = enabled
end

ns.eventFrame:RegisterEvent("ADDON_LOADED")
ns.eventFrame:RegisterEvent("PLAYER_LOGIN")

ns:On("ADDON_LOADED", function(name)
    if name == ADDON_NAME then ns.Config:Init() end
end)

ns:On("PLAYER_LOGIN", function()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return end
    ns.enabled = true
    ns.Config:CreatePanel()
    print("|cff7acb59HelloDruid|r loaded")
end)

SLASH_HELLODRUID1 = "/hd"
SLASH_HELLODRUID2 = "/hellodruid"
SlashCmdList.HELLODRUID = function(message)
    message = (message or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local command, arg = message:match("^(%S+)%s*(.*)$")
    command = command or ""
    if command == "reset" then
        HelloDruidDB, HelloDruidCharDB = nil, nil
        ReloadUI()
    elseif command == "config" then
        if ns.enabled then ns.Config:OpenPanel() end
    elseif command == "bars" and ns.enabled then
        local show = arg == "on" or (arg ~= "off" and HelloDruidCharDB.showBars == false)
        ns.ActionBar:SetVisible(show)
    elseif command == "castbar" and ns.enabled then
        local show = arg == "on" or (arg ~= "off" and HelloDruidCharDB.showCastBar == false)
        ns.CastBar:SetVisible(show)
    elseif command == "pos" and ns.enabled then
        if arg == "reset" then ns.ActionBar:ResetPosition()
        elseif arg == "lock" then ns.ActionBar:SetLocked(true)
        elseif arg == "unlock" then ns.ActionBar:SetLocked(false)
        else ns.ActionBar:SetLocked(not HelloDruidCharDB.locked) end
    elseif command == "keys" and ns.enabled then
        if arg == "clear" then ns.Keybinds:ClearAll()
        elseif arg == "reset" then ns.Keybinds:ResetDefaults()
        else ns.Keybinds:ToggleMode() end
    else
        print("|cff7acb59HelloDruid|r commands:")
        print("  /hd config || /hd reset")
        print("  /hd bars [on||off]   /hd castbar [on||off]")
        print("  /hd pos [lock||unlock||reset]")
        print("  /hd keys [clear||reset]")
    end
end
