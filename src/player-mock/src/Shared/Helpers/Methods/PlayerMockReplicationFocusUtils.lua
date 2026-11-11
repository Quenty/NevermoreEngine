--!strict
--[=[
	The streaming-focus set of a mock. The engine exposes no getter for a real `Player`'s focuses, so
	the set lives on the mock where a test can read it back.

	Use [PlayerMock.addReplicationFocus], [PlayerMock.removeReplicationFocus] and
	[PlayerMock.getReplicationFocuses].

	@class PlayerMockReplicationFocusUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockReplicationFocusUtils = {}

--[=[
	The backing is a set, so adding a part already focused does nothing.

	Use [PlayerMock.addReplicationFocus].

	@param player Player -- must be a PlayerMock
	@param part BasePart
]=]
function PlayerMockReplicationFocusUtils.addReplicationFocus(player: Player, part: BasePart): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	if PlayerMockReplicationFocusUtils._findReplicationFocusValue(player, part) ~= nil then
		return
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = part.Name
	objectValue.Value = part
	objectValue.Parent = PlayerMockReplicationFocusUtils._getOrCreateReplicationFocusFolder(player)
end

--[=[
	Removing a part that is not focused is a no-op.

	Use [PlayerMock.removeReplicationFocus].

	@param player Player -- must be a PlayerMock
	@param part BasePart
]=]
function PlayerMockReplicationFocusUtils.removeReplicationFocus(player: Player, part: BasePart): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local objectValue = PlayerMockReplicationFocusUtils._findReplicationFocusValue(player, part)
	if objectValue ~= nil then
		objectValue:Destroy()
	end
end

--[=[
	Returns the parts currently focused on a mock, in the order they were added.

	Use [PlayerMock.getReplicationFocuses].

	@param player Player -- must be a PlayerMock
	@return { BasePart }
]=]
function PlayerMockReplicationFocusUtils.getReplicationFocuses(player: Player): { BasePart }
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	local folder = PlayerMockReplicationFocusUtils._findReplicationFocusFolder(player)
	if folder == nil then
		return {}
	end

	local focuses: { BasePart } = {}
	for _, child in folder:GetChildren() do
		local value = (child :: ObjectValue).Value
		if value ~= nil then
			table.insert(focuses, value :: BasePart)
		end
	end
	return focuses
end

function PlayerMockReplicationFocusUtils._findReplicationFocusFolder(player: Player): Folder?
	return (player :: Instance):FindFirstChild(PlayerMockConstants.REPLICATION_FOCUS_FOLDER_NAME) :: Folder?
end

function PlayerMockReplicationFocusUtils._getOrCreateReplicationFocusFolder(player: Player): Folder
	local existing = PlayerMockReplicationFocusUtils._findReplicationFocusFolder(player)
	if existing ~= nil then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = PlayerMockConstants.REPLICATION_FOCUS_FOLDER_NAME
	folder.Parent = player :: Instance
	return folder
end

function PlayerMockReplicationFocusUtils._findReplicationFocusValue(player: Player, part: BasePart): ObjectValue?
	local folder = PlayerMockReplicationFocusUtils._findReplicationFocusFolder(player)
	if folder == nil then
		return nil
	end

	for _, child in folder:GetChildren() do
		if (child :: ObjectValue).Value == part then
			return child :: ObjectValue
		end
	end

	return nil
end

return PlayerMockReplicationFocusUtils
