--- Base class for ragdolls, meant to be used with binders
-- @classmod Ragdoll

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")

local Ragdoll = setmetatable({}, BaseObject)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

function Ragdoll.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), Ragdoll)

	return self
end

return Ragdoll