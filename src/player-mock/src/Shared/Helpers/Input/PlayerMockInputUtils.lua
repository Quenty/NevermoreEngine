--!strict
--[=[
	The action registry behind the context-restricted `ContextActionService` binds a mock stands in
	for. All bind domains share one registry per mock, like the engine's, so rebinding a name
	replaces the callback.

	The binds themselves are modelled in [PlayerMockMethodUtils] with every other native method; this
	is where the callbacks they register live.

	Use [PlayerMock.bindInput], [PlayerMock.isInputBound] and [PlayerMock.fireInput].

	@class PlayerMockInputUtils
]=]

local require = require(script.Parent.loader).load(script)

local BindableEncodingUtils = require("BindableEncodingUtils")
local EnumUtils = require("EnumUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockInputUtils = {}

--[=[
	Registers the callback an action fires, replacing whatever that name was bound to.

	Reached through [PlayerMock.bindInput], which routes the engine's bind domains here.

	@param player Player -- must be a PlayerMock
	@param actionName string
	@param functionToBind (actionName: string, userInputState: Enum.UserInputState, inputObject: any) -> any
]=]
function PlayerMockInputUtils.bindAction(player: Player, actionName: string, functionToBind: any): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")
	assert(type(functionToBind) == "function", "Bad functionToBind")

	local bindableFunction = PlayerMockInputUtils._findActionBindable(player, actionName)
	if bindableFunction == nil then
		local created = Instance.new("BindableFunction")
		created.Name = PlayerMockConstants.ACTION_NAME_PREFIX .. actionName
		created.Parent = player :: Instance
		bindableFunction = created
	end

	-- Encoded so a stand-in InputObject crosses the bindable boundary by reference, keeping its
	-- methods and signals, instead of arriving as a copy.
	(bindableFunction :: BindableFunction).OnInvoke = BindableEncodingUtils.encodeCallback(functionToBind)
end

--[=[
	Drops the callback an action fires. Unbinding an unbound action is a no-op.

	Reached through [PlayerMock.bindInput], which routes the engine's unbind domain here.

	@param player Player -- must be a PlayerMock
	@param actionName string
]=]
function PlayerMockInputUtils.unbindAction(player: Player, actionName: string): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")

	local bindableFunction = PlayerMockInputUtils._findActionBindable(player, actionName)
	if bindableFunction ~= nil then
		bindableFunction:Destroy()
	end
end

--[=[
	Returns whether the given action is currently bound on a mock.

	Use [PlayerMock.isInputBound].

	@param player Player -- must be a PlayerMock
	@param actionName string
	@return boolean
]=]
function PlayerMockInputUtils.isInputBound(player: Player, actionName: string): boolean
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")

	return PlayerMockInputUtils._findActionBindable(player, actionName) ~= nil
end

--[=[
	Errors when the action is not bound.

	Use [PlayerMock.fireInput].

	@param player Player -- must be a PlayerMock
	@param actionName string
	@param userInputState Enum.UserInputState
	@param inputObject any? -- a real InputObject, a plain stand-in table, or a [MockInputObject]
	@return Enum.ContextActionResult?
]=]
function PlayerMockInputUtils.fireInput(
	player: Player,
	actionName: string,
	userInputState: Enum.UserInputState,
	inputObject: any?
): Enum.ContextActionResult?
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")
	assert(EnumUtils.isOfType(Enum.UserInputState, userInputState))

	local bindableFunction = PlayerMockInputUtils._findActionBindable(player, actionName)
	if bindableFunction == nil then
		error(string.format("%q is not a bound action", actionName), 2)
	end

	return BindableEncodingUtils.invokeEncodedBindableFunction(
		bindableFunction,
		actionName,
		userInputState,
		inputObject
	)
end

function PlayerMockInputUtils._findActionBindable(player: Player, actionName: string): BindableFunction?
	return (player :: Instance):FindFirstChild(
			PlayerMockConstants.ACTION_NAME_PREFIX .. actionName
		) :: BindableFunction?
end

return PlayerMockInputUtils
