--[=[
	Utility functions involving the root part
	@class RootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Maid = require("Maid")

local RootPartUtils = {}

local MAX_YIELD_TIME = 60

--[=[
	Given a humanoid creates a promise that will resolve once the `Humanoid.RootPart` property
	resolves properly.

	:::info
	This works around the fact that `humanoid:GetPropertyChangedSignal("RootPart")` does not fire
	when the rootpart changes on a humanoid.
	:::

	@param humanoid Humanoid
	@return Promise<BasePart>
]=]
function RootPartUtils.promiseRootPart(humanoid)
	if humanoid.RootPart then
		return Promise.resolved(humanoid.RootPart)
	end

	-- humanoid:GetPropertyChangedSignal("RootPart") doesn't fire. :(

	local maid = Maid.new()
	local promise = Promise.new()

	task.spawn(function()
		while not humanoid.RootPart and promise:IsPending() do
			task.wait(0.05)
		end
		if humanoid.RootPart then
			promise:Resolve(humanoid.RootPart)
		else
			promise:Reject()
		end
	end)

	task.delay(MAX_YIELD_TIME, function()
		if promise:IsPending() then
			warn("[RootPartUtils.promiseRootPart] - TImed out on root part", debug.traceback())
			promise:Reject("Timed out")
		end
	end)

	maid:GiveTask(humanoid.AncestryChanged:Connect(function()
		if not humanoid:IsDescendantOf(game) then
			promise:Reject("Humanoid removed from game")
		end
	end))

	maid:GiveTask(humanoid.Died:Connect(function()
		promise:Reject("Humanoid died")
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

return RootPartUtils