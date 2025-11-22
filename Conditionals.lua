--[[
	Author: Dennis Werner Garske (DWG)
	License: MIT License
]]
local _G = _G or getfenv(0)
local Roids = _G.Roids or {}

-- Validates that the given target is either friend (if [help]) or foe (if [harm])
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy.
-- remarks: Will always return true if help is not given
-- returns: Whether or not the given target can either be attacked or supported, depending on help
function Roids.CheckHelp(target, help)
	if help then
		if help == 1 then
            return UnitCanAssist("player", target);
		else
			return UnitCanAttack("player", target);
		end
	end
	return true;
end

-- Ensures the validity of the given target
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy
-- returns: Whether or not the target is a viable target
function Roids.IsValidTarget(target, help)    
	if target ~= "mouseover" then
		if not Roids.CheckHelp(target, help) or not UnitExists(target) then
			return false;
		end
		return true;
	end
	
	if (not Roids.mouseoverUnit) and not UnitName("mouseover") then
		return false;
	end
    
	return Roids.CheckHelp(target, help);
end

function Roids.Visible(target)
    if target ~= "mouseover" then
		if not UnitIsVisible(target) or not UnitExists(target) or not CheckInteractDistance(target, 4) then
			return false;
		end
		return true;
	end
	
	if (not Roids.mouseoverUnit) and not UnitName("mouseover") then
		return false;
	end
end

-- Returns the current shapeshift / stance index
-- returns: The index of the current shapeshift form / stance. 0 if in no shapeshift form / stance
function Roids.GetCurrentShapeshiftIndex()
    for i=1, GetNumShapeshiftForms() do
        _, _, active = GetShapeshiftFormInfo(i);
        if active then
            return i; 
        end
    end
    
    return 0;
end

Roids.SpellMap = {
    HoF = "Hand of Freedom",
    BoF = "Blessing of Freedom",
    BoM = "Blessing of Might",
    BoW = "Blessing of Wisdom",
    SoL = "Seal of Light",
    JoL = "Judgement of Light",
    SoW = "Seal of Wisdom",
    JoW = "Judgement of Wisdom",
    SoJ = "Seal of Justice",
    JoJ = "Judgement of Justice",
    SoR = "Seal of Righteousness",
    CruS = "Crusader Strike",
    HolyS = "Holy Strike",
    Judge = "Judgement",

    SerpS = "Serpent Sting",
    HM = "Hunter's Mark",
    ConcShot = "Concussive Shot",
    Multi = "Multi-Shot",
    TS = "Trueshot",

    BS = "Battle Shout",
    SA = "Sunder Armor"
}

function MapSpellName(key) 
    local buff = Roids.SpellMap[key];
    if buff ~= nil and buff ~= '' then
        return buff;
    else
        return key
    end
end

-- Checks whether or not the given buffName is present on the given unit's buff bar
-- buffName: The name of the buff
-- unit: The UnitID of the unit to check
-- returns: True if the buffName can be found, false otherwhise
function Roids.HasBuffName(buffName, unit)
    if not buffName or not unit then
        return false;
    end

    buffName = MapSpellName(buffName);    
    local text = getglobal(RoidsTooltip:GetName().."TextLeft1");
	for i=1, 32 do
		RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		RoidsTooltip:SetUnitBuff(unit, i);
		name = text:GetText();
		RoidsTooltip:Hide();
        buffName = string.gsub(buffName, "_", " ");
		if ( name and string.find(name, buffName) ) then
			return true;
		end
    end
    
    return false;
end

-- Checks whether or not the given buffName is present on the given unit's debuff bar
-- buffName: The name of the debuff
-- unit: The UnitID of the unit to check
-- returns: True if the buffName can be found, false otherwhise
function Roids.HasDeBuffName(buffName, unit)
    if not buffName or not unit then
        return false;
    end
    
    buffName = MapSpellName(buffName);
    local text = getglobal(RoidsTooltip:GetName().."TextLeft1");
	for i=1, 16 do
		RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		RoidsTooltip:SetUnitDebuff(unit, i);
		name = text:GetText();
		RoidsTooltip:Hide();
        buffName = string.gsub(buffName, "_", " ");
		if ( name and string.find(name, buffName) ) then
			return true;
		end
    end
    
    return false;
end

function Roids.GetDebuffPosition(buffName, unit)
    if not buffName or not unit then
        return false;
    end
    
    buffName = MapSpellName(buffName);
    local text = getglobal(RoidsTooltip:GetName().."TextLeft1");
	for i=1, 64 do
		RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		RoidsTooltip:SetUnitDebuff(unit, i);
		name = text:GetText();
		RoidsTooltip:Hide();
        buffName = string.gsub(buffName, "_", " ");
		if ( name and string.find(name, buffName) ) then
			return i;
		end
    end
    
    return nil;
end

-- name
-- String - The name of the spell or effect of the debuff, or nil if no debuff was found with the specified name or at the specified index. This is the name shown in yellow when you mouse over the icon.
-- rank
-- String - The rank of the spell or effect that caused the debuff. Returns "" if there is no rank.
-- icon
-- String - The identifier of (path and filename to) the indicated debuff, or nil if no debuff
-- count
-- Number - The number of times the debuff has been applied to the target. Returns 0 for any debuff which doesn't stack. ( Changed in 1.11 ).
-- debuffType
-- String - The type of the debuff: Magic, Disease, Poison, Curse, or nothing for those with out a type.
-- duration
-- Number - The full duration of the debuff in seconds; nil if the debuff was not cast by the player.
-- expirationTime
-- Number - Time at which the debuff expires (GetTime() as a reference frame).
-- unitCaster
-- String - unitId reference to the unit that cast the buff/debuff.
-- isStealable
-- Boolean - 1 if it is stealable otherwise nil
-- shouldConsolidate
-- Boolean - 1 if the buff should be placed in a buff consolidation box (usually long-term effects).
-- spellId
-- Number - spell ID of the aura.
function Roids.CheckDebuffStacks(unit, spell, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local position = Roids.GetDebuffPosition(spell, unit);
    if position then
        local texture, count, last = UnitDebuff(unit, position);
        if (count) then
            if bigger == 0 then
                return count < tonumber(amount);
            end
            return count > tonumber(amount);        
        end
    end

    if bigger == 0 then
        return true;
    else
        return false;
    end
end

-- Checks whether or not the given textureName is present in the current player's buff bar
-- textureName: The full name (including path) of the texture
-- returns: True if the texture can be found, false otherwhise
function Roids.HasBuff(textureName)
    for i = 1, 16 do
        if UnitBuff("player", i) == textureName then
            return true;
        end
    end
    
    return false;
end


-- Maps easy to use weapon type names (e.g. Axes, Shields) to their inventory slot name and their localized tooltip name
Roids.WeaponTypeNames = {
    Daggers = { slot = "MainHandSlot", name = Roids.Localized.Dagger },
    Fists =  { slot = "MainHandSlot", name = Roids.Localized.FistWeapon },
    Axes =  { slot = "MainHandSlot", name = Roids.Localized.Axe },
    Swords =  { slot = "MainHandSlot", name = Roids.Localized.Sword },
    Staffs =  { slot = "MainHandSlot", name = Roids.Localized.Staff },
    Maces =  { slot = "MainHandSlot", name = Roids.Localized.Mace },
    Polearms =  { slot = "MainHandSlot", name = Roids.Localized.Polearm },
    Dagger = { slot = "SecondaryHandSlot", name = Roids.Localized.Dagger },
    Fist =  { slot = "SecondaryHandSlot", name = Roids.Localized.FistWeapon },
    Axe =  { slot = "SecondaryHandSlot", name = Roids.Localized.Axe },
    Sword =  { slot = "SecondaryHandSlot", name = Roids.Localized.Sword },
    Mace =  { slot = "SecondaryHandSlot", name = Roids.Localized.Mace },
    Shields = { slot = "SecondaryHandSlot", name = Roids.Localized.Shield },
    Guns = { slot = "RangedSlot", name = Roids.Localized.Gun },
    Crossbows = { slot = "RangedSlot", name = Roids.Localized.Crossbow },
    Bows = { slot = "RangedSlot", name = Roids.Localized.Bow },
    Thrown = { slot = "RangedSlot", name = Roids.Localized.Thrown },
    Wands = { slot = "RangedSlot", name = Roids.Localized.Wand },
};

-- Checks whether or not the given weaponType is currently equipped
-- weaponType: The name of the weapon's type (e.g. Axe, Shield, etc.)
-- returns: True when equipped, otherwhise false
function Roids.HasWeaponEquipped(weaponType)
    if not Roids.WeaponTypeNames[weaponType] then
        return false;
    end
    
	RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    
    local slotName = Roids.WeaponTypeNames[weaponType].slot;
    local localizedName = Roids.WeaponTypeNames[weaponType].name;

    local slotId = GetInventorySlotInfo(slotName);
    hasItem = RoidsTooltip:SetInventoryItem("player", slotId);
    if not hasItem then
        return false;
    end
    
	local lines = RoidsTooltip:NumLines();
	for i = 1, lines do
		local label = getglobal("RoidsTooltipTextLeft"..i);
		if label:GetText() then
			if label:GetText() == localizedName then
                return true;
            end
		end
        
		label = getglobal("RoidsTooltipTextRight"..i);
		if label:GetText() then
			if label:GetText() == localizedName then
                return true;
            end
		end
    end
    
    return false;
end

-- Checks whether or not the given UnitId is in your party or your raid
-- target: The UnitId of the target to check
-- groupType: The name of the group type your target has to be in ("party" or "raid")
-- returns: True when the given target is in the given groupType, otherwhise false
function Roids.IsTargetInGroupType(target, groupType)
    local upperBound = 5;
    if groupType == "raid" then
        upperBound = 40;
    end
    
    for i = 1, upperBound do
        if UnitName(groupType..i) == UnitName(target) then
            return true;
        end
    end
    
    return false;
end

-- Checks whether or not we're currently casting a channeled spell
function Roids.CheckChanneled(conditionals)
    -- Remove the "(Rank X)" part from the spells name in order to allow downranking
    local spellName = string.gsub(Roids.CurrentSpell.spellName, "%(.-%)%s*", "");
    local channeled = string.gsub(conditionals.checkchanneled, "%(.-%)%s*", "");
    
    if Roids.CurrentSpell.type == "channeled" and spellName == channeled then
        return false;
    end
    
    if channeled == Roids.Localized.Attack then
        return not Roids.CurrentSpell.autoAttack;
    end
    
    if channeled == Roids.Localized.AutoShot then
        return not Roids.CurrentSpell.autoShot;
    end
    
    if channeled == Roids.Localized.Shoot then
        return not Roids.CurrentSpell.wand;
    end
    
    Roids.CurrentSpell.spellName = channeled;
    return true;
end

-- Checks whether or not the given unit has more or less power in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidatePower(unit, bigger, amount)
    local powerPercent = 100 / UnitManaMax(unit) * UnitMana(unit);
    if bigger == 0 then
        return powerPercent < tonumber(amount);
    end
    
    return powerPercent > tonumber(amount);
end

-- Checks whether or not the given unit has more or less total power than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the raw power needs to be bigger, 0 if it needs to be less
-- amount: The required amount
-- returns: True or false
function Roids.ValidateRawPower(unit, bigger, amount)
    local power = UnitMana(unit);
    if bigger == 0 then
        return power < tonumber(amount);
    end
    
    return power > tonumber(amount);
end

-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateHp(unit, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local powerPercent = 100 / UnitHealthMax(unit) * UnitHealth(unit);
    if bigger == 0 then
        return powerPercent < tonumber(amount);
    end
    return powerPercent > tonumber(amount);
end

-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateCurrentHp(unit, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local health = UnitHealth(unit);
    if bigger == 0 then
        return health < tonumber(amount);
    end
    return health > tonumber(amount);
end


-- Don't think this actually works yet, not sure you can get pet resources through
-- the API
function Roids.ValidatePetPower(bigger, amount)
    if not UnitIsVisible('pet') or not UnitExists('pet') then
        return false;
    end

    local power = UnitMana('pet');
    if bigger == 0 then
        return power < tonumber(amount);
    end
    return power > tonumber(amount);
end

-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateMissingHp(unit, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local health = UnitHealth(unit);
    local total = UnitHealthMax(unit);
    local missing = total - health;
    if bigger == 0 then
        return missing < tonumber(amount);
    end
    return missing > tonumber(amount);
end


-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateTotalHp(unit, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local health = UnitHealthMax(unit);
    if bigger == 0 then
        return health < tonumber(amount);
    end
    
    return health > tonumber(amount);
end

-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateTotalHpRatio(unit, bigger, amount)
    if not UnitIsVisible(unit) or not UnitExists(unit) then
        return false;
    end

    local myhealth = UnitHealthMax('player');
    local health = UnitHealthMax(unit);

    local ourRatio = 100 / myhealth * health;
    if bigger == 0 then
        return ourRatio < tonumber(amount);
    end
    
    return ourRatio > tonumber(amount);
end

-- Checks whether the given creatureType is the same as the target's creature type
-- creatureType: The type to check
-- target: The target's unitID
-- returns: True or false
-- remarks: Allows for both localized and unlocalized type names
function Roids.ValidateCreatureType(creatureType, target)
    local targetType = UnitCreatureType(target);
    local englishType = Roids.Localized.CreatureTypes[targetType];
    return creatureType == targetType or creatureType == englishType;
end

-- Returns the cooldown of the given spellName or nil if no such spell was found
function Roids.GetSpellCooldownByName(spellName)
    local checkFor = function(bookType)
        local i = 1
        while true do
            local name, spellRank = GetSpellName(i, bookType);
            
            if not name then
                break;
            end
            
            if name == spellName then
                local _, duration = GetSpellCooldown(i, bookType);
                return duration;
            end
            
            i = i + 1
        end
        return nil;
    end
    
    
    local cd = checkFor(BOOKTYPE_PET);
    if not cd then cd = checkFor(BOOKTYPE_SPELL); end
    
    return cd;
end

-- Returns the cooldown of the given equipped itemName or nil if no such item was found
function Roids.GetInventoryCooldownByName(itemName)
    RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    for i=0, 19 do
        RoidsTooltip:ClearLines();
        hasItem = RoidsTooltip:SetInventoryItem("player", i);
        
        if hasItem then
            local lines = RoidsTooltip:NumLines();
            
            local label = getglobal("RoidsTooltipTextLeft1");
            
            if label:GetText() == itemName then
                local _, duration, _ = GetInventoryItemCooldown("player", i);
                return duration;
            end
        end
    end
    
    return nil;
end

-- Returns the cooldown of the given itemName in the player's bags or nil if no such item was found
function Roids.GetContainerItemCooldownByName(itemName)
    RoidsTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
    
    for i = 0, 4 do
        for j = 1, GetContainerNumSlots(i) do
            RoidsTooltip:ClearLines();
            RoidsTooltip:SetBagItem(i, j);
            if RoidsTooltipTextLeft1:GetText() == itemName then
                local _, duration, _ = GetContainerItemCooldown(i, j);
                return duration;
            end
        end
    end
    
    return nil;
end

function Roids.inMelee(unit)
    return CheckInteractDistance(unit, 3);
end

function Roids.nearOutOfRange(unit)
    return CheckInteractDistance(unit, 4);
end

function Roids.hasPet()
    return UnitExists("pet") and UnitIsVisible("pet") and not UnitIsDeadOrGhost("pet")
end

-- A list of Conditionals and their functions to validate them
Roids.Keywords = {
    help = function(conditionals)
        return true;
    end,
    
    harm = function(conditionals)
        return true;
    end,

    a = function (conditionals)
        return true;
    end,

    h = function (conditionals)
        return true;
    end,
    
    inmelee = function(conditionals)
        return Roids.inMelee(conditionals.target);
    end,

    inrange = function(conditionals)
        return not Roids.inMelee(conditionals.target);
    end,

    nearrange = function(conditionals)
        return Roids.nearOutOfRange(conditionals.target);
    end,

    stance = function(conditionals)
        local inStance = false;
        for k,v in pairs(Roids.splitString(conditionals.stance, "/")) do
            if Roids.GetCurrentShapeshiftIndex() == tonumber(v) then
                inStance = true;
                break;
            end
        end
        
        if not inStance then
            return false;
        end
        return true;
    end,
    
    mod = function(conditionals)
        local modifiersPressed = true;
        
        for k,v in pairs(Roids.splitString(conditionals.mod, "/")) do
            if v == "alt" and not IsAltKeyDown() then
                modifiersPressed = false;
                break;
            elseif v == "ctrl" and not IsControlKeyDown() then
                modifiersPressed = false;
                break;
            elseif v == "shift" and not IsShiftKeyDown() then
                modifiersPressed = false;
                break;
            end
        end
        
        return modifiersPressed;
    end,
    
    target = function(conditionals)
        return Roids.IsValidTarget(conditionals.target, conditionals.help);
    end,
    
    combat = function(conditionals)
        return UnitAffectingCombat("player");
    end,
    
    nocombat = function(conditionals)
        return not UnitAffectingCombat("player");
    end,
    
    stealth = function(conditionals)
        return Roids.HasBuff("Interface\\Icons\\Ability_Ambush");
    end,
    
    nostealth = function(conditionals)
        return not Roids.HasBuff("Interface\\Icons\\Ability_Ambush");
    end,
    
    equipped = function(conditionals)
        return Roids.HasWeaponEquipped(conditionals.equipped);
    end,
    
    noequipped = function(conditionals)
        return not Roids.HasWeaponEquipped(conditionals.noequipped);
    end,

    worn = function(conditionals)
        return Roids.HasWeaponEquipped(conditionals.worn);
    end,

    noworn = function(conditionals)
        return not Roids.HasWeaponEquipped(conditionals.noworn);
    end,
    
    dead = function(conditionals)
        return UnitIsDeadOrGhost(conditionals.target);
    end,
    
    nodead = function(conditionals)
        return not UnitIsDeadOrGhost(conditionals.target);
    end,
    
    party = function(conditionals)
        return Roids.IsTargetInGroupType(conditionals.target, "party");
    end,
    
    raid = function(conditionals)
        return Roids.IsTargetInGroupType(conditionals.target, "raid");
    end,
    
    group = function(conditionals)
        if conditionals.group == "party" then
            return GetNumPartyMembers() > 0;
        elseif conditionals.group == "raid" then
            return GetNumRaidMembers() > 0;
        end
        return false;
    end,
    
    checkchanneled = function(conditionals)
        return Roids.CheckChanneled(conditionals);
    end,
    
    bf = function(conditionals)
        return Roids.HasBuffName(conditionals.bf, conditionals.target);
    end,
    
    nbf = function(conditionals)
        return not Roids.HasBuffName(conditionals.nbf, conditionals.target);
    end,
    
    dbf = function(conditionals)
        return Roids.HasDeBuffName(conditionals.dbf, conditionals.target);
    end,

    dbfstx = function (conditionals)
        return Roids.CheckDebuffStacks(conditionals.target, conditionals.dbfstx.spell, conditionals.dbfstx.bigger, conditionals.dbfstx.amount)
    end,
    
    ndbf = function(conditionals)
        return not Roids.HasDeBuffName(conditionals.ndbf, conditionals.target);
    end,
    
    mybf = function(conditionals)
        return Roids.HasBuffName(conditionals.mybf, "player");
    end,
    
    mynbf = function(conditionals)
        return not Roids.HasBuffName(conditionals.mynbf, "player");
    end,
    
    mydbf = function(conditionals)
        return Roids.HasDeBufName(conditionals.mydbf, "player");
    end,
    
    myndbf = function(conditionals)
        return not Roids.HasDeBuffName(conditionals.myndbf, "player");
    end,
    
    pw = function(conditionals)
        return Roids.ValidatePower(conditionals.target, conditionals.pw.bigger, conditionals.pw.amount);
    end,
    
    mypw = function(conditionals)
        return Roids.ValidatePower("player", conditionals.mypw.bigger, conditionals.mypw.amount);
    end,
    
    cpw = function(conditionals)
        return Roids.ValidateRawPower(conditionals.target, conditionals.cpw.bigger, conditionals.cpw.amount);
    end,

    ppw = function(conditionals)
        return Roids.ValidatePetPower(conditionals.ppw.bigger, conditionals.ppw.amount);
    end,

    mycpw = function(conditionals)
        return Roids.ValidateRawPower("player", conditionals.mycpw.bigger, conditionals.mycpw.amount);
    end,
    
    hp = function(conditionals)
        return Roids.ValidateHp(conditionals.target, conditionals.hp.bigger, conditionals.hp.amount);
    end,

    hpt = function(conditionals)
        return Roids.ValidateTotalHp(conditionals.target, conditionals.hpt.bigger, conditionals.hpt.amount);
    end,

    hpc = function(conditionals)
        return Roids.ValidateCurrentHp(conditionals.target, conditionals.hpc.bigger, conditionals.hpc.amount);
    end,

    hpm = function(conditionals)
        return Roids.ValidateMissingHp(conditionals.target, conditionals.hpm.bigger, conditionals.hpm.amount);
    end,

    hpr = function(conditionals)
        return Roids.ValidateTotalHpRatio(conditionals.target, conditionals.hpr.bigger, conditionals.hpr.amount);
    end,
    
    myhp = function(conditionals)
        return Roids.ValidateHp("player", conditionals.myhp.bigger, conditionals.myhp.amount);
    end,
    
    t = function(conditionals)
        return Roids.ValidateCreatureType(conditionals.t, conditionals.target);
    end,

    tme = function (conditionals)
        return UnitIsUnit("targettarget", "player")
    end,

    ntme = function (conditionals)
        return not UnitIsUnit("targettarget", "player");
    end,

    ptpet = function (conditionals)
        return UnitIsUnit("pettargettarget", "pet")
    end,

    nptpet = function (conditionals)
        return not UnitIsUnit("pettargettarget", "pet")
    end,

    haspet = function (conditionals)
        return Roids.hasPet();
    end,

    v = function(conditionals)
        return Roids.Visible(conditionals.target)
    end,

    npetbf = function(conditionals)
        return not Roids.HasBuffName(conditionals.npetbf, "pet");
    end,

    petbf = function(conditionals)
        return Roids.HasBuffName(conditionals.petbf, "pet");
    end,
    
    cd = function(conditionals)
        local spell = MapSpellName(conditionals.nocd);
        local name = string.gsub(spell, "_", " ");
        local cd = Roids.GetSpellCooldownByName(name);
        if not cd then cd = Roids.GetInventoryCooldownByName(name); end
        if not cd then cd = Roids.GetContainerItemCooldownByName(name) end
        return cd > 0;
    end,
    
    nocd = function(conditionals)
        local spell = MapSpellName(conditionals.nocd);
        local name = string.gsub(spell, "_", " ");
        local cd = Roids.GetSpellCooldownByName(name);
        if not cd then cd = Roids.GetInventoryCooldownByName(name); end
        if not cd then cd = Roids.GetContainerItemCooldownByName(name) end
        return cd == 0;
    end,
    
    channeled = function(conditionals)
        return Roids.CurrentSpell.spellName ~= "";
    end,
    
    nochanneled = function(conditionals)
        return Roids.CurrentSpell.spellName == "";
    end,
    
    attacks = function(conditionals)
        return UnitIsUnit("targettarget", conditionals.attacks);
    end,
    
    noattacks = function(conditionals)
        return not UnitIsUnit("targettarget", conditionals.noattacks);
    end,
    
    isplayer = function(conditionals)
        return UnitIsPlayer(conditionals.isplayer);
    end,
    
    isnpc = function(conditionals)
        return not UnitIsPlayer(conditionals.isnpc);
    end,
};