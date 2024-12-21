local LONE_WOLF_STATUS = "GOON_LONE_WOLF_STATUS"
local LONE_WOLF_PASSIVE = "Goon_Lone_Wolf_Passive_Dummy"
local LONE_WOLF_THRESHOLD = 2 -- Max party size for Lone Wolf to apply
local isUpdating = false -- Prevent recursive calls

-- Mapping of passives to corresponding statuses
local statBoosts = {
    Goon_Lone_Wolf_Strength = "GOON_LONE_WOLF_STRENGTH_STATUS",
    Goon_Lone_Wolf_Dexterity = "GOON_LONE_WOLF_DEXTERITY_STATUS",
    Goon_Lone_Wolf_Constitution = "GOON_LONE_WOLF_CONSTITUTION_STATUS",
    Goon_Lone_Wolf_Intelligence = "GOON_LONE_WOLF_INTELLIGENCE_STATUS",
    Goon_Lone_Wolf_Wisdom = "GOON_LONE_WOLF_WISDOM_STATUS",
    Goon_Lone_Wolf_Charisma = "GOON_LONE_WOLF_CHARISMA_STATUS",
    Goon_Lone_Wolf_Extra_HP = "GOON_LONE_WOLF_EXTRA_HP", -- New HP boost status
    Goon_Lone_Wolf_Extra_DR = "GOON_LONE_WOLF_EXTRA_DR" -- New Damage Reduction boost status
}

-- Function to apply or remove a status based on a passive
local function AddStatusForPassive(charID, passive, status)
    if Osi.HasPassive(charID, passive) == 1 then
        if not Osi.HasActiveStatus(charID, status) then
            Ext.Utils.Print(string.format("[AddStatusForPassive] Applying status %s for passive %s to %s", status, passive, charID))
            Osi.ApplyStatus(charID, status, -1, 1)
        end
    else
        if Osi.HasActiveStatus(charID, status) then
            Ext.Utils.Print(string.format("[AddStatusForPassive] Removing status %s for missing passive %s from %s", status, passive, charID))
            Osi.RemoveStatus(charID, status)
        end
    end
end

Ext.Timer.Start(100, function()
    AddStatusForPassive(charID, passive, status)
end)


-- Function to update Lone Wolf status for all party members
local function UpdateLoneWolfStatus()
    if isUpdating then
        Ext.Utils.Print("[UpdateLoneWolfStatus] Update already in progress. Skipping.")
        return
    end

    isUpdating = true
    Ext.Utils.Print("[UpdateLoneWolfStatus] Starting update...")

    local partyMembers = Osi.DB_PartyMembers:Get(nil)
    local partySize = #partyMembers -- Count total party members

    Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Total party members: %d", partySize))

    -- Loop through all party members
    for _, member in pairs(partyMembers) do
        local charID = member[1]
        Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Processing character: %s", charID))

        -- Check if character has the Lone Wolf passive
        local hasPassive = Osi.HasPassive(charID, LONE_WOLF_PASSIVE) == 1
        local hasStatus = Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) == 1

        if hasPassive and partySize <= LONE_WOLF_THRESHOLD then
            -- Apply main Lone Wolf status
            if not hasStatus then
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Applying Lone Wolf status to %s", charID))
                Osi.ApplyStatus(charID, LONE_WOLF_STATUS, -1, 1) -- Apply status indefinitely
            end

            -- Apply associated statuses for passives
            for passive, status in pairs(statBoosts) do
                AddStatusForPassive(charID, passive, status)
            end
        else
            -- Remove main Lone Wolf status if criteria are not met
            if hasStatus then
                Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing Lone Wolf status from %s", charID))
                Osi.RemoveStatus(charID, LONE_WOLF_STATUS)
            end
        
            -- Only remove associated statuses if the main Lone Wolf status is no longer active
            if not Osi.HasActiveStatus(charID, LONE_WOLF_STATUS) then
                for passive, status in pairs(statBoosts) do
                    if Osi.HasActiveStatus(charID, status) then
                        Ext.Utils.Print(string.format("[UpdateLoneWolfStatus] Removing %s from %s", status, charID))
                        Osi.RemoveStatus(charID, status)
                    end
                end
            end
        end
    end

    Ext.Utils.Print("[UpdateLoneWolfStatus] Update complete.")
    isUpdating = false
end

-- Event: Party size changes
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterJoinedParty")
    UpdateLoneWolfStatus()
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function()
    Ext.Utils.Print("Event triggered: CharacterLeftParty")
    UpdateLoneWolfStatus()
end)

-- Event: Gameplay starts
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    Ext.Utils.Print("Event triggered: LevelGameplayStarted")
    UpdateLoneWolfStatus()
end)

-- Function to update Lone Wolf status after a delay for level-ups
local function DelayedUpdateLoneWolfStatus(character)
    Ext.Utils.Print(string.format("[DelayedUpdateLoneWolfStatus] Waiting to update Lone Wolf status for character: %s", character))
    Ext.Timer.WaitFor(500, function()
        Ext.Utils.Print("[DelayedUpdateLoneWolfStatus] Event triggered: LeveledUp (Delayed)")
        UpdateLoneWolfStatus()
    end)
end

-- Register listener for "LeveledUp" event
Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    Ext.Utils.Print("Event triggered: LeveledUp")
    DelayedUpdateLoneWolfStatus(character)
end)
