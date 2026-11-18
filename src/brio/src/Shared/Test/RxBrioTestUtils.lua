--!strict
--[=[
	Tracks which values of a brio observable are alive, to assert on with `expect`.

	```lua
	local alivePlayers = RxBrioTestUtils.collectAliveList(controller.maid, RxPlayerUtils.observePlayersBrio())

	expect(alivePlayers).toContain(player)

	player:Destroy()

	expect(alivePlayers).never.toContain(player)
	```

	@class RxBrioTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")

local RxBrioTestUtils = {}

--[=[
	Collects the values whose brios are alive, in emission order, until the maid cleans up.

	@param maid Maid
	@param observable Observable<Brio<T>>
	@return { T }
]=]
function RxBrioTestUtils.collectAliveList<T>(maid: Maid.Maid, observable: Observable.Observable<Brio.Brio<T>>): { T }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(Observable.isObservable(observable), "Bad observable")

	local values: { T } = {}
	local aliveBrios: { Brio.Brio<T> } = {}

	maid:GiveTask(observable:Subscribe(function(brio: Brio.Brio<T>)
		if brio:IsDead() then
			return
		end

		-- A nil value can't sit in the list without shifting the brio it's paired with
		local value = brio:GetValue()
		if value == nil then
			return
		end

		table.insert(values, value)
		table.insert(aliveBrios, brio)

		brio:ToMaid():GiveTask(function()
			local index = table.find(aliveBrios, brio)
			if index then
				table.remove(aliveBrios, index)
				table.remove(values, index)
			end
		end)
	end))

	return values
end

--[=[
	Collects the set of values with an alive brio, until the maid cleans up.

	@param maid Maid
	@param observable Observable<Brio<T>>
	@return { [T]: true }
]=]
function RxBrioTestUtils.collectAliveSet<T>(
	maid: Maid.Maid,
	observable: Observable.Observable<Brio.Brio<T>>
): { [T]: true }
	assert(Maid.isMaid(maid), "Bad maid")
	assert(Observable.isObservable(observable), "Bad observable")

	local set: { [T]: true } = {}
	local aliveCounts: { [T]: number } = {}

	maid:GiveTask(observable:Subscribe(function(brio: Brio.Brio<T>)
		if brio:IsDead() then
			return
		end

		local value = brio:GetValue()
		if value == nil then
			return
		end

		aliveCounts[value] = (aliveCounts[value] or 0) + 1
		set[value] = true

		brio:ToMaid():GiveTask(function()
			local remaining = (aliveCounts[value] or 1) - 1
			if remaining <= 0 then
				aliveCounts[value] = nil
				set[value] = nil
			else
				aliveCounts[value] = remaining
			end
		end)
	end))

	return set
end

return RxBrioTestUtils
