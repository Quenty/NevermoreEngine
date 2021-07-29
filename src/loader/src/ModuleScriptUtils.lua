--- Utility functions for working with module scripts. Core utilites from Quenty's Nevermore.
-- @module ModuleScriptUtils
-- @author Quenty

local ModuleScriptUtils = {}

function ModuleScriptUtils.requireByName(_require, lookupTable)
	assert(type(_require) == "function", "Bad _require")
	assert(type(lookupTable) == "table", "Bad lookupTable")

	return function(_module)
		if typeof(_module)  == "Instance" and _module:IsA("ModuleScript") then
			return _require(_module)
		elseif type(_module) == "string" then
			if lookupTable[_module] then
				return _require(lookupTable[_module])
			else
				error("Error: Library '" .. tostring(_module) .. "' does not exist.", 2)
			end
		elseif type(_module) == "number" then
			return _require(_module)
		else
			error(("Error: module must be a string or ModuleScript, got '%s' for '%s'")
				:format(typeof(_module), tostring(_module)))
		end
	end
end

function ModuleScriptUtils.detectCyclicalRequires(_require)
	assert(type(_require) == "function", "Bad _require")

	local stack = {}
	local loading = {}

	return function(_module, ...)
		assert(typeof(_module) == "Instance" or type(_module) == "number", "Bad _module")

		if loading[_module] then
			local cycle = ModuleScriptUtils.getCyclicalStateFromStack(stack, loading[_module])
			warn(('Warning: Cyclical require on %q.\nCycle: %s')
				:format(ModuleScriptUtils.getModuleFullName(_module), cycle))
			return _require(_module)
		end

		loading[_module] = #stack + 1
		table.insert(stack, _module)

		local result = _require(_module, ...)
		loading[_module] = nil

		assert(table.remove(stack) == _module, "Bad removal")

		return result
	end
end

function ModuleScriptUtils.getModuleName(_module)
	if type(_module) == "number" then
		return ("Module(%d)"):format(_module)
	elseif typeof(_module) == "Instance" then
		return _module.Name
	else
		error("Bad module type")
	end
end

function ModuleScriptUtils.getModuleFullName(_module)
	if type(_module) == "number" then
		return ("Module(%d)"):format(_module)
	elseif typeof(_module) == "Instance" then
		return _module:GetFullName()
	else
		error("Bad module type")
	end
end


function ModuleScriptUtils.getCyclicalStateFromStack(stack, depth)
	local str = ""
	for i=depth, #stack do
		str = str .. ModuleScriptUtils.getModuleName(stack[i]) .. " -> "
	end
	return str .. ModuleScriptUtils.getModuleName(stack[depth])
end

return ModuleScriptUtils