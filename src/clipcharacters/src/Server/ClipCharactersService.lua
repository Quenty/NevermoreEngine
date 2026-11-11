--!strict
--[=[
	@class ClipCharactersService
]=]

local require = require(script.Parent.loader).load(script)

local PhysicsService = game:GetService("PhysicsService")

local ClipCharactersServiceConstants = require("ClipCharactersServiceConstants")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local ClipCharactersService = {}
ClipCharactersService.ServiceName = "ClipCharactersService"

export type ClipCharactersService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = ClipCharactersService })
))

function ClipCharactersService.Init(self: ClipCharactersService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self:_setupPhysicsGroup()
end

function ClipCharactersService._setupPhysicsGroup(_self: ClipCharactersService): ()
	PhysicsService:RegisterCollisionGroup(ClipCharactersServiceConstants.COLLISION_GROUP_NAME)
	PhysicsService:CollisionGroupSetCollidable(ClipCharactersServiceConstants.COLLISION_GROUP_NAME, "Default", false)
end

function ClipCharactersService.Destroy(self: ClipCharactersService): ()
	self._maid:DoCleaning()
end

return ClipCharactersService
