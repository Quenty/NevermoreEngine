-- A system by Seranok to sandbox methods in ROBLOX.
-- https://github.com/matthewdean/sandbox.lua/blob/master/proxy.lua

-- FilteredProxy.lua
-- Modified to allow a "filter" on items to sandbox stuff.


local convertValue do
	
	local pack = function(...)
		-- in Lua 5.2, table.pack
		return {n = select('#',...), ...}
	end
	
	local convertValues = function(Filter, mt, from, to, ...)
		local results = pack(...)
		for i = 1, results.n do
			results[i] = convertValue(Filter, mt,from,to,results[i])
		end
		return unpack(results,1,results.n)
	end

	convertValue = function(Filter, mt, from, to, value)
		-- if there is already a wrapper, return it
		-- no point in making a new one and it ensures consistency
		-- print(Game == Game) --> true

		-- @param mt Metatable, every action should go through this metatable. 
		-- @param to/from Caches/Tables (weak)
		-- @param value The value to wrap into a proxy
		-- @param Filter A function, sends it the value being "accessed", if it returns "true" then the value will act as "nil"
		-- @return The converted / wrapped value. 

		local result = to.lookup[value]
		if result then
			return result
		end
		
		local type = type(value)
		if Filter(value) then
			return nil
		else
			if type == 'table' then
				result =  {}
				-- must be indexed before keys and values are converted
				-- otherwise stack overflow
				to.lookup[value] = result
				from.lookup[result] = value
				for key, value in pairs(value) do
					result[convertValue(Filter, mt,from,to,key)] = convertValue(Filter, mt,from,to,value)
				end
				if not from.trusted then
					-- any future changes by the user to the table
					-- will be picked up by the metatable and transferred to its partner
					setmetatable(value,mt)
				else
					setmetatable(result,mt)
				end
				return result
			elseif type == 'userdata' then
				-- create a userdata to serve as proxy for this one
				result = newproxy(true)
				local metatable = getmetatable(result)
				for event, metamethod in pairs(mt) do
					metatable[event] = metamethod
				end
				to.lookup[value] = result
				from.lookup[result] = value
				return result
			elseif type == 'function' then
				-- unwrap arguments, call function, wrap arguments
				result = function(...)
					local results = pack(ypcall(function(...) return value(...) end,convertValues(Filter, mt,to,from,...)))
					if results[1] then
						return convertValues(Filter, mt,from,to,unpack(results,2,results.n))
					else
						error(results[2],2)
					end
				end
				to.lookup[value] = result
				from.lookup[result] = value
				return result
			else
				-- numbers, strings, booleans, nil, and threads are left as-is
				-- because they are harmless
				return value
			end
		end
	end
end

local proxy = {}

local defaultMetamethods = {
	__len       = function(a) return #a end;
	__unm       = function(a) return -a end;
	__add       = function(a, b) return a + b end;
	__sub       = function(a, b) return a - b end;
	__mul       = function(a, b) return a * b end;
	__div       = function(a, b) return a / b end;
	__mod       = function(a, b) return a % b end;
	__pow       = function(a, b) return a ^ b end;
	__lt        = function(a, b) return a < b end;
	__eq        = function(a, b) return a == b end;
	__le        = function(a, b) return a <= b end;
	__concat    = function(a, b) return a .. b end;
	__call      = function(f, ...) return f(...) end;
	__tostring  = function(a) return tostring(a) end;
	__index     = function(t, k) return t[k] end;
	__newindex  = function(t, k, v) t[k] = v end;
	__metatable = function(t) return getmetatable(t) end;
}

proxy.new = function(options)
	options = options or {}
	local environment = options.environment or getfenv(2) -- defaults to calling function's environment
	local metatable = options.metatable or {}

	-- allow wrappers to be garbage-collected
	local trusted = {trusted = true,lookup = setmetatable({},{__mode='k'})}
	local untrusted = {trusted = false,lookup = setmetatable({},{__mode='v'})}

	local Filter = options.filter or error("[FilteredProxy] - No filter provided")

	for event, metamethod in pairs(defaultMetamethods) do
		-- the metamethod will be fired on the wrapper class
		-- so we need to unwrap the arguments and wrap the return values
		metatable[event] = convertValue(Filter, metatable, trusted, untrusted, metatable[event] or metamethod)
	end

	return convertValue(Filter, metatable, trusted, untrusted, environment)
end

return proxy