--!strict
--[=[
	The native methods a mock stands in for, each named by the canonical `Class.Method` the production
	code path bottoms out in -- the interception point is the engine API, not the Nevermore util
	wrapping it. Reflection decides which paths exist; the modelled table below only says what one
	answers until a test says otherwise.

	Every domain is an implementation the mock runs, whether it performs the call -- `Player:Kick`
	really removing the mock from the DataModel -- or answers it, like the truthful
	`MarketplaceService:UserOwnsGamePassAsync` for a fake UserId. Both are displaced the same way, by
	binding a stand-in over them with [PlayerMockMethodUtils.bindMethod] -- over the whole method, or
	over one argument tuple; [PlayerMockMethodUtils.writeLookup] is that bind with a constant answer in
	place of a callback. A domain that models argument and result shapes holds every call and every
	answer to them, whichever stand-in ran.

	Use [PlayerMock.callMethod], [PlayerMock.bindMethod], [PlayerMock.readLookup],
	[PlayerMock.writeLookup] and [PlayerMock.getKickMessage].

	@class PlayerMockMethodUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local BindableEncodingUtils = require("BindableEncodingUtils")
local InstancePathUtils = require("InstancePathUtils")
local PlayerMockCharacterUtils = require("PlayerMockCharacterUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockCoreGuiUtils = require("PlayerMockCoreGuiUtils")
local PlayerMockInputUtils = require("PlayerMockInputUtils")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")
local PlayerMockReflectionUtils = require("PlayerMockReflectionUtils")
local PlayerMockReplicationFocusUtils = require("PlayerMockReplicationFocusUtils")
local PlayerMockUtils = require("PlayerMockUtils")
local Tuple = require("Tuple")
local t: any = require("t")

local PlayerMockMethodUtils = {}

-- The implementation validates its own arguments, the way the engine method it stands in for does.
-- The optional validators are the domain's shapes rather than one implementation's, so they hold
-- whatever stands in for it: the modelled implementation, a bound callback, an injected answer.
type MethodSpec = {
	implementation: (player: Player, ...any) -> ...any,
	validateArguments: ((...any) -> (boolean, string?))?,
	validateReturnValue: ((any) -> (boolean, string?))?,
}

-- Defaults are the truthful answer for a fake UserId: in no group, owning nothing.
local METHODS: { [string]: MethodSpec } = {
	-- GroupService:GetRolesInGroupAsync(userId, groupId) -> { IsMember, Roles = { { Name, Rank } } }
	["GroupService.GetRolesInGroupAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.interface({
			IsMember = t.boolean,
			Roles = t.array(t.interface({
				Name = t.string,
				Rank = t.number,
			})),
		}),
		implementation = function(): any
			return { IsMember = false, Roles = {} }
		end,
	},
	-- GroupService:GetGroupsAsync(userId) -> { { Id, Rank, Role, ... } }. Turns on the mock's own
	-- userId alone, so it is stood in for under a fixed 0.
	["GroupService.GetGroupsAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.array(t.interface({
			Id = t.number,
			Rank = t.number,
			Role = t.string,
		})),
		implementation = function(): any
			return {}
		end,
	},
	-- MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) -> owned
	["MarketplaceService.UserOwnsGamePassAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- MarketplaceService:PlayerOwnsAsset(player, assetId) -> owned (inventory items: hats, gear, ...)
	["MarketplaceService.PlayerOwnsAsset"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- MarketplaceService:PlayerOwnsAssetAsync(player, assetId) -> owned (paid access to a game)
	["MarketplaceService.PlayerOwnsAssetAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- MarketplaceService:PlayerOwnsBundle(player, bundleId) -> owned
	["MarketplaceService.PlayerOwnsBundle"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- MarketplaceService:PromptGamePassPurchase(player, gamePassId) -> whether the mock "user"
	-- accepts the prompt, the engine being unable to prompt a mock.
	["MarketplaceService.PromptGamePassPurchase"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- StarterGui:SetCoreGuiEnabled(coreGuiType, enabled). Effect-recording: production writes it on
	-- the mock local player and the test reads it back. CoreGui starts enabled on a real client.
	["StarterGui.SetCoreGuiEnabled"] = {
		validateArguments = t.tuple(t.enum(Enum.CoreGuiType)),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return true
		end,
	},
	-- UserInputService:IsKeyDown(keyCode) / :IsMouseButtonPressed(userInputType) -> held right now.
	-- Production reads these to learn about a press that began before it was listening; release
	-- through the "UserInputService.InputEnded" service signal.
	["UserInputService.IsKeyDown"] = {
		validateArguments = t.tuple(t.enum(Enum.KeyCode)),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	["UserInputService.IsMouseButtonPressed"] = {
		validateArguments = t.tuple(t.enum(Enum.UserInputType)),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- TeleportService Teleport / TeleportAsync / TeleportToPlaceInstance, keyed by destination
	-- placeId. Effect-recording: production (TeleportServiceUtils) writes a
	-- { via, teleportData?, instanceId?, spawnName? } record and the test reads back the hop.
	["TeleportService.Teleport"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.interface({
			via = t.string,
			teleportData = t.optional(t.table),
		}),
		implementation = function(): any
			return nil
		end,
	},
	-- Players:GetFriendsAsync(userId) -> FriendPages, stored as the flat FriendData array the pages
	-- iterate. Turns on the mock's own userId alone, so it is stood in for under a fixed 0.
	["Players.GetFriendsAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.array(t.interface({
			Id = t.number,
			Username = t.string,
			DisplayName = t.string,
			IsOnline = t.boolean,
		})),
		implementation = function(): any
			return {}
		end,
	},
	-- Player:IsFriendsWithAsync(userId) -> isFriends, keyed by the other player's UserId.
	["Player.IsFriendsWithAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.boolean,
		implementation = function(): boolean
			return false
		end,
	},
	-- UserService:GetUserInfosByUserIdsAsync({ userId })[1] -> { Id, Username, DisplayName,
	-- HasVerifiedBadge }. Turns on the mock's own userId alone, so it is stood in for under a fixed
	-- 0. The default derives from the mock's own identity so identity consumers agree without an
	-- injection.
	["UserService.GetUserInfosByUserIdsAsync"] = {
		validateArguments = t.tuple(t.integer),
		validateReturnValue = t.interface({
			Id = t.number,
			Username = t.string,
			DisplayName = t.string,
			HasVerifiedBadge = t.boolean,
		}),
		implementation = function(player: Player): any
			return {
				Id = PlayerMockPropertyUtils.read(player, "UserId"),
				Username = player.Name,
				DisplayName = PlayerMockPropertyUtils.read(player, "DisplayName"),
				HasVerifiedBadge = PlayerMockPropertyUtils.read(player, "HasVerifiedBadge"),
			}
		end,
	},
	-- MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId) ->
	-- { IsSubscribed, IsRenewing }, keyed by the subscriptionId string (e.g. "EXP-...").
	["MarketplaceService.GetUserSubscriptionStatusAsync"] = {
		-- Subscription ids are strings (e.g. "EXP-..."), and an empty one names nothing.
		validateArguments = t.tuple(t.match("^.+$")),
		validateReturnValue = t.interface({
			IsSubscribed = t.boolean,
			IsRenewing = t.boolean,
		}),
		implementation = function(): any
			return { IsSubscribed = false, IsRenewing = false }
		end,
	},

	["StarterGui.GetCore"] = {
		implementation = function(player: Player, coreName: string): BindableEvent
			return PlayerMockCoreGuiUtils.getCoreEvent(player, coreName)
		end,
	},

	-- The context-restricted `ContextActionService` binds. Each validates what the emulation depends
	-- on and discards the rest; [PlayerMockInputUtils] holds the callbacks they register.
	-- ContextActionService:BindAction(actionName, functionToBind, createTouchButton, ...inputTypes)
	["ContextActionService.BindAction"] = {
		implementation = function(player: Player, actionName: string, functionToBind: any): ()
			PlayerMockInputUtils.bindAction(player, actionName, functionToBind)
		end,
	},
	-- ContextActionService:BindActionAtPriority(actionName, functionToBind, createTouchButton,
	-- priorityLevel, ...inputTypes)
	["ContextActionService.BindActionAtPriority"] = {
		implementation = function(
			player: Player,
			actionName: string,
			functionToBind: any,
			_createTouchButton: any,
			priorityLevel: any
		): ()
			-- Required for signature parity; there is no bind stack to prioritize against.
			assert(type(priorityLevel) == "number", "Bad priorityLevel")

			PlayerMockInputUtils.bindAction(player, actionName, functionToBind)
		end,
	},
	-- ContextActionService:UnbindAction(actionName)
	["ContextActionService.UnbindAction"] = {
		implementation = function(player: Player, actionName: string): ()
			PlayerMockInputUtils.unbindAction(player, actionName)
		end,
	},

	-- Players:GetUserIdFromNameAsync(userName) -> userId, answered from the mocks in the DataModel: a
	-- mock's username is its "UserService.GetUserInfosByUserIdsAsync" domain's `Username`. The
	-- `Players` service is DataModel-wide, so the mock this is called through is only a handle -- any
	-- of them gives the same answer.
	--
	-- Answers nil rather than raising for a name no mock carries, where the real service raises:
	-- production branches to the engine on a miss, and a mock that raised would take that branch away.
	["Players.GetUserIdFromNameAsync"] = {
		implementation = function(_player: Player, userName: string): number?
			assert(type(userName) == "string", "Bad userName")

			for _, tagged in CollectionService:GetTagged(PlayerMockConstants.MOCK_TAG) do
				if PlayerMockUtils.isMock(tagged) then
					local mock = (tagged :: any) :: Player
					local userInfo = (PlayerMockMethodUtils :: any).call(
						mock,
						"UserService.GetUserInfosByUserIdsAsync",
						0
					)
					if userInfo.Username == userName then
						return PlayerMockPropertyUtils.read(mock, "UserId")
					end
				end
			end

			return nil
		end,
	},

	-- Player:Kick(message). Performed rather than recorded: production that kicks expects the player
	-- to actually go, so a mock that only noted the call would leave every later assertion lying.
	["Player.Kick"] = {
		implementation = function(player: Player, message: string?): ()
			assert(message == nil or type(message) == "string", "Bad message")

			local instance = player :: Instance
			instance:SetAttribute(PlayerMockConstants.KICK_MESSAGE_ATTRIBUTE, message or "")

			-- Explicitly, rather than via the Destroying hook, so CharacterRemoving observers still
			-- see a live (parented) mock -- the engine removes the character before the player
			-- instance goes away.
			PlayerMockCharacterUtils.removeCharacter(player)
			instance.Parent = nil
		end,
	},
	-- Player:AddReplicationFocus(part) / :RemoveReplicationFocus(part). The engine offers no getter
	-- for the resulting set, so [PlayerMockReplicationFocusUtils] keeps it where a test can read it.
	["Player.AddReplicationFocus"] = {
		implementation = function(player: Player, part: BasePart): ()
			PlayerMockReplicationFocusUtils.addReplicationFocus(player, part)
		end,
	},
	["Player.RemoveReplicationFocus"] = {
		implementation = function(player: Player, part: BasePart): ()
			PlayerMockReplicationFocusUtils.removeReplicationFocus(player, part)
		end,
	},
}

--[=[
	Calls a native method on a mock, running whichever stand-in it has: a callback bound over the
	whole method through [PlayerMockMethodUtils.bindMethod], otherwise one bound over these arguments
	-- an answer injected through [PlayerMockMethodUtils.writeLookup] among them -- otherwise what the
	domain models. The domain's own shapes hold whichever ran, the arguments going in and the answer
	coming back alike.

	Use [PlayerMock.callMethod].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"MarketplaceService.UserOwnsGamePassAsync"`
	@param ... any -- the engine call's own arguments; for an injected answer, what it turns on
	@return ...any
]=]
function PlayerMockMethodUtils.call(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	...: any
): ...any
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(methodPath), "Bad methodPath")
	assert(PlayerMockMethodUtils._isMethod(methodPath))

	local domainPath = InstancePathUtils.fromPathTable(methodPath)
	PlayerMockMethodUtils._assertArguments(domainPath, ...)

	-- A bound callback displaces the modelled stand-in, the way a stub displaces the real method: a
	-- test that needs logic rather than a value writes it here.
	local binding = PlayerMockMethodUtils._findMethodBinding(player, domainPath)
		or PlayerMockMethodUtils._findMethodBinding(player, domainPath, ...)
	if binding ~= nil then
		return PlayerMockMethodUtils._assertReturnValues(
			domainPath,
			BindableEncodingUtils.invokeEncodedBindableFunction(binding, player, ...)
		)
	end

	local spec = METHODS[domainPath]
	if spec == nil then
		error(
			string.format(
				"%q is a real method, but the mock models no stand-in for it -- bind one with PlayerMockMethodUtils.bindMethod",
				domainPath
			),
			2
		)
	end

	return PlayerMockMethodUtils._assertReturnValues(domainPath, spec.implementation(player, ...))
end

--[=[
	Binds a callback to stand in for a native method on one mock, displacing whatever
	[PlayerMockMethodUtils.call] would otherwise run. The callback receives the mock followed by the
	call's own arguments; binding again replaces the previous callback, and binding nil removes it,
	leaving the domain to answer what it models again.

	Passing the call's arguments narrows the binding to that one argument tuple, leaving every other
	tuple to what the domain models; passing none binds the whole method, which wins over any tuple
	binding. The domain holds the tuple named here to its argument shape, and the callback's answer to
	its result shape when the call runs.

	The path only has to name a real method, so this reaches methods the mock models no default for.

	Returns a function that removes this binding, for a maid to hold. It removes only the binding it
	came from: after a rebind it is a no-op, so an unwinding maid cannot tear down a stand-in that
	replaced its own.

	Use [PlayerMock.bindMethod].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param callback ((player: Player, ...any) -> ...any)? -- nil removes the binding
	@param ... any -- the arguments to bind over, or none for the whole method
	@return () -> ()
]=]
function PlayerMockMethodUtils.bindMethod(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	callback: ((player: Player, ...any) -> ...any)?,
	...: any
): () -> ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(methodPath), "Bad methodPath")
	assert(PlayerMockMethodUtils._isMethod(methodPath))
	assert(callback == nil or type(callback) == "function", "Bad callback")

	local domainPath = InstancePathUtils.fromPathTable(methodPath)
	-- The arguments a binding is keyed by are a call's own, so they are held to the same shapes.
	if select("#", ...) > 0 then
		PlayerMockMethodUtils._assertArguments(domainPath, ...)
	end

	local bindableFunction = PlayerMockMethodUtils._bind(player, domainPath, callback, ...)

	return function()
		-- By name rather than by domain, so a binding over one argument tuple removes itself.
		if bindableFunction and (player :: Instance):FindFirstChild(bindableFunction.Name) == bindableFunction then
			bindableFunction:Destroy()
		end
	end
end

--[=[
	Removes a callback bound through [PlayerMockMethodUtils.bindMethod], so the domain falls back to
	its modelled stand-in. The arguments are the ones the binding was made over; unbinding a method
	that was never bound is a no-op.

	Use [PlayerMock.unbindMethod].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param ... any -- the arguments the binding was made over, or none for the whole method
]=]
function PlayerMockMethodUtils.unbindMethod(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	...: any
): ()
	PlayerMockMethodUtils.bindMethod(player, methodPath, nil, ...)
end

--[=[
	Returns whether a callback is currently bound for the method on this mock, over the arguments
	given or over the whole method when none are.

	Use [PlayerMock.isMethodBound].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param ... any -- the arguments the binding was made over, or none for the whole method
	@return boolean
]=]
function PlayerMockMethodUtils.isMethodBound(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	...: any
): boolean
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(methodPath), "Bad methodPath")
	assert(PlayerMockMethodUtils._isMethod(methodPath))

	local domainPath = InstancePathUtils.fromPathTable(methodPath)
	if select("#", ...) > 0 then
		PlayerMockMethodUtils._assertArguments(domainPath, ...)
	end

	return PlayerMockMethodUtils._findMethodBinding(player, domainPath, ...) ~= nil
end

--[=[
	Reads back what the mock answers for an engine call, the test-side name for
	[PlayerMockMethodUtils.call].

	Use [PlayerMock.readLookup].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- a known lookup domain, e.g. "GroupService.GetRolesInGroupAsync"
	@param ... any -- the engine call's own arguments, the ones the answer turns on
	@return any
]=]
function PlayerMockMethodUtils.readLookup(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	...: any
): any
	return PlayerMockMethodUtils.call(player, methodPath, ...)
end

--[=[
	Injects the answer a mock gives for one argument tuple of an engine call: the
	[PlayerMockMethodUtils.bindMethod] bind, with a constant in place of a callback. Passing nil
	removes the injection, leaving the domain to answer what it models again.

	The domain holds the value to its result shape when it is read, the way it holds any stand-in's
	answer.

	Use [PlayerMock.writeLookup].

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- a known lookup domain, e.g. "MarketplaceService.UserOwnsGamePassAsync"
	@param value any -- must match the domain's result shape; nil removes the injection
	@param ... any -- the engine call's own arguments, the ones the answer turns on
]=]
function PlayerMockMethodUtils.writeLookup(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	value: any,
	...: any
): ()
	PlayerMockMethodUtils.bindMethod(player, methodPath, PlayerMockMethodUtils._constantAnswer(value), ...)
end

--[=[
	Returns the message a mock was kicked with, or nil when the mock was never kicked. The engine has
	no counterpart -- a real `Player:Kick` leaves nothing to read -- so this is the test-side reader
	for the `"Player.Kick"` domain.

	Use [PlayerMock.getKickMessage].

	@param player Player -- must be a PlayerMock
	@return string?
]=]
function PlayerMockMethodUtils.getKickMessage(player: Player): string?
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	local message = (player :: Instance):GetAttribute(PlayerMockConstants.KICK_MESSAGE_ATTRIBUTE)
	return if type(message) == "string" then message else nil
end

-- Every domain the mock models, for the spec that holds them against the engine's own reflection.
function PlayerMockMethodUtils._getMethodDomains(): { string }
	local domains = {}
	for domainPath in METHODS do
		table.insert(domains, domainPath)
	end
	table.sort(domains)

	return domains
end

function PlayerMockMethodUtils._isMethod(methodPath: InstancePathUtils.InstancePathTableLike): (boolean, string?)
	local pathTable = InstancePathUtils.toPathTable(methodPath)
	local path = InstancePathUtils.fromPathTable(pathTable)

	if #pathTable ~= 2 then
		return false, string.format("%q is not a Class.Method path", path)
	end

	local className, methodName = pathTable[1], pathTable[2]
	if not PlayerMockReflectionUtils.isClass(className) then
		return false, string.format("%q names no class the engine reflects", className)
	end

	-- A service, or the `Player` the mock itself is: unlike a property or an event, a method the
	-- mock answers for can be one of its own.
	if className ~= "Player" and not PlayerMockReflectionUtils.isService(className) then
		return false, string.format("%q is neither a service nor Player", className)
	end

	if not PlayerMockReflectionUtils.isClassMethod(className, methodName) then
		return false, string.format("%q is not a method of %s", methodName, className)
	end

	return true
end

function PlayerMockMethodUtils._assertArguments(domainPath: string, ...: any): ()
	local spec = METHODS[domainPath]
	if spec == nil or spec.validateArguments == nil then
		return
	end

	local isValid, message = spec.validateArguments(...)
	if not isValid then
		error(string.format("Bad arguments for %s: %s", domainPath, tostring(message)), 3)
	end
end

-- nil is the absence of an answer rather than one -- what a domain with nothing recorded for these
-- arguments gives back -- so it is the one value no result shape is held against.
function PlayerMockMethodUtils._assertReturnValues(domainPath: string, ...: any): ...any
	local spec = METHODS[domainPath]
	local value = ...
	if spec == nil or spec.validateReturnValue == nil or value == nil then
		return ...
	end

	local isValid, message = spec.validateReturnValue(value)
	if not isValid then
		error(string.format("Bad return value for %s: %s", domainPath, tostring(message)), 3)
	end

	return ...
end

-- An injected answer is a stand-in that ignores the call it was made for; no answer is no stand-in.
function PlayerMockMethodUtils._constantAnswer(value: any): ((player: Player, ...any) -> ...any)?
	if value == nil then
		return nil
	end

	return function(): any
		return value
	end
end

function PlayerMockMethodUtils._bind(
	player: Player,
	domainPath: string,
	callback: ((player: Player, ...any) -> ...any)?,
	...: any
): BindableFunction?
	-- A fresh bindable per bind rather than a new callback on the old one, so a binding has an
	-- identity its own cleanup can recognise.
	local previous = PlayerMockMethodUtils._findMethodBinding(player, domainPath, ...)
	if previous ~= nil then
		previous:Destroy()
	end

	if callback == nil then
		return nil
	end

	local bindableFunction = Instance.new("BindableFunction")
	bindableFunction.Name = PlayerMockMethodUtils._getMethodBindingName(domainPath, ...)
	bindableFunction.OnInvoke = BindableEncodingUtils.encodeCallback(callback)
	bindableFunction.Parent = player :: Instance

	return bindableFunction
end

function PlayerMockMethodUtils._findMethodBinding(player: Player, domainPath: string, ...: any): BindableFunction?
	return (player :: Instance):FindFirstChild(
			PlayerMockMethodUtils._getMethodBindingName(domainPath, ...)
		) :: BindableFunction?
end

function PlayerMockMethodUtils._getMethodBindingName(domainPath: string, ...: any): string
	-- Instance names cannot hold the path separator, so the domain and its arguments flatten
	-- together. Going through the tuple keeps each argument's own type in the name, so two enums
	-- sharing a name cannot collide.
	local flattened = if select("#", ...) == 0 then domainPath else tostring(Tuple.new(domainPath, ...))

	return PlayerMockConstants.METHOD_BINDING_NAME_PREFIX .. (string.gsub(flattened, "[^%w_]", "_"))
end

return PlayerMockMethodUtils
