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
		killerHumanoid = HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid);
		killerPlayer = HumanoidKillerUtils.getPlayerKillerOfHumanoid(humanoid);
		weaponData = DeathReportUtils.createWeaponData();
	}
end

function DeathReportUtils.isDeathReport(deathReport)
	return type(deathReport) == "table"
		and typeof(deathReport.humanoid) == "Instance"
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
			warn("DeathReport.humanoid without character")
			return "Unknown entity"
		end
	else
		error("DeathReport without a humanoid")
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

function DeathReportUtils.getDefaultColor()
	return DEFAULT_COLOR
end

return DeathReportUtils