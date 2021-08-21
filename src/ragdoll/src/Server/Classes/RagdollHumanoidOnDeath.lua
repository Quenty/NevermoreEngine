--- Ragdolls the humanoid on death
-- @classmod RagdollHumanoidOnDeath
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

function RagdollHumanoidOnDeath.new(humanid, serviceBag)
	local self = setmetatable(BaseObject.new(humanid), RagdollHumanoidOnDeath)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Health"):Connect(function()
		if self._obj.Health <= 0 then
			self._ragdollBinder:Bind(self._obj)
		end
	end))

	return self
end

return RagdollHumanoidOnDeath