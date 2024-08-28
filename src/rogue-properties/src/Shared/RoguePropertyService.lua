--[=[
	This service handles the observable part of a rogue property which allows for us to listen
	for all of these additives and multipliers in a centralized location.

	@class RoguePropertyService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Signal = require("Signal")
local Maid = require("Maid")

local RoguePropertyService = {}
RoguePropertyService.ServiceName = "RoguePropertyService"

function RoguePropertyService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
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

function RoguePropertyService:CanInitializeProperties()
	return RunService:IsServer()
end

function RoguePropertyService:Destroy()
	self._maid:DoCleaning()
end

return RoguePropertyService