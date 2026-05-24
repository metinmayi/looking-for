local LookingFor = LibStub("AceAddon-3.0"):NewAddon("LookingFor", "AceEvent-3.0", "AceConsole-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

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

local defaults = {
    char = {
        enabled = true,
        classes = {},
    },
}
for _, c in ipairs(CLASS_ORDER) do
    defaults.char.classes[c] = false
end

local seen = {}
local lastPlayed = 0

local function buildOptions()
    local options = {
        type = "group",
        name = "LookingFor",
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = "Enable alerts",
                desc = "Master switch. When off, no sounds will play regardless of class selections.",
                width = "full",
                get = function() return LookingFor.db.char.enabled end,
                set = function(_, v) LookingFor.db.char.enabled = v end,
            },
            classGroup = {
                order = 2,
                type = "group",
                inline = true,
                name = "Alert me when these classes sign up",
                args = {},
            },
            test = {
                order = 3,
                type = "execute",
                name = "Test sound",
                desc = "Play the alert sound now.",
                func = function() PlaySound(SOUND_ID) end,
            },
        },
    }
    for i, classKey in ipairs(CLASS_ORDER) do
        options.args.classGroup.args[classKey] = {
            order = i,
            type = "toggle",
            name = CLASS_NAMES[classKey],
            width = "half",
            get = function() return LookingFor.db.char.classes[classKey] end,
            set = function(_, v) LookingFor.db.char.classes[classKey] = v end,
        }
    end
    return options
end

function LookingFor:OnInitialize()
    self.db = AceDB:New("LookingForDB", defaults, true)
    AceConfig:RegisterOptionsTable("LookingFor", buildOptions())
    self.blizPanel = AceConfigDialog:AddToBlizOptions("LookingFor", "LookingFor")
    self:RegisterChatCommand("lookingfor", "OpenConfig")
end

function LookingFor:OnEnable()
    self:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED", "OnApplicantListUpdated")
    self:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE",    "OnActiveEntryUpdate")
    self:MarkExistingApplicantsSeen()
end

function LookingFor:OpenConfig()
    Settings.OpenToCategory(self.blizPanel.name)
end

function LookingFor:MarkExistingApplicantsSeen()
    if not C_LFGList.HasActiveEntryInfo() then return end
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end
    for _, id in ipairs(applicants) do
        seen[id] = true
    end
end

function LookingFor:OnActiveEntryUpdate()
    if not C_LFGList.HasActiveEntryInfo() then
        wipe(seen)
    end
end

function LookingFor:OnApplicantListUpdated()
    if not self.db.char.enabled then return end
    if not C_LFGList.HasActiveEntryInfo() then return end
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end

    for _, applicantID in ipairs(applicants) do
        if not seen[applicantID] then
            seen[applicantID] = true
            if self:ApplicantMatches(applicantID) then
                self:PlayAlert()
            end
        end
    end
end

function LookingFor:ApplicantMatches(applicantID)
    local applicantData = C_LFGList.GetApplicantInfo(applicantID)
    if not applicantData or not applicantData.numMembers or applicantData.numMembers == 0 then return false end
    local numMembers = applicantData.numMembers
    for i = 1, numMembers do
        local _, classFile = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if classFile and self.db.char.classes[classFile] then
            return true
        end
    end
    return false
end

function LookingFor:PlayAlert()
    local now = GetTime()
    if now - lastPlayed < THROTTLE then return end
    lastPlayed = now
    PlaySound(SOUND_ID)
end
