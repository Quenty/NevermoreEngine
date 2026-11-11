--!strict
--[=[
	Simple undo redo stack history
	@class UndoableReducer
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local HISTORY_LIMIT = 50

type Action = { type: string?, [string]: any }
type UndoableState = { past: { any }, present: any, future: { any } }
type Reducer = (state: any, action: Action) -> any

local function insert(state: UndoableState, reduced: any): UndoableState
	local start = math.max(1, #state.past - HISTORY_LIMIT + 2)
	local _end = math.min(#state.past, start + HISTORY_LIMIT)

	local newPast: { any } = {}
	for i = start, _end do
		newPast[#newPast + 1] = state.past[i]
	end
	newPast[#newPast + 1] = state.present

	return {
		past = newPast,
		present = reduced,
		future = {},
	}
end

return function(reducer: Reducer): (state: UndoableState?, action: Action) -> UndoableState
	local actions: { [string]: (state: UndoableState, action: Action) -> UndoableState } = {
		undo = function(state: UndoableState, _action: Action): UndoableState
			if #state.past == 0 then
				return state
			end

			local newPast: { any } = {}
			for i = 1, #state.past - 1 do
				newPast[#newPast + 1] = state.past[i]
			end

			return {
				past = newPast,
				present = state.past[#state.past],
				future = Table.mergeLists(state.future, { state.present }),
			}
		end,
		redo = function(state: UndoableState, _action: Action): UndoableState
			if #state.future == 0 then
				return state
			end

			local newFuture: { any } = {}
			for i = 1, #state.future - 1 do
				newFuture[#newFuture + 1] = state.future[i]
			end

			return {
				past = Table.mergeLists(state.past, { state.present }),
				present = state.future[#state.future],
				future = newFuture,
			}
		end,
	}

	return function(state: UndoableState?, action: Action): UndoableState
		local currentState: UndoableState = state or {
			past = {},
			present = reducer(nil, {}),
			future = {},
		}

		if not action.type then
			return currentState
		elseif actions[action.type] then
			return actions[action.type](currentState, action)
		else
			local reduced = reducer(currentState.present, action)

			if currentState.present == reduced then
				return currentState
			end

			return insert(currentState, reduced)
		end
	end
end
