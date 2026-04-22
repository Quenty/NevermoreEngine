--!strict
--[=[
	@class Motor6DStackClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Motor6DStackBase = require("Motor6DStackBase")
local ServiceBag = require("ServiceBag")

local Motor6DStackClient = setmetatable({}, Motor6DStackBase)
Motor6DStackClient.ClassName = "Motor6DStackClient"
Motor6DStackClient.__index = Motor6DStackClient

export type Motor6DStackClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
		},
		{} :: typeof({ __index = Motor6DStackClient })
	))
	& Motor6DStackBase.Motor6DStackBase

function Motor6DStackClient.new(motor6D: Motor6D, serviceBag: ServiceBag.ServiceBag): Motor6DStackClient
	local self: Motor6DStackClient = setmetatable(Motor6DStackBase.new(motor6D, serviceBag) :: any, Motor6DStackClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("Motor6DStack", Motor6DStackClient :: any) :: Binder.Binder<Motor6DStackClient>
