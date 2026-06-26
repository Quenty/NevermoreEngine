--!strict
--[=[
	Generic command definition template which we can use to
	@class CmdrExecutionTemplate
]=]

local function waitForValue(objectValue: Instance): any
	local value = (objectValue :: any).Value
	if value then
		return value
	end

	return (objectValue :: any).Changed:Wait()
end

local cmdrServiceId = waitForValue(script:WaitForChild("CmdrServiceId"))
local cmdrCommandId = waitForValue(script:WaitForChild("CmdrCommandId"))
local commandServiceDefinition = (require :: any)(waitForValue(script:WaitForChild("CmdrServiceTarget")) :: ModuleScript)
local cmdrService = commandServiceDefinition:__getServiceFromId(cmdrServiceId)

return function(...: any): any
	return cmdrService:__executeCommand(cmdrCommandId, ...)
end
