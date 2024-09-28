local playerGUID = UnitGUID("player")
local f = CreateFrame("Frame")

local VER_UI = select(4, GetBuildInfo())
local VER_TBC = 20501

local SPELL_MARK = VER_UI < VER_TBC and 5231 or 1126
local SPELL_THORNS = 467
local SPELL_AI = 1459
local SPELL_MIGHT = 19834
local SPELL_KINGS = 20217
local SPELL_WIS = 19742
local SPELL_FORT = VER_UI < VER_TBC and 1255 or 1243
local SPELL_BREATH = 5697

-- short/simple non-namespaced global function names are bad, other addons may end up overwriting ours or ours overwrites theirs, let's make it local.
local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

-- we will conditionally register our combat parser to avoid emoting for already applied buffs after loading screens
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")

f:SetScript("OnEvent", function(self, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(event, CombatLogGetCurrentEventInfo())
    else
        return self[event] and self[event](self)
    end
end)

-- Build Spell list (this ignores ranks)
local buff_list = Set({
    (GetSpellInfo(SPELL_MARK)), --Mark of the Wild
    (GetSpellInfo(SPELL_THORNS)), --Thorns
    (GetSpellInfo(SPELL_AI)), --Arcane Intellect
    (GetSpellInfo(SPELL_MIGHT)), --Blessing Of Might
    (GetSpellInfo(SPELL_KINGS)), --Blessing Of Kings
    (GetSpellInfo(SPELL_WIS)), --Blessing Of Wisdom
    (GetSpellInfo(SPELL_FORT)), --Power Word: Fortitude
    (GetSpellInfo(SPELL_BREATH)), --Unending Breath
})

local random_elist = {-- "thank", "cheer", "hail", "praise", "drink"
    EMOTE98_TOKEN,EMOTE21_TOKEN,EMOTE54_TOKEN,EMOTE123_TOKEN,EMOTE36_TOKEN
}
local emote_count = #random_elist

-- keep track of folks that have been thanked recently
local thank_cd = {}

-- we're about to enter a loading screen (instance or mage portal, boat, zeppelin or tram, summon etc), unregister our combat parser
function f:PLAYER_LEAVING_WORLD()
    f:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
-- we're exiting the loading screen, start monitoring for new buffs again
function f:PLAYER_ENTERING_WORLD()
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f._enter = GetTime()
end

function f:OnCombatEvent(event, ...)
    local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName = ...
    local spell_name, _, aura_type = select(13, ...)

    local now = GetTime()
    if f._enter and now - f._enter < 2 then return end

    if subevent == "SPELL_AURA_APPLIED" then
        -- clear expired thank cooldowns
        for key,value in pairs(thank_cd) do
            if value < now then
                thank_cd[key] = nil
            end
        end

        -- Make sure its cast on us from another source and they are not in our raidgroup / party
        if (destGUID and sourceGUID) -- do not consider source-less buffs, sourceGUID ~= playerGUID is not enough because nil ~= playerGUID == true
        and (destGUID == playerGUID)
        and (sourceGUID ~= destGUID)
        and not (thank_cd[sourceGUID])
        and not (UnitInParty(sourceName) or UnitInRaid(sourceName)) then
            if buff_list[spell_name] then
                local srcType = strsplit("-", sourceGUID) -- `type` is a reserved word for a Lua function
                -- Make sure the other source is a player
                if srcType == "Player" then
                    thank_cd[sourceGUID] = now + 90
                    if not TFTB_NEWEMOTE or (TFTB_NEWEMOTE == "EMOTE0_TOKEN") then
                        local id = fastrandom(1,emote_count)
                        DoEmote(random_elist[id], sourceName)
                    else
                        DoEmote(_G[TFTB_NEWEMOTE], sourceName)
                    end
                end
            end
        end
    end
end

-- let's cache available emotes so we can alert the player if they try to set a non-existent one
local emote_cache = {}
for i=1,306 do
    local token = string.format("EMOTE%d_TOKEN",i)
    if _G[token] then
        emote_cache[_G[token]] = token
    end
end

local function TFTBCommands(msg, editbox)
    local msg = msg or ""
    msg = string.upper(msg)
    if msg == "" then
        if TFTB_NEWEMOTE and TFTB_NEWEMOTE ~= "EMOTE0_TOKEN" then
            print("TFTB current emote is: ".. _G[TFTB_NEWEMOTE]..".")
        else
            print("TFTB is currently using a random emote.")
            print("    Use /tftb EMOTE to set your preferred one for example /tftb thank")
        end
    elseif msg == "RANDOM" then
        TFTB_NEWEMOTE = "EMOTE0_TOKEN" -- we're using this non-existent token to denote "random" from our list
        print("TFTB is now using a random emote.")
    else
        local token = emote_cache[msg] -- is this an actual emote? store its token in our SV
        if token then
            TFTB_NEWEMOTE = token
            print("TFTB emote has been set to: ".. msg .. ".")
        else
            print(msg .. " is not a valid emote.")
        end
    end
end

SLASH_TFTB1 = "/tftb"
SlashCmdList.TFTB = TFTBCommands