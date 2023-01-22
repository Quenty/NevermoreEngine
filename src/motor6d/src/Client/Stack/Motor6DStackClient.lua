--[=[
	@class Motor6DStackClient
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DStackBase = require("Motor6DStackBase")

local Motor6DStackClient = setmetatable({}, Motor6DStackBase)
Motor6DStackClient.ClassName = "Motor6DStackClient"
Motor6DStackClient.__index = Motor6DStackClient

function Motor6DStackClient.new(obj, serviceBag)
	local self = setmetatable(Motor6DStackBase.new(obj), Motor6DStackClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Motor6DStackClient