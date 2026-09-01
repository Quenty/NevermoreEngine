--!strict
--[[
	Where a run leaves its results for a reader that never saw the return value.

	A test script is free to discard what `runTestsIfNeededAsync` returns, and
	most of them do (`if runTestsIfNeededAsync(root) then return end`). A single
	run does not care — nothing reads its return value — but the batch runner
	reads each package's, and a discarded one costs that package its counts. The
	counts are then only in Jest's printed report, which is the first thing a
	long batch's log window drops.

	So results are left here as well as returned, and the batch runner reads this
	when a package's script returned nothing. That lets a package report its
	counts without its own test script changing.

	Named `.global` for the same reason the loader's tracker is: jest hoists and
	reloads ordinary modules between suites, which would hand the writer and the
	reader two different tables. This one it leaves alone.

	Deliberately dependency-free and behaviourless. It is a mailbox, and the two
	sides of it are in different places — one written by Luau under the loader,
	one read by a raw script with no loader at all — so anything more than a
	field here would have to exist on both sides.
]]

export type State = {
	--[[
		The most recent run's results, as a NevermoreTestResults table.

		Cleared by the batch runner before each package: a stale value credited
		to the wrong package is worse than no value at all.
	]]
	results: any?,
}

local NevermoreTestRunnerState: State = {
	results = nil,
}

return NevermoreTestRunnerState
