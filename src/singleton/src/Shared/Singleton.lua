--!strict
--[=[
	This class converts a class into a singleton
	@class Singleton
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local Singleton = {}
Singleton.ClassName = "Singleton"
Singleton.__index = Singleton

export type Constructor<T> = (serviceBag: _ServiceBag.ServiceBag) -> T
export type Singleton<T> = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_constructor: Constructor<T>,
	},
	{} :: typeof({ __index = Singleton })
))

function Singleton.new<T>(serviceName: string, constructor: Constructor<T>): Singleton<T>
	assert(type(serviceName) == "string", "Bad serviceName")
	assert(type(constructor) == "function", "Bad constructor")

	local self: Singleton<T> = setmetatable({} :: any, Singleton)

	self.ServiceName = assert(serviceName, "No serviceName")
	self._constructor = assert(constructor, "No constructor")

	return self
end

function Singleton.Init<T>(self: Singleton<T>, serviceBag: _ServiceBag.ServiceBag)
	assert((self :: any) ~= Singleton, "Cannot initialize Singleton template directly")

	local object = self._constructor(serviceBag)
	assert(type(object) == "table", "Bad object")

	rawset(object, "ServiceName", self.ServiceName)

	if rawget(object, "Init") then
		object:Init(serviceBag)
	end

	-- Override
	setmetatable(self :: any, { __index = object })
end

return Singleton