--!strict
--[=[
	@class ShowBody
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local TransparencyService = require("TransparencyService")

local ShowBody = setmetatable({}, BaseObject)
ShowBody.ClassName = "ShowBody"
ShowBody.__index = ShowBody

export type ShowBody =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_transparencyService: TransparencyService.TransparencyService,
		},
		{} :: typeof({ __index = ShowBody })
	))
	& BaseObject.BaseObject

function ShowBody.new(character: Model, serviceBag: ServiceBag.ServiceBag): ShowBody
	local self: ShowBody = setmetatable(BaseObject.new(character) :: any, ShowBody)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._transparencyService = self._serviceBag:GetService(TransparencyService) :: any

	self._maid:GiveTask(self:_observeNonHeadAndFaceAccessoryPartsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local part = brio:GetValue()
		local maid = brio:ToMaid()

		-- Force visibility
		maid:GiveTask(part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
			part.LocalTransparencyModifier = 0
		end))
		part.LocalTransparencyModifier = 0
	end))

	self._maid:GiveTask(self:_observeNonHeadParts():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local part = brio:GetValue()
		local maid = brio:ToMaid()

		-- Force visibility
		maid:GiveTask(part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
			part.LocalTransparencyModifier = 0
		end))
		part.LocalTransparencyModifier = 0
	end))

	return self
end

function ShowBody._observeNonHeadParts(self: ShowBody): Observable.Observable<Brio.Brio<BasePart>>
	return RxInstanceUtils.observeChildrenBrio(self._obj :: Instance, function(child)
		return child:IsA("BasePart") and child.Name ~= "Head" -- make some assumptions
	end) :: any
end

function ShowBody._observeNonHeadAndFaceAccessoryPartsBrio(self: ShowBody): Observable.Observable<Brio.Brio<BasePart>>
	return (self:_observeAccessoriesBrio() :: any):Pipe({
		RxBrioUtils.flatMapBrio(function(accessory: any): any
			return (RxInstanceUtils.observePropertyBrio(accessory, "AccessoryType", function(accessoryType)
				return accessoryType ~= Enum.AccessoryType.Hat and accessoryType ~= Enum.AccessoryType.Face
			end) :: any):Pipe({
				RxBrioUtils.onlyLastBrioSurvives() :: any,
				RxBrioUtils.switchMapBrio(function(): any
					return RxInstanceUtils.observeDescendantsBrio(accessory, function(child)
						return child:IsA("BasePart")
					end)
				end) :: any,
			})
		end),
	})
end

function ShowBody._observeAccessoriesBrio(self: ShowBody): Observable.Observable<Brio.Brio<Accessory>>
	return RxInstanceUtils.observeDescendantsBrio(self._obj :: Instance, function(inst)
		return inst:IsA("Accessory")
	end) :: any
end

return ShowBody
