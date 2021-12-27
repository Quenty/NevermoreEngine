--[=[
	Generic command definition template
	@class CmdrCommandDefinitionTemplate
]=]

local HttpService = game:GetService("HttpService")

local value = script:WaitForChild("CmdrJsonCommandData")
return HttpService:JSONDecode(value.Value)