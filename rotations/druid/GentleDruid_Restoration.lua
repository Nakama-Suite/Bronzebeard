-- =====================================================
-- GentleDruid - Restoration Healing for APEP
-- Optimized Restoration Druid for WotLK 3.3.5
-- Based on GentlePally architecture for maximum performance
-- =====================================================

local nakamaMedia, _A, nakama = ...
local player, target, roster, enemies

-- =====================================================
-- CONFIGURATION CONSTANTS
-- =====================================================

-- Healing performance constants
local MIN_CAST_TIME = 0.275             -- Minimum cast time to interrupt
local MIN_CHANNEL_TIME = 0.575          -- Minimum channel time to interrupt
local FACING_ANGLE = 130                -- Required facing angle for abilities
local HEAL_RANGE = 40                   -- Maximum healing range
local DISPEL_PRIORITY_TIME = 3          -- Seconds between dispel attempts

-- Cache optimization settings
local CACHE_REFRESH_INTERVAL = 0.08     -- 80ms refresh for optimal performance
local UI_REFRESH_INTERVAL = 1.0         -- UI settings refresh every 1 second
local TARGET_SCAN_REFRESH = 0.5          -- Target scan refresh every 500ms

-- =====================================================
-- PERFORMANCE CACHE SYSTEM
-- =====================================================

local cache = {
    -- Timing control
    last_refresh = 0,
    refresh_interval = CACHE_REFRESH_INTERVAL,
    
    -- Cached UI settings for performance
    ui_settings = {},
    
    -- Combat state cache
    last_heal_targets = {},
    last_target_scan = 0,
    
    -- Spell cooldown cache
    last_spell_checks = {},
    
    -- Tank detection cache
    last_tank = nil,
    last_tank_check = 0,
    
    -- Damage prediction cache
    damage_predictions = {},
    
    -- Target scan optimization
    target_scan_interval = TARGET_SCAN_REFRESH,
}

-- =====================================================
-- SPELL DEFINITIONS
-- =====================================================

local spells = {
    -- Core HoT spells (Restoration priorities)
    rejuvenation = "Rejuvenation",          -- Most powerful HoT - maintain at all times
    lifebloom = "Lifebloom",                -- Stack on tanks, emergency bloom
    wildGrowth = "Wild Growth",             -- AoE HoT for group damage
    regrowth = "Regrowth",                  -- Direct + HoT hybrid heal
    
    -- Direct healing spells
    healingTouch = "Healing Touch",         -- Main direct heal
    nourish = "Nourish",                    -- Fast heal with HoT bonus
    swiftmend = "Swiftmend",                -- Emergency instant heal
    
    -- Cooldowns and utility
    naturesSwiftness = "Nature's Swiftness", -- Emergency instant cast
    tranquility = "Tranquility",            -- Last resort group heal
    innervate = "Innervate",                -- Mana regeneration
    
    -- Buffs and utility
    markOfTheWild = "Mark of the Wild",     -- Stats buff
    thorns = "Thorns",                      -- Damage reflection
    barkskin = "Barkskin",                  -- Damage reduction
    
    -- Dispels
    removeCurse = "Remove Curse",           -- Curse removal
    abolishPoison = "Abolish Poison",       -- Poison removal (HoT style)
    
    -- Forms (for utility)
    travelForm = "Travel Form",
    bearForm = "Dire Bear Form",
    catForm = "Cat Form",
}

-- =====================================================
-- BUFF/DEBUFF SPELL REFERENCES
-- =====================================================

-- APEP spell info references for buff detection
local drink = _A.GetSpellInfo(430)  -- Drinking buff
local eat = _A.GetSpellInfo(433)    -- Eating buff

-- =====================================================
-- USER INTERFACE CONFIGURATION
-- =====================================================

local gui = {
    key = "gentledruid_config",
    title = "GentleDruid - Restoration Settings",
    width = 320,
    height = 200,
    profiles = true,
    config = {
        -- General healing settings
        { type = "header", text = "Healing Thresholds" },
        { type = "spinner", text = "Combat Heal Threshold %", key = "heal_combat", default = 70, min = 40, max = 95, step = 5 },
        { type = "spinner", text = "Out of Combat Heal %", key = "heal_ooc", default = 85, min = 60, max = 95, step = 5 },
        { type = "spinner", text = "Emergency Threshold %", key = "emergency", default = 30, min = 15, max = 50, step = 5 },
        { type = "spinner", text = "Rejuvenation Threshold %", key = "rejuv", default = 80, min = 70, max = 95, step = 5 },
        
        { type = "spacer" },
        
        -- Group healing configuration
        { type = "header", text = "Group Healing" },
        { type = "spinner", text = "Group Heal Threshold", key = "group_threshold", default = 3, min = 2, max = 5, step = 1 },
        { type = "checkbox", text = "Prioritize Tanks", key = "tank_priority", default = true },
        { type = "checkbox", text = "Auto Wild Growth", key = "auto_wild_growth", default = true },
        { type = "checkbox", text = "Maintain Lifebloom on Tanks", key = "lifebloom_tanks", default = true },
        
        { type = "spacer" },
        
        -- Emergency and utility
        { type = "header", text = "Emergency & Utility" },
        { type = "checkbox", text = "Use Nature's Swiftness", key = "use_ns", default = true },
        { type = "checkbox", text = "Use Swiftmend", key = "use_swiftmend", default = true },
        { type = "checkbox", text = "Auto Dispel", key = "auto_dispel", default = true },
        { type = "checkbox", text = "Use Tranquility", key = "use_tranquility", default = true },
        
        { type = "spacer" },
        
        -- Mana management
        { type = "header", text = "Mana Management" },
        { type = "spinner", text = "Innervate Mana %", key = "innervate_mana", default = 30, min = 15, max = 60, step = 5 },
        { type = "spinner", text = "Low Mana Threshold %", key = "low_mana", default = 25, min = 10, max = 50, step = 5 },
    }
}

-- =====================================================
-- PERFORMANCE OPTIMIZED CACHE FUNCTIONS
-- =====================================================

-- Efficiently refresh UI settings with batched pcall operations
local function RefreshUISettings()
    local pl = _A.Object("player")
    if not pl or type(pl.ui) ~= "function" then
        return false
    end
    
    local settings = cache.ui_settings
    
    -- Optimized batch UI reading with single function
    local function batchGet(keys_defaults)
        for key, default in pairs(keys_defaults) do
            local ok, val = pcall(pl.ui, pl, key)
            settings[key] = (ok and val ~= nil) and val or default
        end
    end
    
    -- Batch all settings at once for performance
    batchGet({
        heal_combat = 70,
        heal_ooc = 85,
        emergency = 30,
        rejuv = 80,
        group_threshold = 3,
        tank_priority = true,
        auto_wild_growth = true,
        lifebloom_tanks = true,
        use_ns = true,
        use_swiftmend = true,
        auto_dispel = true,
        use_tranquility = true,
        innervate_mana = 30,
        low_mana = 25
    })
    
    return true
end

-- Master cache refresh with intelligent timing
local function RefreshCache()
    local now = _A.GetTime()
    
    -- Skip refresh if within interval
    if now - cache.last_refresh < cache.refresh_interval then
        return
    end
    
    cache.last_refresh = now
    
    -- Refresh UI settings every second to reduce overhead
    if now % UI_REFRESH_INTERVAL < 0.1 then
        RefreshUISettings()
    end
end

-- =====================================================
-- TANK IDENTIFICATION SYSTEM
-- =====================================================

-- Optimized tank identification with caching (like GentlePally)
local function GetTank()
    local now = _A.GetTime()
    
    -- Use cached tank if recent
    if cache.last_tank and (now - cache.last_tank_check) < 2.0 then
        return cache.last_tank
    end
    
    cache.last_tank_check = now
    local roster = _A.OM:Get("Roster")
    if not roster then 
        cache.last_tank = nil
        return nil 
    end
    
    -- Find tank with optimized checks
    for _, member in pairs(roster) do
        if member and not member:Dead() then
            local class = member:Class()
            -- Priority to tank classes with threat (using APEP-compatible method)
            if (class == "WARRIOR" or class == "PALADIN" or class == "DEATH_KNIGHT") 
                and (member:Threat() or 0) > 50 then -- Use Threat() instead of ThreatSituation()
                cache.last_tank = member
                return member
            end
        end
    end
    
    -- Fallback: any tank class
    for _, member in pairs(roster) do
        if member and not member:Dead() then
            local class = member:Class()
            if class == "WARRIOR" or class == "PALADIN" or class == "DEATH_KNIGHT" then
                cache.last_tank = member
                return member
            end
        end
    end
    
    cache.last_tank = nil
    return nil
end

-- =====================================================
-- HEAL TARGET SCANNING SYSTEM
-- =====================================================

-- Optimized heal targets with caching and batch processing (like GentlePally)
local function GetHealTargets()
    local now = _A.GetTime()
    
    -- Use cached targets if recent
    if cache.last_heal_targets and (now - cache.last_target_scan) < TARGET_SCAN_REFRESH then
        return cache.last_heal_targets
    end
    
    cache.last_target_scan = now
    local healTargets = {}
    local roster = _A.OM:Get("Roster")
    
    if not roster then 
        -- Solo mode optimization
        local player = _A.Object("player")
        if player then
            healTargets = {{target = player, hp = (player:Health() or 100), priority = 1}}
        end
        cache.last_heal_targets = healTargets
        return healTargets
    end
    
    local tank = GetTank()
    
    -- Batch process all members with optimized priority system
    for _, member in pairs(roster) do
        if member and not member:Dead() and member:SpellRange(spells.healingTouch) and member:Los() then
            local hp = member:Health() or 100
            local priority = 3 -- Default
            
            -- Optimized priority assignment
            if member == tank then
                priority = 1 -- Tank = highest priority
            elseif member:Class() == "PRIEST" or member:Class() == "SHAMAN" 
                or member:Class() == "PALADIN" or member:Class() == "DRUID" then
                priority = 2 -- Healers
            end
            
            table.insert(healTargets, {target = member, hp = hp, priority = priority})
        end
    end
    
    -- Optimized sorting: priority first, then HP
    table.sort(healTargets, function(a, b)
        if a.priority == b.priority then
            return a.hp < b.hp -- Lower HP = higher priority
        end
        return a.priority < b.priority -- Lower number = higher priority
    end)
    
    cache.last_heal_targets = healTargets
    return healTargets
end

-- =====================================================
-- HOT MANAGEMENT SYSTEM
-- =====================================================

-- Optimized Rejuvenation + Lifebloom management (Restoration priority system)
local function MaintainHoTs()
    local player = _A.Object("player")
    if not player then return false end
    
    local healTargets = GetHealTargets() -- Uses cached data
    
    for _, data in pairs(healTargets) do
        local target = data.target
        
        -- PRIORITY 1: Rejuvenation (most powerful HoT - maintain at all times)
        if data.hp < (cache.ui_settings.rejuv or 80) then
            if not target:BuffUp(spells.rejuvenation) and player:SpellReady(spells.rejuvenation) and target:Los() then
                return target:Cast(spells.rejuvenation)
            end
        end
        
        -- PRIORITY 2: Lifebloom on tanks (3 stacks, maintain constantly)
        if data.priority == 1 and data.hp < 95 and cache.ui_settings.lifebloom_tanks then -- Tank priority
            local lifestacks = target:BuffStack(spells.lifebloom) or 0
            if lifestacks < 3 and player:SpellReady(spells.lifebloom) and target:Los() then
                return target:Cast(spells.lifebloom)
            end
        end
        
        -- PRIORITY 3: Regrowth after Rejuvenation (hybrid healing)
        if data.hp < (cache.ui_settings.rejuv or 80) and target:BuffUp(spells.rejuvenation) then
            if not target:BuffUp(spells.regrowth) and player:SpellReady(spells.regrowth) and target:Los() then
                return target:Cast(spells.regrowth)
            end
        end
    end
    
    return false
end

-- =====================================================
-- EMERGENCY HEALING SYSTEM
-- =====================================================

-- Emergency healing system
local function EmergencyHealing(healTargets)
    local player = _A.Object("player")
    if not player then return false end
    
    for _, data in pairs(healTargets) do
        local target = data.target
        
        -- EMERGENCY 1: Nature's Swiftness + Healing Touch (panic button)
        if data.hp < (cache.ui_settings.emergency or 30) and cache.ui_settings.use_ns then
            if player:SpellReady(spells.naturesSwiftness) and player:SpellReady(spells.healingTouch) and target:Los() then
                if player:Cast(spells.naturesSwiftness) then
                    return target:Cast(spells.healingTouch)
                end
            end
        end
        
        -- EMERGENCY 2: Swiftmend (with Glyph of Swiftmend - mandatory)
        if data.hp < (cache.ui_settings.emergency or 30) and cache.ui_settings.use_swiftmend then
            if player:SpellReady(spells.swiftmend) and (target:BuffUp(spells.rejuvenation) or target:BuffUp(spells.regrowth)) and target:Los() then
                return target:Cast(spells.swiftmend)
            end
        end
    end
    
    return false
end

-- =====================================================
-- FILLER HEALING SYSTEM
-- =====================================================

-- Filler spells system
local function CastFillerSpells(healTargets, inCombat)
    local player = _A.Object("player")
    if not player then return false end
    
    local threshold = inCombat and (cache.ui_settings.heal_combat or 70) or (cache.ui_settings.heal_ooc or 85)
    
    for _, data in pairs(healTargets) do
        local target = data.target
        
        if data.hp < threshold then
            -- FILLER 1: Nourish (20% bonus if HoTs active)
            if target:BuffUp(spells.rejuvenation) or target:BuffUp(spells.regrowth) then
                if player:SpellReady(spells.nourish) and target:Los() then
                    return target:Cast(spells.nourish)
                end
            end
            
            -- FILLER 2: Healing Touch (main direct heal)
            if player:SpellReady(spells.healingTouch) and target:Los() then
                return target:Cast(spells.healingTouch)
            end
        end
    end
    
    return false
end

-- =====================================================
-- GROUP HEALING SYSTEM
-- =====================================================

-- Optimized group healing (Restoration AoE priorities)
local function SmartGroupHeal(healTargets, inCombat)
    local player = _A.Object("player")
    if not player then return false end
    
    local threshold = inCombat and (cache.ui_settings.heal_combat or 70) or (cache.ui_settings.heal_ooc or 85)
    local emergencyCount = 0
    local lowHealthCount = 0
    
    -- Count emergencies and low health (optimized)
    for _, data in pairs(healTargets) do
        if data.hp < (cache.ui_settings.emergency or 30) then
            emergencyCount = emergencyCount + 1
        elseif data.hp < threshold then
            lowHealthCount = lowHealthCount + 1
        end
        
        -- Early exit optimization
        if emergencyCount > 0 and lowHealthCount >= (cache.ui_settings.group_threshold or 3) then
            break
        end
    end
    
    -- PRIORITY 1: Emergency healing first
    if emergencyCount > 0 then
        if EmergencyHealing(healTargets) then
            return true
        end
    end
    
    -- PRIORITY 2: Wild Growth (cast whenever available)
    if lowHealthCount >= 2 and cache.ui_settings.auto_wild_growth and player:SpellReady(spells.wildGrowth) then
        return player:Cast(spells.wildGrowth)
    end
    
    -- PRIORITY 3: Group HoT maintenance
    if MaintainHoTs() then
        return true
    end
    
    -- PRIORITY 4: Tranquility (last resort group heal)
    if lowHealthCount >= (cache.ui_settings.group_threshold or 3) and cache.ui_settings.use_tranquility then
        if player:SpellReady(spells.tranquility) then
            return player:Cast(spells.tranquility)
        end
    end
    
    -- PRIORITY 5: Filler spells
    if CastFillerSpells(healTargets, inCombat) then
        return true
    end
    
    return false
end

-- =====================================================
-- PLAYER STATE MONITORING SYSTEM
-- =====================================================

-- Comprehensive player state checking with performance optimization
local function GetPlayerState()
    local states = {
        isCasting = player:IscastingAnySpell(),
        isMoving = player:Moving(),
        isStunned = player:State("stun"),
        isSilenced = player:State("silence"),
        isFeared = player:State("fear"),
        isCharmed = player:State("charm"),
        isIncapacitated = player:State("incapacitate"),
        isImmune = player:State("immune"),
        isMounted = player:Mounted(),
        isDead = player:Dead(),
        
        -- Buff states
        isDrinking = player:BuffAny(drink),
        isEating = player:BuffAny(eat),
        
        -- Health and mana
        health = player:Health(),
        mana = player:Mana(),
    }
    
    -- Combined disable states for quick checking
    states.isDisabled = states.isStunned or states.isSilenced or states.isFeared 
                       or states.isCharmed or states.isIncapacitated or states.isDead
    
    -- States that prevent most actions
    states.cantAct = states.isCasting or states.isDisabled or states.isMounted
    
    -- States that prevent movement-based abilities
    states.cantMove = states.isMoving or states.isDisabled
    
    return states
end

-- Enhanced early exit function with comprehensive state checking
local function ShouldEarlyExit(playerState)
    -- Priority 1: Absolutely cannot act
    if playerState.cantAct then
        return true
    end
    
    -- Priority 2: Drinking/eating (out of combat restoration)
    if playerState.isDrinking or playerState.isEating then
        return true
    end
    
    -- Priority 3: Immune state (abilities won't work)
    if playerState.isImmune then
        return true
    end
    
    return false
end

-- =====================================================
-- INITIALIZATION AND CLEANUP
-- =====================================================

-- Plugin initialization - optimize UI and set default cache
local function exeOnLoad()
    -- Disable UI error spam for cleaner experience
    _A.UIErrorsFrame:Hide()
    _A.Sound_EnableErrorSpeech = 0
    
    -- Initialize performance cache with optimal defaults
    cache.ui_settings = {
        heal_combat = 70,
        heal_ooc = 85,
        emergency = 30,
        rejuv = 80,
        group_threshold = 3,
        tank_priority = true,
        auto_wild_growth = true,
        lifebloom_tanks = true,
        use_ns = true,
        use_swiftmend = true,
        auto_dispel = true,
        use_tranquility = true,
        innervate_mana = 30,
        low_mana = 25
    }
    
    -- Initialize timing cache
    cache.last_target_scan = 0
    cache.last_spell_checks = {}
    
    print("🌿 GentleDruid - Optimized Restoration Healer loaded!")
end

-- Plugin cleanup
local function exeOnUnload() 
    -- Reset cache to free memory
    cache = nil
    print("🌿 GentleDruid unloaded!")
end

-- =====================================================
-- MAIN COMBAT ROTATION - IN COMBAT
-- =====================================================

local function inCombat()
    -- Performance: refresh cache and get objects
    RefreshCache()
    player = _A.Object("player")
    target = _A.Object("target")
    enemies = _A.OM:Get("EnemyCombat")
    
    if not player then return true end

    -- Get comprehensive player state
    local playerState = GetPlayerState()
    
    -- Enhanced early exit with comprehensive state checking
    if ShouldEarlyExit(playerState) then
        return true
    end

    -- ===============================
    -- PRIORITY 1: EMERGENCY HEALING
    -- ===============================
    
    local healTargets = GetHealTargets() -- Uses cached data
    if SmartGroupHeal(healTargets, true) then
        return true
    end
    
    -- ===============================
    -- PRIORITY 2: DISPEL SYSTEM
    -- ===============================
    
    -- Dispel (optimized like GentlePally utility spells)
    if cache.ui_settings.auto_dispel then
        local roster = _A.OM:Get("Roster")
        if roster then
            for _, member in pairs(roster) do
                if member and not member:Dead() and member:SpellRange(spells.removeCurse) and member:Los() then
                    if member:DebuffType("Curse || Poison") then
                        if player:SpellReady(spells.removeCurse) and player:LastcastSeen(spells.removeCurse) > DISPEL_PRIORITY_TIME then
                            return member:Cast(spells.removeCurse)
                        end
                        if player:SpellReady(spells.abolishPoison) and player:LastcastSeen(spells.abolishPoison) > DISPEL_PRIORITY_TIME then
                            return member:Cast(spells.abolishPoison)
                        end
                    end
                end
            end
        end
    end

    -- ===============================
    -- PRIORITY 3: HOT MAINTENANCE
    -- ===============================
    
    if MaintainHoTs() then
        return true
    end
    
    -- ===============================
    -- PRIORITY 4: MANA MANAGEMENT
    -- ===============================
    
    -- Innervate if low mana
    if playerState.mana < (cache.ui_settings.innervate_mana or 30) and player:SpellReady(spells.innervate) then
        return player:Cast(spells.innervate)
    end
    
    return false
end

-- =====================================================
-- OUT OF COMBAT ROUTINE - MAINTENANCE MODE
-- =====================================================

local function outCombat()
    -- Performance cache refresh
    RefreshCache()
    player = _A.Object("player")

    if not player then return true end

    -- Get comprehensive player state
    local playerState = GetPlayerState()

    -- Enhanced early exit with comprehensive state checking
    if ShouldEarlyExit(playerState) then
        return true
    end

    -- ===============================
    -- PRIORITY 1: BUFF MAINTENANCE
    -- ===============================
    
    -- Only maintain buffs if not silenced
    if not playerState.isSilenced and not playerState.isDisabled then
        if player:SpellReady(spells.markOfTheWild) and not player:BuffUp(spells.markOfTheWild) then
            return player:Cast(spells.markOfTheWild)
        end
        
        if player:SpellReady(spells.thorns) and not player:BuffUp(spells.thorns) then
            return player:Cast(spells.thorns)
        end
    end

    -- ===============================
    -- PRIORITY 2: GROUP HEALING
    -- ===============================
    
    local healTargets = GetHealTargets()
    if SmartGroupHeal(healTargets, false) then
        return true
    end
    
    -- ===============================
    -- PRIORITY 3: HOT MAINTENANCE
    -- ===============================
    
    if MaintainHoTs() then
        return true
    end
    
    return false
end

-- =====================================================
-- PLUGIN REGISTRATION
-- =====================================================

-- Spell ID localization table (if needed)
local spellIds_Loc = {}

-- Blacklist table for spell restrictions (if needed)
local blacklist = {}

-- Register the combat routine with APEP
_A.CR:Add("Druid", {
    name = "GentleDruid - Restoration",
    ic = inCombat,
    ooc = outCombat,
    use_lua_engine = true,
    gui = gui.config,
    gui_st = { 
        title = "GentleDruid - Restoration Settings", 
        color = "40E0D0", 
        width = "320", 
        height = "400" 
    },
    wow_ver = "3.3.5",
    apep_ver = "1.1",
    load = exeOnLoad,
    unload = exeOnUnload,
})

-- =====================================================
-- END OF GENTLEDRUID RESTORATION ROTATION
-- Performance optimized for WotLK 3.3.5 Restoration Druid
-- =====================================================