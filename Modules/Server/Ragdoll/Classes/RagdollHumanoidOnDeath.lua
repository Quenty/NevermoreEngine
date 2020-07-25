--- Ragdolls the humanoid on death
-- @classmod RagdollHumanoidOnDeath
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local RagdollBindersServer = require("RagdollBindersServer")

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

function RagdollHumanoidOnDeath.new(humanid)
	local self = setmetatable(BaseObject.new(humanid), RagdollHumanoidOnDeath)

	self._maid:GiveTask(self._obj.Died:Connect(function()
		RagdollBindersServer.Ragdoll:Bind(self._obj)
	end))

	return self
end

return RagdollHumanoidOnDeath