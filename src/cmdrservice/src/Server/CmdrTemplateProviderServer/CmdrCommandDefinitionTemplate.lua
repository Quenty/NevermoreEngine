--- Generic command definition template
-- @module CmdrCommandDefinitionTemplate

local HttpService = game:GetService("HttpService")

local value = script:WaitForChild("CmdrJsonCommandData")
return HttpService:JSONDecode(value.Value)