--!nonstrict
--[=[
	@class useBinder
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis, instance: Instance, binderTag: string, debug: boolean?)
		local hookState, hookMaid = getOrCreateHookState(rt, dis)

		if hookState.boundObject ~= nil then
			return hookState.boundObject
		end

		if hookState.pendingPromise ~= nil then
			if debug then
				warn(`Pending promise for {binderTag} exists...`)
			end
			return nil
		end

		local binder = rt.serviceBag:GetService(rt.require(binderTag))
		if not binder then
			warn(`No binder found for tag {binderTag}`)
			return nil
		end

		if not hookState.startedBinderPromise then
			if debug then
				warn(`Starting promise for {binderTag}`)
			end
			hookState.startedBinderPromise = true
			hookMaid:GivePromise(binder
				:Promise(instance)
				:Then(function(boundObject)
					if debug then
						warn(`Bound object for {binderTag}!`)
					end
					hookState.boundObject = boundObject
				end)
				:Catch(function(err)
					warn(`Failed to start binder promise for {binderTag}`, err)
					hookState.boundObject = nil
				end))
			return binder:Get(instance)
		end

		return nil
	end
end
