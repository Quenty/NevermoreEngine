--- Retrieves CmdrTemplateProviderServer
-- @module CmdrTemplateProviderServer
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local TemplateProvider = require("TemplateProvider")

return TemplateProvider.new(script)