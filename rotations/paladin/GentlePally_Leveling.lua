--------------------------------------------------------------------------------
-- GentlePally - Leveling
-- Author: Gentleman
--------------------------------------------------------------------------------
local nakama, _A, nakama = ...
local apepDir = _A.GetApepDirectory()
_A.require(apepDir .. "\\nakama\\paladin\\spells.lua")
_A.require(apepDir .. "\\nakama\\generic\\spells.lua")
_A.require(apepDir .. "\\nakama\\modules\\pause.lua")
_A.require(apepDir .. "\\nakama\\modules\\nakamaLoot.lua")
_A.require(apepDir .. "\\nakama\\modules\\potions.lua")
local pallySpell = nakama.SpellBook.Paladin
local genericSpell = nakama.SpellBook.Generic
local pause = nakama.Pause

local gui = {
    -- dummy
    {
        type = "section",
        dummy = true,
        contentHeight = 18
    },
    -- spacer (2)
    {
        type = "spacer",
        size = 2,
    },
    -- header
    {
        type = "header",
        text = "GentlePally - Leveling" .. "|r",
        size = 14,
        align = "CENTER"
    },
    -- potion section
    {
        type = "section",
        size = 12,
        text = "Potions |r",
        align = "center",
        contentHeight = 40,
        expanded = false,
        height = 20,
    },
    -- spacer (2)
    {
        type = "spacer",
        size = 2,
    },
    -- checkbox | use HP potion
    {
        type = "checkbox",
        size = 12,
        y = -1,
        text = "use " .. "|cffff0000HP " .. "|cffffffffpotions |r",
        key = "_use_potions_health",
        default = true
    },
    -- text | HP potion % threshold
    {
        type = "text",
        text = "|cffff0000HP " .. "|cffffffff% threshold |r",
        size = 12,
        x = 15,
    },
    -- spinner | HP potion % threshold
    {
        type = "spinner",
        key = "_use_potions_healthpercent",
        height = 10,
        y = 12,
        spin = 30,
        step = 1,
        shiftStep = 1,
        min = 1,
        max = 70
    },
    -- QOL section
    {
        type = "section",
        size = 12,
        text = "QOL |r",
        align = "center",
        contentHeight = 40,
        expanded = false,
        height = 20,
    },
    -- spacer(2)
    {
        type = "spacer",
        size = 2,
    },
    -- nakama loothelper
    {
        type = "checkbox",
        size = 12,
        text = "|cFFA0522Dnakama loothelper |r",
        key = "_nakama_loothelper",
        default = true
    },
}

local function exeOnLoad()
    if _A.UIErrorsFrame then _A.UIErrorsFrame:Hide() end
    _A.Sound_EnableErrorSpeech = 0
    nakama.Loot.AddListener()
end

local function exeOnUnload()
    nakama.Loot.DeleteListener()
end

local function sealOfRighteousness()
    if player:SpellReady(pallySpell.SealOfRighteousness)
        and not player:Buff(pallySpell.SealOfRighteousness) then
        return player:Cast(pallySpell.SealOfRighteousness)
    end
end

local function inCombat()
    if not player then return true end

    if pause.PlayerCasting() then
        return true
    end

    if pause.BadStateOrMounted() then
        return true
    end
end

local function outCombat()
    if not player then return true end

    if pause.PlayerCasting() then
        return true
    end

    if pause.Mounted() then
        return true
    end

    if sealOfRighteousness() then
        return true
    end
end

--------------------------------------------------------------------------------
-- Routine registration
--------------------------------------------------------------------------------
_A.CR:Add("Paladin", {
    name = "GentlePally - Leveling",
    ic = inCombat,
    ooc = outCombat,
    use_lua_engine = true,
    gui = gui,
    gui_st = { title = "Settings", color = "FFF468", width = "200", height = "200" },
    wow_ver = "3.3.5",
    apep_ver = "1.1",
    load = exeOnLoad,
    unload = exeOnUnload,
})
