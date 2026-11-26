-- WhyTheyNameThisWay: English-learning notes for names in tooltips,
-- plus a draggable, resizable, lockable window that keeps the last explanation on screen.
local ADDON, ns = ...
local D = ns.D
local LEVEL = ns.LEVEL

local PER_NAME = 3      -- most hints per name (sub-zone and zone each get their own 3)
local SKIP = { the = true, of = true, a = true, an = true, ["and"] = true, to = true,
               ["in"] = true, on = true, at = true, ["for"] = true, with = true, from = true }
local LEVEL_NAMES = { [0] = "show all words", [1] = "hide Basic words", [2] = "hide Basic + Intermediate words" }

local DEFAULTS = {
    shown = true, tooltip = true, fontSize = 12, skipLevel = 1, zoneUpdate = true,
    chinese = false, -- show a Chinese (中文) explanation under each hint; off by default
    locked = false, width = 320, height = 0,
    point = "TOPLEFT", relPoint = "CENTER", x = 150, y = 100,
}
local FONT_MIN, FONT_MAX = 8, 24
local db -- WhyTheyNameThisWayDB, set on ADDON_LOADED

local function Print(msg)
    print("|cff66bfffWhyTheyNameThisWay:|r " .. msg)
end

---------------------------------------------------------------- lookup
-- Returns the entry and the dictionary key it was found under (wolves -> wolf).
local function Lookup(word)
    local tries = { word }
    if word:sub(-3) == "ves" then tries[#tries + 1] = word:sub(1, -4) .. "f" end
    if word:sub(-3) == "ies" then tries[#tries + 1] = word:sub(1, -4) .. "y" end
    if word:sub(-2) == "es"  then tries[#tries + 1] = word:sub(1, -3) end
    if word:sub(-1) == "s"   then tries[#tries + 1] = word:sub(1, -2) end
    for _, k in ipairs(tries) do
        if D[k] then return D[k], k end
    end
end

-- Skip this key? (too easy for the chosen level, or hidden by the player)
local function Skipped(key)
    if db and db.hidden[key] then return true end
    return (LEVEL[key] or 3) <= ((db and db.skipLevel) or 0)
end

local function Clean(name)
    if type(name) ~= "string" or name == "" then return end
    if issecretvalue and issecretvalue(name) then return end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return end
    return name
end

-- Hints for one name: the whole name first, then individual words.
-- Returns a list of { title, entry, key }.
local function Collect(name, seen)
    local list = {}
    local lower = name:lower()
    local whole = D[lower]
    if whole then
        if not seen[lower] and not Skipped(lower) then
            seen[lower] = true
            list[1] = { name, whole, lower }
            return list -- a whole-name note already explains the parts
        end
        if not lower:find("[^%a']") then return list end -- one-word name, nothing to split
    end
    for word in lower:gsub("[^%a']", " "):gmatch("%S+") do
        if #list >= PER_NAME then break end
        word = word:gsub("'s$", ""):gsub("^'+", ""):gsub("'+$", "")
        if word ~= "" and not SKIP[word] and not seen[word] then
            local e, key = Lookup(word)
            local already = key and seen[key] -- check BEFORE marking, or every word counts as a duplicate
            seen[word] = true
            if e and not already and not Skipped(key) then
                seen[key] = true
                list[#list + 1] = { (word:gsub("^%l", string.upper)), e, key }
            end
        end
    end
    return list
end

-- Build groups: { { name = "Northshire Abbey", hints = {...} }, ... }
-- Each argument is a name, or { englishName, shownName } from the translation layer
-- (Translate.lua); then hints come from the English name and the title shows both.
local function Gather(...)
    local groups, seen = {}, {}
    for i = 1, select("#", ...) do
        local item, shown = select(i, ...), nil
        if type(item) == "table" then item, shown = item[1], Clean(item[2]) end
        local name = Clean(item)
        if name then
            local hints = Collect(name, seen)
            if #hints > 0 then
                local title = name
                if shown and shown ~= name then title = name .. " (" .. shown .. ")" end
                groups[#groups + 1] = { name = title, hints = hints }
            end
        end
    end
    return groups
end

---------------------------------------------------------------- window
local panel, panelTitle, emptyText
local PAD = 12
local MIN_W, MIN_H, MAX_W, MAX_H = 200, 80, 1000, 800
local sizing = false        -- true while the user drags the resize grip
local current = nil         -- groups currently shown in the window
local rows, heads = {}, {}  -- reusable hint rows and group headings
local fontSetting, lockSetting

-- Chinese explanation for a dictionary key, when the option is on (DataZH.lua).
local function ZhFor(key)
    return db and db.chinese and ns.ZH and key and ns.ZH[key] or nil
end

-- On a non-Chinese client the normal window font has no Chinese characters, so when
-- the Chinese option is on, switch the window to a Chinese-capable game font.
local CJK_CLIENT = ((GetLocale and GetLocale()) or ""):find("^zh") ~= nil
local CJK_FONT = "Fonts\\ARHei.ttf"

local function FontFor(fs, template, delta)
    local file, _, flags = template:GetFont()
    local size = db.fontSize + (delta or 0)
    if db.chinese and not CJK_CLIENT and fs:SetFont(CJK_FONT, size, flags or "") then return end
    fs:SetFont(file, size, flags or "")
end

local function SavePosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not (left and top) then return end
    db.point, db.relPoint, db.x, db.y = "TOPLEFT", "BOTTOMLEFT", left, top
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- Always pinned by the TOP-LEFT corner, so growing never moves the buttons.
local function ApplyPosition()
    panel:ClearAllPoints()
    panel:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    if db.point ~= "TOPLEFT" or db.relPoint ~= "BOTTOMLEFT" then SavePosition() end
end

local Render -- defined below

local function HideHint(key, title)
    db.hidden[key] = true
    Print("hid '" .. title .. "'. Type |cffffd100/why unhide " .. key .. "|r to bring it back.")
    if current then
        for gi = #current, 1, -1 do
            local g = current[gi]
            for hi = #g.hints, 1, -1 do
                if g.hints[hi][3] == key then table.remove(g.hints, hi) end
            end
            if #g.hints == 0 then table.remove(current, gi) end
        end
    end
    Render()
end

local function GetHead(i)
    local h = heads[i]
    if not h then
        h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetJustifyH("LEFT")
        heads[i] = h
    end
    FontFor(h, GameFontNormal, 0)
    h:SetTextColor(0.4, 0.75, 1)
    return h
end

local function GetRow(i)
    local r = rows[i]
    if not r then
        r = {}
        r.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetJustifyH("LEFT")
        r.text:SetJustifyV("TOP")
        r.text:SetSpacing(2)
        r.hide = CreateFrame("Button", nil, panel)
        r.hide:SetSize(14, 14)
        r.hide:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        r.hide:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        r.hide:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
        r.hide:SetScript("OnClick", function(self) HideHint(self.key, self.title) end)
        r.hide:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Hide this hint")
            GameTooltip:AddLine("'" .. self.title .. "' won't be shown again.", 1, 1, 1, true)
            GameTooltip:AddLine("/why unhide " .. self.key .. " brings it back.", 0.65, 0.65, 0.65, true)
            GameTooltip:Show()
        end)
        r.hide:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    FontFor(r.text, GameFontHighlightSmall, 0)
    return r
end

local function HintText(title, e, key)
    local s = "|cffffd100" .. title .. ":|r " .. e[1]
    if e[2] and e[2] ~= "" then s = s .. "\n|cffa6a6a6Roots: " .. e[2] .. "|r" end
    if e[3] and e[3] ~= "" then s = s .. "\n|cff80e680e.g. " .. e[3] .. "|r" end
    local zh = ZhFor(key)
    if zh then s = s .. "\n|cffffb366中文：" .. zh .. "|r" end
    return s
end

-- Lay out headings and hint rows top to bottom, then fit the height.
Render = function()
    if not panel then return end
    for _, h in ipairs(heads) do h:Hide() end
    for _, r in ipairs(rows) do r.text:Hide(); r.hide:Hide() end

    local w = panel:GetWidth()
    local textW = w - PAD * 2 - 18 -- room for the hide button
    local titleH = math.max(panelTitle:GetStringHeight(), 18)
    local y = PAD + titleH + 8

    local nh, nr = 0, 0
    local multi = current and #current > 1
    if current and #current > 0 then
        emptyText:Hide()
        for gi, g in ipairs(current) do
            if multi then
                nh = nh + 1
                local h = GetHead(nh)
                h:SetWidth(textW)
                h:SetText(g.name)
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
                h:Show()
                y = y + h:GetStringHeight() + 4
            end
            for _, hint in ipairs(g.hints) do
                nr = nr + 1
                local r = GetRow(nr)
                r.text:SetWidth(textW)
                r.text:SetText(HintText(hint[1], hint[2], hint[3]))
                r.text:ClearAllPoints()
                r.text:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
                r.text:Show()
                r.hide.key, r.hide.title = hint[3], hint[1]
                r.hide:ClearAllPoints()
                r.hide:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD + 2, -y)
                r.hide:Show()
                y = y + r.text:GetStringHeight() + 10
            end
            if gi < #current then y = y + 4 end
        end
    else
        emptyText:SetWidth(w - PAD * 2)
        FontFor(emptyText, GameFontHighlightSmall, 0)
        emptyText:ClearAllPoints()
        emptyText:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
        emptyText:Show()
        y = y + emptyText:GetStringHeight() + 4
    end

    if not sizing then
        panel:SetHeight(math.floor(math.max(y + PAD, db.height or 0, MIN_H) + 0.5))
    end
end

local function ApplySize()
    panel:SetWidth(math.max(MIN_W, math.min(MAX_W, db.width or DEFAULTS.width)))
    Render()
end

local function ApplyFont()
    if not panel then return end
    db.fontSize = math.max(FONT_MIN, math.min(FONT_MAX, math.floor((db.fontSize or 12) + 0.5)))
    FontFor(panelTitle, GameFontNormal, 2)
    Render()
end

local function SetFontSize(size)
    db.fontSize = size
    ApplyFont()
    if fontSetting and fontSetting.GetValue and fontSetting:GetValue() ~= db.fontSize then
        fontSetting:SetValue(db.fontSize)
    end
end

-- Chinese explanation on/off: window button, Options checkbox and /why zh stay in sync.
local chineseSetting
local function SetChinese(on)
    db.chinese = on and true or false
    if panel and panel.zhButton then
        panel.zhButton:SetText(db.chinese and "|cffffd100ZH|r" or "|cff808080ZH|r")
    end
    ApplyFont() -- re-applies the font and redraws the window with or without Chinese
    if chineseSetting and chineseSetting.GetValue and chineseSetting:GetValue() ~= db.chinese then
        chineseSetting:SetValue(db.chinese)
    end
end

-- Locked: no dragging, no resizing, grip hidden.
local function SetLocked(locked)
    db.locked = locked and true or false
    if panel then
        panel.lockButton:SetNormalTexture(db.locked and "Interface\\Buttons\\LockButton-Locked-Up"
                                                     or "Interface\\Buttons\\LockButton-Unlocked-Up")
        panel.grip:SetShown(not db.locked)
    end
    if lockSetting and lockSetting.GetValue and lockSetting:GetValue() ~= db.locked then
        lockSetting:SetValue(db.locked)
    end
end

local function CreatePanel()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    panel = CreateFrame("Frame", "WhyTheyNameThisWayFrame", UIParent, template)
    panel:SetSize(db.width, 80)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif panel.SetMinResize then
        panel:SetMinResize(MIN_W, MIN_H)
        panel:SetMaxResize(MAX_W, MAX_H)
    end
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        panel:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        panel:SetBackdropBorderColor(0.4, 0.6, 0.9, 1)
    end

    -- A- / A+ in the top-left corner (the left edge never moves)
    local function FontButton(label, delta, x)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(26, 18)
        b:SetText(label)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -PAD + 3)
        b:SetScript("OnClick", function() SetFontSize(db.fontSize + delta) end)
        return b
    end
    FontButton("A-", -1, PAD - 4)
    FontButton("A+", 1, PAD + 24)

    panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panelTitle:SetPoint("TOPLEFT", PAD + 56, -PAD - 1)
    panelTitle:SetPoint("RIGHT", -84, 0) -- room for ZH, lock and close buttons
    panelTitle:SetJustifyH("LEFT")
    panelTitle:SetText("Why this name?")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() panel:Hide(); db.shown = false end)

    local lock = CreateFrame("Button", nil, panel)
    lock:SetSize(20, 20)
    lock:SetPoint("RIGHT", close, "LEFT", 2, 0)
    lock:SetScript("OnClick", function() SetLocked(not db.locked) end)
    lock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(db.locked and "Unlock window" or "Lock window (no moving or resizing)")
        GameTooltip:Show()
    end)
    lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.lockButton = lock

    -- ZH button: Chinese explanation on/off
    local zh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    zh:SetSize(30, 18)
    zh:SetPoint("RIGHT", lock, "LEFT", -2, 0)
    zh:SetScript("OnClick", function() SetChinese(not db.chinese) end)
    zh:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(db.chinese and "Hide Chinese explanation" or "Show Chinese explanation")
        GameTooltip:AddLine("中文解释 on/off  (/why zh)", 1, 1, 1)
        GameTooltip:Show()
    end)
    zh:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.zhButton = zh

    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        if db.locked then return end
        sizing = true
        panel:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        if not sizing then return end
        panel:StopMovingOrSizing()
        sizing = false
        db.width, db.height = math.floor(panel:GetWidth() + 0.5), math.floor(panel:GetHeight() + 0.5)
        SavePosition()
        ApplySize()
    end)
    panel.grip = grip
    panel:SetScript("OnSizeChanged", function() if sizing then Render() end end)

    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("|cffa6a6a6Hover over an NPC, item, spell, or the zone name above the minimap. "
        .. "New places update this window automatically.\nDrag to move, corner to resize. Type /why for options.|r")

    ApplyPosition()
    ApplySize()
    ApplyFont()
    SetLocked(db.locked)
    SetChinese(db.chinese)
    panel:SetShown(db.shown)
end

local lastKey
local function ShowInPanel(groups)
    if not panel then return end
    local names = {}
    for i, g in ipairs(groups) do names[i] = g.name .. #g.hints end
    local key = table.concat(names, "|") .. "#" .. db.skipLevel
    if key == lastKey then return end -- same thing hovered again
    lastKey = key
    current = groups
    if #groups == 1 then
        panelTitle:SetText("|cff66bfff" .. groups[1].name .. "|r")
    else
        panelTitle:SetText("Why this name?")
    end
    Render()
end

---------------------------------------------------------------- explain
local function Explain(tt, ...)
    local groups = Gather(...)
    if #groups == 0 then return end -- nothing known: the window keeps its last entry

    ShowInPanel(groups)

    if not (db and db.tooltip) or not tt or not tt.AddLine then return end
    tt:AddLine(" ")
    tt:AddLine("Why this name?", 0.4, 0.75, 1)
    for _, g in ipairs(groups) do
        if #groups > 1 then tt:AddLine(g.name, 0.4, 0.75, 1) end
        for _, hint in ipairs(g.hints) do
            local title, e = hint[1], hint[2]
            tt:AddLine(title .. ": |cffffffff" .. e[1] .. "|r", 1, 0.82, 0, true)
            if e[2] and e[2] ~= "" then tt:AddLine("Roots: " .. e[2], 0.65, 0.65, 0.65, true) end
            if e[3] and e[3] ~= "" then tt:AddLine("e.g. " .. e[3], 0.5, 0.9, 0.5, true) end
            local zh = ZhFor(hint[3])
            if zh then tt:AddLine("中文：" .. zh, 1, 0.7, 0.4, true) end
        end
    end
    tt:Show() -- resize to fit the new lines
end

local function Allowed(tt)
    return tt == GameTooltip or tt == ItemRefTooltip
end

---------------------------------------------------------------- tooltip hooks
local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- The modern client may hide (make "secret") what GameTooltip:GetUnit() returns,
-- so read the name with UnitName() on the unit token instead (same as /why check).
local function OnUnit(tt, data)
    if not Allowed(tt) then return end
    local unit
    if tt.GetUnit then
        local ok, _, u = pcall(tt.GetUnit, tt)
        if ok and type(u) == "string" and not IsSecret(u) then unit = u end
    end
    if not unit and UnitExists("mouseover") then unit = "mouseover" end

    local name
    if unit then
        local ok, n = pcall(UnitName, unit)
        if ok and type(n) == "string" and not IsSecret(n) then name = n end
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and not IsSecret(isPlayer) and isPlayer == true then return end -- skip other players
    end
    local via = name and "UnitName" or nil
    if not name then -- fallback: the first line of the tooltip is the unit's name
        local line = data and data.lines and data.lines[1]
        local t = line and line.leftText
        if type(t) == "string" and not IsSecret(t) then name = t; via = "tooltip line" end
    end
    local en, how = ns.T.Unit(unit, name) -- non-English client: NPC ID -> English name
    if db and db.debug and ns.T.active then
        Print(("translate: %s -> %s (%s)"):format(tostring(name), tostring(en), how or "no match"))
    end
    if db and db.debug then
        local function show(v)
            if v == nil then return "nil" end
            if IsSecret(v) then return "(hidden by game)" end
            return tostring(v)
        end
        local rawName, rawUnit
        if tt.GetUnit then
            local ok, n, u = pcall(tt.GetUnit, tt)
            if ok then rawName, rawUnit = n, u end
        end
        Print(("unit hook: GetUnit name=%s unit=%s | mouseover=%s | using=%s (%s)"):format(
            show(rawName), show(rawUnit), tostring(UnitExists("mouseover")), show(name), via or "none"))
    end
    Explain(tt, ns.T.Pair(en, name))
end

local function OnItem(tt, data)
    if not Allowed(tt) then return end
    local name, link
    if tt.GetItem then name, link = tt:GetItem() end
    if (not name or name == "") and data and data.id then
        if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(data.id)
        elseif GetItemInfo then name = GetItemInfo(data.id) end
    end
    local en = ns.T.Item(data and data.id, link) -- non-English client: item ID -> English name
    Explain(tt, ns.T.Pair(en, name))
end

local function OnSpell(tt, data)
    if not Allowed(tt) then return end
    local name
    if tt.GetSpell then name = tt:GetSpell() end
    if (not name or name == "") and data and data.id then
        if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(data.id)
        elseif GetSpellInfo then name = GetSpellInfo(data.id) end
    end
    Explain(tt, name)
end

-- Run a hook safely; with /why debug on, print any error instead of failing silently.
local function Guard(fn, label)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and db and db.debug then Print("|cffff6060" .. label .. " error:|r " .. tostring(err)) end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    local T = Enum.TooltipDataType
    if T.Unit  then TooltipDataProcessor.AddTooltipPostCall(T.Unit,  Guard(OnUnit, "unit"))   end
    if T.Item  then TooltipDataProcessor.AddTooltipPostCall(T.Item,  Guard(OnItem, "item"))   end
    if T.Spell then TooltipDataProcessor.AddTooltipPostCall(T.Spell, Guard(OnSpell, "spell")) end
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        pcall(tt.HookScript, tt, "OnTooltipSetUnit",  Guard(OnUnit, "unit"))
        pcall(tt.HookScript, tt, "OnTooltipSetItem",  Guard(OnItem, "item"))
        pcall(tt.HookScript, tt, "OnTooltipSetSpell", Guard(OnSpell, "spell"))
    end
end

---------------------------------------------------------------- zones
local function ZoneNames()
    local zone, sub = GetZoneText(), GetSubZoneText()
    if sub == "" or sub == zone then sub = nil end
    -- non-English client: localized zone text -> English name
    if sub then sub = ns.T.Pair(ns.T.Zone(sub), sub) end
    zone = ns.T.Pair(ns.T.Zone(zone), zone)
    return sub, zone -- sub-zone first, then the main zone
end

-- Entering a new zone or sub-zone updates the window (no tooltip involved).
local function OnZoneChanged()
    if not (db and db.zoneUpdate) then return end
    Explain(nil, ZoneNames())
end

local function HookZoneButton()
    local btn = MinimapZoneTextButton or (MinimapCluster and MinimapCluster.ZoneTextButton)
    if not btn or btn.__wtnwHooked then return end
    btn.__wtnwHooked = true
    btn:HookScript("OnEnter", function() Explain(GameTooltip, ZoneNames()) end)
end

---------------------------------------------------------------- options panel
local function RegisterOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local category = Settings.RegisterVerticalLayoutCategory("Why They Name This Way")

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_SkipLevel", "skipLevel", db,
            Settings.VarType.Number, "Hide easy words", DEFAULTS.skipLevel)
        s:SetValueChangedCallback(function() lastKey = nil end)
        local function GetOptions()
            local c = Settings.CreateControlTextContainer()
            c:Add(0, "Show all words")
            c:Add(1, "Hide Basic (wolf, sword, red)")
            c:Add(2, "Hide Basic + Intermediate (dagger, swamp)")
            return c:GetData()
        end
        local create = Settings.CreateDropdown or Settings.CreateDropDown
        create(category, s, GetOptions, "Skip words you already know. Boss and place name stories are always shown.")
    end)

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_FontSize", "fontSize", db,
            Settings.VarType.Number, "Window font size", DEFAULTS.fontSize)
        s:SetValueChangedCallback(function(_, value) db.fontSize = value; ApplyFont() end)
        local opts = Settings.CreateSliderOptions(FONT_MIN, FONT_MAX, 1)
        if MinimalSliderWithSteppersMixin then
            opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        end
        Settings.CreateSlider(category, s, opts, "Size of the text in the window.")
        fontSetting = s
    end)

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_Locked", "locked", db,
            Settings.VarType.Boolean, "Lock window", DEFAULTS.locked)
        s:SetValueChangedCallback(function(_, value) SetLocked(value) end)
        Settings.CreateCheckbox(category, s, "Stop the window from being moved or resized.")
        lockSetting = s
    end)

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_ZoneUpdate", "zoneUpdate", db,
            Settings.VarType.Boolean, "Update when entering a new place", DEFAULTS.zoneUpdate)
        Settings.CreateCheckbox(category, s, "Explain the zone and sub-zone names when you arrive there.")
    end)

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_Chinese", "chinese", db,
            Settings.VarType.Boolean, "Show Chinese explanation (中文解释)", DEFAULTS.chinese)
        s:SetValueChangedCallback(function(_, value) SetChinese(value) end)
        Settings.CreateCheckbox(category, s, "Add a Chinese line under each English hint, in the window and in tooltips.")
        chineseSetting = s
    end)

    pcall(function()
        local s = Settings.RegisterAddOnSetting(category, "WTNW_Tooltip", "tooltip", db,
            Settings.VarType.Boolean, "Show notes in tooltips", DEFAULTS.tooltip)
        Settings.CreateCheckbox(category, s, "Also add the explanation to the bottom of tooltips.")
    end)

    Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------- slash command
SLASH_WHYTHEYNAMETHISWAY1 = "/why"
SlashCmdList.WHYTHEYNAMETHISWAY = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        db.point, db.relPoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relPoint, DEFAULTS.x, DEFAULTS.y
        db.width, db.height = DEFAULTS.width, DEFAULTS.height
        ApplyPosition()
        ApplySize()
        SetLocked(false)
        panel:Show(); db.shown = true
        Print("window position and size reset, and unlocked.")
    elseif msg == "lock" or msg == "unlock" then
        SetLocked(msg == "lock")
        Print("window " .. (db.locked and "locked" or "unlocked") .. ".")
    elseif msg:match("^font") then
        local n = tonumber(msg:match("^font%s+(%d+)"))
        if n then
            SetFontSize(n)
            Print("font size " .. db.fontSize .. ".")
        else
            Print("font size is " .. db.fontSize .. ". Use /why font 14 (" .. FONT_MIN .. "-" .. FONT_MAX .. ").")
        end
    elseif msg:match("^level") then
        local n = tonumber(msg:match("^level%s+(%d)"))
        if n and LEVEL_NAMES[n] then db.skipLevel = n; lastKey = nil end
        Print("level: " .. LEVEL_NAMES[db.skipLevel] .. ". Use /why level 0, 1 or 2.")
    elseif msg == "hidden" then
        local list = {}
        for k in pairs(db.hidden) do list[#list + 1] = k end
        table.sort(list)
        if #list == 0 then Print("no hidden hints.")
        else Print("hidden hints: " .. table.concat(list, ", ")) end
    elseif msg:match("^unhide") then
        local what = msg:match("^unhide%s+(.+)$")
        if what == "all" then
            wipe(db.hidden)
            Print("all hidden hints are back.")
        elseif what and db.hidden[what] then
            db.hidden[what] = nil
            Print("'" .. what .. "' is back.")
        else
            Print("use /why unhide <word> or /why unhide all. /why hidden lists them.")
        end
        lastKey = nil
    elseif msg == "check" then
        -- Explain why a monster/NPC does or doesn't get a hint.
        local unit = (UnitExists("mouseover") and "mouseover") or (UnitExists("target") and "target") or nil
        if not unit then
            Print("target (or hover) a monster, then type /why check.")
            return
        end
        local ok, name = pcall(UnitName, unit)
        if not ok or type(name) ~= "string" then
            Print("the game did not give this unit's name to addons.")
            return
        end
        if issecretvalue and issecretvalue(name) then
            Print("the game is hiding this name from addons right now (in combat or an instance), so no hint can show.")
            return
        end
        if ns.T.active then
            local en, how = ns.T.Unit(unit, name)
            if en then
                Print("game language " .. ns.T.locale .. ": '" .. name .. "' is '" .. en .. "' in English (" .. how .. ").")
                name = en
            else
                Print("game language " .. ns.T.locale .. ": no English name found for '" .. name .. "'.")
            end
        end
        Print("checking '" .. name .. "'  (tooltip notes " .. (db.tooltip and "ON" or "OFF")
            .. ", level setting " .. db.skipLevel .. "):")
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and isPlayer == true then Print("  this is a player - player names are skipped.") end
        local lower = name:lower()
        if D[lower] then
            Print("  whole name: in the dictionary" .. (Skipped(lower) and ", but hidden (level or X button)" or " - should show"))
        end
        for word in lower:gsub("[^%a']", " "):gmatch("%S+") do
            word = word:gsub("'s$", ""):gsub("^'+", ""):gsub("'+$", "")
            if word ~= "" then
                if SKIP[word] then
                    Print("  " .. word .. ": ignored (small word)")
                else
                    local e, key = Lookup(word)
                    if not e then
                        Print("  " .. word .. ": not in the dictionary")
                    elseif db.hidden[key] then
                        Print("  " .. word .. ": you hid it with X - /why unhide " .. key)
                    elseif Skipped(key) then
                        Print("  " .. word .. ": too easy for your level setting - /why level 0 shows it")
                    else
                        Print("  " .. word .. ": should show")
                    end
                end
            end
        end
    elseif msg == "zh" or msg == "chinese" or msg == "中文" then
        SetChinese(not db.chinese)
        Print("Chinese explanation " .. (db.chinese and "ON (中文解释已开启)" or "OFF (中文解释已关闭)") .. ".")
    elseif msg == "debug" then
        db.debug = not db.debug
        Print("debug messages " .. (db.debug and "ON - hook errors will be printed in chat." or "OFF."))
    elseif msg == "zone" then
        db.zoneUpdate = not db.zoneUpdate
        Print("update on entering a new place " .. (db.zoneUpdate and "ON" or "OFF") .. ".")
        if db.zoneUpdate then lastKey = nil; OnZoneChanged() end
    elseif msg == "tooltip" then
        db.tooltip = not db.tooltip
        Print("tooltip notes " .. (db.tooltip and "ON" or "OFF") .. ".")
    elseif msg == "" or msg == "show" or msg == "hide" or msg == "toggle" then
        local show
        if msg == "show" then show = true
        elseif msg == "hide" then show = false
        else show = not panel:IsShown() end
        panel:SetShown(show)
        db.shown = show
    else
        Print("/why - show/hide the window")
        Print("/why lock, /why unlock - stop/allow moving and resizing")
        Print("/why reset - reset window position and size")
        Print("/why font 14 - set the window text size (" .. FONT_MIN .. "-" .. FONT_MAX .. ")")
        Print("/why level 0|1|2 - 0 show all, 1 hide Basic words, 2 also hide Intermediate")
        Print("/why check - target a monster to see why it does or doesn't get a hint")
        Print("/why hidden - list hints you hid with the X button")
        Print("/why unhide <word> | all - show hidden hints again")
        Print("/why zone - turn updating on entering a new place on/off")
        Print("/why tooltip - turn tooltip notes on/off")
        Print("/why zh - turn the Chinese explanation on/off (中文解释)")
        Print("Settings are also in Options > AddOns > Why They Name This Way.")
    end
end

---------------------------------------------------------------- startup
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        WhyTheyNameThisWayDB = WhyTheyNameThisWayDB or {}
        db = WhyTheyNameThisWayDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        db.hidden = db.hidden or {}
        CreatePanel()
        RegisterOptions()
    elseif event == "PLAYER_LOGIN" then
        HookZoneButton()
    elseif db then
        OnZoneChanged()
    end
end)
