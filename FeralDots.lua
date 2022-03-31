--
-- API
--   FeralDots_RakeHasTF(unit)
--   FeralDots_RakeHasStealth(unit)
--   FeralDots_RipHasTF(unit)
--   FeralDots_RipHasBT(unit)
--   FeralDots_ThrashHasTF(unit)
--   FeralDots_ThrashHasMOC(unit)
--     These functions return true if the related dot on the given target has this empowerment
--
-- WeakAura events
--   FERAL_DOTS_RAKE
--   FERAL_DOTS_RIP
--   FERAL_DOTS_THRASH
--     These events are triggered whenever the related dot is applied/removed
--

FeralDots = {}

if select(2, UnitClass('player')) ~= 'DRUID' then
	return
end

--
-- aura tracking
--

local FeralDots_PlayerGUID = UnitGUID('player')

local FeralDots_TigersFuryStart = 0.0
local FeralDots_TigersFuryEnd = 0.0

local FeralDots_BloodTalonsStart = 0.0
local FeralDots_BloodTalonsEnd = 0.0

local FeralDots_StealthStart = 0.0
local FeralDots_StealthEnd = 0.0

local FeralDots_ShadowMeldStart = 0.0
local FeralDots_ShadowMeldEnd = 0.0

local FeralDots_BerserkStart = 0.0
local FeralDots_BerserkEnd = 0.0

local FeralDots_ClearcastStart = 0.0
local FeralDots_ClearcastEnd = 0.0

local FeralDots_RakeFlags = {}
local FeralDots_RipFlags = {}
local FeralDots_ThrashFlags = {}

local FeralDots_UsingMOC = false

local FERAL_DOTS_TIGERS_FURY = 5217
local FERAL_DOTS_BLOOD_TALONS = 145152
local FERAL_DOTS_RAKE = 1822
local FERAL_DOTS_RAKE_DOT = 155722
local FERAL_DOTS_RAKE_STUN = 163505
local FERAL_DOTS_RIP = 1079
local FERAL_DOTS_THRASH = 106830
local FERAL_DOTS_CLEARCAST = 135700
local FERAL_DOTS_STEALTH = 5215
local FERAL_DOTS_SHADOW_MELD = 58984
local FERAL_DOTS_BERSERK = 106951

local FERAL_DOTS_MOC_TALENT = 21646

local FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD = 0.15

local FERAL_DOTS_TIGERS_FURY_BIT = 1
local FERAL_DOTS_BLOOD_TALONS_BIT = 2
local FERAL_DOTS_STEALTH_BIT = 4
local FERAL_DOTS_CLEARCAST_BIT = 8

local function FeralDots_GetCurrentFlags(ts)
	local f0 = (FeralDots_TigersFuryEnd  < FeralDots_TigersFuryStart  or ts <= FeralDots_TigersFuryEnd ) and FERAL_DOTS_TIGERS_FURY_BIT or 0
	local f1 = (FeralDots_BloodTalonsEnd < FeralDots_BloodTalonsStart or ts <= FeralDots_BloodTalonsEnd) and FERAL_DOTS_BLOOD_TALONS_BIT or 0
	local f2 = (FeralDots_StealthEnd     < FeralDots_StealthStart     or ts <= FeralDots_StealthEnd    ) and FERAL_DOTS_STEALTH_BIT or 0
	local f3 = (FeralDots_ShadowMeldEnd  < FeralDots_ShadowMeldStart  or ts <= FeralDots_ShadowMeldEnd ) and FERAL_DOTS_STEALTH_BIT or 0
	local f4 = (FeralDots_BerserkEnd     < FeralDots_BerserkStart     or ts <= FeralDots_BerserkEnd    ) and FERAL_DOTS_STEALTH_BIT or 0
	local f5 = (FeralDots_ClearcastEnd   < FeralDots_ClearcastStart   or ts <= FeralDots_ClearcastEnd  ) and FERAL_DOTS_CLEARCAST_BIT or 0

	return bit.bor(f0, f1, f2, f3, f4, f5)
end

function FeralDots_RakeHasTF(target)
	return bit.band(FeralDots_RakeFlags[target] or 0, FERAL_DOTS_TIGERS_FURY_BIT) ~= 0
end

function FeralDots_RakeHasStealth(target)
	return bit.band(FeralDots_RakeFlags[target] or 0, FERAL_DOTS_STEALTH_BIT) ~= 0
end

function FeralDots_RipHasTF(target)
	return bit.band(FeralDots_RipFlags[target] or 0, FERAL_DOTS_TIGERS_FURY_BIT) ~= 0
end

function FeralDots_RipHasBT(target)
	return bit.band(FeralDots_RipFlags[target] or 0, FERAL_DOTS_BLOOD_TALONS_BIT) ~= 0
end

function FeralDots_ThrashHasTF(target)
	return bit.band(FeralDots_ThrashFlags[target] or 0, FERAL_DOTS_TIGERS_FURY_BIT) ~= 0
end

function FeralDots_ThrashHasMOC(target)
	return FeralDots_UsingMOC and bit.band(FeralDots_ThrashFlags[target] or 0, FERAL_DOTS_CLEARCAST_BIT) ~= 0
end

local function FeralDots_RaiseEvent(event)
	local wa = _G['WeakAuras']
	if wa and wa.ScanEvents then wa.ScanEvents(event) end
end

local function FeralDots_CombatHandler(self, event, ...)
	local ts, ev, _, source, _, _, _, target, _, _, _, spell, spellName = CombatLogGetCurrentEventInfo()

	if source == FeralDots_PlayerGUID then
		if ev == 'SPELL_AURA_APPLIED' or ev == 'SPELL_AURA_REFRESH' then
			if spell == FERAL_DOTS_TIGERS_FURY then
				FeralDots_TigersFuryStart = ts
				FeralDots_TigersFuryEnd = 0.0
			elseif spell == FERAL_DOTS_BLOOD_TALONS then
				FeralDots_BloodTalonsStart = ts
				FeralDots_BloodTalonsEnd = 0.0
			elseif spell == FERAL_DOTS_CLEARCAST then
				FeralDots_ClearcastStart = ts
				FeralDots_ClearcastEnd = 0.0
			elseif spell == FERAL_DOTS_STEALTH then
				FeralDots_StealthStart = ts
				FeralDots_StealthEnd = 0.0
			elseif spell == FERAL_DOTS_SHADOW_MELD then
				FeralDots_ShadowMeldStart = ts
				FeralDots_ShadowMeldEnd = 0.0
			elseif spell == FERAL_DOTS_BERSERK then
				FeralDots_BerserkStart = ts
				FeralDots_BerserkEnd = 0.0
			elseif spell == FERAL_DOTS_RAKE_DOT then
				FeralDots_RakeFlags[target] = FeralDots_GetCurrentFlags(ts)
				FeralDots_RaiseEvent('FERAL_DOTS_RAKE')
			elseif spell == FERAL_DOTS_RIP then
				FeralDots_RipFlags[target] = FeralDots_GetCurrentFlags(ts)
				FeralDots_RaiseEvent('FERAL_DOTS_RIP')
			elseif spell == FERAL_DOTS_THRASH then
				FeralDots_ThrashFlags[target] = FeralDots_GetCurrentFlags(ts)
				FeralDots_RaiseEvent('FERAL_DOTS_THRASH')
			end
		elseif ev == 'SPELL_AURA_REMOVED' then
			if spell == FERAL_DOTS_TIGERS_FURY then
				FeralDots_TigersFuryEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_BLOOD_TALONS then
				FeralDots_BloodTalonsEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_CLEARCAST then
				FeralDots_ClearcastEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_STEALTH then
				FeralDots_StealthEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_SHADOW_MELD then
				FeralDots_ShadowMeldEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_BERSERK then
				FeralDots_BerserkEnd = ts + FERAL_DOTS_AURA_EXPIRE_TIMING_THRESHOLD
			elseif spell == FERAL_DOTS_RAKE_DOT then
				FeralDots_RakeFlags[target] = nil
				FeralDots_RaiseEvent('FERAL_DOTS_RAKE')
			elseif spell == FERAL_DOTS_RIP then
				FeralDots_RipFlags[target] = nil
				FeralDots_RaiseEvent('FERAL_DOTS_RIP')
			elseif spell == FERAL_DOTS_THRASH then
				FeralDots_ThrashFlags[target] = nil
				FeralDots_RaiseEvent('FERAL_DOTS_THRASH')
			end
		end

		--print(ts, ev, spellName)
	end
end

local FeralDots_CombatFrame = CreateFrame('Frame')

FeralDots_CombatFrame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
FeralDots_CombatFrame:SetScript('OnEvent', FeralDots_CombatHandler)

--
-- name plates
--

local FeralDots_Plates = {}
local FeralDots_PlateIcons = {}
local FeralDots_PlateAuras = {}

local FeralDots_NamePlateFrame = CreateFrame('Frame')

local function FeralDots_ApplySnapshotIcons(iconTable, auras, unitID, buff)
	local spell = auras[buff:GetID()]
	local icons = iconTable[buff]

	if spell == FERAL_DOTS_RAKE_DOT or spell == FERAL_DOTS_RIP or spell == FERAL_DOTS_THRASH then
		if icons == nil then
			icons = { }

			local frame = CreateFrame('Frame', nil, buff)
			frame:SetPoint('CENTER', buff, 'TOP', 0, 0)
			frame:SetSize(18, 2)
			frame:Raise()
			frame:Show()

			icons[1] = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
			icons[1]:SetSize(7, 7)
			icons[1]:SetTexture([[Interface\Addons\FeralDots\SnapIcon.tga]])
			icons[1]:SetPoint('CENTER', frame, 'CENTER', -6, 0)

			icons[2] = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
			icons[2]:SetSize(7, 7)
			icons[2]:SetTexture([[Interface\Addons\FeralDots\SnapIcon.tga]])
			icons[2]:SetPoint('CENTER', frame, 'CENTER', 0, 0)

			icons[3] = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
			icons[3]:SetSize(7, 7)
			icons[3]:SetTexture([[Interface\Addons\FeralDots\SnapIcon.tga]])
			icons[3]:SetPoint('CENTER', frame, 'CENTER', 6, 0)

			iconTable[buff] = icons
		end

		local function showDot(index, r, g, b, active)
			if active then
				icons[index]:SetVertexColor(r, g, b)
				icons[index]:Show()
			else
				icons[index]:Hide()
			end
		end

		if spell == FERAL_DOTS_RAKE_DOT then
			showDot(1, 1.0, 1.0, 0.0, FeralDots_RakeHasTF(unitID))
			showDot(2, 1.0, 0.0, 0.0, false)
			showDot(3, 0.5, 0.3, 1.0, FeralDots_RakeHasStealth(unitID))
		elseif spell == FERAL_DOTS_RIP then
			showDot(1, 1.0, 1.0, 0.0, FeralDots_RipHasTF(unitID))
			showDot(2, 1.0, 0.0, 0.0, FeralDots_RipHasBT(unitID))
			showDot(3, 1.0, 0.0, 0.0, false)
		elseif spell == FERAL_DOTS_THRASH then
			showDot(1, 1.0, 1.0, 0.0, FeralDots_ThrashHasTF(unitID))
			showDot(2, 1.0, 0.0, 0.0, false)
			showDot(3, 0.0, 0.5, 1.0, FeralDots_ThrashHasMOC(unitID))
		end
	else
		if icons then
			for k, v in pairs(icons) do v:Hide() end
		end
	end
end

local function FeralDots_NamePlate_UpdateIcons(plate, unit, filter)
	local auras = FeralDots_PlateAuras[plate]
	local unitID = UnitGUID(unit)

	for _, buff in pairs(plate.UnitFrame.BuffFrame.buffList) do
		FeralDots_ApplySnapshotIcons(FeralDots_PlateIcons, auras, unitID, buff)
	end
end

local function FeralDots_NamePlate_UpdateBuffs(plate, unit, filter)
	local index = 1
	local auras = {}

	AuraUtil.ForEachAura(unit, filter, BUFF_MAX_DISPLAY, function(_, _, _, _, _, _, _, _, _, spell, _, _, _, _) auras[index] = spell; index = index + 1 end)

	FeralDots_PlateAuras[plate] = auras

	FeralDots_NamePlate_UpdateIcons(plate, unit, filter)
end

local function FeralDots_NamePlateHandler(self, event, unit, ...)
	if event == 'NAME_PLATE_UNIT_ADDED' then
		local plate = C_NamePlate.GetNamePlateForUnit(unit)

		if FeralDots_Plates[plate] == nil then
			FeralDots_Plates[plate] = plate

			local oldUpdateBuffs = plate.UnitFrame.BuffFrame.UpdateBuffs

			plate.UnitFrame.BuffFrame.UpdateBuffs = function(self, unit, filter, ...) oldUpdateBuffs(self, unit, filter, ...) FeralDots_NamePlate_UpdateBuffs(plate, unit, filter) end

			NamePlateDriverFrame:OnUnitAuraUpdate(unit)
		end
	end
end

FeralDots_NamePlateFrame:RegisterEvent('NAME_PLATE_UNIT_ADDED')
FeralDots_NamePlateFrame:SetScript('OnEvent', FeralDots_NamePlateHandler)

--
-- target frame
--

local FeralDots_TargetIcons = {}

local function FeralDots_TargetFrame_UpdateAuras(self)
	local debuffs = TargetFrame.Debuff

	if debuffs then
		local index = 1
		local auras = { }

		AuraUtil.ForEachAura(self.unit, 'HARMFUL|INCLUDE_NAME_PLATE_ONLY', #debuffs, function(_, _, _, _, _, _, _, _, _, spell, _, _, _, _) auras[index] = spell; index = index + 1 end)

		local unitID = UnitGUID('target')

		for _, buff in pairs(debuffs) do
			FeralDots_ApplySnapshotIcons(FeralDots_TargetIcons, auras, unitID, buff)
		end
	end
end

hooksecurefunc('TargetFrame_UpdateAuras', FeralDots_TargetFrame_UpdateAuras)

--
-- general event tracking
--

local function FeralDots_CheckTalents()
	local sg = GetActiveSpecGroup()
	FeralDots_UsingMOC = not not select(4, GetTalentInfoByID(FERAL_DOTS_MOC_TALENT, sg))
end

local FeralDots_GlobalCombatID = 0

local function FeralDots_BeginCombat()
	FeralDots_GlobalCombatID = FeralDots_GlobalCombatID + 1
end

local function FeralDots_OutOfCombatCheck(currentCombatID)
	if currentCombatID == FeralDots_GlobalCombatID then
		local function ClearTable(t)
			for i, v in pairs(t) do t[i] = nil end
		end

		ClearTable(FeralDots_RakeFlags)
		ClearTable(FeralDots_RipFlags)
		ClearTable(FeralDots_ThrashFlags)
	end
end

local function FeralDots_EndCombat()
	local currentCombatID = FeralDots_GlobalCombatID
	C_Timer.After(40, function() FeralDots_OutOfCombatCheck(currentCombatID) end)
end

local function FeralDots_EventHandler(self, event, ...)
	if event == 'PLAYER_TALENT_UPDATE' then
		FeralDots_CheckTalents()
	elseif event == 'PLAYER_REGEN_DISABLED' then
		FeralDots_BeginCombat()
	elseif event == 'PLAYER_REGEN_ENABLED' then
		FeralDots_EndCombat()
	end
end

local FeralDots_EventFrame = CreateFrame('Frame')

FeralDots_EventFrame:RegisterEvent('PLAYER_TALENT_UPDATE')
FeralDots_EventFrame:RegisterEvent('PLAYER_REGEN_DISABLED')
FeralDots_EventFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
FeralDots_EventFrame:SetScript('OnEvent', FeralDots_EventHandler)

FeralDots_CheckTalents()

--
-- debug
--

local function FeralDots_SlashCmd(msg, editbox)
	if msg == 'debug' then
		UIParentLoadAddOn('Blizzard_DebugTools')
		--DisplayTableInspectorWindow(FeralDots_TargetIcons)
		--DisplayTableInspectorWindow(FeralDots_RakeFlags)
		DisplayTableInspectorWindow(FeralDots_RipFlags)
		--DisplayTableInspectorWindow(FeralDots_ThrashFlags)
		--DisplayTableInspectorWindow(FeralDots_Plates)
	elseif msg == 'mem' then
		local frame = CreateFrame('Frame', nil, UIParent)

		frame:SetSize(10, 10)
		frame:SetPoint('LEFT', UIParent, 'LEFT', 0, 0)

		local text = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		text:SetPoint('TOPLEFT', 0, 0)
		text:SetText('FeralDots: ?k')
	
		local time = 0

		frame:SetScript('OnUpdate',
				function(self, elapsed)
					time = time + elapsed

					if time >= 1 then
						time = 0
						UpdateAddOnMemoryUsage()
						text:SetText('FeralDots: ' .. math.ceil(GetAddOnMemoryUsage('FeralDots')) .. 'k')
					end
				end
			)
	end
end

SLASH_FERAL_DOTS1 = "/feraldots"
SlashCmdList["FERAL_DOTS"] = FeralDots_SlashCmd
