--!strict
--[=[
	@class FilteredObservableListView
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")
local SortedNode = require("SortedNode")
local Symbol = require("Symbol")

local FilteredObservableListView = setmetatable({}, BaseObject)
FilteredObservableListView.ClassName = "FilteredObservableListView"
FilteredObservableListView.__index = FilteredObservableListView

export type ObservableListLike<T> = {
	ObserveItemsBrio: (self: any) -> Observable.Observable<Brio.Brio<T>>,
	ObserveIndexByKey: (self: any, key: Symbol.Symbol) -> Observable.Observable<number?>,
}

export type FilteredObservableListView<T> =
	typeof(setmetatable(
		{} :: {
			_compare: (any, any) -> number,
			_baseList: ObservableListLike<T>,
			_observeScoreCallback: (T) -> Observable.Observable<any>,
			_scoredList: ObservableSortedList.ObservableSortedList<T>,
		},
		{} :: typeof({ __index = FilteredObservableListView })
	))
	& BaseObject.BaseObject

-- Higher numbers last
local function defaultCompare(a: any, b: any): number
	-- equivalent of `return a - b` except it supports comparison of strings and stuff
	if b > a then
		return -1
	elseif b < a then
		return 1
	else
		return 0
	end
end

function FilteredObservableListView.new<T>(
	observableList: ObservableListLike<T>,
	observeScoreCallback: (T) -> Observable.Observable<any>,
	compare: ((any, any) -> number)?
): FilteredObservableListView<T>
	local self: FilteredObservableListView<T> = setmetatable(BaseObject.new() :: any, FilteredObservableListView)

	self._compare = compare or defaultCompare
	self._baseList = assert(observableList, "No observableList")
	self._observeScoreCallback = assert(observeScoreCallback, "No observeScoreCallback")

	self._scoredList = self._maid:Add(ObservableSortedList.new(false, function(a: any, b: any): number
		-- Preserve index when scoring does not
		if a.score == b.score then
			return a.index - b.index
		else
			return self._compare(a.score, b.score)
		end
	end) :: ObservableSortedList.ObservableSortedList<T>)

	-- Shockingly this is somewhat performant because the sorted list defers all events
	-- to process the list reordering.
	self._maid:GiveTask((self._baseList:ObserveItemsBrio() :: any):Subscribe(function(brio: any)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local entry, key = brio:GetValue()
		local observeScore = self._observeScoreCallback(entry)
		assert(Observable.isObservable(observeScore), "Bad observeScore")

		maid._add = self._scoredList:Add(
			entry,
			(Rx.combineLatest({
				score = observeScore,
				index = self._baseList:ObserveIndexByKey(key),
			}) :: any):Pipe({
				Rx.map(function(state): any
					if state.score == nil then
						return nil
					end
					return state
				end),
			})
		)
	end))

	return self
end

--[=[
	Observes all items in the list
	@return Observable<Brio<T>>
]=]
function FilteredObservableListView.ObserveItemsBrio<T>(
	self: FilteredObservableListView<T>
): Observable.Observable<Brio.Brio<T>>
	return (self._scoredList:ObserveItemsBrio() :: any) :: Observable.Observable<Brio.Brio<T>>
end

--[=[
	Observes the index as it changes, until the entry at the existing
	key is removed.

	@param key Symbol
	@return Observable<number>
]=]
function FilteredObservableListView.ObserveIndexByKey<T>(
	self: FilteredObservableListView<T>,
	key: SortedNode.SortedNode<T>
): Observable.Observable<number>
	return self._scoredList:ObserveIndexByKey(key)
end

--[=[
	Gets the count of items in the list
	@return number
]=]
function FilteredObservableListView.GetCount<T>(self: FilteredObservableListView<T>): number
	return self._scoredList:GetCount()
end

FilteredObservableListView.__len = FilteredObservableListView.GetCount

--[=[
	Observes the count of the list
	@return Observable<number>
]=]
function FilteredObservableListView.ObserveCount<T>(self: FilteredObservableListView<T>): Observable.Observable<number>
	return self._scoredList:ObserveCount()
end

return FilteredObservableListView
