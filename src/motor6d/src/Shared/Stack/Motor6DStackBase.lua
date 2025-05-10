--[=[
	@class Motor6DStackBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Motor6DAnimator = require("Motor6DAnimator")
local Motor6DPhysicsTransformer = require("Motor6DPhysicsTransformer")
local Motor6DStackInterface = require("Motor6DStackInterface")
local TieRealmService = require("TieRealmService")

local Motor6DStackBase = setmetatable({}, BaseObject)
Motor6DStackBase.ClassName = "Motor6DStackBase"
Motor6DStackBase.__index = Motor6DStackBase

function Motor6DStackBase.new(motor6D, serviceBag)
	local self = setmetatable(BaseObject.new(motor6D), Motor6DStackBase)

	self._animator = self._maid:Add(Motor6DAnimator.new(motor6D))

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._maid:GiveTask(Motor6DStackInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

function Motor6DStackBase:TransformFromCFrame(physicsTransformCFrame, speed)
	assert(typeof(physicsTransformCFrame) == "CFrame", "Bad physicsTransformCFrame")
	assert(type(speed) == "number" or speed == nil, "Bad speed")

	local transformer = Motor6DPhysicsTransformer.new(physicsTransformCFrame)
	if speed then
		transformer:SetSpeed(speed)
	end

	self._animator:Push(transformer)

	return transformer
end

function Motor6DStackBase:Push(transformer)
	assert(transformer, "No transformer")

	return self._animator:Push(transformer)
end

return Motor6DStackBase
