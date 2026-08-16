--!strict
--[=[
	Budgets the synchronous work the loader does while walking the package tree.

	Bootstrapping recurses over every folder, module script and value in the
	tree in one go, which on a large game can exhaust Roblox's script execution
	timeout. Callers thread a scheduler through that recursion and call
	[LoaderScheduler.YieldIfNeededAsync] as they walk, which spreads the work over
	frames instead of blowing the whole budget at once.

	@class LoaderScheduler
]=]

local DEFAULT_BUDGET_BEFORE_YIELD = 1 / 3
local DEBUG_PRINT_SCHEDULER_YIELD = true

local LoaderScheduler = {}
LoaderScheduler.ClassName = "LoaderScheduler"
LoaderScheduler.__index = LoaderScheduler

export type LoaderScheduler = typeof(setmetatable(
	{} :: {
		_label: string,
		_initialTime: number?,
		_totalComputeTime: number,
		_totalYields: number,
		_budgetBeforeYield: number,
	},
	{} :: typeof({ __index = LoaderScheduler })
))

--[=[
	Constructs a new scheduler with a fresh budget.

	@param label string -- Names the walk being budgeted, for debug output
	@param budgetBeforeYield number? -- Seconds of work allowed before yielding
	@return LoaderScheduler
]=]
function LoaderScheduler.new(label: string, budgetBeforeYield: number?): LoaderScheduler
	assert(type(label) == "string", "Bad label")
	assert(type(budgetBeforeYield) == "number" or budgetBeforeYield == nil, "Bad budgetBeforeYield")

	local self: LoaderScheduler = setmetatable({} :: any, LoaderScheduler)

	self._label = label
	self._initialTime = nil
	self._totalComputeTime = 0
	self._totalYields = 0
	self._budgetBeforeYield = budgetBeforeYield or DEFAULT_BUDGET_BEFORE_YIELD

	return self
end

--[=[
	Returns true if the argument is a loader scheduler

	@param loaderScheduler any?
	@return boolean
]=]
function LoaderScheduler.isLoaderScheduler(loaderScheduler: any): boolean
	return type(loaderScheduler) == "table" and getmetatable(loaderScheduler :: any) == LoaderScheduler
end

--[=[
	Starts the budget over without yielding. Use this when the caller has
	already yielded for its own reasons.

	Pass a start time from [LoaderScheduler.GetBudgetStartTime] to continue a
	window another scheduler already opened, so work handed between schedulers
	inside one frame keeps counting against that frame instead of each walk
	being handed a full budget.

	@param startTime number? -- Defaults to now
]=]
function LoaderScheduler.RestartBudget(self: LoaderScheduler, startTime: number?)
	assert(type(startTime) == "number" or startTime == nil, "Bad startTime")

	self._initialTime = startTime or os.clock()
end

--[=[
	When the current budget window started, or nil if none is open.

	@return number?
]=]
function LoaderScheduler.GetBudgetStartTime(self: LoaderScheduler): number?
	return self._initialTime
end

--[=[
	Clears the budget so the next [LoaderScheduler.YieldIfNeededAsync] starts a
	fresh window. Use this when the walk is done, otherwise the next caller
	measures against however long ago we last yielded.
]=]
function LoaderScheduler.ClearBudget(self: LoaderScheduler)
	self._initialTime = nil
end

--[=[
	Total time spent computing, excluding time spent yielded. Compare against
	wall clock time to see what the yielding is costing.

	@return number
]=]
function LoaderScheduler.GetTotalComputeTime(self: LoaderScheduler): number
	if self._initialTime then
		return self._totalComputeTime + (os.clock() - self._initialTime)
	end

	return self._totalComputeTime
end

--[=[
	Yields if this frame's budget is spent, otherwise returns immediately.

	Callers that yield here have to revalidate whatever they captured before
	the call, since the tree can change while we're yielded.

	@return boolean -- true if we yielded
]=]
function LoaderScheduler.YieldIfNeededAsync(self: LoaderScheduler): boolean
	if not self._initialTime then
		self:RestartBudget()
		return false
	end

	local elapsed = os.clock() - self._initialTime
	if elapsed < self._budgetBeforeYield then
		return false
	end

	self._totalComputeTime += elapsed
	self._totalYields += 1

	if DEBUG_PRINT_SCHEDULER_YIELD then
		warn(
			string.format(
				"[LoaderScheduler] - Delaying %s by a frame (yield %d): held for %.1fms, %.1fms of compute so far",
				self._label,
				self._totalYields,
				elapsed * 1000,
				self._totalComputeTime * 1000
			)
		)
	end

	task.wait()
	self:RestartBudget()

	return true
end

return LoaderScheduler
