--!nonstrict
--[=[
	@class ImmediateCommonHooks

	Assembles the built-in hook factories under middleware/ImmediateHooks/commonhooks.
]=]

local rawrequire = require
local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")

local ImmediateCommonHooks = {}

function ImmediateCommonHooks.createHookCallbacks(rt: ImmediateTypes.ImmediateRuntime)
	local hooksFolder = script.Parent.commonhooks
	local hooks = {}
	for _, child in hooksFolder:GetChildren() do
		if child:IsA("ModuleScript") and child.Name ~= "loader" then
			hooks[child.Name] = rawrequire(child)(rt)
		end
	end
	return hooks
end

export type ImmediateHookCallbacks = typeof(ImmediateCommonHooks.createHookCallbacks({} :: ImmediateTypes.ImmediateRuntime))

return ImmediateCommonHooks
