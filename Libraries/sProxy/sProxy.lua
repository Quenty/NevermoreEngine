-- A system by Seranok to sandbox methods in ROBLOX.
-- https://github.com/matthewdean/sandbox.lua/blob/master/proxy.lua

local convertValue do
	
	local pack = function(...)
		-- in Lua 5.2, table.pack
		return {n = select('#',...), ...}
	end
	
	local convertValues = function(mt, from, to, ...)
		local results = pack(...)
		for i = 1, results.n do
			results[i] = convertValue(mt,from,to,results[i])
		end
		return unpack(results,1,results.n)
	end

	convertValue = function(mt, from, to, value)
		-- if there is already a wrapper, return it
		-- no point in making a new one and it ensures consistency
		-- print(Game == Game) --> true
		local result = to.lookup[value]
		if result then
			return result
		end
		
		local type = type(value)
		if type == 'table' then
			result =  {}
			-- must be indexed before keys and values are converted
			-- otherwise stack overflow
			to.lookup[value] = result
			from.lookup[result] = value
			for key, value in pairs(value) do
				result[convertValue(mt,from,to,key)] = convertValue(mt,from,to,value)
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
				local results = pack(ypcall(function(...) return value(...) end,convertValues(mt,to,from,...)))
				if results[1] then
					return convertValues(mt,from,to,unpack(results,2,results.n))
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

	for event, metamethod in pairs(defaultMetamethods) do
		-- the metamethod will be fired on the wrapper class
		-- so we need to unwrap the arguments and wrap the return values
		metatable[event] = convertValue(metatable, trusted, untrusted, metatable[event] or metamethod)
	end

	return convertValue(metatable, trusted, untrusted, environment)
end

return proxy