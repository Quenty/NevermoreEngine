--!strict
--[=[
	Helps track the active cooldown that is running.

	@class CooldownTrackerModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local CooldownModel = require("CooldownModel")
local DuckTypeUtils = require("DuckTypeUtils")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local CooldownTrackerModel = setmetatable({}, BaseObject)
CooldownTrackerModel.ClassName = "CooldownTrackerModel"
CooldownTrackerModel.__index = CooldownTrackerModel

export type CooldownTrackerModel = typeof(setmetatable(
	{} :: {
		_currentCooldownModel: ValueObject.ValueObject<CooldownModel.CooldownModel?>,
	},
	{} :: typeof({ __index = CooldownTrackerModel })
)) & BaseObject.BaseObject

--[=[
	Creates a new cooldown tracker model

	@return CooldownTrackerModel
]=]
function CooldownTrackerModel.new(): CooldownTrackerModel
	local self: CooldownTrackerModel = setmetatable(BaseObject.new() :: any, CooldownTrackerModel)

	self._currentCooldownModel = self._maid:Add(ValueObject.new(nil))

	self._maid:GiveTask(self._currentCooldownModel
		:ObserveBrio(function(value)
			return value ~= nil
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, cooldown = brio:ToMaidAndValue()
			assert(cooldown, "Must have cooldown")

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

function CooldownTrackerModel.IsCoolingDown(self: CooldownTrackerModel): boolean
	return self._currentCooldownModel.Value ~= nil
end

function CooldownTrackerModel.ObserveActiveCooldownModel(
	self: CooldownTrackerModel
): Observable.Observable<CooldownModel.CooldownModel?>
	return self._currentCooldownModel:Observe()
end

--[=[
	Observes the active cooldown model, but only fires when it is not nil

	@return Observable<Brio<CooldownModel>>
]=]
function CooldownTrackerModel.ObserveActiveCooldownModelBrio(self: CooldownTrackerModel): Observable.Observable<
	Brio.Brio<CooldownModel.CooldownModel>
>
	return self._currentCooldownModel:ObserveBrio(function(value)
		return value ~= nil
	end) :: any
end

--[=[
	Sets the cooldown model. Returns a function to unmount the model.

	@param cooldownModel CooldownModel
	@return function
]=]
function CooldownTrackerModel.SetCooldownModel(
	self: CooldownTrackerModel,
	cooldownModel: ValueObject.Mountable<CooldownModel.CooldownModel?>
): () -> ()
	self._currentCooldownModel:Mount(cooldownModel)

	return function()
		if not self.Destroy then
			return
		end

		if self._currentCooldownModel.Value == cooldownModel then
			self._currentCooldownModel:Mount(nil)
		end
	end
end

return CooldownTrackerModel
