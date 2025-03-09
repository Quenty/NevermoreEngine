--[=[
	@class FilteredObservableListView
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")

local FilteredObservableListView = setmetatable({}, BaseObject)
FilteredObservableListView.ClassName = "FilteredObservableListView"
FilteredObservableListView.__index = FilteredObservableListView

-- Higher numbers last
local function defaultCompare(a, b)
	-- equivalent of `return a - b` except it supports comparison of strings and stuff
	if b > a then
		return -1
	elseif b < a then
		return 1
	else
		return 0
	end
end

function FilteredObservableListView.new(observableList, observeScoreCallback, compare)
	local self = setmetatable(BaseObject.new(), FilteredObservableListView)

	self._compare = compare or defaultCompare
	self._baseList = assert(observableList, "No observableList")
	self._observeScoreCallback = assert(observeScoreCallback, "No observeScoreCallback")

	self._scoredList = self._maid:Add(ObservableSortedList.new(false, function(a, b)
		-- Preserve index when scoring does not
		if a.score == b.score then
			return a.index - b.index
		else
			return self._compare(a.score, b.score)
		end
	end))

	-- Shockingly this is somewhat performant because the sorted list defers all events
	-- to process the list reordering.
	self._maid:GiveTask(self._baseList:ObserveItemsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local entry, key = brio:GetValue()
		local observeScore = self._observeScoreCallback(entry)
		assert(Observable.isObservable(observeScore), "Bad observeScore")

		maid._add = self._scoredList:Add(entry, Rx.combineLatest({
			score = observeScore;
			index = self._baseList:ObserveIndexByKey(key);
		}):Pipe({
			Rx.map(function(state)
				if state.score == nil then
					return nil
				end
				return state
			end)
		}))
	end))

	return self
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T>>
]=]
function FilteredObservableListView:ObserveItemsBrio()
	return self._scoredList:ObserveItemsBrio()
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number>
]=]
function FilteredObservableListView:ObserveIndexByKey(key)
	return self._scoredList:ObserveIndexByKey(key)
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function FilteredObservableListView:GetCount()
	return self._scoredList:GetCount()
end

FilteredObservableListView.__len = FilteredObservableListView.GetCount

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function FilteredObservableListView:ObserveCount()
	return self._scoredList:ObserveCount()
end

return FilteredObservableListView