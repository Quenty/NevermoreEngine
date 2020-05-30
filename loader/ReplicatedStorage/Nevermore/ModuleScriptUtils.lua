--- Utility functions for working with module scripts. Core utilites from Quenty's Nevermore.
-- @module ModuleScriptUtils
-- @author Quenty

local ModuleScriptUtils = {}

function ModuleScriptUtils.requireByName(_require, lookupTable)
	assert(type(_require) == "function")
	assert(type(lookupTable) == "table")

	return function(_module)
		if typeof(_module)  == "Instance" and _module:IsA("ModuleScript") then
			return _require(_module)
		elseif type(_module) == "string"then
			if lookupTable[_module] then
				return _require(lookupTable[_module])
			else
				error("Error: Library '" .. tostring(_module) .. "' does not exist.", 2)
			end
		else
			error(("Error: module must be a string or ModuleScript, got '%s' for '%s'")
				:format(typeof(_module), tostring(_module)))
		end
	end
end

function ModuleScriptUtils.detectCyclicalRequires(_require)
	assert(type(_require) == "function")

	local stack = {}
	local loading = {}

	return function(_module, ...)
		assert(typeof(_module) == "Instance")

		if loading[_module] then
			local cycle = ModuleScriptUtils.getCyclicalStateFromStack(stack, loading[_module])
			warn(('Warning: Cyclical require on %q.\nCycle: %s')
				:format( _module:GetFullName(), cycle))
			return _require(_module)
		end

		loading[_module] = #stack + 1
		table.insert(stack, _module)

		local result = _require(_module, ...)
		loading[_module] = nil

		assert(table.remove(stack) == _module)

		return result
	end
end

function ModuleScriptUtils.getCyclicalStateFromStack(stack, depth)
	local str = ""
	for i=depth, #stack do
		str = str .. stack[i].Name .. " -> "
	end
	return str .. stack[depth].Name
end

return ModuleScriptUtils