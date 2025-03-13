--[=[
	Clip characters locally on the client of other clients so they don't interfer with physics.
	@class ClipCharacters
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ClipCharactersServiceConstants = require("ClipCharactersServiceConstants")
local RxBrioUtils = require("RxBrioUtils")
local RxCharacterUtils = require("RxCharacterUtils")
local RxPlayerUtils = require("RxPlayerUtils")

local ClipCharacters = setmetatable({}, BaseObject)
ClipCharacters.ClassName = "ClipCharacters"
ClipCharacters.__index = ClipCharacters

--[=[
	Prevents characters from clipping together

	@return ClipCharacters
]=]
function ClipCharacters.new()
	local self = setmetatable(BaseObject.new(), ClipCharacters)

	self._maid:GiveTask(RxPlayerUtils.observePlayersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(player)
			return RxCharacterUtils.observeLastCharacterBrio(player)
		end)
	}):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, character = brio:ToMaidAndValue()
		self:_setupCharacter(maid, character)
	end))

	return self
end

function ClipCharacters:_onDescendantAdded(originalTable, descendant)
	if not originalTable[descendant] and descendant:IsA("BasePart") then
		originalTable[descendant] = descendant.CollisionGroup
		descendant.CollisionGroup = ClipCharactersServiceConstants.COLLISION_GROUP_NAME
	end
end

function ClipCharacters:_onDescendantRemoving(originalTable, descendant)
	if originalTable[descendant] then
		descendant.CollisionGroup = originalTable[descendant]
		originalTable[descendant] = nil
	end
end

function ClipCharacters:_setupCharacter(maid, character)
	local originalTable = {}

	maid:GiveTask(character.DescendantAdded:Connect(function(descendant)
		self:_onDescendantAdded(originalTable, descendant)
	end))

	maid:GiveTask(character.DescendantRemoving:Connect(function(descendant)
		self:_onDescendantRemoving(originalTable, descendant)
	end))

	-- Cleanup
	maid:GiveTask(function()
		for descendant, _ in originalTable do
			self:_onDescendantRemoving(originalTable, descendant)
		end
	end)

	-- Initialize
	for _, descendant in character:GetDescendants() do
		self:_onDescendantAdded(originalTable, descendant)
	end
end

return ClipCharacters