--!strict
--[=[
	In-memory stand-in for a Roblox `Player`. A real `Player` cannot be `Instance.new`'d and no
	client joins a headless test place, so a mock is a tagged `Folder` typed as a `Player`.

	Guards keep their real-`Player` assert and add an explicit OR clause:

	```lua
	assert(player:IsA("Player") or PlayerMock.isMock(player), "Bad player")
	```

	Native members a Folder cannot expose are read through mock-only accessors, so call sites branch
	explicitly and the real-`Player` path stays plain member access:

	```lua
	local player = PlayerMock.new({ UserId = 12345, AccountAge = 30 })
	player.Parent = game:GetService("Players")

	local userId = if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId

	PlayerMock.write(player, "AccountAge", 31)
	```

	Events follow the same shape through [PlayerMock.getSignal], with [PlayerMock.fireSignal] as the
	test-side trigger:

	```lua
	local chatted = if PlayerMock.isMock(player) then PlayerMock.getSignal(player, "Chatted") else player.Chatted
	maid:GiveTask(chatted:Connect(onChatted))

	PlayerMock.fireSignal(player, "Chatted", "hello")
	```

	Results of argument-keyed engine calls (group rank, gamepass/asset ownership, ...) go through
	[PlayerMock.writeLookup] / [PlayerMock.readLookup], named by the canonical `Service.Method` and
	keyed by the arguments the call turns on:

	```lua
	PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", {
		IsMember = true,
		Roles = { { Name = "Admin", Rank = 230 } },
	}, 372)
	```

	@class PlayerMock
]=]

local require = require(script.Parent.loader).load(script)

local InstancePathUtils = require("InstancePathUtils")
local MockInputObject = require("MockInputObject")
local PlayerMockCharacterUtils = require("PlayerMockCharacterUtils")
local PlayerMockChildrenUtils = require("PlayerMockChildrenUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockInputUtils = require("PlayerMockInputUtils")
local PlayerMockMethodUtils = require("PlayerMockMethodUtils")
local PlayerMockPlayerServiceUtils = require("PlayerMockPlayerServiceUtils")
local PlayerMockPropertyUtils = require("PlayerMockPropertyUtils")
local PlayerMockReplicationFocusUtils = require("PlayerMockReplicationFocusUtils")
local PlayerMockSignalUtils = require("PlayerMockSignalUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMock = {}

export type InputObjectProps = MockInputObject.InputObjectProps

--[=[
	The CollectionService tag every mock carries, and the channel [PlayerMockService] /
	[PlayerMockServiceClient] discover mocks through. Tag resolution is DataModel-scoped, so a mock
	becomes discoverable when it is parented in and drops out when it is destroyed or kicked.

	@prop TAG string
	@readonly
	@within PlayerMock
]=]
PlayerMock.TAG = PlayerMockConstants.MOCK_TAG

--[=[
	Constructs a mock player, unparented -- the caller parents and/or maids it. Once parented into
	the DataModel it is discoverable place-wide in either realm (see [PlayerMock.TAG]).

	Every stand-in property (see [PlayerMock.read]) is seeded from `overrides` or its default.

	```lua
	local player = PlayerMock.new({ UserId = 12345, DisplayName = "Quenty" })
	player.Parent = game:GetService("Players")
	```

	@param overrides { [string]: any }? -- Per-property seed values, keyed by native property name.
	@return Player
]=]
function PlayerMock.new(overrides: { [string]: any }?): Player
	assert(overrides == nil or type(overrides) == "table", "Bad overrides")

	local userId = if overrides then overrides.UserId else nil
	assert(userId == nil or type(userId) == "number", "Bad UserId override")

	local player = Instance.new("Folder")
	player.Name = if userId ~= nil then string.format("PlayerMock_%d", userId) else "PlayerMock"
	player:AddTag(PlayerMockConstants.MOCK_TAG)

	local castPlayer = (player :: any) :: Player

	PlayerMockPropertyUtils.seedProperties(castPlayer, overrides)
	PlayerMockChildrenUtils.seedContainers(castPlayer)

	-- The engine removes a player's character when they leave or are kicked.
	player.Destroying:Connect(function()
		PlayerMockCharacterUtils.removeCharacter(castPlayer)
	end)

	return castPlayer
end

--[=[
	Returns whether the given value is a [PlayerMock]. A foreign instance merely carrying
	[PlayerMock.TAG] is rejected.

	```lua
	assert(player:IsA("Player") or PlayerMock.isMock(player), "Bad player")
	```

	@param value any
	@return boolean
]=]
function PlayerMock.isMock(value: any): boolean
	return PlayerMockUtils.isMock(value)
end

--[=[
	Returns the nearest ancestor of `instance` that is a [PlayerMock], or nil. The mock counterpart
	of `FindFirstAncestorWhichIsA("Player")`, which a mock's backing Folder is invisible to:

	```lua
	local player = instance:FindFirstAncestorWhichIsA("Player") or PlayerMock.findFirstAncestorMock(instance)
	```

	Like the engine call, the walk starts at the parent -- `instance` itself is never returned.

	@param instance Instance
	@return Player?
]=]
function PlayerMock.findFirstAncestorMock(instance: Instance): Player?
	return PlayerMockUtils.findFirstAncestorMock(instance)
end

--[=[
	Returns the mock in the DataModel whose `UserId` stand-in matches, or nil. The mock counterpart
	of `Players:GetPlayerByUserId`, for code paths keyed by userId alone with no player value in hand
	to `isMock`-branch on:

	```lua
	local mockPlayer = PlayerMock.getMockByUserId(userId)
	if mockPlayer ~= nil then
		result = PlayerMock.readLookup(mockPlayer, "MarketplaceService.UserOwnsGamePassAsync", gamePassId)
	else
		result = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end
	```

	Like the engine call, only mocks in the game resolve. Seed UserIds uniquely -- the first match wins.

	@param userId number
	@return Player?
]=]
function PlayerMock.getMockByUserId(userId: number): Player?
	return PlayerMockPlayerServiceUtils.getPlayerByUserId(userId)
end

--[=[
	Returns the mocks in the DataModel. The mock counterpart of `Players:GetPlayers()`:

	```lua
	for _, player in Players:GetPlayers() do
		handlePlayer(player)
	end
	for _, player in PlayerMock.getMocks() do
		handlePlayer(player)
	end
	```

	@return { Player }
]=]
function PlayerMock.getMocks(): { Player }
	return PlayerMockUtils.getMocks()
end

--[=[
	Returns the signal that fires when a mock enters the DataModel. The mock counterpart of
	`Players.PlayerAdded`, which mocks are invisible to:

	```lua
	maid:GiveTask(Players.PlayerAdded:Connect(handlePlayer))
	maid:GiveTask(PlayerMock.getMockAddedSignal():Connect(handlePlayer))
	```

	Fires when a mock is parented in -- which is when [PlayerMock.getMocks] starts returning it --
	not when it is constructed.

	@return RBXScriptSignal
]=]
function PlayerMock.getMockAddedSignal(): RBXScriptSignal
	return PlayerMockUtils.getMockAddedSignal()
end

--[=[
	Returns the signal that fires when a mock leaves the DataModel, whether it was destroyed or
	merely unparented (which is how [PlayerMock.kick] ends a mock). The mock counterpart of
	`Players.PlayerRemoving`, connected alongside it like [PlayerMock.getMockAddedSignal].

	@return RBXScriptSignal
]=]
function PlayerMock.getMockRemovingSignal(): RBXScriptSignal
	return PlayerMockUtils.getMockRemovingSignal()
end

--[=[
	Returns the mock in the DataModel whose `Character` stand-in is the given model, or nil. The
	mock counterpart of `Players:GetPlayerFromCharacter`:

	```lua
	local player = Players:GetPlayerFromCharacter(model) or PlayerMock.getMockFromCharacter(model)
	```

	Like the engine call, only the exact character model matches -- a descendant part resolves nil.

	@param character Instance
	@return Player?
]=]
function PlayerMock.getMockFromCharacter(character: Instance): Player?
	return PlayerMockCharacterUtils.getMockFromCharacter(character)
end

--[=[
	Reads a stand-in native property off a mock. Errors on anything that is not a [PlayerMock],
	including a real `Player`, so call sites branch explicitly:

	```lua
	local userId = if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
	```

	A bare name reads a `Player` property. A `Service.Property` path reads the mock's own copy of a
	client-global service member, which a headless server has only one of:

	```lua
	local selected = PlayerMock.read(player, "GuiService.SelectedObject")
	```

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@return any
]=]
function PlayerMock.read(player: Player, propertyPath: InstancePathUtils.InstancePathTableLike): any
	return PlayerMockPropertyUtils.read(player, propertyPath)
end

--[=[
	Mocks a native property on a mock, firing [PlayerMock.getPropertyChangedSignal] so observers see
	the change. Takes the same paths [PlayerMock.read] does.

	```lua
	PlayerMock.write(player, "AccountAge", 31)
	PlayerMock.write(player, "GuiService.SelectedObject", button)
	```

	Writing `Character = nil` carries the engine's despawn semantics -- see [PlayerMock.removeCharacter].

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@param value any
]=]
function PlayerMock.write(player: Player, propertyPath: InstancePathUtils.InstancePathTableLike, value: any): ()
	PlayerMockPropertyUtils.write(player, propertyPath, value)
end

--[=[
	Returns the signal that fires when the given stand-in property changes on a mock. Mock-only,
	like [PlayerMock.read] -- the real-Player path stays `player:GetPropertyChangedSignal(propertyName)`.

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@return RBXScriptSignal
]=]
function PlayerMock.getPropertyChangedSignal(
	player: Player,
	propertyPath: InstancePathUtils.InstancePathTableLike
): RBXScriptSignal
	return PlayerMockPropertyUtils.getPropertyChangedSignal(player, propertyPath)
end

--[=[
	Calls a native method on a mock, running whichever stand-in it has: a callback bound over the
	whole method through [PlayerMock.bindMethod], otherwise an answer injected for these arguments
	through [PlayerMock.writeLookup], otherwise what the domain models.

	```lua
	if PlayerMock.isMock(player) then
		PlayerMock.callMethod(player, "Player.AddReplicationFocus", part)
	else
		player:AddReplicationFocus(part)
	end
	```

	The path is validated against the engine's reflection, so a typo errors instead of silently
	standing in for a method production could never have called.

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"MarketplaceService.UserOwnsGamePassAsync"`
	@param ... any -- the engine call's own arguments; for a lookup, what its answer turns on
	@return ...any
]=]
function PlayerMock.callMethod(player: Player, methodPath: InstancePathUtils.InstancePathTableLike, ...: any): ...any
	return PlayerMockMethodUtils.call(player, methodPath, ...)
end

--[=[
	Binds a callback to stand in for a native method on one mock, displacing whatever
	[PlayerMock.callMethod] would otherwise run. Use it where a value is not enough and the stand-in
	has to compute -- an answer that varies per call, or a method the mock models no default for.

	```lua
	PlayerMock.bindMethod(player, "Players.GetFriendsAsync", function(_player, _userId)
		return if attempts > 1 then friends else error("Rate limited")
	end)
	```

	The callback receives the mock followed by the call's own arguments. Binding again replaces the
	previous callback, and binding nil removes it; [PlayerMock.unbindMethod] is that same removal
	under a name that says so.

	Passing the call's arguments narrows the binding to that one argument tuple, the way
	[PlayerMock.writeLookup] injects a value for one; passing none binds the whole method.

	Returns a function that removes this binding, so a maid can hold it:

	```lua
	maid:GiveTask(PlayerMock.bindMethod(player, "Players.GetFriendsAsync", stubFriends))
	```

	It removes only the binding it came from -- after a rebind it is a no-op -- so a maid unwinding
	late cannot tear down a stand-in that replaced its own.

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param callback ((player: Player, ...any) -> ...any)? -- nil removes the binding
	@param ... any -- the arguments to bind over, or none for the whole method
	@return () -> ()
]=]
function PlayerMock.bindMethod(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	callback: ((player: Player, ...any) -> ...any)?,
	...: any
): () -> ()
	return PlayerMockMethodUtils.bindMethod(player, methodPath, callback, ...)
end

--[=[
	Removes a callback bound through [PlayerMock.bindMethod], so the method falls back to its
	modelled stand-in. The arguments are the ones the binding was made over; unbinding a method that
	was never bound is a no-op.

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param ... any -- the arguments the binding was made over, or none for the whole method
]=]
function PlayerMock.unbindMethod(player: Player, methodPath: InstancePathUtils.InstancePathTableLike, ...: any): ()
	PlayerMockMethodUtils.unbindMethod(player, methodPath, ...)
end

--[=[
	Returns whether a callback is currently bound for the method on this mock, over the arguments
	given or over the whole method when none are.

	@param player Player -- must be a PlayerMock
	@param methodPath InstancePathTableLike -- `"Player.Kick"` or `"Players.GetFriendsAsync"`
	@param ... any -- the arguments the binding was made over, or none for the whole method
	@return boolean
]=]
function PlayerMock.isMethodBound(
	player: Player,
	methodPath: InstancePathUtils.InstancePathTableLike,
	...: any
): boolean
	return PlayerMockMethodUtils.isMethodBound(player, methodPath, ...)
end

--[=[
	Reads back what a mock answers for an argument-keyed engine call, the test-side name for
	[PlayerMock.callMethod]. The value is the raw engine result shape, so production parsing runs
	over it unchanged:

	```lua
	if PlayerMock.isMock(player) then
		return PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", groupId)
	end
	return GroupService:GetRolesInGroupAsync(player.UserId, groupId)
	```

	Effect-recording domains (e.g. `StarterGui.SetCoreGuiEnabled`) run the same machinery in the
	other direction: production writes through [PlayerMock.writeLookup] and the test reads here.

	@param player Player -- must be a PlayerMock
	@param domain InstancePathTableLike -- a known lookup domain, e.g. "GroupService.GetRolesInGroupAsync"
	@param ... any -- the engine call's own arguments, the ones the answer turns on
	@return any
]=]
function PlayerMock.readLookup(player: Player, domain: InstancePathUtils.InstancePathTableLike, ...: any): any
	return PlayerMockMethodUtils.readLookup(player, domain, ...)
end

--[=[
	Injects the result a mock answers for an argument-keyed engine call -- [PlayerMock.bindMethod]
	over those arguments, with a constant in place of a callback. Passing nil removes the injection,
	leaving the domain to answer what it models again.

	```lua
	PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", {
		IsMember = true,
		Roles = { { Name = "Admin", Rank = 230 } },
	}, 372)
	PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", true, 12345)
	```

	@param player Player -- must be a PlayerMock
	@param domain InstancePathTableLike -- a known lookup domain, e.g. "MarketplaceService.UserOwnsGamePassAsync"
	@param value any -- must match the domain's result shape; nil removes the injection
	@param ... any -- the engine call's own arguments, the ones the answer turns on
]=]
function PlayerMock.writeLookup(
	player: Player,
	domain: InstancePathUtils.InstancePathTableLike,
	value: any,
	...: any
): ()
	PlayerMockMethodUtils.writeLookup(player, domain, value, ...)
end

--[=[
	Emulates `Player:LoadCharacterAsync()` on a mock. The caller supplies the character model -- e.g.
	`Players:CreateHumanoidModelFromUserId`/`FromDescription` (both work in cloud test runs) or a
	hand-built rig -- or omits it to get a default R15 built from an empty `HumanoidDescription`
	(which may yield).

	```lua
	local character = PlayerMock.loadCharacterAsync(player, rig)
	```

	The sequence encodes the engine's [avatar loading event ordering](https://devforum.roblox.com/t/avatar-loading-event-ordering-improvements/269607),
	which PlayerMock.spec asserts step by step:

	1. `CharacterRemoving(old)` fires while `Character` still points at the old, parented model
	2. `Character` nils, then the old character is destroyed
	3. the new rig is fully built before any signal fires
	4. `Character` is set to the new model
	5. the new character is parented to the Workspace
	6. `CharacterAdded(new)` fires
	7. `HasAppearanceLoaded` flips true and `CharacterAppearanceLoaded(new)` fires
	8. the call returns

	`CharacterAdded` fires only during avatar loading, which is why a plain
	`PlayerMock.write(player, "Character", model)` deliberately does not fire it.

	Each call also replaces the [PlayerMock.getBackpack] stand-in with a fresh empty one, like the
	engine does on respawn (minus the StarterPack copy). The first call additionally inserts the
	[PlayerMock.getStarterGear] stand-in, which later spawns keep.

	@param player Player -- must be a PlayerMock
	@param character Model? -- the new character; nil builds a default R15 rig
	@return Model
]=]
function PlayerMock.loadCharacterAsync(player: Player, character: Model?): Model
	return PlayerMockCharacterUtils.loadCharacterAsync(player, character)
end

--[=[
	[PlayerMock.loadCharacterAsync] with a minimal hand-built rig -- an anchored `HumanoidRootPart`
	(the `PrimaryPart`) and a `Humanoid`. Building it never yields, so specs that only need *a*
	character spawn instantly:

	```lua
	local character = PlayerMock.loadMinimalCharacterAsync(playerMock)
	```

	@param player Player -- must be a PlayerMock
	@return Model
]=]
function PlayerMock.loadMinimalCharacterAsync(player: Player): Model
	return PlayerMockCharacterUtils.loadMinimalCharacterAsync(player)
end

--[=[
	Emulates the character being removed with no replacement, i.e. `player.Character = nil`:
	`CharacterRemoving` fires while `Character` still points at the model, `Character` is set to nil,
	and the model is destroyed. No-op when no character is loaded.

	Runs automatically when the mock is destroyed or kicked.

	@param player Player -- must be a PlayerMock
]=]
function PlayerMock.removeCharacter(player: Player): ()
	PlayerMockCharacterUtils.removeCharacter(player)
end

--[=[
	Returns the mock's current `Backpack` stand-in, or nil before the first spawn. It is a genuine
	`Backpack` parented to the mock, so production code observing its children works unchanged.
	[PlayerMock.loadCharacterAsync] replaces it with a fresh empty one on every spawn:

	```lua
	local character = PlayerMock.loadCharacterAsync(player, rig)
	local backpack = assert(PlayerMock.getBackpack(player))
	tool.Parent = backpack
	```

	@param player Player -- must be a PlayerMock
	@return Backpack?
]=]
function PlayerMock.getBackpack(player: Player): Backpack?
	return PlayerMockChildrenUtils.getBackpack(player)
end

--[=[
	Returns the mock's current `StarterGear` stand-in, or nil before the first spawn. It is a genuine
	`StarterGear` parented to the mock, and unlike the Backpack it survives respawns. Consumers that
	dot-index `player.StarterGear` branch:

	```lua
	local starterGear = if PlayerMock.isMock(player)
		then PlayerMock.getStarterGear(player)
		else player.StarterGear
	```

	@param player Player -- must be a PlayerMock
	@return StarterGear?
]=]
function PlayerMock.getStarterGear(player: Player): StarterGear?
	return PlayerMockChildrenUtils.getStarterGear(player)
end

--[=[
	Returns the mock's `PlayerGui` stand-in, parented at construction. It is really a `Folder` named
	"PlayerGui", so consumers branch instead of using `FindFirstChildOfClass`:

	```lua
	local playerGui = if PlayerMock.isMock(player)
		then PlayerMock.getPlayerGui(player)
		else player:FindFirstChildOfClass("PlayerGui")
	```

	[PlayerGuiUtils] branches this way internally, so its consumers work against a mock unchanged.

	@param player Player -- must be a PlayerMock
	@return PlayerGui
]=]
function PlayerMock.getPlayerGui(player: Player): PlayerGui
	return PlayerMockChildrenUtils.getPlayerGui(player)
end

--[=[
	Returns the mock's `PlayerScripts` stand-in, parented at construction. Like the PlayerGui stand-in
	it is really a `Folder`, which can never satisfy an `IsA("PlayerScripts")` filter, so consumers
	observing the child by class branch on the class name:

	```lua
	local playerScriptsClassName = if PlayerMock.isMock(localPlayer) then "Folder" else "PlayerScripts"
	RxInstanceUtils.observeLastNamedChildBrio(localPlayer, playerScriptsClassName, "PlayerScripts")
	```

	@param player Player -- must be a PlayerMock
	@return PlayerScripts
]=]
function PlayerMock.getPlayerScripts(player: Player): PlayerScripts
	return PlayerMockChildrenUtils.getPlayerScripts(player)
end

--[=[
	Emulates `Player:Kick(message)` on a mock, performing the removal sequence rather than merely
	recording the call:

	1. the message is recorded for [PlayerMock.getKickMessage]
	2. the character is removed (see [PlayerMock.removeCharacter])
	3. the mock leaves the DataModel (`Parent = nil`, not a destroy -- a held reference stays
	   readable), so `AncestryChanged` genuinely fires

	```lua
	if PlayerMock.isMock(player) then
		PlayerMock.kick(player, reason)
	else
		player:Kick(reason)
	end
	```

	`Players.PlayerRemoving` is a `Players`-service event only the engine fires, so consumers of it
	cannot observe a mock kick -- observe `AncestryChanged` instead.

	@param player Player -- must be a PlayerMock
	@param message string? -- recorded for [PlayerMock.getKickMessage]; nil records ""
]=]
function PlayerMock.kick(player: Player, message: string?): ()
	PlayerMockMethodUtils.call(player, "Player.Kick", message)
end

--[=[
	Returns the message a mock was kicked with via [PlayerMock.kick], or nil when it was never kicked.
	A kick with no message reads back as `""`. Stays readable after the kick, as long as the caller
	holds a reference.

	@param player Player -- must be a PlayerMock
	@return string?
]=]
function PlayerMock.getKickMessage(player: Player): string?
	return PlayerMockMethodUtils.getKickMessage(player)
end

--[=[
	Emulates `Player:AddReplicationFocus(part)` on a mock. The backing is a set, so adding a part
	already focused does nothing.

	```lua
	if PlayerMock.isMock(player) then
		PlayerMock.addReplicationFocus(player, part)
	else
		player:AddReplicationFocus(part)
	end
	```

	@param player Player -- must be a PlayerMock
	@param part BasePart
]=]
function PlayerMock.addReplicationFocus(player: Player, part: BasePart): ()
	PlayerMockMethodUtils.call(player, "Player.AddReplicationFocus", part)
end

--[=[
	Emulates `Player:RemoveReplicationFocus(part)` on a mock. The removal half of the branch in
	[PlayerMock.addReplicationFocus]; removing a part that is not focused is a no-op.

	@param player Player -- must be a PlayerMock
	@param part BasePart
]=]
function PlayerMock.removeReplicationFocus(player: Player, part: BasePart): ()
	PlayerMockMethodUtils.call(player, "Player.RemoveReplicationFocus", part)
end

--[=[
	Returns the parts currently focused on a mock, in the order they were added. The engine has no
	counterpart -- a real `Player`'s focuses can only be added and removed -- so this is the test-side
	reader for [PlayerMock.addReplicationFocus] / [PlayerMock.removeReplicationFocus].

	@param player Player -- must be a PlayerMock
	@return { BasePart }
]=]
function PlayerMock.getReplicationFocuses(player: Player): { BasePart }
	return PlayerMockReplicationFocusUtils.getReplicationFocuses(player)
end

--[=[
	Reads a stand-in native event off a mock: the genuine native signal for events the backing Folder
	inherits from `Instance`, otherwise a signal a test fires through [PlayerMock.fireSignal]. The
	path is validated against the engine's reflection, so a typo errors instead of returning a signal
	that can never fire.

	```lua
	local chatted = if PlayerMock.isMock(player) then PlayerMock.getSignal(player, "Chatted") else player.Chatted
	```

	A bare name reads a `Player` event. A `Service.Event` path reads the mock's own copy of a
	client-global service event, which a headless server has only one of -- see
	[PlayerMock.getServiceSignal].

	@param player Player -- must be a PlayerMock
	@param eventPath InstancePathTableLike -- `"Chatted"` or `"UserInputService.WindowFocused"`
	@return RBXScriptSignal
]=]
function PlayerMock.getSignal(player: Player, eventPath: InstancePathUtils.InstancePathTableLike): RBXScriptSignal
	return PlayerMockSignalUtils.getSignal(player, eventPath)
end

--[=[
	Fires the backing signal for an event on a mock, so code connected through [PlayerMock.getSignal]
	observes the event as if the engine had fired it. Takes the same paths [PlayerMock.getSignal] does.

	```lua
	PlayerMock.fireSignal(player, "Chatted", "hello")
	PlayerMock.fireSignal(player, "UserInputService.WindowFocused")
	```

	Events the backing Folder inherits from `Instance` resolve to genuine native signals, which only
	the engine fires, so they cannot be fired here.

	@param player Player -- must be a PlayerMock
	@param eventPath InstancePathTableLike -- `"Chatted"` or `"UserInputService.WindowFocused"`
	@param ... any -- Event arguments delivered to connected handlers.
]=]
function PlayerMock.fireSignal(player: Player, eventPath: InstancePathUtils.InstancePathTableLike, ...: any): ()
	PlayerMockSignalUtils.fireSignal(player, eventPath, ...)
end

--[=[
	Reads a stand-in for a client service's event off a mock -- `UserInputService.WindowFocused`,
	`UserInputService.InputEnded`, and the like -- which a test fires through
	[PlayerMock.fireServiceSignal]:

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer ~= nil and PlayerMock.isMock(localPlayer) then
		return PlayerMock.getServiceSignal(localPlayer, "UserInputService.WindowFocused")
	end
	return UserInputService.WindowFocused
	```

	Named sugar over [PlayerMock.getSignal], which takes the same `Service.Event` path -- the mock is
	only where the backing lives.

	Arguments cross a `BindableEvent`, so they are marshalled: EnumItems, numbers and strings arrive
	intact, but a table's methods and metatable do not survive. Hand a [PlayerMock.makeInputObject]
	stand-in to [PlayerMock.fireInput] instead when the handler calls methods on it.

	@param player Player -- must be a PlayerMock
	@param domain InstancePathTableLike -- a canonical Service.Event, e.g. "UserInputService.WindowFocused"
	@return RBXScriptSignal
]=]
function PlayerMock.getServiceSignal(player: Player, domain: InstancePathUtils.InstancePathTableLike): RBXScriptSignal
	return PlayerMockSignalUtils.getSignal(player, domain)
end

--[=[
	Fires the backing signal for a client service's event on a mock, so code connected through
	[PlayerMock.getServiceSignal] observes the event as if the engine had fired it. Named sugar over
	[PlayerMock.fireSignal].

	```lua
	PlayerMock.fireServiceSignal(player, "UserInputService.WindowFocused")
	```

	@param player Player -- must be a PlayerMock
	@param domain InstancePathTableLike -- a canonical Service.Event, e.g. "UserInputService.WindowFocused"
	@param ... any -- Event arguments delivered to connected handlers.
]=]
function PlayerMock.fireServiceSignal(player: Player, domain: InstancePathUtils.InstancePathTableLike, ...: any): ()
	PlayerMockSignalUtils.fireSignal(player, domain, ...)
end

--[=[
	Emulates a context-restricted `ContextActionService` call on a mock. The args after the domain are
	the engine call's own, so a production mock branch is the identical call aimed at the mock:

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer ~= nil and PlayerMock.isMock(localPlayer) then
		PlayerMock.bindInput(localPlayer, "ContextActionService.BindAction", "Drag", onDragAction, false, Enum.UserInputType.MouseButton2)
	else
		ContextActionService:BindAction("Drag", onDragAction, false, Enum.UserInputType.MouseButton2)
	end
	```

	Unbinding goes through the same entry point -- the domain names the operation:

	```lua
	PlayerMock.bindInput(localPlayer, "ContextActionService.UnbindAction", "Drag")
	```

	A test dispatches a bound action through [PlayerMock.fireInput]. Deliberately not modelled: touch
	buttons, priority routing, input-type routing, and the engine's bind stack. All bind domains
	share one action registry per mock, like the engine's, so rebinding a name replaces the callback.

	@param player Player -- must be a PlayerMock
	@param domain InstancePathTableLike -- a known input domain, e.g. "ContextActionService.BindAction"
	@param actionName string
	@param ... any -- the engine call's remaining args, e.g. `functionToBind, createTouchButton, ...inputTypes`
]=]
function PlayerMock.bindInput(
	player: Player,
	domain: InstancePathUtils.InstancePathTableLike,
	actionName: string,
	...: any
): ()
	PlayerMockMethodUtils.call(player, domain, actionName, ...)
end

--[=[
	Returns whether the given action is currently bound on a mock via [PlayerMock.bindInput].

	@param player Player -- must be a PlayerMock
	@param actionName string
	@return boolean
]=]
function PlayerMock.isInputBound(player: Player, actionName: string): boolean
	return PlayerMockInputUtils.isInputBound(player, actionName)
end

--[=[
	Dispatches a bound action on a mock, invoking the bound callback with
	`(actionName, userInputState, inputObject)` -- the engine's argument order -- and returning its
	result. Errors when the action is not bound.

	```lua
	PlayerMock.fireInput(player, "Drag", Enum.UserInputState.Begin, input)
	```

	`inputObject` is passed by reference, so hand it a real `InputObject`, a plain table of the fields
	the callback reads, or a [PlayerMock.makeInputObject] stand-in when the callback also needs
	`:GetPropertyChangedSignal(...)`.

	@param player Player -- must be a PlayerMock
	@param actionName string
	@param userInputState Enum.UserInputState
	@param inputObject any? -- a real InputObject, a plain stand-in table, or a makeInputObject stand-in
	@return Enum.ContextActionResult?
]=]
function PlayerMock.fireInput(
	player: Player,
	actionName: string,
	userInputState: Enum.UserInputState,
	inputObject: any?
): Enum.ContextActionResult?
	return PlayerMockInputUtils.fireInput(player, actionName, userInputState, inputObject)
end

--[=[
	Builds a stand-in `InputObject` for [PlayerMock.fireInput] to hand a bound action, for handlers
	that read more than the raw fields -- in particular `:GetPropertyChangedSignal("UserInputState")`.
	A real `InputObject` is not `Instance.new`-able, so this is a plain table exposing the fields and
	that one method; drive the press lifecycle with `:SetUserInputState(...)`:

	```lua
	local input = PlayerMock.makeInputObject({ UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonA })
	PlayerMock.fireInput(mock, actionName, Enum.UserInputState.Begin, input)
	input:SetUserInputState(Enum.UserInputState.End)
	```

	@param props InputObjectProps?
	@return table -- an InputObject stand-in
]=]
function PlayerMock.makeInputObject(props: InputObjectProps?): any
	return MockInputObject.new(props)
end

--[=[
	Sets the mock's stand-in for `GuiService.SelectedObject`, or clears it with nil. A headless server
	has no PlayerGui, so the engine rejects `GuiService.SelectedObject = obj` outright and selection
	code branches:

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer ~= nil and PlayerMock.isMock(localPlayer) then
		PlayerMock.setSelectedGuiObject(localPlayer, button)
	else
		GuiService.SelectedObject = button
	end
	```

	Named sugar over `PlayerMock.write(player, "GuiService.SelectedObject", guiObject)`, which reads
	and writes the same per-mock store.

	@param player Player -- must be a PlayerMock
	@param guiObject GuiObject? -- the focused object, or nil to clear
]=]
function PlayerMock.setSelectedGuiObject(player: Player, guiObject: GuiObject?): ()
	assert(guiObject == nil or (typeof(guiObject) == "Instance" and guiObject:IsA("GuiObject")), "Bad guiObject")

	PlayerMockPropertyUtils.write(player, "GuiService.SelectedObject", guiObject)
end

--[=[
	Reads the mock's stand-in for `GuiService.SelectedObject`, or nil when nothing is selected. The
	read side of the same branch as [PlayerMock.setSelectedGuiObject].

	@param player Player -- must be a PlayerMock
	@return GuiObject?
]=]
function PlayerMock.getSelectedGuiObject(player: Player): GuiObject?
	return PlayerMockPropertyUtils.read(player, "GuiService.SelectedObject")
end

--[=[
	Returns the signal that fires when the mock's stand-in for `GuiService.SelectedObject` changes,
	standing in for `GuiService:GetPropertyChangedSignal("SelectedObject")`.

	@param player Player -- must be a PlayerMock
	@return RBXScriptSignal
]=]
function PlayerMock.getSelectedGuiObjectChangedSignal(player: Player): RBXScriptSignal
	return PlayerMockPropertyUtils.getPropertyChangedSignal(player, "GuiService.SelectedObject")
end

--[=[
	Designates a mock as the local player for the client realm, or clears it with nil. Read back
	through [PlayerMock.getMockedLocalPlayer].

	```lua
	maid:GiveTask(PlayerMock.setMockedLocalPlayer(player))
	```

	Call this directly *before* booting bags to pre-designate -- matching production, where
	`Players.LocalPlayer` exists before any service runs -- and a booting [PlayerMockServiceClient]
	adopts the designation and owns its cleanup. After boot, designate through
	[PlayerMockServiceClient.SetLocalPlayer] instead.

	The mock must already be parented into the DataModel, the designation being a tag that
	`GetTagged` only resolves for parented instances.

	The returned disposer restores whatever was designated before this call, so nested designations
	unwind correctly. It is a no-op when the designation has since moved on, and calling it more than
	once is safe.

	@param player Player? -- must be a PlayerMock in the DataModel, or nil to clear
	@return () -> () -- Restores the previous designation. Safe to call more than once.
]=]
function PlayerMock.setMockedLocalPlayer(player: Player?): () -> ()
	return PlayerMockPlayerServiceUtils.setMockedLocalPlayer(player)
end

--[=[
	Returns the mock designated as the local player, or nil. This is only ever the mock -- there is
	deliberately no helper resolving the real `Players.LocalPlayer`, so call sites fall back
	explicitly and the real read stays visible to luau-lsp:

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	```

	@return Player?
]=]
function PlayerMock.getMockedLocalPlayer(): Player?
	return PlayerMockUtils.getMockedLocalPlayer()
end

return PlayerMock
