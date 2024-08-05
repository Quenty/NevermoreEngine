--[=[
	@class DeathReportUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local HumanoidKillerUtils = require("HumanoidKillerUtils")

local DEFAULT_COLOR = Color3.new(0.9, 0.9, 0.9)

local DeathReportUtils = {}

--[=[
	Constructs a new DeathReport from a humanoid

	@param humanoid Humanomid
	@param weaponData WeaponData
	@return DeathReport
]=]
function DeathReportUtils.fromDeceasedHumanoid(humanoid, weaponData)
	assert(DeathReportUtils.isWeaponData(weaponData) or weaponData == nil, "Bad weaponData")

	local killerHumanoid = HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)
	return DeathReportUtils.create(humanoid.Parent, killerHumanoid, weaponData)
end

function DeathReportUtils.create(adornee, killerAdornee, weaponData)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local humanoid
	if adornee:IsA("Humanoid") then
		humanoid = adornee
	else
		humanoid = adornee:FindFirstChildWhichIsA("Humanoid")
	end

	return {
		type = "deathReport";
		adornee = adornee;
		humanoid = humanoid;
		player = CharacterUtils.getPlayerFromCharacter(adornee);
		killerAdornee = killerAdornee;
		killerHumanoid = killerAdornee and killerAdornee:IsA("Humanoid") and killerAdornee or nil;
		killerPlayer = killerAdornee and CharacterUtils.getPlayerFromCharacter(killerAdornee) or nil;
		weaponData = weaponData or DeathReportUtils.createWeaponData(nil);
	}
end

--[=[
	Returns true if a DeathReport

	@param deathReport any
	@return boolean
]=]
function DeathReportUtils.isDeathReport(deathReport)
	return type(deathReport) == "table"
		and deathReport.type == "deathReport"
end

--[=[
	Returns true if a WeaponData

	@param weaponData any
	@return boolean
]=]
function DeathReportUtils.isWeaponData(weaponData)
	return type(weaponData) == "table" and (typeof(weaponData.weaponInstance) == "Instance" or weaponData.weaponInstance == nil)
end

--[=[
	Creates weapon data information

	@param weaponInstance Instance?
	@return WeaponData
]=]
function DeathReportUtils.createWeaponData(weaponInstance)
	assert(typeof(weaponInstance) == "Instance" or weaponInstance == nil, "Bad weaponInstance")

	return {
		weaponInstance = weaponInstance;
	}
end

--[=[
	Gets the dead display name for the player who died.

	@param deathReport DeathReport
	@return string
]=]
function DeathReportUtils.getDeadDisplayName(deathReport)
	if deathReport.player then
		return deathReport.player.DisplayName
	elseif deathReport.humanoid then
		local character = deathReport.humanoid.Parent
		if character then
			return character.Name
		else
			warn("DeathReport.humanoid without character")
			return "Unknown entity"
		end
	elseif deathReport.adornee then
		return nil
	else
		error("DeathReport without an adornee")
	end
end

--[=[
	Returns true if the death involves another player

	@param deathReport DeathReport
	@param player Player
	@return string
]=]
function DeathReportUtils.involvesPlayer(deathReport, player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return (deathReport.player == player) or (deathReport.killerPlayer == player)
end

--[=[
	Gets the killer display name for the player who died.

	@param deathReport DeathReport
	@return string?
]=]
function DeathReportUtils.getKillerDisplayName(deathReport)
	if deathReport.killerPlayer then
		assert(deathReport.killerPlayer:IsA("Player"), "Bad player")
		return deathReport.killerPlayer.DisplayName
	elseif deathReport.killerHumanoid then
		local character = deathReport.killerHumanoid.Parent
		if character then
			return character.Name
		else
			warn("DeathReport.killerHumanoid without character")
			return nil
		end
	else
		return nil
	end
end

--[=[
	Returns the dead's color

	@param deathReport DeathReport
	@return Color3?
]=]
function DeathReportUtils.getDeadColor(deathReport)
	if deathReport.player then
		local team = deathReport.player.Team
		if team then
			return team.TeamColor.Color
		end
	end

	return nil
end

--[=[
	Returns the killer's color

	@param deathReport DeathReport
	@return Color3?
]=]
function DeathReportUtils.getKillerColor(deathReport)
	if deathReport.killerPlayer then
		local team = deathReport.killerPlayer.Team
		if team then
			return team.TeamColor.Color
		end
	end

	return nil
end

--[=[
	Gets the default color of a death report to use.
	@return Color3
]=]
function DeathReportUtils.getDefaultColor()
	return DEFAULT_COLOR
end

return DeathReportUtils