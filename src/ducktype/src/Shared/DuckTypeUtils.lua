--!strict
--[=[
	Utility method to check interface is equivalent for two implementations

	@class DuckTypeUtils
]=]

local DuckTypeUtils = {}

--[=[
	Returns true if a template is similar to a target

	@param template table
	@param target any
	@return boolean
]=]
function DuckTypeUtils.isImplementation(template: any, target: any): boolean
	assert(type(template) == "table", "Bad template")

	return type(target) == "table"
		and (getmetatable(target) == template or DuckTypeUtils._checkInterface(template, target))
end

function DuckTypeUtils._checkInterface(template: any, target: any): boolean
	local targetMetatable = getmetatable(target)
	local templateMetatable = getmetatable(template)
	if targetMetatable and type(targetMetatable.__index) == "function" then
		-- Indexing into this target could cause an error. Treat it differently and fast-fail
		if templateMetatable then
			return templateMetatable.__index == targetMetatable.__index
		end

		return false
	end

	for key, value in template do
		if type(value) == "function" and type(target[key]) ~= "function" then
			return false
		end
	end

	-- TODO: Prevent infinite recursion potential
	if templateMetatable and type(templateMetatable.__index) == "table" then
		return DuckTypeUtils._checkInterface(templateMetatable.__index, target)
	end

	return true
end

return DuckTypeUtils
