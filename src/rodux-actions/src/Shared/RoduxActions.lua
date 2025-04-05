--[=[
	@class RoduxActions
]=]

local require = require(script.Parent.loader).load(script)

local RoduxActionFactory = require("RoduxActionFactory")
local Table = require("Table")

local RoduxActions = {}
RoduxActions.ServiceName = "RoduxActions"
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
	assert(type(handlers) == "table", "Bad handlers")

	for actionType, func in handlers do
		assert(type(func) == "function", "Bad handler")
		if not self:Get(actionType) then
			error(string.format("[RoduxActions.CreateReducer] - %q type is not registered", tostring(actionType)), 2)
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

			return handler(state, Table.readonly(table.clone(action)))
		end

		return state
	end
end

function RoduxActions:Validate(action)
	assert(type(action) == "table", "Bad action")
	assert(type(action.type) == "string","Bad action")

	local actionFactory = self:Get(action.type)
	if not actionFactory then
		return false, string.format("%q is not a valid action type", tostring(action.type))
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
		error(string.format("%q Not a valid index", tostring(index)))
	end
end

return RoduxActions