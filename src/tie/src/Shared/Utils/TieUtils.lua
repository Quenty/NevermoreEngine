--!strict
--[=[
	@class TieUtils
]=]

local require = require(script.Parent.loader).load(script)

local BindableEncodingUtils = require("BindableEncodingUtils")

local TieUtils = {}

--[=[
	Encoding arguments for Tie consumption. Namely this will convert any table
	into a closure for encoding.
	@param ... any
	@return ... any
]=]
function TieUtils.encode(...)
	return BindableEncodingUtils.encode(...)
end

--[=[
	Encodes a given callback so it can be assigned to a BindableFunction
	@param callback function
]=]
function TieUtils.encodeCallback(callback)
	return BindableEncodingUtils.encodeCallback(callback)
end

--[=[
	Encodes a given callback so it can be assigned to a BindableFunction
	@param bindableFunction BindableFunction
	@param ... any
	@return any
]=]
function TieUtils.invokeEncodedBindableFunction(bindableFunction: BindableFunction, ...)
	return BindableEncodingUtils.invokeEncodedBindableFunction(bindableFunction, ...)
end

--[=[
	Decodes arguments for Tie consumption.
	@param ... any
	@return ... any
]=]
function TieUtils.decode(...)
	return BindableEncodingUtils.decode(...)
end

return TieUtils
