--!strict
--[=[
	Utility functions involving the root part
	@class RootPartUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")

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
function RootPartUtils.promiseRootPart(humanoid: Humanoid): Promise.Promise<BasePart>
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
			warn(debug.traceback("[RootPartUtils.promiseRootPart] - Timed out on root part"))
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

--[=[
	Gets the root part of a character, if it exists
	@param character Model
	@return BasePart? -- Nil if not found
]=]
function RootPartUtils.getRootPart(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil
	end

	return rootPart
end

return RootPartUtils
