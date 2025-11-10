--------------------------------------------------------------------------------
-- nakama Pause - Module
-- Author: TheGentleman
--------------------------------------------------------------------------------
local nakama, _A, nakama = ...
nakama.Pause = nakama.Pause or {}

function nakama.Pause.PlayerCasting()
    return player:IscastingAnySpell()
end

function nakama.Pause.BadStateOrMounted()
    return player:Mounted() or player:State("stun || silence")
end

function nakama.Pause.Mounted()
    return player:Mounted()
end
