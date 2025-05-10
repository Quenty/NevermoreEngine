--[=[
	@class TieUtils
]=]

local require = require(script.Parent.loader).load(script)

local Symbol = require("Symbol")

local TieUtils = {}

--[=[
	Encoding arguments for Tie consumption. Namely this will convert any table
	into a closure for encoding.
	@param ... any
	@return ... any
]=]
function TieUtils.encode(...)
	local results = table.pack(...)

	for i = 1, results.n do
		if
			type(results[i]) == "table"
			or type(results[i]) == "function"
			or typeof(results[i]) == "userdata" -- newproxy() symbols
			or Symbol.isSymbol(results[i])
		then
			local saved = results[i]
			results[i] = function()
				return saved -- Pack into a callback so we can transfer data.
			end
		end
	end

	return unpack(results, 1, results.n)
end

--[=[
	Encodes a given callback so it can be assigned to a BindableFunction
	@param callback function
]=]
function TieUtils.encodeCallback(callback)
	assert(type(callback) == "function", "Bad callback")

	return function(...)
		return TieUtils.encode(callback(TieUtils.decode(...)))
	end
end

--[=[
	Encodes a given callback so it can be assigned to a BindableFunction
	@param bindableFunction BindableFunction
	@param ... any
	@return any
]=]
function TieUtils.invokeEncodedBindableFunction(bindableFunction: BindableFunction, ...)
	assert(typeof(bindableFunction) == "Instance" and bindableFunction:IsA("BindableFunction"), "Bad bindableFunction")

	return TieUtils.decode(bindableFunction:Invoke(TieUtils.encode(...)))
end

--[=[
	Decodes arguments for Tie consumption.
	@param ... any
	@return ... any
]=]
function TieUtils.decode(...)
	local results = table.pack(...)

	for i = 1, results.n do
		if type(results[i]) == "function" then
			results[i] = results[i]()
		end
	end

	return unpack(results, 1, results.n)
end

return TieUtils
