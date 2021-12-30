--[=[
	Generic command definition template
	@class CmdrCommandDefinitionTemplate
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
local cmdrService = commandServiceDefinition:__GetServiceFromId(cmdrServiceId)

return function(...)
	return cmdrService:__ExecuteCommand(cmdrCommandId, ...)
end