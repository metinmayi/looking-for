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

local seen = {}
local lastPlayed = 0
local db
local settingsCategory

local function loadDB()
    LookingForDB = LookingForDB or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local char = LookingForDB[key] or {}
    if char.enabled == nil then char.enabled = true end
    char.classes = char.classes or {}
    for _, c in ipairs(CLASS_ORDER) do
        if char.classes[c] == nil then char.classes[c] = false end
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
        local _, classFile = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if classFile and db.classes[classFile] then
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
    subtitle:SetText("Plays a sound when an applicant of a selected class signs up to your LFG listing.")

    local enabledCB = makeCheckbox(panel, "Enable alerts",
        "Master switch. When off, no sounds will play regardless of class selections.")
    enabledCB:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    enabledCB:SetScript("OnShow", function(self) self:SetChecked(db.enabled) end)
    enabledCB:SetScript("OnClick", function(self) db.enabled = self:GetChecked() end)

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -16)
    header:SetText("Alert me when these classes sign up")

    local COL_WIDTH = 160
    local ROW_HEIGHT = 26
    for i, classKey in ipairs(CLASS_ORDER) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cb = makeCheckbox(panel, CLASS_NAMES[classKey])
        cb:SetPoint("TOPLEFT", header, "BOTTOMLEFT", col * COL_WIDTH, -8 - row * ROW_HEIGHT)
        cb:SetScript("OnShow", function(self) self:SetChecked(db.classes[classKey]) end)
        cb:SetScript("OnClick", function(self) db.classes[classKey] = self:GetChecked() end)
    end

    local rows = math.ceil(#CLASS_ORDER / 2)
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(120, 22)
    testBtn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8 - rows * ROW_HEIGHT - 16)
    testBtn:SetText("Test sound")
    testBtn:SetScript("OnClick", function() PlaySound(SOUND_ID) end)

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
