--!strict
--[=[
	@class Motor6DStackHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DStack = require("Motor6DStack")
local Motor6DStackHumanoidBase = require("Motor6DStackHumanoidBase")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local ServiceBag = require("ServiceBag")

local Motor6DStackHumanoid = setmetatable({}, Motor6DStackHumanoidBase)
Motor6DStackHumanoid.ClassName = "Motor6DStackHumanoid"
Motor6DStackHumanoid.__index = Motor6DStackHumanoid

export type Motor6DStackHumanoid =
	typeof(setmetatable(
		{} :: {
			_obj: Humanoid,
			_serviceBag: ServiceBag.ServiceBag,
		},
		{} :: typeof({ __index = Motor6DStackHumanoid })
	))
	& Motor6DStackHumanoidBase.Motor6DStackHumanoidBase

function Motor6DStackHumanoid.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): Motor6DStackHumanoid
	local self: Motor6DStackHumanoid =
		setmetatable(Motor6DStackHumanoidBase.new(humanoid, serviceBag) :: any, Motor6DStackHumanoid)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid:GiveTask(self:ObserveMotor6DsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, motor = brio:ToMaidAndValue()

		Motor6DStack:Tag(motor)
		maid:GiveTask(function()
			Motor6DStack:Untag(motor)
		end)
	end))

	return self
end

return PlayerHumanoidBinder.new("Motor6DStackHumanoid", Motor6DStackHumanoid)
