--[=[
	@class RogueSetter
]=]

local require = require(script.Parent.loader).load(script)

local RogueModifierBase = require("RogueModifierBase")
local Binder = require("Binder")
local RxValueBaseUtils = require("RxValueBaseUtils")
local RogueModifierInterface = require("RogueModifierInterface")

local RogueSetter = setmetatable( {}, RogueModifierBase)
RogueSetter.ClassName = "RogueSetter"
RogueSetter.__index = RogueSetter

function RogueSetter.new(valueObject, serviceBag)
	local self = setmetatable(RogueModifierBase.new(valueObject, serviceBag), RogueSetter)

	self._maid:GiveTask(RogueModifierInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function RogueSetter:GetModifiedVersion()
	return self._obj.Value
end

function RogueSetter:ObserveModifiedVersion()
	return RxValueBaseUtils.observeValue(self._obj)
end

function RogueSetter:GetInvertedVersion(_, initialValue)
	return initialValue
end

return Binder.new("RogueSetter", RogueSetter)