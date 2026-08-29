--!strict
--[=[
	Utility methods for writing Jest specs.

	@class JestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MaidTaskUtils = require("MaidTaskUtils")

local JestUtils = {}

type QueuedTask = {
	job: MaidTaskUtils.MaidTask,
}

local doTask: (MaidTaskUtils.MaidTask) -> ...any = MaidTaskUtils.doTask

local stack: { QueuedTask } = {}

local function unwindStack()
	local errors = {}

	while #stack > 0 do
		local entry = table.remove(stack) :: QueuedTask

		local ok, message = xpcall(doTask, function(err)
			return debug.traceback(tostring(err), 2)
		end, entry.job)
		if not ok then
			table.insert(errors, message)
		end
	end

	if next(errors) then
		error(string.format("[JestUtils.afterThis] - Cleanup failed\n%s", table.concat(errors, "\n")), 0)
	end
end

-- jest-circus rejects a hook added once tests have started, so this has to happen at require
-- time. Each spec file gets its own module instance, so the hook lands in that file's root block.
Jest.Globals.afterEach(unwindStack)

--[=[
	Queues a maid task to be cleaned up once the current test finishes. Tasks unwind in reverse of the
	order they were queued, so teardown mirrors setup the way it would if each task were cleaned up
	right after the code it undoes.

	```lua
	it("reads back what it wrote", function()
		local store = DataStore.new()
		JestUtils.afterThis(store)

		local handle = store:GetHandle()
		JestUtils.afterThis(handle)

		expect(handle:Read()).toEqual(nil)
	end)
	```

	Returns a function that removes the task from the queue again, so an object that outlives its own
	registration can disown the cleanup instead of being destroyed twice.

	```lua
	local maid = Maid.new()
	maid:GiveTask(JestUtils.afterThis(maid))
	```

	Every queued task runs even if an earlier one throws, and the failures are reported together
	against the test that queued them. Tasks queued while the stack is unwinding run before the ones
	still below them.

	@param job MaidTask
	@return () -> () -- Cancels the queued cleanup. Safe to call more than once.
]=]
function JestUtils.afterThis(job: MaidTaskUtils.MaidTask): () -> ()
	assert(MaidTaskUtils.isValidTask(job), "Bad job")

	local entry: QueuedTask = {
		job = job,
	}

	table.insert(stack, entry)

	return function()
		local index = table.find(stack, entry)
		if index then
			table.remove(stack, index)
		end
	end
end

return JestUtils
