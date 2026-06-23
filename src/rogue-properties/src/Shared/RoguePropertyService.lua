--!strict
--[=[
	This service handles the observable part of a rogue property which allows for us to listen
	for all of these additives and multipliers in a centralized location.

	@class RoguePropertyService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local RoguePropertyService = {}
RoguePropertyService.ServiceName = "RoguePropertyService"

export type RoguePropertyService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = RoguePropertyService })
))

function RoguePropertyService.Init(self: RoguePropertyService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()

	-- Internal
	self._serviceBag:GetService(require("RoguePropertyCacheService"))
	self._serviceBag:GetService(require("TieRealmService"))

	-- Binders
	self._serviceBag:GetService(require("RogueAdditive"))
	self._serviceBag:GetService(require("RogueMultiplier"))
	self._serviceBag:GetService(require("RogueSetter"))
end

function RoguePropertyService.CanInitializeProperties(_self: RoguePropertyService): boolean
	return RunService:IsServer()
end

function RoguePropertyService.Destroy(self: RoguePropertyService)
	self._maid:DoCleaning()
end

return RoguePropertyService
