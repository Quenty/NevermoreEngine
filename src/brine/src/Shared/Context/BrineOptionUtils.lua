--!strict
--[=[
    @class BrineOptionUtils
]=]

local require = require(script.Parent.loader).load(script)

local BrineTypes = require("BrineTypes")

local BrineOptionUtils = {}

local DEFAULT_HOOK: BrineTypes.InstanceHook = {
	encode = function(_instance: Instance, data: BrineTypes.BrineInstanceWithExtraData?): BrineTypes.BrineInstanceWithExtraData?
		return data
	end,
	decode = function(data: BrineTypes.BrineInstanceWithExtraData): Instance
		return Instance.new(data.ClassName)
	end,
}

function BrineOptionUtils.defaultOptions(options: BrineTypes.BrineOptions?): BrineTypes.SafeBrineOptions
	local current: any = options or {}

	return table.freeze({
		includeDescendants = if current.includeDescendants == nil then true else current.includeDescendants,
		includeAttributes = if current.includeAttributes == nil then true else current.includeDescendants,
		includeTags = if current.includeTags == nil then true else current.includeDescendants,
		instanceHook = if current.instanceHook == nil then DEFAULT_HOOK else current.instanceHook,
		references = current.references,
	})
end

return BrineOptionUtils
