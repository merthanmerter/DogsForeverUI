-- PROFILES: the whole UI's settings saved under a name, for any character of
-- the account to load.
--
-- The settings themselves are per character (DogsForeverUIDB). A profile is a
-- copy of them taken when it is saved, kept in DogsForeverUIProfiles - the one
-- table every character of the account shares. Loading one copies it over
-- this character's settings the way a reset copies the defaults (Core:Reset):
-- every section emptied and refilled in place, anything the profile lacks
-- from the defaults, every piece put where the profile has it. After that the
-- two are unrelated: changing a setting changes this character's settings,
-- not the profile, until it is saved again under the same name.
--
-- What a profile does not carry is what a reset keeps (a module's `keep`):
-- the player's own content rather than settings - the cooldown manager's
-- list, which is one character's spells and items. Loading a profile leaves
-- this character's list as it is.
--
-- The saved table follows the core's rules (LoadSettings there): look for it
-- until it has been read, since this client can hand it over late, and never
-- write over one that was not read. A profile saved before a late file turned
-- up is kept beside the file's.

local Profiles = {}
DogsForeverUI.Profiles = Profiles

do -- private scope
    local Core = DogsForeverUI

    Profiles.MAX_NAME = 32

    -- The live profiles: { [name] = { [module key] = section } }.
    -- DogsForeverUIProfiles is pointed at this table.
    local saved = {}
    Profiles.saved = saved
    local adopted = false

    local function Trim(text)
        if type(text) ~= "string" then return "" end
        return (text:match("^%s*(.-)%s*$"))
    end

    function Profiles.Names()
        local names = {}
        for name in pairs(saved) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            local la, lb = a:lower(), b:lower()
            if la == lb then return a < b end
            return la < lb
        end)
        return names
    end

    function Profiles.Exists(name)
        return saved[Trim(name)] ~= nil
    end

    -- This character's settings as they are now, minus what a profile does
    -- not carry.
    local function Snapshot()
        local settings = {}
        for _, module in ipairs(Core.modules) do
            local section = Core.DeepCopy(module.db)
            for name in pairs(module.keep or {}) do section[name] = nil end
            section.unlocked = nil
            settings[module.key] = section
        end
        return settings
    end

    -- Each answers whether it happened, and a line to say so; Save also the
    -- name as it was saved.

    function Profiles.Save(name)
        name = Trim(name)
        if name == "" then return false, "Type a name for the profile." end
        if #name > Profiles.MAX_NAME then
            return false, "A profile's name is at most " .. Profiles.MAX_NAME .. " letters."
        end
        local replaced = saved[name] ~= nil
        saved[name] = Snapshot()
        if replaced then return true, "Profile " .. name .. " updated.", name end
        return true, "Profile " .. name .. " saved.", name
    end

    function Profiles.Load(name)
        name = Trim(name)
        local profile = saved[name]
        if not profile then return false, "No profile is called " .. name .. "." end
        if not Core:ApplySettings(profile) then
            return false, "Profiles cannot be loaded in combat."
        end
        return true, "Profile " .. name .. " loaded."
    end

    function Profiles.Delete(name)
        name = Trim(name)
        if not saved[name] then return false, "No profile is called " .. name .. "." end
        saved[name] = nil
        return true, "Profile " .. name .. " deleted."
    end

    ---------------------------------------------------------------------------
    -- The saved table.
    ---------------------------------------------------------------------------

    local function Load()
        local file = DogsForeverUIProfiles
        if not adopted and type(file) == "table" and file ~= saved and next(file) ~= nil then
            for name, profile in pairs(file) do
                if type(name) == "string" and type(profile) == "table" and saved[name] == nil then
                    saved[name] = profile
                end
            end
            adopted = true
        end
        DogsForeverUIProfiles = saved
    end

    local function Save()
        local file = DogsForeverUIProfiles
        if not adopted and type(file) == "table" and file ~= saved and next(file) ~= nil then
            return
        end
        DogsForeverUIProfiles = saved
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("VARIABLES_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDONS_UNLOADING")
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDONS_UNLOADING" then
            Save()
        elseif not adopted then
            Load()
        end
    end)
end
