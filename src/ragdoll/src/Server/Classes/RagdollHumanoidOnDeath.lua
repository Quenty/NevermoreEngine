--!strict
--[=[
	Ragdolls the humanoid on death. This class exports a [Binder].
	@server
	@class RagdollHumanoidOnDeath
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")
local ServiceBag = require("ServiceBag")

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

export type RagdollHumanoidOnDeath =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: typeof(Ragdoll),
		},
		{} :: typeof({ __index = RagdollHumanoidOnDeath })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new RagdollHumanoidOnDeath. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeath
]=]
function RagdollHumanoidOnDeath.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RagdollHumanoidOnDeath
	local self: RagdollHumanoidOnDeath = setmetatable(BaseObject.new(humanoid) :: any, RagdollHumanoidOnDeath)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	local humanoidObj = self._obj :: Humanoid
	humanoidObj.BreakJointsOnDeath = false
	self._maid:GiveTask(function()
		humanoidObj.BreakJointsOnDeath = true
	end)

	self._maid:GiveTask(humanoidObj:GetPropertyChangedSignal("Health"):Connect(function()
		if humanoidObj.Health <= 0 then
			self._ragdollBinder:Bind(humanoidObj)
		end
	end))

	return self
end

return PlayerHumanoidBinder.new(
		"RagdollHumanoidOnDeath",
		RagdollHumanoidOnDeath :: any
	) :: PlayerHumanoidBinder.PlayerHumanoidBinder<RagdollHumanoidOnDeath>
