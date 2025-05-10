--[=[
	@class Motor6DStackHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Motor6DStack = require("Motor6DStack")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local Motor6DStackHumanoid = setmetatable({}, BaseObject)
Motor6DStackHumanoid.ClassName = "Motor6DStackHumanoid"
Motor6DStackHumanoid.__index = Motor6DStackHumanoid

function Motor6DStackHumanoid.new(humanoid: Humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Motor6DStackHumanoid)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid:GiveTask(self:_observeMotorsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local motor = brio:GetValue()
		local maid = brio:ToMaid()

		Motor6DStack:Tag(motor)
		maid:GiveTask(function()
			Motor6DStack:Untag(motor)
		end)
	end))

	return self
end

function Motor6DStackHumanoid:_observeMotorsBrio()
	return RxInstanceUtils.observePropertyBrio(self._obj, "Parent", function(parent)
		return parent ~= nil
	end):Pipe({
		RxBrioUtils.flatMapBrio(function(character)
			return RxInstanceUtils.observeDescendantsBrio(character, function(descendant)
				return descendant:IsA("Motor6D")
			end)
		end),
	})
end

return PlayerHumanoidBinder.new("Motor6DStackHumanoid", Motor6DStackHumanoid)
