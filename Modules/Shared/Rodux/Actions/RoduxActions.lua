---
-- @module RoduxActions
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RoduxActionFactory = require("RoduxActionFactory")
local Table = require("Table")

local RoduxActions = {}
RoduxActions.ClassName = "RoduxActions"

function RoduxActions.new(initFunction)
	local self = setmetatable({}, RoduxActions)

	self._initFunction = initFunction or error("No initFunction")

	return self
end

function RoduxActions:Init()
	assert(not rawget(self, "_actionFactories"), "Already initialized")

	self._actionFactories = {}
	self._initFunction(self)
end

function RoduxActions:CreateReducer(initialState, handlers)
	assert(type(handlers) == "table")

	for actionType, func in pairs(handlers) do
		assert(type(func) == "function")
		if not self:Get(actionType) then
			error(("[RoduxActions.CreateReducer] - %q type is not registered"):format(tostring(actionType)), 2)
		end
	end

	return function(state, action)
		if state == nil then
			state = initialState
		end

		local handler = handlers[action.type]

		if handler then
			local validator = self:Get(action.type) or error("No validator")

			assert(validator:Validate(action))

			return handler(state, Table.readonly(Table.copy(action)))
		end

		return state
	end
end

function RoduxActions:Validate(action)
	assert(type(action) == "table")
	assert(type(action.type) == "string")

	local actionFactory = self:Get(action.type)
	if not actionFactory then
		return false, ("%q is not a valid action type"):format(tostring(action.type))
	end

	return actionFactory:Validate(action)
end

function RoduxActions:Get(actionName)
	local actionFactories = rawget(self, "_actionFactories")
	assert(actionFactories, "Not initialized yet")

	return actionFactories[actionName]
end

function RoduxActions:Add(actionName, typeTable)
	local actionFactories = rawget(self, "_actionFactories")
	assert(actionFactories, "Not initialized yet")

	assert(actionFactories[actionName] == nil, "Duplicate action already exists")

	actionFactories[actionName] = RoduxActionFactory.new(actionName, typeTable)
end

function RoduxActions:__index(index)
	if RoduxActions[index] then
		return RoduxActions[index]
	end

	local actionFactories = rawget(self, "_actionFactories")
	assert(actionFactories, "Not initialized yet")

	if actionFactories[index] then
		return actionFactories[index]
	else
		error(("%q Not a valid index"):format(tostring(index)))
	end
end

return RoduxActions