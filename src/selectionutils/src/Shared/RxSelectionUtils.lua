--!strict
--[=[
	@class RxSelectionUtils
]=]

local Selection = game:GetService("Selection")

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")
local Brio = require("Brio")
local ValueObject = require("ValueObject")
local RxBrioUtils = require("RxBrioUtils")
local Set = require("Set")

local RxSelectionUtils = {}

--[=[
	Observes first selection in the selection list which is of a class

	```lua
	RxSelectionUtils.observeFirstSelectionWhichIsA("BasePart"):Subscribe(function(part)
		print("part", part)
	end)
	```

	@param className string
	@return Observable<Instance?>
]=]
function RxSelectionUtils.observeFirstSelectionWhichIsA(className: string): Observable.Observable<Instance?>
	assert(type(className) == "string", "Bad className")

	return RxSelectionUtils.observeFirstSelection(function(inst)
		return inst:IsA(className)
	end)
end

--[=[
	Observes first selection in the selection list which is of a class wrapped in a brio

	```lua
	RxSelectionUtils.observeFirstSelectionWhichIsA("BasePart"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		print("part", brio:GetValue())
	end)
	```

	@param className string
	@return Observable<Brio<Instance>>
]=]
function RxSelectionUtils.observeFirstSelectionWhichIsABrio(
	className: string
): Observable.Observable<Brio.Brio<Instance>>
	assert(type(className) == "string", "Bad className")

	return RxSelectionUtils.observeFirstSelectionBrio(function(inst)
		return inst:IsA(className)
	end) :: any
end

--[=[
	Observes first selection in the selection list which is an "Adornee"

	@return Observable<Instance?>
]=]
function RxSelectionUtils.observeFirstAdornee(): Observable.Observable<Instance?>
	return RxSelectionUtils.observeFirstSelection(function(inst)
		return inst:IsA("BasePart") or inst:IsA("Model")
	end)
end

--[=[
	Observes selection in which are an "Adornee"

	@return Observable<Brio<Instance>>
]=]
function RxSelectionUtils.observeAdorneesBrio(): Observable.Observable<Brio.Brio<Instance>>
	return RxSelectionUtils.observeSelectionItemsBrio():Pipe({
		RxBrioUtils.where(function(inst)
			return inst:IsA("BasePart") or inst:IsA("Model")
		end) :: any,
	}) :: any
end

--[=[
	Observes first selection which meets condition

	```lua
	RxSelectionUtils.observeFirstSelection(function(instance)
		return instance:IsA("BasePart")
	end):Subscribe(function(part)
		print("part", part)
	end)
	```

	@param where callback
	@return Observable<Instance?>
]=]
function RxSelectionUtils.observeFirstSelection(where)
	assert(type(where) == "function", "Bad where")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local current = ValueObject.new(nil)
		maid:GiveTask(current)

		local function handleSelectionChanged()
			for _, item in Selection:Get() do
				if where(item) then
					current.Value = item
					return
				end
			end

			current.Value = nil
		end

		maid:GiveTask(Selection.SelectionChanged:Connect(handleSelectionChanged))
		handleSelectionChanged()

		maid:GiveTask(current:Observe():Subscribe(function(value)
			task.spawn(function()
				sub:Fire(value)
			end)
		end))

		return maid
	end)
end

--[=[
	Observes first selection which meets condition

	@param where callback
	@return Observable<Brio<Instance>>
]=]
function RxSelectionUtils.observeFirstSelectionBrio(where)
	assert(type(where) == "function", "Bad where")

	return RxSelectionUtils.observeFirstSelection(where):Pipe({
		RxBrioUtils.toBrio(),
		RxBrioUtils.onlyLastBrioSurvives(),
		RxBrioUtils.where(function(value)
			return value ~= nil
		end),
	})
end

--[=[
	Observes the current selection table.

	@return Observable<{ Instance }>
]=]
function RxSelectionUtils.observeSelectionList()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local current = Selection:Get()

		maid:GiveTask(Selection.SelectionChanged:Connect(function()
			sub:Fire(Selection:Get())
		end))
		sub:Fire(current)

		return maid
	end)
end

--[=[
	Observes selection items by brio. De-duplicates changed events.

	@return Observable<Brio<Instance>>
]=]
function RxSelectionUtils.observeSelectionItemsBrio()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastSet = {}

		local function handleSelectionChanged()
			local currentSet = Set.fromList(Selection:Get())
			local toRemoveSet = Set.difference(lastSet, currentSet)
			local toAddSet = Set.difference(currentSet, lastSet)
			lastSet = currentSet

			-- Remove first
			for toRemove, _ in toRemoveSet do
				maid[toRemove] = nil
			end

			-- Then add
			for toAdd, _ in toAddSet do
				local brio = Brio.new(toAdd)
				maid[toAdd] = brio

				task.spawn(function()
					sub:Fire(brio)
				end)
			end
		end

		maid:GiveTask(Selection.SelectionChanged:Connect(handleSelectionChanged))
		handleSelectionChanged()

		return maid
	end)
end

return RxSelectionUtils
