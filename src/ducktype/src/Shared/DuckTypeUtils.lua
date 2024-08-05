--[=[
	Utility method to check interface is equivalent for two implementations

	@class DuckTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = {}

--[=[
	Returns true if a template is similar to a target

	@param template table
	@param target any
	@return boolean
]=]
function DuckTypeUtils.isImplementation(template, target)
	assert(type(template) == "table", "Bad template")

	return type(target) == "table"
		and (getmetatable(target) == template or DuckTypeUtils._checkInterface(template, target))
end

function DuckTypeUtils._checkInterface(template, target)
	local targetMetatable = getmetatable(target)
	local templateMetatable = getmetatable(template)
	if targetMetatable and type(targetMetatable.__index) == "function" then
		-- Indexing into this target could cause an error. Treat it differently and fast-fail
		if templateMetatable then
			return targetMetatable.__index == templateMetatable.__index
		end

		return false
	end

	for key, value in pairs(template) do
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