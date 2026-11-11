--!strict
--[=[
	@class HideHead
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local Observable = require("Observable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")
local ServiceBag = require("ServiceBag")
local TransparencyService = require("TransparencyService")

local HideHead = setmetatable({}, BaseObject)
HideHead.ClassName = "HideHead"
HideHead.__index = HideHead

export type HideHead =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_transparencyService: any,
		},
		{} :: typeof({ __index = HideHead })
	))
	& BaseObject.BaseObject

function HideHead.new(character: Model, serviceBag: ServiceBag.ServiceBag): HideHead
	local self: HideHead = setmetatable(BaseObject.new(character) :: any, HideHead)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._transparencyService = self._serviceBag:GetService(TransparencyService)

	self._maid:GiveTask(self:_observeHeadAndFaceAccessoryPartsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local part = brio:GetValue()
		local maid = brio:ToMaid()

		self._transparencyService:SetTransparency(maid, part, 1)
		maid:GiveTask(function()
			self._transparencyService:ResetTransparency(maid, part)
		end)
	end))

	self._maid:GiveTask(self:_observeHeadBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local part = brio:GetValue()
		local maid = brio:ToMaid()

		self._transparencyService:SetTransparency(maid, part, 1)
		maid:GiveTask(function()
			self._transparencyService:ResetTransparency(maid, part)
		end)
	end))

	return self
end

function HideHead._observeHeadBrio(self: HideHead): Observable.Observable<Brio.Brio<BasePart>>
	return RxR15Utils.observeCharacterPartBrio(self._obj :: Model, "Head") :: any
end

function HideHead._observeHeadAndFaceAccessoryPartsBrio(self: HideHead): Observable.Observable<Brio.Brio<BasePart>>
	return (self:_observeAccessoriesBrio() :: any):Pipe({
		RxBrioUtils.flatMapBrio(function(accessory): any
			return (RxInstanceUtils.observePropertyBrio(accessory, "AccessoryType", function(accessoryType)
				return accessoryType == Enum.AccessoryType.Hat
					or accessoryType == Enum.AccessoryType.Face
					or accessoryType == Enum.AccessoryType.Hair
					or accessoryType == Enum.AccessoryType.Eyebrow
					or accessoryType == Enum.AccessoryType.Eyelash
			end) :: any):Pipe({
				RxBrioUtils.onlyLastBrioSurvives(),
				RxBrioUtils.switchMapBrio(function(): any
					return RxInstanceUtils.observeDescendantsBrio(accessory, function(child)
						return child:IsA("BasePart")
					end)
				end) :: any,
			})
		end),
	}) :: any
end

function HideHead._observeAccessoriesBrio(self: HideHead): Observable.Observable<Brio.Brio<Accessory>>
	return (
		RxInstanceUtils.observeDescendantsBrio(self._obj :: Instance, function(inst)
			return inst:IsA("Accessory")
		end) :: any
	) :: Observable.Observable<Brio.Brio<Accessory>>
end

return HideHead
