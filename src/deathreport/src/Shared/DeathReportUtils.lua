--!strict
--[=[
	@class DeathReportUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local HumanoidKillerUtils = require("HumanoidKillerUtils")
local PlayerMock = require("PlayerMock")

local DEFAULT_COLOR = Color3.new(0.9, 0.9, 0.9)

local DeathReportUtils = {}

--[=[
	Constructs a new DeathReport from a humanoid

	@param humanoid Humanomid
	@param weaponData WeaponData
	@return DeathReport
]=]
function DeathReportUtils.fromDeceasedHumanoid(humanoid: Humanoid, weaponData: WeaponData?): DeathReport
	assert(DeathReportUtils.isWeaponData(weaponData) or weaponData == nil, "Bad weaponData")

	local killerHumanoid = HumanoidKillerUtils.getKillerHumanoidOfHumanoid(humanoid)
	local character = assert(humanoid.Parent, "No character for humanoid")
	return DeathReportUtils.create(character, killerHumanoid, weaponData)
end

export type WeaponData = {
	weaponInstance: Instance?,
}
export type DeathReport = {
	type: "deathReport",
	adornee: Instance,
	humanoid: Humanoid?,
	player: Player?,
	killerAdornee: Instance?,
	killerHumanoid: Humanoid?,
	killerPlayer: Player?,
	weaponData: WeaponData,
}

--[=[
	Constructs a death report for the adornee that died

	@param adornee Instance -- The humanoid or character that died
	@param killerAdornee Instance? -- The humanoid or character that killed it
	@param weaponData WeaponData?
	@return DeathReport
]=]
function DeathReportUtils.create(adornee: Instance, killerAdornee: Instance?, weaponData: WeaponData?): DeathReport
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local humanoid: Humanoid?
	if adornee:IsA("Humanoid") then
		humanoid = adornee
	else
		humanoid = adornee:FindFirstChildWhichIsA("Humanoid")
	end

	return {
		type = "deathReport",
		adornee = adornee,
		humanoid = humanoid,
		player = CharacterUtils.getPlayerFromCharacter(adornee),
		killerAdornee = killerAdornee,
		killerHumanoid = killerAdornee and killerAdornee:IsA("Humanoid") and killerAdornee or nil,
		killerPlayer = killerAdornee and CharacterUtils.getPlayerFromCharacter(killerAdornee) or nil,
		weaponData = weaponData or DeathReportUtils.createWeaponData(nil),
	}
end

--[=[
	Returns true if a DeathReport

	@param deathReport any
	@return boolean
]=]
function DeathReportUtils.isDeathReport(deathReport: any): boolean
	return type(deathReport) == "table" and deathReport.type == "deathReport"
end

--[=[
	Returns true if a WeaponData

	@param weaponData any
	@return boolean
]=]
function DeathReportUtils.isWeaponData(weaponData: any): boolean
	return type(weaponData) == "table"
		and (typeof(weaponData.weaponInstance) == "Instance" or weaponData.weaponInstance == nil)
end

--[=[
	Creates weapon data information

	@param weaponInstance Instance?
	@return WeaponData
]=]
function DeathReportUtils.createWeaponData(weaponInstance: Instance?): WeaponData
	assert(typeof(weaponInstance) == "Instance" or weaponInstance == nil, "Bad weaponInstance")

	return {
		weaponInstance = weaponInstance,
	}
end

--[=[
	Gets the dead display name for the player who died.

	@param deathReport DeathReport
	@return string
]=]
function DeathReportUtils.getDeadDisplayName(deathReport: DeathReport): string?
	local player = deathReport.player
	if player then
		return if PlayerMock.isMock(player) then PlayerMock.read(player, "DisplayName") else player.DisplayName
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
function DeathReportUtils.involvesPlayer(deathReport: DeathReport, player: Player): boolean
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	return (deathReport.player == player) or (deathReport.killerPlayer == player)
end

--[=[
	Gets the killer display name for the player who died.

	@param deathReport DeathReport
	@return string?
]=]
function DeathReportUtils.getKillerDisplayName(deathReport: DeathReport): string?
	local killerPlayer = deathReport.killerPlayer
	if killerPlayer then
		assert(killerPlayer:IsA("Player") or PlayerMock.isMock(killerPlayer), "Bad player")
		return if PlayerMock.isMock(killerPlayer)
			then PlayerMock.read(killerPlayer, "DisplayName")
			else killerPlayer.DisplayName
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
function DeathReportUtils.getDeadColor(deathReport: DeathReport): Color3?
	local player = deathReport.player
	if player then
		local team = if PlayerMock.isMock(player) then PlayerMock.read(player, "Team") else player.Team
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
function DeathReportUtils.getKillerColor(deathReport: DeathReport): Color3?
	local killerPlayer = deathReport.killerPlayer
	if killerPlayer then
		local team = if PlayerMock.isMock(killerPlayer)
			then PlayerMock.read(killerPlayer, "Team")
			else killerPlayer.Team
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
function DeathReportUtils.getDefaultColor(): Color3
	return DEFAULT_COLOR
end

return DeathReportUtils
