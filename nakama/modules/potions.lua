--------------------------------------------------------------------------------
-- nakama Potions - Table for ID's
-- Author: TheGentleman
--------------------------------------------------------------------------------
local nakama, _A, nakama = ...

nakama.Potions = {}

nakama.Potions.Health = {
    _A.GetItemInfo(858), -- Lesser Healing Potion
    _A.GetItemInfo(118), -- Minor Healing Potion
}

function nakama:useHealthPotion()
    local potion
    for _, potName in ipairs(self.Potions.Health) do
        if player:ItemCount(potName) > 0 and player:ItemUsable(potName) then
            potion = potName
            break
        end
    end

    return player:UseItem(potion)
end

_A.Core:WhenInGame(function()
    print("nakama - potion module loaded!")
end)
