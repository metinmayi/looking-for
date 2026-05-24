local ADDON_NAME = ...

local SOUND_ID = 8959
local THROTTLE = 1.5

local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
    "SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASS_NAMES = {
    DEATHKNIGHT = "Death Knight",
    DEMONHUNTER = "Demon Hunter",
    DRUID       = "Druid",
    EVOKER      = "Evoker",
    HUNTER      = "Hunter",
    MAGE        = "Mage",
    MONK        = "Monk",
    PALADIN     = "Paladin",
    PRIEST      = "Priest",
    ROGUE       = "Rogue",
    SHAMAN      = "Shaman",
    WARLOCK     = "Warlock",
    WARRIOR     = "Warrior",
}

local SPECS_BY_CLASS = {
    DEATHKNIGHT = { { id = 250, name = "Blood" },         { id = 251, name = "Frost" },        { id = 252, name = "Unholy" } },
    DEMONHUNTER = { { id = 577, name = "Havoc" },         { id = 581, name = "Vengeance" },   { id = 1480, name = "Devourer" } },
    DRUID       = { { id = 102, name = "Balance" },       { id = 103, name = "Feral" },        { id = 104, name = "Guardian" },   { id = 105, name = "Restoration" } },
    EVOKER      = { { id = 1467, name = "Devastation" },  { id = 1468, name = "Preservation" }, { id = 1473, name = "Augmentation" } },
    HUNTER      = { { id = 253, name = "Beast Mastery" }, { id = 254, name = "Marksmanship" }, { id = 255, name = "Survival" } },
    MAGE        = { { id = 62,  name = "Arcane" },        { id = 63,  name = "Fire" },         { id = 64,  name = "Frost" } },
    MONK        = { { id = 268, name = "Brewmaster" },    { id = 270, name = "Mistweaver" },   { id = 269, name = "Windwalker" } },
    PALADIN     = { { id = 65,  name = "Holy" },          { id = 66,  name = "Protection" },   { id = 70,  name = "Retribution" } },
    PRIEST      = { { id = 256, name = "Discipline" },    { id = 257, name = "Holy" },         { id = 258, name = "Shadow" } },
    ROGUE       = { { id = 259, name = "Assassination" }, { id = 260, name = "Outlaw" },       { id = 261, name = "Subtlety" } },
    SHAMAN      = { { id = 262, name = "Elemental" },     { id = 263, name = "Enhancement" },  { id = 264, name = "Restoration" } },
    WARLOCK     = { { id = 265, name = "Affliction" },    { id = 266, name = "Demonology" },   { id = 267, name = "Destruction" } },
    WARRIOR     = { { id = 71,  name = "Arms" },          { id = 72,  name = "Fury" },         { id = 73,  name = "Protection" } },
}

local seen = {}
local lastPlayed = 0
local db
local settingsCategory

local function loadDB()
    LookingForDB = LookingForDB or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local char = LookingForDB[key] or {}
    if char.enabled == nil then char.enabled = true end

    char.specs = char.specs or {}

    if char.classes then
        for classKey, wasEnabled in pairs(char.classes) do
            if wasEnabled and SPECS_BY_CLASS[classKey] then
                for _, spec in ipairs(SPECS_BY_CLASS[classKey]) do
                    if char.specs[spec.id] == nil then
                        char.specs[spec.id] = true
                    end
                end
            end
        end
        char.classes = nil
    end

    for _, classKey in ipairs(CLASS_ORDER) do
        for _, spec in ipairs(SPECS_BY_CLASS[classKey]) do
            if char.specs[spec.id] == nil then char.specs[spec.id] = false end
        end
    end

    LookingForDB[key] = char
    db = char
end

local function playAlert()
    local now = GetTime()
    if now - lastPlayed < THROTTLE then return end
    lastPlayed = now
    PlaySound(SOUND_ID)
end

local function applicantMatches(applicantID)
    local data = C_LFGList.GetApplicantInfo(applicantID)
    if not data or not data.numMembers or data.numMembers == 0 then return false end
    for i = 1, data.numMembers do
        local specID = select(16, C_LFGList.GetApplicantMemberInfo(applicantID, i))
        if specID and db.specs[specID] then
            return true
        end
    end
    return false
end

local function onApplicantListUpdated()
    if not db.enabled then return end
    if not C_LFGList.HasActiveEntryInfo() then return end
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end
    for _, id in ipairs(applicants) do
        if not seen[id] then
            seen[id] = true
            if applicantMatches(id) then
                playAlert()
            end
        end
    end
end

local function onActiveEntryUpdate()
    if not C_LFGList.HasActiveEntryInfo() then
        wipe(seen)
    end
end

local function markExistingApplicantsSeen()
    if not C_LFGList.HasActiveEntryInfo() then return end
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end
    for _, id in ipairs(applicants) do
        seen[id] = true
    end
end

local function makeCheckbox(parent, label, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.text:SetFontObject("GameFontHighlight")
    cb.text:SetText(label)
    if tooltip then
        cb.tooltipText = label
        cb.tooltipRequirement = tooltip
    end
    return cb
end

local function setAllClassSpecs(classKey, value)
    for _, spec in ipairs(SPECS_BY_CLASS[classKey]) do
        db.specs[spec.id] = value
    end
end

local function classAllOn(classKey)
    for _, spec in ipairs(SPECS_BY_CLASS[classKey]) do
        if not db.specs[spec.id] then return false end
    end
    return true
end

local function buildPanel()
    local panel = CreateFrame("Frame")
    panel.name = "LookingFor"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LookingFor")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Plays a sound when an applicant of a selected spec signs up to your LFG listing.")

    local enabledCB = makeCheckbox(panel, "Enable alerts",
        "Master switch. When off, no sounds will play regardless of spec selections.")
    enabledCB:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    enabledCB:SetScript("OnShow", function(self) self:SetChecked(db.enabled) end)
    enabledCB:SetScript("OnClick", function(self) db.enabled = self:GetChecked() end)

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -16)
    header:SetText("Alert me when these specs sign up")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("RIGHT", -32, 0)
    scroll:SetPoint("BOTTOM", 0, 16)

    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)

    local COL_WIDTH = 200
    local SPEC_ROW_HEIGHT = 22
    local CLASS_HEADER_HEIGHT = 22
    local CLASS_GAP = 6
    local SPEC_INDENT = 16

    local columns = { {}, {} }
    for i, classKey in ipairs(CLASS_ORDER) do
        local col = ((i - 1) % 2) + 1
        table.insert(columns[col], classKey)
    end

    local classCheckboxes = {}

    for colIndex, classList in ipairs(columns) do
        local yOffset = 0
        for _, classKey in ipairs(classList) do
            local classCB = makeCheckbox(content, CLASS_NAMES[classKey],
                "Toggle all " .. CLASS_NAMES[classKey] .. " specs.")
            classCB.text:SetFontObject("GameFontNormal")
            classCB:SetPoint("TOPLEFT", content, "TOPLEFT",
                (colIndex - 1) * COL_WIDTH, -yOffset)
            classCB:SetScript("OnShow", function(self) self:SetChecked(classAllOn(classKey)) end)
            classCB:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                setAllClassSpecs(classKey, checked and true or false)
                for _, child in ipairs(classCheckboxes[classKey].specs) do
                    child:SetChecked(checked)
                end
            end)
            classCheckboxes[classKey] = { class = classCB, specs = {} }
            yOffset = yOffset + CLASS_HEADER_HEIGHT

            for _, spec in ipairs(SPECS_BY_CLASS[classKey]) do
                local specCB = makeCheckbox(content, spec.name)
                specCB:SetPoint("TOPLEFT", content, "TOPLEFT",
                    (colIndex - 1) * COL_WIDTH + SPEC_INDENT, -yOffset)
                specCB:SetScript("OnShow", function(self) self:SetChecked(db.specs[spec.id]) end)
                specCB:SetScript("OnClick", function(self)
                    db.specs[spec.id] = self:GetChecked() and true or false
                    classCheckboxes[classKey].class:SetChecked(classAllOn(classKey))
                end)
                table.insert(classCheckboxes[classKey].specs, specCB)
                yOffset = yOffset + SPEC_ROW_HEIGHT
            end

            yOffset = yOffset + CLASS_GAP
        end
    end

    local maxY = 0
    for _, classList in ipairs(columns) do
        local y = 0
        for _, classKey in ipairs(classList) do
            y = y + CLASS_HEADER_HEIGHT + #SPECS_BY_CLASS[classKey] * SPEC_ROW_HEIGHT + CLASS_GAP
        end
        if y > maxY then maxY = y end
    end

    content:SetSize(COL_WIDTH * 2, maxY)

    return panel
end

local function registerSettings()
    local panel = buildPanel()
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "LookingFor")
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function openConfig()
    Settings.OpenToCategory(settingsCategory:GetID())
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            loadDB()
            registerSettings()
        end
    elseif event == "PLAYER_LOGIN" then
        eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        markExistingApplicantsSeen()
    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        onApplicantListUpdated()
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        onActiveEntryUpdate()
    end
end)

SLASH_LOOKINGFOR1 = "/lookingfor"
SLASH_LOOKINGFOR2 = "/lf"
SlashCmdList["LOOKINGFOR"] = openConfig
