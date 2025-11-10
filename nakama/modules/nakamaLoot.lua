--------------------------------------------------------------------------------
-- nakama Loot - Module
-- Author: TheGentleman
--------------------------------------------------------------------------------
local nakama, _A, nakama = ...
nakama.Loot = nakama.Loot or {}
-- Local blacklist cache (O(1) lookups)
nakama.Loot.Blacklist = {}

--------------------------------------------------------------------------------
-- Listener: reset blacklist when entering combat
--------------------------------------------------------------------------------
function nakama.Loot.AddListener()
    _A.Listener:Add("nakamaLoot", { "PLAYER_REGEN_DISABLED" }, function(event)
        if event == "PLAYER_REGEN_DISABLED" then
            for k in pairs(nakama.Loot.Blacklist) do
                nakama.Loot.Blacklist[k] = nil
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Listener removal
--------------------------------------------------------------------------------
function nakama.Loot.DeleteListener()
    _A.Listener:Remove("nakamaLoot")
end

--------------------------------------------------------------------------------
-- Auto-loot routine
-- Runs O(n) over visible corpses
--------------------------------------------------------------------------------
function nakama.Loot.Auto()
    if _A.BagSpace() < 1 then return false end

    local corpses = _A.OM:Get("Dead")
    local blacklist = nakama.Loot.Blacklist

    for _, corpse in pairs(corpses) do
        if corpse:Hasloot() and corpse:Distance() < 4.5 then
            local guid = corpse.guid
            if not blacklist[guid] and player:delay("nakamaLoot", 0.5) then
                _A.InteractUnit(guid)
                _A.ClearTarget()
                blacklist[guid] = true
                return true
            end
        end
    end
end

_A.Core:WhenInGame(function()
    print("nakama - loot module loaded!")
end)
