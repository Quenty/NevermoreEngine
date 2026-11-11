--!strict
--[=[
	@class RoduxActions
]=]

local require = require(script.Parent.loader).load(script)

local RoduxActionFactory = require("RoduxActionFactory")
local Table = require("Table")

local RoduxActions = {}
RoduxActions.ServiceName = "RoduxActions"
RoduxActions.ClassName = "RoduxActions"

export type RoduxActions = typeof(setmetatable(
	{} :: {
		_initFunction: (RoduxActions) -> (),
		_actionFactories: { [string]: RoduxActionFactory.RoduxActionFactory },
	},
	{} :: typeof({ __index = RoduxActions })
))

function RoduxActions.new(initFunction: (RoduxActions) -> ()): RoduxActions
	local self: RoduxActions = setmetatable({}, RoduxActions) :: any

	self._initFunction = initFunction or error("No initFunction")

	return self
end

function RoduxActions.Init(self: RoduxActions): ()
	assert(not rawget(self :: any, "_actionFactories"), "Already initialized")

	self._actionFactories = {}
	self._initFunction(self)
end

function RoduxActions.CreateReducer(
	self: RoduxActions,
	initialState: any,
	handlers: { [string]: (state: any, action: any) -> any }
): (state: any, action: any) -> any
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

function RoduxActions.Validate(self: RoduxActions, action: any): (boolean, string?)
	assert(type(action) == "table", "Bad action")
	assert(type(action.type) == "string", "Bad action")

	local actionFactory = self:Get(action.type)
	if not actionFactory then
		return false, string.format("%q is not a valid action type", tostring(action.type))
	end

	return actionFactory:Validate(action)
end

function RoduxActions.Get(self: RoduxActions, actionName: string): RoduxActionFactory.RoduxActionFactory?
	local actionFactories = rawget(self :: any, "_actionFactories")
	assert(actionFactories, "Not initialized yet")

	return actionFactories[actionName]
end

function RoduxActions.Add(self: RoduxActions, actionName: string, typeTable: { [any]: any }?): ()
	local actionFactories = rawget(self :: any, "_actionFactories")
	assert(actionFactories, "Not initialized yet")

	assert(actionFactories[actionName] == nil, "Duplicate action already exists")

	actionFactories[actionName] = RoduxActionFactory.new(actionName, typeTable)
end

(RoduxActions :: any).__index = function(self, index)
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
