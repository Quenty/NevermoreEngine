--[=[
	@class DuckTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = {}

function DuckTypeUtils.isImplementation(template, target)
	assert(type(template) == "table", "Bad template")

	return type(target) == "table"
		and (getmetatable(target) == template or DuckTypeUtils._checkInterface(template, target))
end

function DuckTypeUtils._checkInterface(template, target)
	for key, value in pairs(template) do
		if type(value) == "function" and type(target[key]) ~= "function" then
			return false
		end
	end

	-- TODO: Prevent infinite recursion potential
	local metatable = getmetatable(template)
	if metatable and type(metatable.__index) == "table" then
		return DuckTypeUtils._checkInterface(metatable.__index, target)
	end

	return true
end

return DuckTypeUtils