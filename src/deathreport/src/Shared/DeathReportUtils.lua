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
	@return DeathReport
]=]
function DeathReportUtils.fromDeceasedHumanoid(humanoid)
	return {
		adornee = humanoid.Parent;
		humanoid = humanoid;
		player = CharacterUtils.getPlayerFromCharacter(humanoid);
		killer = HumanoidKillerUtils.getKillerOfHumanoid(humanoid);
		weaponData = DeathReportUtils.createWeaponData();
	}
end

--[=[
	Creates weapon data information

	@return WeaponData
]=]
function DeathReportUtils.createWeaponData()
	return {
		weaponKey = "test";
		weaponInstance = nil;
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
			warn("DeathReport without character")
			return "Unknown entity"
		end
	else
		error("DeathReport without a humanoid")
	end
end

--[=[
	Returns true if the death involves another player

	@param deathReport DeathReport
	@parm player Player
	@return string
]=]
function DeathReportUtils.involvesPlayer(deathReport, player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return (deathReport.player == player) or (deathReport.killer == player)
end

--[=[
	Gets the killer display name for the player who died.

	@param deathReport DeathReport
	@return string
]=]
function DeathReportUtils.getKillerDisplayName(deathReport)
	if not deathReport.killer then
		return nil
	end

	assert(deathReport.killer:IsA("Player"), "Bad player")

	return deathReport.killer.DisplayName
end

--[=[
	Returns the dead's color

	@param deathReport DeathReport
	@return Color3
]=]
function DeathReportUtils.getDeadColor(deathReport)
	if not deathReport.player then
		return DEFAULT_COLOR
	end

	local team = deathReport.player.Team
	if not team then
		return DEFAULT_COLOR
	end

	return team.TeamColor.Color
end

--[=[
	Returns the killer's color

	@param deathReport DeathReport
	@return Color3
]=]
function DeathReportUtils.getKillerColor(deathReport)
	if not deathReport.killer then
		return DEFAULT_COLOR
	end

	local team = deathReport.killer.Team
	if not team then
		return DEFAULT_COLOR
	end

	return team.TeamColor.Color
end

return DeathReportUtils