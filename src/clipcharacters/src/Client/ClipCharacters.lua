--!strict
--[=[
	Clip characters locally on the client of other clients so they don't interfer with physics.
	@class ClipCharacters
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ClipCharactersServiceConstants = require("ClipCharactersServiceConstants")
local Maid = require("Maid")
local RxBrioUtils = require("RxBrioUtils")
local RxCharacterUtils = require("RxCharacterUtils")
local RxPlayerUtils = require("RxPlayerUtils")

local ClipCharacters = setmetatable({}, BaseObject)
ClipCharacters.ClassName = "ClipCharacters"
ClipCharacters.__index = ClipCharacters

export type ClipCharacters = typeof(setmetatable({}, {} :: typeof({ __index = ClipCharacters }))) & BaseObject.BaseObject

--[=[
	Prevents characters from clipping together

	@return ClipCharacters
]=]
function ClipCharacters.new(): ClipCharacters
	local self = setmetatable(BaseObject.new() :: any, ClipCharacters)

	self._maid:GiveTask(RxPlayerUtils.observePlayersBrio()
		:Pipe({
			RxBrioUtils.flatMapBrio(function(player)
				return RxCharacterUtils.observeLastCharacterBrio(player)
			end) :: any,
		})
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, character = brio:ToMaidAndValue()
			self:_setupCharacter(maid, character)
		end))

	return self
end

function ClipCharacters._onDescendantAdded(_self: ClipCharacters, originalTable, descendant: Instance)
	if not originalTable[descendant] and descendant:IsA("BasePart") then
		originalTable[descendant] = descendant.CollisionGroup
		descendant.CollisionGroup = ClipCharactersServiceConstants.COLLISION_GROUP_NAME
	end
end

function ClipCharacters._onDescendantRemoving(_self: ClipCharacters, originalTable, descendant)
	if originalTable[descendant] then
		descendant.CollisionGroup = originalTable[descendant]
		originalTable[descendant] = nil
	end
end

function ClipCharacters._setupCharacter(self: ClipCharacters, maid: Maid.Maid, character: Model)
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
