--!strict
--[=[
    @class Motor6DStackHumanoidClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Motor6DStackHumanoidBase = require("Motor6DStackHumanoidBase")
local ServiceBag = require("ServiceBag")

local Motor6DStackHumanoidClient = setmetatable({}, Motor6DStackHumanoidBase)
Motor6DStackHumanoidClient.ClassName = "Motor6DStackHumanoidClient"
Motor6DStackHumanoidClient.__index = Motor6DStackHumanoidClient

export type Motor6DStackHumanoidClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
		},
		{} :: typeof({ __index = Motor6DStackHumanoidClient })
	))
	& Motor6DStackHumanoidBase.Motor6DStackHumanoidBase

function Motor6DStackHumanoidClient.new(
	humanoid: Humanoid,
	serviceBag: ServiceBag.ServiceBag
): Motor6DStackHumanoidClient
	local self: Motor6DStackHumanoidClient =
		setmetatable(Motor6DStackHumanoidBase.new(humanoid, serviceBag) :: any, Motor6DStackHumanoidClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new(
		"Motor6DStackHumanoid",
		Motor6DStackHumanoidClient :: any
	) :: Binder.Binder<Motor6DStackHumanoidClient>
