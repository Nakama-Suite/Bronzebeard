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
_A.require(apepDir .. "\\nakama\\modules\\colors.lua")

local pallySpell = nakama.SpellBook.Paladin
local genericSpell = nakama.SpellBook.Generic
local pause = nakama.Pause
local loot = nakama.Loot
local colors = nakama.Colors

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
    -- heal section
    {
        type = "section",
        size = 12,
        text = "Heal |r",
        align = "center",
        contentHeight = 30,
        expanded = false,
        height = 20,
    },
    -- spacer (2)
    {
        type = "spacer",
        size = 2,
    },
    -- checkbox | use Holy Light
    {
        type = "checkbox",
        size = 12,
        y = -1,
        text = "use " .. colors.LightPink .. "Holy Light (inCombat)",
        key = "_use_heal_holyLight",
        default = true
    },
    -- text | Holy Light % threshold
    {
        type = "text",
        text = colors.Red .. "HP " .. colors.White .. "% threshold |r",
        size = 12,
        x = 15,
    },
    -- spinner | Holy Light % threshold
    {
        type = "spinner",
        key = "_use_heal_holyLight",
        height = 10,
        y = 12,
        spin = 35,
        step = 1,
        shiftStep = 5,
        min = 20,
        max = 70
    },
    -- spacer (2)
    {
        type = "spacer",
        size = 2,
    },
    -- potion section
    {
        type = "section",
        size = 12,
        text = colors.White .. "Potions|r",
        align = "center",
        contentHeight = 30,
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
        text = "use " .. colors.Red .. "HP " .. colors.White .. "potions |r",
        key = "_use_potions_health",
        default = true
    },
    -- text | HP potion % threshold
    {
        type = "text",
        text = colors.Red .. "HP " .. colors.White .. "% threshold |r",
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
        shiftStep = 5,
        min = 10,
        max = 50
    },
    -- QOL section
    {
        type = "section",
        size = 12,
        text = colors.PeachPuff .. "QOL|r",
        align = "center",
        contentHeight = 20,
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
        text = colors.PeachPuff .. "nakama loothelper|r",
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

local function holyLight()
    if not player:Ui("_use_heal_holyLight") then return false end
    if player:SpellReady(pallySpell.HolyLight)
        and player:Health() < player:Ui("_use_heal_holyLight_spin")
        and not player:Moving() then
        return player:Cast(pallySpell.HolyLight)
    end
end

local function mainRotation()
    if target:Range(1) < 5 and _A.UnitIsFacing(player.guid, target.guid, 130) then
        if player:SpellReady(pallySpell.CrusaderStrike) then
            return target:Cast(pallySpell.CrusaderStrike)
        end
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

    if not target then
        return true
    end

    if target:Dead() or target:Friend() then
        return true
    end

    if holyLight() then
        return true
    end

    if sealOfRighteousness() then
        return true
    end

    if mainRotation() then
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

    if loot.Auto() then
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
    gui_st = { title = "Settings", color = "F48CBA", width = "200", height = "200" },
    wow_ver = "3.3.5",
    apep_ver = "1.1",
    load = exeOnLoad,
    unload = exeOnUnload,
})
