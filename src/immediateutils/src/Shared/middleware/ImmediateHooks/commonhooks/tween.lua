--!strict
--[=[
	@class tween

	Advances by last time called by default.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")

return function(_rt: ImmediateTypes.ImmediateRuntime)
	return function(_dis: any?, _start: any?, _goal: any?, _duration: number?) end
end
