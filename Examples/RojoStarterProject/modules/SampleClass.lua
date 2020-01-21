--- Sample class with Nevermore
-- @classmod SampleClass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local SampleClass = {}
SampleClass.ClassName = "SampleClass"
SampleClass.__index = SampleClass

function SampleClass.new()
	local self = setmetatable({}, SampleClass)

	self._maid = Maid.new()
	print("Made new SampleClass")

	return self
end

return SampleClass