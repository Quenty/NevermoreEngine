--!strict
--[=[
    @class DynamicHideBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local HideUtils = require("HideUtils")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local DynamicHideBase = setmetatable({}, BaseObject)
DynamicHideBase.ClassName = "DynamicHideBase"
DynamicHideBase.__index = DynamicHideBase

export type DynamicHideBase =
	typeof(setmetatable(
		{} :: {
			_obj: Instance,
		},
		{} :: typeof({ __index = DynamicHideBase })
	))
	& BaseObject.BaseObject

function DynamicHideBase.new(instance: Instance): DynamicHideBase
	local self: DynamicHideBase = setmetatable(BaseObject.new(instance) :: any, DynamicHideBase)

	return self
end

function DynamicHideBase._observeHideChildrenBrio(
	self: DynamicHideBase,
	hideBinder: any
): Observable.Observable<Brio.Brio<Instance>>
	return hideBinder:ObserveBrio(self._obj):Pipe({
		RxBrioUtils.switchMapBrio(function()
			return RxInstanceUtils.observeDescendantsAndSelfBrio(self._obj, function(child)
				return HideUtils.hasLocalTransparencyModifier(child) or HideUtils.hasTransparency(child)
			end)
		end),
	})
end

return DynamicHideBase
