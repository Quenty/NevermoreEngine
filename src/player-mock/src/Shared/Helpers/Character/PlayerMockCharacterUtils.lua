--!strict
--[=[
	The character spawn lifecycle of a mock. The spawn sequence mirrors the engine's
	[avatar loading event ordering](https://devforum.roblox.com/t/avatar-loading-event-ordering-improvements/269607),
	which PlayerMock.spec asserts step by step.

	Use [PlayerMock.loadCharacterAsync], [PlayerMock.loadMinimalCharacterAsync] and
	[PlayerMock.removeCharacter].

	@class PlayerMockCharacterUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlayerMockChildrenUtils = require("PlayerMockChildrenUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")
local PlayerMockSignalUtils = require("PlayerMockSignalUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockCharacterUtils = {}

--[=[
	Omitting `character` builds a default R15 rig from an empty `HumanoidDescription`, which may
	yield.

	Use [PlayerMock.loadCharacterAsync].

	@param player Player -- must be a PlayerMock
	@param character Model? -- the new character; nil builds a default R15 rig
	@return Model
]=]
function PlayerMockCharacterUtils.loadCharacterAsync(player: Player, character: Model?): Model
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(character == nil or (typeof(character) == "Instance" and character:IsA("Model")), "Bad character")

	local newCharacter: Model = character
		or Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	newCharacter.Name = player.Name

	if PlayerMockPropertyUtils.read(player, "Character") ~= nil then
		PlayerMockPropertyUtils.write(player, "Character", nil)
	end

	-- Replaced before any spawn signal fires, so CharacterAdded handlers reach the new backpack.
	local oldBackpack = PlayerMockChildrenUtils.getBackpack(player)
	if oldBackpack ~= nil then
		oldBackpack:Destroy()
	end

	local backpack = Instance.new("Backpack")
	backpack.Parent = player :: Instance

	-- Unlike the Backpack, the engine never replaces StarterGear on respawn.
	if PlayerMockChildrenUtils.getStarterGear(player) == nil then
		local starterGear = Instance.new("StarterGear")
		starterGear.Parent = player :: Instance
	end

	PlayerMockPropertyUtils.write(player, "Character", newCharacter)
	newCharacter.Parent = Workspace
	PlayerMockSignalUtils.fireSignal(player, "CharacterAdded", newCharacter)

	PlayerMockPropertyUtils.write(player, "HasAppearanceLoaded", true)
	PlayerMockSignalUtils.fireSignal(player, "CharacterAppearanceLoaded", newCharacter)

	return newCharacter
end

--[=[
	An anchored `HumanoidRootPart` (the `PrimaryPart`) and a `Humanoid`, which never yields to build.

	Use [PlayerMock.loadMinimalCharacterAsync].

	@param player Player -- must be a PlayerMock
	@return Model
]=]
function PlayerMockCharacterUtils.loadMinimalCharacterAsync(player: Player): Model
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	local character = Instance.new("Model")

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character
	character.PrimaryPart = rootPart

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character

	return PlayerMockCharacterUtils.loadCharacterAsync(player, character)
end

--[=[
	No-op when no character is loaded.

	Use [PlayerMock.removeCharacter].

	@param player Player -- must be a PlayerMock
]=]
function PlayerMockCharacterUtils.removeCharacter(player: Player): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	if PlayerMockPropertyUtils.read(player, "Character") ~= nil then
		PlayerMockPropertyUtils.write(player, "Character", nil)
	end
end

--[=[
	Returns the mock whose `Character` stand-in is the given model, or nil. Like the engine call only
	the exact character model matches -- a descendant part resolves nil, so callers walking up from a
	descendant keep their own ancestor walk.

	Use [PlayerMock.getMockFromCharacter].

	@param character Instance
	@return Player?
]=]
function PlayerMockCharacterUtils.getMockFromCharacter(character: Instance): Player?
	assert(typeof(character) == "Instance", "Bad character")

	for _, tagged in CollectionService:GetTagged(PlayerMockConstants.MOCK_TAG) do
		if PlayerMockUtils.isMock(tagged) then
			local mock = (tagged :: any) :: Player
			if PlayerMockPropertyUtils.read(mock, "Character") == character then
				return mock
			end
		end
	end

	return nil
end

return PlayerMockCharacterUtils
