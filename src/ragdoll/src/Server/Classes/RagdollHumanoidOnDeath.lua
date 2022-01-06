--[=[
	Ragdolls the humanoid on death.
	@server
	@class RagdollHumanoidOnDeath
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

--[=[
	Constructs a new RagdollHumanoidOnDeath. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnDeath
]=]
function RagdollHumanoidOnDeath.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnDeath)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Health"):Connect(function()
		if self._obj.Health <= 0 then
			self._ragdollBinder:Bind(self._obj)
		end
	end))

	return self
end

return RagdollHumanoidOnDeath