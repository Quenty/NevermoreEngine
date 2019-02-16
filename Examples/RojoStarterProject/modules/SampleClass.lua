--- Sample class with Nevermore
-- @classmod SampleClass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SampleClass = {}
SampleClass.ClassName = "SampleClass"
SampleClass.__index = SampleClass

function SampleClass.new()
	local self = setmetatable({}, SampleClass)

	print("Made new SampleClass")

	return self
end

return SampleClass