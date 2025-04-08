--[=[
	Like a template provider, but it also reparents and retrieves tagged objects

	@class TaggedTemplateProvider
]=]

local require = require(script.Parent.loader).load(script)

local TemplateProvider = require("TemplateProvider")
local RxCollectionServiceUtils = require("RxCollectionServiceUtils")

local TaggedTemplateProvider = {}

function TaggedTemplateProvider.new(providerName: string, tagName: string): TemplateProvider.TemplateProvider
	assert(type(providerName) == "string", "bad providerName")
	assert(type(tagName) == "string", "Bad tagName")

	return TemplateProvider.new(providerName, RxCollectionServiceUtils.observeTaggedBrio(tagName))
end

return TaggedTemplateProvider