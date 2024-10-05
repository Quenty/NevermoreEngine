--[=[
	Retrieves CmdrTemplateProviderServer
	@class CmdrTemplateProviderServer
]=]

local require = require(script.Parent.loader).load(script)

local TemplateProvider = require("TemplateProvider")

return TemplateProvider.new(script.Name, script)