--!strict
--[=[
	@class ClipCharactersServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ClipCharacters = require("ClipCharacters")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

local ClipCharactersServiceClient = {}
ClipCharactersServiceClient.ServiceName = "ClipCharactersServiceClient"

export type ClipCharactersServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_disableCollisions: StateStack.StateStack<boolean>,
	},
	{} :: typeof({ __index = ClipCharactersServiceClient })
))

function ClipCharactersServiceClient.Init(self: ClipCharactersServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._disableCollisions = self._maid:Add(StateStack.new(false, "boolean"))
end

--[=[
	Disables collisions between default geometry and other characters which stops some random physics
	glitches from occurring.
]=]
function ClipCharactersServiceClient.PushDisableCharacterCollisionsWithDefault(self: ClipCharactersServiceClient): () -> ()
	return self._disableCollisions:PushState(true)
end

function ClipCharactersServiceClient.Start(self: ClipCharactersServiceClient): ()
	self._maid:GiveTask(self._disableCollisions
		:ObserveBrio(function(value)
			return value
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			maid:GiveTask(ClipCharacters.new())
		end))
end

function ClipCharactersServiceClient.Destroy(self: ClipCharactersServiceClient): ()
	self._maid:DoCleaning()
end

return ClipCharactersServiceClient
