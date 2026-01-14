--!strict
--[=[
	Helps transform or modify a Motor6D's CFrame over time, on top of Roblox's animation stack.

	@class Motor6DTransformer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local Motor6DTransformer = setmetatable({}, BaseObject)
Motor6DTransformer.ClassName = "Motor6DTransformer"
Motor6DTransformer.__index = Motor6DTransformer

export type Motor6DTransformer =
	typeof(setmetatable(
		{} :: {
			Finished: Signal.Signal<()>,
		},
		{} :: typeof({ __index = Motor6DTransformer })
	))
	& BaseObject.BaseObject

export type GetBelowFunction = () -> CFrame

function Motor6DTransformer.new(): Motor6DTransformer
	local self: Motor6DTransformer = setmetatable(BaseObject.new() :: any, Motor6DTransformer)

	self.Finished = Signal.new()
	self._maid:GiveTask(function()
		self.Finished:Fire()
		self.Finished:Destroy()
	end)

	return self
end

function Motor6DTransformer.Transform(_self: Motor6DTransformer, _getBelow: GetBelowFunction): CFrame?
	error("Not implemented")
end

--[=[
	Fires the Finished signal indicating to cleanup this transformer.
]=]
function Motor6DTransformer.FireFinished(self: Motor6DTransformer): ()
	self.Finished:Fire()
end

return Motor6DTransformer
