--!strict
--[=[
	@class tween

	Advances by last time called by default.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")

return function(_rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(_dis: any?, _start: any?, _goal: any?, _duration: number?) end
end
