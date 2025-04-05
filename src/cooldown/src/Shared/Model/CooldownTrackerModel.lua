--[=[
	@class CooldownTrackerModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local DuckTypeUtils = require("DuckTypeUtils")

local CooldownTrackerModel = setmetatable({}, BaseObject)
CooldownTrackerModel.ClassName = "CooldownTrackerModel"
CooldownTrackerModel.__index = CooldownTrackerModel

function CooldownTrackerModel.new()
	local self = setmetatable(BaseObject.new(), CooldownTrackerModel)

	self._currentCooldownModel = self._maid:Add(ValueObject.new(nil))

	self._maid:GiveTask(self._currentCooldownModel:ObserveBrio(function(value)
		return value ~= nil
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, cooldown = brio:ToMaidAndValue()
		maid:GiveTask(cooldown.Done:Connect(function()
			if self._currentCooldownModel.Value == cooldown then
				self._currentCooldownModel.Value = nil
			end
		end))
	end))

	return self
end

function CooldownTrackerModel.isCooldownTrackerModel(value: any): boolean
	return DuckTypeUtils.isImplementation(CooldownTrackerModel, value)
end

function CooldownTrackerModel:IsCoolingDown(): boolean
	return self._currentCooldownModel.Value ~= nil
end

function CooldownTrackerModel:ObserveActiveCooldownModel()
	return self._currentCooldownModel:Observe()
end

function CooldownTrackerModel:ObserveActiveCooldownModelBrio()
	return self._currentCooldownModel:ObserveBrio(function(value)
		return value ~= nil
	end)
end

function CooldownTrackerModel:SetCooldownModel(cooldownModel)
	self._currentCooldownModel:Mount(cooldownModel)

	return function()
		if not self.Destroy then
			return
		end

		if self._currentCooldownModel.Value == cooldownModel then
			self._currentCooldownModel.Value = nil
		end
	end
end

return CooldownTrackerModel