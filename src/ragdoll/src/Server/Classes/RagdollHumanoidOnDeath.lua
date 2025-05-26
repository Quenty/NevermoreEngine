--[=[
	Ragdolls the humanoid on death. This class exports a [Binder].
	@server
	@class RagdollHumanoidOnDeath
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local Ragdoll = require("Ragdoll")

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

--[=[
	Constructs a new RagdollHumanoidOnDeath. This class exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeath
]=]
function RagdollHumanoidOnDeath.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnDeath)

	self._serviceBag = assert(serviceBag, "Bad serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(Ragdoll)

	self._obj.BreakJointsOnDeath = false
	self._maid:GiveTask(function()
		self._obj.BreakJointsOnDeath = true
	end)

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Health"):Connect(function()
		if self._obj.Health <= 0 then
			self._ragdollBinder:Bind(self._obj)
		end
	end))

	return self
end

return PlayerHumanoidBinder.new("RagdollHumanoidOnDeath", RagdollHumanoidOnDeath)
