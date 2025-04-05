--[=[
	@class ClipCharactersService
]=]

local require = require(script.Parent.loader).load(script)

local PhysicsService = game:GetService("PhysicsService")

local Maid = require("Maid")
local ClipCharactersServiceConstants = require("ClipCharactersServiceConstants")
local _ServiceBag = require("ServiceBag")

local ClipCharactersService = {}
ClipCharactersService.ServiceName = "ClipCharactersService"

function ClipCharactersService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self:_setupPhysicsGroup()
end

function ClipCharactersService:_setupPhysicsGroup()
	PhysicsService:RegisterCollisionGroup(ClipCharactersServiceConstants.COLLISION_GROUP_NAME)
	PhysicsService:CollisionGroupSetCollidable(ClipCharactersServiceConstants.COLLISION_GROUP_NAME, "Default", false)
end

function ClipCharactersService:Destroy()
	self._maid:DoCleaning()
end

return ClipCharactersService