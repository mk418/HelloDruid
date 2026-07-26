local _, ns = ...
ns.Config = {}
local Config = ns.Config

local defaults = {
    schema = 1,
    showBars = true,
    showCastBar = true,
    locked = true,
}

local function applyDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then target[key] = value end
    end
end

function Config:Init()
    HelloDruidDB = HelloDruidDB or { schema = 1 }
    HelloDruidCharDB = HelloDruidCharDB or {}
    applyDefaults(HelloDruidCharDB, defaults)
end

local function checkbox(parent, label, anchor, gap)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -6)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", button, "RIGHT", 2, 0)
    text:SetText(label)
    return button
end

function Config:CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = "HelloDruid"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HelloDruid")
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Cat, Bear, and Balance ability manager for Classic Era.")

    local bars = checkbox(panel, "Show HelloDruid bars", subtitle, -18)
    local locked = checkbox(panel, "Lock position", bars)
    local castbar = checkbox(panel, "Show cast bar (hides Blizzard's)", locked)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(120, 22)
    reset:SetPoint("TOPLEFT", castbar, "BOTTOMLEFT", 0, -10)
    reset:SetText("Reset position")
    reset:SetScript("OnClick", function() ns.ActionBar:ResetPosition() end)

    local function sync()
        bars:SetChecked(HelloDruidCharDB.showBars ~= false)
        locked:SetChecked(HelloDruidCharDB.locked ~= false)
        castbar:SetChecked(HelloDruidCharDB.showCastBar ~= false)
    end
    bars:SetScript("OnClick", function(self) ns.ActionBar:SetVisible(self:GetChecked()); sync() end)
    locked:SetScript("OnClick", function(self) ns.ActionBar:SetLocked(self:GetChecked()); sync() end)
    castbar:SetScript("OnClick", function(self) ns.CastBar:SetVisible(self:GetChecked()); sync() end)
    panel:SetScript("OnShow", sync)

    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -16)
    help:SetJustifyH("LEFT")
    help:SetText("The active layout follows form: Cat and Bear have dedicated bars; every other form uses Balance.\n" ..
        "Use /hd keys, hover a button, and press a key to edit bindings. Escape exits keybind mode.")

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    end
    self.panel = panel
end

function Config:OpenPanel()
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
