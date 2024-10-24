--[=[
	Generic command definition template which we can use to
	@class CmdrExecutionTemplate
]=]

local function waitForValue(objectValue)
	local value = objectValue.Value
	if value then
		return value
	end

	return objectValue.Changed:Wait()
end

local cmdrServiceId = waitForValue(script:WaitForChild("CmdrServiceId"))
local cmdrCommandId = waitForValue(script:WaitForChild("CmdrCommandId"))
local commandServiceDefinition = require(waitForValue(script:WaitForChild("CmdrServiceTarget")))
local cmdrService = commandServiceDefinition:__getServiceFromId(cmdrServiceId)

return function(...)
	return cmdrService:__executeCommand(cmdrCommandId, ...)
end