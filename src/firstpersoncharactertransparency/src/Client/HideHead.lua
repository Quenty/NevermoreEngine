--[=[
	@class HideHead
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TransparencyService = require("TransparencyService")
local RxR15Utils = require("RxR15Utils")

local HideHead = setmetatable({}, BaseObject)
HideHead.ClassName = "HideHead"
HideHead.__index = HideHead

function HideHead.new(character, serviceBag)
	local self = setmetatable(BaseObject.new(character), HideHead)

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

function HideHead:_observeHeadBrio()
	return RxR15Utils.observeCharacterPartBrio(self._obj, "Head")
end

function HideHead:_observeHeadAndFaceAccessoryPartsBrio()
	return self:_observeAccessoriesBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(accessory)
			return RxInstanceUtils.observePropertyBrio(accessory, "AccessoryType", function(accessoryType)
				return accessoryType == Enum.AccessoryType.Hat
					or accessoryType == Enum.AccessoryType.Face
					or accessoryType == Enum.AccessoryType.Hair
					or accessoryType == Enum.AccessoryType.Eyebrow
					or accessoryType == Enum.AccessoryType.Eyelash
			end):Pipe({
				RxBrioUtils.onlyLastBrioSurvives();
				RxBrioUtils.switchMapBrio(function()
					return RxInstanceUtils.observeDescendantsBrio(accessory, function(child)
						return child:IsA("BasePart")
					end)
				end);
			})
		end)
	})
end

function HideHead:_observeAccessoriesBrio()
	return RxInstanceUtils.observeDescendantsBrio(self._obj, function(inst)
		return inst:IsA("Accessory")
	end)
end

return HideHead