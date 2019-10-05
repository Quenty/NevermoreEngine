--- Simple undo redo stack history
-- @module UndoableReducer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

local HISTORY_LIMIT = 25

local function insert(state, reduced)
	local start = math.max(1, #state.past - HISTORY_LIMIT)
	local _end = math.min(#state.past, start + HISTORY_LIMIT)

	local newPast = {}
	for i=start, _end do
		newPast[i] = state.past[i]
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
		undo = function(state, action)
			if #state.past == 0 then
				return state
			end

			local newPast = {}
			for i=1, #state.past - 1 do
				newPast[i] = state.past[i]
			end

			return {
				past = newPast;
				present = state.past[#state.past];
				future = Table.Merge(state.future, { state.present });
			}
		end;
		redo = function(state, action)
			if #state.future == 0 then
				return state
			end

			local newFuture = {}
			for i=1, #state.future - 1 do
				newFuture[i] = state.future[i]
			end

			return {
				past = Table.Merge(state.past, { state.present });
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