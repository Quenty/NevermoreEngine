--[=[
	@class RagdollableBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local RxSignal = require("RxSignal")

local RagdollableBase = setmetatable({}, BaseObject)
RagdollableBase.ClassName = "RagdollableBase"
RagdollableBase.__index = RagdollableBase

function RagdollableBase.new(humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(humanoid), RagdollableBase)

	self.Ragdolled = RxSignal.new(function()
		return self:ObserveIsRagdolled():Pipe({
			Rx.skip(1),
			Rx.where(function(value)
				return value == true
			end),
		})
	end)

	self.Unragdolled = RxSignal.new(function()
		return self:ObserveIsRagdolled():Pipe({
			Rx.skip(1),
			Rx.where(function(value)
				return value == true
			end),
		})
	end)

	return self
end

function RagdollableBase:Ragdoll()
	self._obj:AddTag("Ragdoll")
end

function RagdollableBase:Unragdoll()
	self._obj:RemoveTag("Ragdoll")
end

function RagdollableBase:ObserveIsRagdolled()
	error("Not implemented")
end

function RagdollableBase:IsRagdolled(): boolean
	return self._obj:HasTag("Ragdoll")
end

return RagdollableBase
