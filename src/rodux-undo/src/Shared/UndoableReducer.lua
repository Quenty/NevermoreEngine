--[=[
	Simple undo redo stack history
	@class UndoableReducer
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local HISTORY_LIMIT = 50

local function insert(state, reduced)
	local start = math.max(1, #state.past - HISTORY_LIMIT + 2)
	local _end = math.min(#state.past, start + HISTORY_LIMIT)

	local newPast = {}
	for i=start, _end do
		newPast[#newPast + 1] = state.past[i]
	end
	newPast[#newPast + 1] = state.present

	return {
		past = newPast;
		present = reduced;
		future = {};
	}
end

return function(reducer)
	local actions = {
		undo = function(state, _action)
			if #state.past == 0 then
				return state
			end

			local newPast = {}
			for i=1, #state.past - 1 do
				newPast[#newPast + 1] = state.past[i]
			end

			return {
				past = newPast;
				present = state.past[#state.past];
				future = Table.mergeLists(state.future, { state.present });
			}
		end;
		redo = function(state, _action)
			if #state.future == 0 then
				return state
			end

			local newFuture = {}
			for i=1, #state.future - 1 do
				newFuture[#newFuture + 1] = state.future[i]
			end

			return {
				past = Table.mergeLists(state.past, { state.present });
				present = state.future[#state.future];
				future = newFuture;
			}
		end;
	}

	return function(state, action)
		state = state or {
			past = {};
			present = reducer(nil, {});
			future = {};
		}

		if not action.type then
			return state
		elseif actions[action.type] then
			return actions[action.type](state, action)
		else
			local reduced = reducer(state.present, action)

			if state.present == reduced then
				return state
			end

			return insert(state, reduced)
		end
	end;
end