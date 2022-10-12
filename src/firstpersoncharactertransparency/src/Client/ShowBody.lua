--[=[
	@class ShowBody
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TransparencyService = require("TransparencyService")

local ShowBody = setmetatable({}, BaseObject)
ShowBody.ClassName = "ShowBody"
ShowBody.__index = ShowBody

function ShowBody.new(character, serviceBag)
	local self = setmetatable(BaseObject.new(character), ShowBody)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._transparencyService = self._serviceBag:GetService(TransparencyService)

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

function ShowBody:_observeNonHeadParts()
	return RxInstanceUtils.observeChildrenBrio(self._obj, function(child)
		return child:IsA("BasePart") and child.Name ~= "Head" -- make some assumptions
	end)
end


function ShowBody:_observeNonHeadAndFaceAccessoryPartsBrio()
	return self:_observeAccessoriesBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(accessory)
			return RxInstanceUtils.observePropertyBrio(accessory, "AccessoryType", function(accessoryType)
				return accessoryType ~= Enum.AccessoryType.Hat and accessoryType ~= Enum.AccessoryType.Face
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

function ShowBody:_observeAccessoriesBrio()
	return RxInstanceUtils.observeDescendantsBrio(self._obj, function(inst)
		return inst:IsA("Accessory")
	end)
end

return ShowBody