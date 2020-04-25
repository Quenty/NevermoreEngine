---
-- @classmod RagdollableClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")

local RagdollableClient = setmetatable({}, BaseObject)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

function RagdollableClient.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), RagdollableClient)

	return self
end

return RagdollableClient