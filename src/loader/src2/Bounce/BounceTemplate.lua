--[=[
	Bounces the current named script to the expected version of this module

	@private
	@class BounceTemplate
]=]

local function waitForValue(objectValue)
	local value = objectValue.Value
	if value then
		return value
	end

	return objectValue.Changed:Wait()
end

return require(waitForValue(script:WaitForChild("BounceTarget")))