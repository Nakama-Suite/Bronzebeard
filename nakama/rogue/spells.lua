--------------------------------------------------------------------------------
-- GentleRogue - Spell Library
-- Author: Gentleman
--------------------------------------------------------------------------------
local nakama, _A, nakama = ...
nakama.SpellBook = nakama.SpellBook or {}
nakama.SpellBook.Rogue = {
    SinisterStrike = _A.GetSpellInfo(1101752),
    SliceAndDice   = _A.GetSpellInfo(1105171),
    Eviscerate     = _A.GetSpellInfo(1102098),
    Evasion        = _A.GetSpellInfo(1105277),
}
