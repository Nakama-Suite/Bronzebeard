-- =====================================================
-- GentlePally - Leveling Rotation for APEP
-- Optimized Retribution Paladin for WotLK 3.3.5
-- =====================================================

local nakamaMedia, _A, nakama = ...
local player, target, roster, enemies

-- =====================================================
-- CONFIGURATION CONSTANTS
-- =====================================================

-- Combat performance constants
local UNDEAD_TYPE = 6
local DEMON_TYPE = 3
local INTERRUPT_CAST_THRESHOLD = 60     -- Interrupt casts at 60%
local INTERRUPT_CHANNEL_THRESHOLD = 15  -- Interrupt channels at 15%
local MIN_CAST_TIME = 0.275             -- Minimum cast time to interrupt
local MIN_CHANNEL_TIME = 0.575          -- Minimum channel time to interrupt
local FACING_ANGLE = 130                -- Required facing angle for melee abilities

-- Cache optimization settings
local CACHE_REFRESH_INTERVAL = 0.08     -- 80ms refresh for optimal performance
local UI_REFRESH_INTERVAL = 1.0         -- UI settings refresh every 1 second
local ENEMY_COUNT_REFRESH = 0.5          -- Enemy count refresh every 500ms

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
    last_enemy_count = 0,
    last_enemy_refresh = 0,
    
    -- Spell cooldown cache
    last_spell_checks = {},
}

-- =====================================================
-- SPELL DEFINITIONS
-- =====================================================

local spells = {
    -- Seals - Primary damage enchantments
    sealOfRighteousness = "Seal of Righteousness",  -- Single target DPS
    sealOfCommand = "Seal of Command",              -- Multi-target proc-based
    
    -- Core combat abilities
    judgmentOfWisdom = "Judgement of Wisdom",       -- Mana regeneration priority
    crusaderStrike = "Crusader Strike",             -- Main builder ability
    divineStorm = "Divine Storm",                   -- AoE finisher
    exorcism = "Exorcism",                          -- Burst damage (with Art of War)
    consecration = "Consecration",                  -- Ground AoE damage
    holyWrath = "Holy Wrath",                       -- Anti-undead/demon AoE
    hammerOfWrath = "Hammer of Wrath",              -- Execute ability (≤20% HP)
    
    -- Defensive cooldowns
    avengingWrath = "Avenging Wrath",               -- DPS boost + wings
    divineProtection = "Divine Protection",          -- Damage reduction
    hammerOfJustice = "Hammer of Justice",          -- Stun/interrupt
    
    -- Passive auras
    devotionAura = "Devotion Aura",                 -- Armor boost for survivability
    retributionAura = "Retribution Aura",           -- Damage reflection
    
    -- Blessing buffs
    blessingOfMight = "Blessing of Might",          -- Attack power boost
    blessingOfKings = "Blessing of Kings",          -- All stats boost (preferred)
    
    -- Healing and utility
    holyLight = "Holy Light",                       -- Main healing spell
    cleanse = "Cleanse",                            -- Disease/poison removal (WotLK)
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
    key = "gentlepally_config",
    title = "GentlePally - Leveling Settings",
    width = 320,
    height = 200,
    profiles = true,
    config = {
        -- General combat settings
        { type = "header", text = "General Settings" },
        { type = "checkbox", text = "Enable AoE Rotation", key = "aoe_enabled", default = true },
        { type = "spinner", text = "AoE Enemy Threshold", key = "aoe_threshold", default = 2, min = 1, max = 10, step = 1 },
        { type = "spinner", text = "Consecration Mana %", key = "consecration_mana", default = 50, min = 0, max = 100, step = 5 },
        { type = "combo", text = "Preferred Aura", key = "aura_type", default = "devotion", list = {
            { key = "devotion", text = "Devotion Aura (Survivability)" },
            { key = "retribution", text = "Retribution Aura (Damage)" },
        } },
        
        { type = "spacer" },
        
        -- Combat spell configuration
        { type = "header", text = "Combat Abilities" },
        { type = "checkbox", text = "Use Exorcism (Art of War only)", key = "use_exorcism", default = true },
        { type = "checkbox", text = "Use Hammer of Justice (Interrupts)", key = "use_interrupt", default = true },
        { type = "text", text = "Note: Judgement of Wisdom used automatically for mana" },
        { type = "combo", text = "Self Blessing Priority", key = "blessing_type", default = "kings", list = {
            { key = "kings", text = "Blessing of Kings (Recommended)" },
            { key = "might", text = "Blessing of Might" },
            { key = "auto", text = "Auto (Kings > Might)" },
        } },
        { type = "combo", text = "Seal Selection", key = "seal_type", default = "righteousness", list = {
            { key = "righteousness", text = "Seal of Righteousness (Single)" },
            { key = "command", text = "Seal of Command (Multi)" },
            { key = "auto", text = "Auto (Righteousness/Command)" },
        } },
        
        { type = "spacer" },
        
        -- Cooldown management
        { type = "header", text = "Cooldown Management" },
        { type = "checkbox", text = "Use Avenging Wrath", key = "use_avenging_wrath", default = true },
        { type = "spinner", text = "Avenging Wrath HP Trigger", key = "aw_hp", default = 60, min = 10, max = 90, step = 5 },
        { type = "checkbox", text = "Use Hammer of Wrath (Execute)", key = "use_hammer_wrath", default = true },
        { type = "checkbox", text = "Use Holy Wrath (Undead/Demons)", key = "use_holy_wrath", default = true },
        
        { type = "spacer" },
        
        -- Healing and survival
        { type = "header", text = "Survival Settings" },
        { type = "spinner", text = "Self-Heal HP Threshold", key = "heal_threshold", default = 40, min = 20, max = 80, step = 5 },
        { type = "spinner", text = "Divine Protection HP Trigger", key = "dp_hp", default = 20, min = 5, max = 50, step = 5 },
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
        aoe_enabled = true,
        aoe_threshold = 2,
        consecration_mana = 50,
        aura_type = "devotion",
        use_exorcism = true,
        use_interrupt = true,
        blessing_type = "auto",
        seal_type = "righteousness",
        heal_threshold = 40,
        dp_hp = 20,
        use_avenging_wrath = true,
        aw_hp = 60,
        use_hammer_wrath = true,
        use_holy_wrath = true
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
-- INTELLIGENT SEAL MANAGEMENT
-- =====================================================

-- Optimized seal lookup table
local sealLookup = {
    righteousness = spells.sealOfRighteousness,
    command = spells.sealOfCommand
}

-- Available seals list for fast iteration
local availableSeals = { spells.sealOfRighteousness, spells.sealOfCommand }

-- Smart seal selection based on combat situation
local function GetOptimalSeal()
    local seal_type = cache.ui_settings.seal_type or "righteousness"
    
    -- Auto mode: intelligent seal selection
    if seal_type == "auto" then
        local enemy_count = cache.last_enemy_count or 0
        
        -- Command for 3+ enemies (proc-based AoE), Righteousness for single/dual
        return enemy_count >= 3 and spells.sealOfCommand or spells.sealOfRighteousness
    end
    
    -- Manual selection with fallback
    return sealLookup[seal_type] or spells.sealOfRighteousness
end

-- Fast seal presence check
local function HasActiveSeal()
    for i = 1, #availableSeals do
        if player:Buff(availableSeals[i]) then
            return true
        end
    end
    return false
end

-- =====================================================
-- AURA MANAGEMENT
-- =====================================================

-- Determine optimal aura based on settings
local function GetOptimalAura()
    local aura_type = cache.ui_settings.aura_type or "devotion"
    return aura_type == "retribution" and spells.retributionAura or spells.devotionAura
end

-- =====================================================
-- INTELLIGENT HEALING SYSTEM
-- =====================================================

-- Context-aware healing with combat state optimization
local function SmartHeal(playerHealth, playerMana, isMoving, inCombat)
    local heal_threshold = cache.ui_settings.heal_threshold or 40
    
    -- Dynamic threshold adjustment based on combat state
    local effective_threshold = inCombat and heal_threshold or (heal_threshold + 20)
    
    -- Performance exit conditions
    if playerHealth >= effective_threshold or isMoving or playerMana < 30 then
        return false
    end
    
    -- Execute heal if conditions met
    if player:SpellReady(spells.holyLight) then
        return player:Cast(spells.holyLight)
    end
    
    return false
end

-- =====================================================
-- SMART JUDGMENT SYSTEM
-- =====================================================

-- Optimized judgment casting with range/LoS validation
local function SmartJudgment(target)
    if not target or not player:SpellReady(spells.judgmentOfWisdom) then
        return false
    end
    
    -- Combined range and line-of-sight check for performance
    if target:SpellRange(spells.judgmentOfWisdom) and target:Los() then
        return target:Cast(spells.judgmentOfWisdom)
    end
    
    return false
end

-- =====================================================
-- ART OF WAR EXORCISM SYSTEM
-- =====================================================

-- Proc-based Exorcism usage (only with Art of War for instant cast)
local function SmartExorcism(target, isMoving)
    -- Early exit conditions batched for performance
    if not cache.ui_settings.use_exorcism or not target or isMoving then
        return false
    end
    
    -- Only cast with Art of War proc (instant cast, no movement penalty)
    if player:SpellReady(spells.exorcism) and target:SpellRange(spells.exorcism) 
        and player:Buff("The Art of War") then
        return target:Cast(spells.exorcism)
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
        aoe_enabled = true,
        aoe_threshold = 2,
        consecration_mana = 50,
        aura_type = "devotion",
        seal_type = "righteousness",
        heal_threshold = 40,
        dp_hp = 20,
        use_exorcism = true,
        use_interrupt = true,
        blessing_type = "auto",
        use_avenging_wrath = true,
        aw_hp = 60,
        use_hammer_wrath = true,
        use_holy_wrath = true
    }
    
    -- Initialize timing cache
    cache.last_enemy_refresh = 0
    cache.last_spell_checks = {}
end

-- Plugin cleanup
local function exeOnUnload() 
    -- Reset cache to free memory
    cache = nil
end

-- =====================================================
-- OPTIMIZED ENEMY COUNTING SYSTEM
-- =====================================================

-- High-performance enemy counting with caching
local function GetEnemyCount()
    local now = _A.GetTime()
    
    -- Use cached count if recent
    if now - cache.last_enemy_refresh < ENEMY_COUNT_REFRESH then
        return cache.last_enemy_count
    end
    
    local count = 0
    if enemies then
        for _, enemy in pairs(enemies) do
            if enemy and not enemy:Dead() then
                count = count + 1
                -- Early exit optimization for AoE threshold
                if count >= 3 then 
                    break 
                end
            end
        end
    end
    
    -- Update cache
    cache.last_enemy_count = count
    cache.last_enemy_refresh = now
    
    return count
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
    -- PRIORITY 1: EMERGENCY SURVIVAL
    -- ===============================
    
    -- Emergency self-healing (only if not feared/charmed/incapacitated)
    if not playerState.isDisabled and SmartHeal(playerState.health, playerState.mana, playerState.isMoving, true) then
        return true
    end

    -- Emergency Divine Protection (panic button)
    local dp_threshold = cache.ui_settings.dp_hp or 20
    if not playerState.isDisabled and player:SpellReady(spells.divineProtection) 
        and playerState.health <= dp_threshold then
        return player:Cast(spells.divineProtection)
    end

    -- ===============================
    -- PRIORITY 2: MAINTENANCE BUFFS
    -- ===============================
    
    -- Aura maintenance (only if not silenced)
    if not playerState.isSilenced and not playerState.isDisabled then
        local aura = GetOptimalAura()
        if aura and player:SpellReady(aura) and not player:Buff(aura) then
            return player:Cast(aura)
        end
    end

    -- Cleanse poisons/diseases (only if not silenced and have mana)
    if not playerState.isSilenced and not playerState.isDisabled 
        and player:DebuffType("Poison || Disease") and player:SpellReady(spells.cleanse) 
        and playerState.mana > 75 and player:LastcastSeen(spells.cleanse) > 5 then
        return player:Cast(spells.cleanse)
    end

    -- Seal maintenance (only if not silenced)
    if not playerState.isSilenced and not playerState.isDisabled then
        local preferredSeal = GetOptimalSeal()
        if preferredSeal and player:SpellReady(preferredSeal) then
            if not HasActiveSeal() or not player:Buff(preferredSeal) then
                return player:Cast(preferredSeal)
            end
        end
    end

    -- ===============================
    -- PRIORITY 3: COOLDOWN MANAGEMENT
    -- ===============================
    
    -- Avenging Wrath burst (immune to silence as it's instant)
    if not playerState.isDisabled and cache.ui_settings.use_avenging_wrath 
        and player:SpellReady(spells.avengingWrath) 
        and playerState.health < (cache.ui_settings.aw_hp or 60) then
        return player:Cast(spells.avengingWrath)
    end

    -- ===============================
    -- PRIORITY 4: INTERRUPT SYSTEM
    -- ===============================
    
    -- Hammer of Justice interrupts (physical ability, works when silenced)
    if not playerState.isStunned and not playerState.isFeared and not playerState.isCharmed
        and cache.ui_settings.use_interrupt and player:SpellReady(spells.hammerOfJustice) and enemies then
        for _, enemy in pairs(enemies) do
            if enemy:IscastingAnySpell() and enemy:SpellRange(spells.hammerOfJustice) then
                local _, total, ischanneled = enemy:CastingDelta()
                local shouldInterrupt = false
                
                -- Optimized interrupt logic
                if not ischanneled then
                    shouldInterrupt = enemy:CastingPercent() >= INTERRUPT_CAST_THRESHOLD and total >= MIN_CAST_TIME
                else
                    shouldInterrupt = enemy:ChannelingPercent() >= INTERRUPT_CHANNEL_THRESHOLD and total >= MIN_CHANNEL_TIME
                end
                
                if shouldInterrupt then
                    return enemy:Cast(spells.hammerOfJustice)
                end
            end
        end
    end

    -- ===============================
    -- PRIORITY 5: DAMAGE ROTATION
    -- ===============================
    
    -- Only proceed with damage rotation if not disabled and have valid target
    if not playerState.isDisabled and target and not (target:Dead() or target:Friend()) then
        local enemy_count = GetEnemyCount()
        
        -- Single Target Rotation (1-2 enemies)
        if enemy_count < 3 then
            -- 1. Judgement of Wisdom (highest priority - mana sustain, works when silenced)
            if not playerState.isSilenced and SmartJudgment(target) then return true end
            
            -- 2. Hammer of Wrath (execute at ≤20% HP, physical ability)
            if cache.ui_settings.use_hammer_wrath and player:SpellReady(spells.hammerOfWrath) 
                and target:SpellRange(spells.hammerOfWrath) and target:Health() <= 20 then
                return target:Cast(spells.hammerOfWrath)
            end
            
            -- 3. Crusader Strike (main builder, physical ability)
            if player:SpellReady(spells.crusaderStrike) and target:SpellRange(spells.crusaderStrike)
                and _A.UnitIsFacing(player.guid, target.guid, FACING_ANGLE) then
                return target:Cast(spells.crusaderStrike)
            end
            
            -- 4. Consecration (mana permitting, spell - affected by silence)
            if not playerState.isSilenced then
                local consecrMana = cache.ui_settings.consecration_mana or 50
                if player:SpellReady(spells.consecration) and not playerState.isMoving 
                    and playerState.mana >= consecrMana and target:SpellRange(spells.consecration) then
                    return player:Cast(spells.consecration)
                end
            end
            
            -- 5. Divine Storm (finisher, physical ability)
            if player:SpellReady(spells.divineStorm) and target:SpellRange(spells.divineStorm)
                and _A.UnitIsFacing(player.guid, target.guid, FACING_ANGLE) then
                return target:Cast(spells.divineStorm)
            end
            
            -- 6. Exorcism (Art of War proc only, spell - affected by silence)
            if not playerState.isSilenced and SmartExorcism(target, playerState.isMoving) then 
                return true 
            end
            
            -- 7. Holy Wrath (vs Demons/Undead, spell - affected by silence)
            if not playerState.isSilenced and cache.ui_settings.use_holy_wrath 
                and player:SpellReady(spells.holyWrath) 
                and target:SpellRange(spells.holyWrath) and target:CreatureType("Demon || Undead") then
                return target:Cast(spells.holyWrath)
            end
        
        -- AoE Rotation (3+ enemies)
        else
            -- 1. Divine Storm (highest AoE priority, physical ability)
            if player:SpellReady(spells.divineStorm) and target:SpellRange(spells.divineStorm)
                and _A.UnitIsFacing(player.guid, target.guid, FACING_ANGLE) then
                return target:Cast(spells.divineStorm)
            end
            
            -- 2. Consecration (main AoE damage, spell - affected by silence)
            if not playerState.isSilenced and player:SpellReady(spells.consecration) 
                and not playerState.isMoving 
                and playerState.mana >= (cache.ui_settings.consecration_mana or 50) 
                and target:SpellRange(spells.consecration) then
                return player:Cast(spells.consecration)
            end
            
            -- 3. Holy Wrath (vs Demons/Undead groups, spell - affected by silence)
            if not playerState.isSilenced and cache.ui_settings.use_holy_wrath 
                and player:SpellReady(spells.holyWrath) 
                and target:SpellRange(spells.holyWrath) and target:CreatureType("Demon || Undead") then
                return target:Cast(spells.holyWrath)
            end
            
            -- 4. Crusader Strike (builder in AoE, physical ability)
            if player:SpellReady(spells.crusaderStrike) and target:SpellRange(spells.crusaderStrike)
                and _A.UnitIsFacing(player.guid, target.guid, FACING_ANGLE) then
                return target:Cast(spells.crusaderStrike)
            end
            
            -- 5. Hammer of Wrath (execute, physical ability)
            if cache.ui_settings.use_hammer_wrath and player:SpellReady(spells.hammerOfWrath) 
                and target:SpellRange(spells.hammerOfWrath) and target:Health() <= 20 then
                return target:Cast(spells.hammerOfWrath)
            end
            
            -- 6. Judgement of Wisdom (lower priority in AoE, works when silenced)
            if not playerState.isSilenced and SmartJudgment(target) then return true end
            
            -- 7. Exorcism (Art of War proc, spell - affected by silence)
            if not playerState.isSilenced and SmartExorcism(target, playerState.isMoving) then 
                return true 
            end
        end
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
    -- PRIORITY 1: AURA MAINTENANCE
    -- ===============================
    
    -- Only maintain aura if not silenced
    if not playerState.isSilenced and not playerState.isDisabled then
        local aura = GetOptimalAura()
        if aura and player:SpellReady(aura) and not player:Buff(aura) then
            return player:Cast(aura)
        end
    end

    -- ===============================
    -- PRIORITY 2: CLEANSE DEBUFFS
    -- ===============================
    
    -- Cleanse diseases/poisons when out of combat (only if not silenced)
    if not playerState.isSilenced and not playerState.isDisabled 
        and player:DebuffType("Poison || Disease") and player:SpellReady(spells.cleanse) 
        and playerState.mana > 75 and player:LastcastSeen(spells.cleanse) > 5 then
        return player:Cast(spells.cleanse)
    end

    -- ===============================
    -- PRIORITY 3: HEALING
    -- ===============================
    
    -- Out-of-combat healing with generous threshold (only if not disabled)
    if not playerState.isDisabled and SmartHeal(playerState.health, playerState.mana, playerState.isMoving, false) then
        return true
    end

    -- ===============================
    -- PRIORITY 4: SEAL MAINTENANCE
    -- ===============================
    
    -- Only maintain seal if not silenced
    if not playerState.isSilenced and not playerState.isDisabled then
        local preferredSeal = GetOptimalSeal()
        if preferredSeal and player:SpellReady(preferredSeal) then
            if not HasActiveSeal() or not player:Buff(preferredSeal) then
                return player:Cast(preferredSeal)
            end
        end
    end

    -- ===============================
    -- PRIORITY 5: BLESSING MAINTENANCE
    -- ===============================
    
    -- Self-blessing logic with intelligent prioritization (only if not silenced)
    if not playerState.isSilenced and not playerState.isDisabled then
        local blessing_pref = cache.ui_settings.blessing_type or "auto"
        local primary, secondary
        
        -- Determine blessing priority
        if blessing_pref == "might" then
            primary, secondary = spells.blessingOfMight, spells.blessingOfKings
        else -- "kings" or "auto" - prioritize Kings for overall stats
            primary, secondary = spells.blessingOfKings, spells.blessingOfMight
        end
        
        -- Apply blessing if missing (self-only to avoid group spam)
        if not (player:BuffAny(spells.blessingOfKings) or player:BuffAny(spells.blessingOfMight)) then
            if primary and player:SpellReady(primary) then
                return player:Cast(primary)
            elseif secondary and player:SpellReady(secondary) then
                return player:Cast(secondary)
            end
        end
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
_A.CR:Add("Paladin", {
    name = "GentlePally - Leveling",
    ic = inCombat,
    ooc = outCombat,
    use_lua_engine = true,
    gui = gui.config,
    gui_st = { 
        title = "GentlePally - Rotation Settings", 
        color = "F48CBA", 
        width = "315", 
        height = "370" 
    },
    wow_ver = "3.3.5",
    apep_ver = "1.1",
    load = exeOnLoad,
    unload = exeOnUnload,
})

-- =====================================================
-- END OF GENTLEPALLY LEVELING ROTATION
-- Performance optimized for WotLK 3.3.5 Retribution
-- =====================================================
