--[=[
	@class ClipCharactersServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ClipCharacters = require("ClipCharacters")
local Maid = require("Maid")
local StateStack = require("StateStack")
local _ServiceBag = require("ServiceBag")

local ClipCharactersServiceClient = {}
ClipCharactersServiceClient.ServiceName = "ClipCharactersServiceClient"

function ClipCharactersServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._disableCollisions = self._maid:Add(StateStack.new(false, "boolean"))
end

--[=[
	Disables collisions between default geometry and other charaters which stops some random physics
	glitches from occuring.
]=]
function ClipCharactersServiceClient:PushDisableCharacterCollisionsWithDefault()
	return self._disableCollisions:PushState(true)
end

function ClipCharactersServiceClient:Start()
	self._maid:GiveTask(self._disableCollisions:ObserveBrio(function(value)
		return value
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		maid:GiveTask(ClipCharacters.new())
	end))
end

function ClipCharactersServiceClient:Destroy()
	self._maid:DoCleaning()
end

return ClipCharactersServiceClient