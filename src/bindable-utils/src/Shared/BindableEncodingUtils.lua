--!strict
--[=[
	Encodes and decodes arguments so they can survive a trip through a
	BindableEvent or BindableFunction. Roblox copies tables sent over a bindable
	and rejects functions and userdata outright, so those values are wrapped in a
	closure which the receiving side calls to retrieve the original reference.

	@class BindableEncodingUtils
]=]

local require = require(script.Parent.loader).load(script)

local Symbol = require("Symbol")

local BindableEncodingUtils = {}

--[=[
	Encodes arguments for transfer over a bindable. Namely this will convert any
	table into a closure so the receiver gets the original value instead of a copy.
	@param ... any
	@return ... any
]=]
function BindableEncodingUtils.encode(...)
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
function BindableEncodingUtils.encodeCallback(callback)
	assert(type(callback) == "function", "Bad callback")

	return function(...)
		return BindableEncodingUtils.encode(callback(BindableEncodingUtils.decode(...)))
	end
end

--[=[
	Invokes a BindableFunction with encoded arguments and decodes the results.
	@param bindableFunction BindableFunction
	@param ... any
	@return any
]=]
function BindableEncodingUtils.invokeEncodedBindableFunction(bindableFunction: BindableFunction, ...)
	assert(typeof(bindableFunction) == "Instance" and bindableFunction:IsA("BindableFunction"), "Bad bindableFunction")

	return BindableEncodingUtils.decode(bindableFunction:Invoke(BindableEncodingUtils.encode(...)))
end

--[=[
	Decodes arguments encoded by [BindableEncodingUtils.encode].
	@param ... any
	@return ... any
]=]
function BindableEncodingUtils.decode(...)
	local results = table.pack(...)

	for i = 1, results.n do
		if type(results[i]) == "function" then
			results[i] = results[i]()
		end
	end

	return unpack(results, 1, results.n)
end

return BindableEncodingUtils
