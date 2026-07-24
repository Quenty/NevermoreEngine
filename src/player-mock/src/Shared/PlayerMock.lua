--!strict
--[=[
	In-memory stand-in for a Roblox `Player` used by tests. A real `Player` cannot be
	`Instance.new`'d and no client joins a headless Open Cloud test place, so this builds a
	`Folder` that carries the marker and identity attributes production code reads -- letting a
	"player" flow through guards and providers without a real join.

	It is the shared replacement for the ad-hoc `Instance.new("Folder") :: Player` stand-ins that
	had accreted across the test suites. Guards keep their hard `Player` assert and add an explicit
	OR clause so support for the mock is greppable rather than a silent weakening:

	```lua
	assert(player:IsA("Player") or PlayerMock.isMock(player), "Bad player")
	```

	Native `Player` members a Folder cannot expose are read through [PlayerMock.read], which is
	mock-only and errors on anything else (including a real `Player`). Consumers branch explicitly --
	`if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId` -- so the
	real-Player path stays plain member access that luau-lsp can type-check. Each property is backed by
	a same-named attribute (Instance-valued members like `Character` by an ObjectValue child), so a test
	can mock a value and observe changes via [PlayerMock.getPropertyChangedSignal]:

	```lua
	local player = PlayerMock.new({ UserId = 12345, AccountAge = 30 })
	player.Parent = game:GetService("Players") -- where real players live; see PlayerMockService.CreatePlayer

	assert(PlayerMock.isMock(player))
	assert(PlayerMock.read(player, "UserId") == 12345)
	assert(PlayerMock.read(player, "MembershipType") == Enum.MembershipType.None)

	PlayerMock.write(player, "AccountAge", 31) -- fires GetAttributeChangedSignal("AccountAge")
	```

	Native `Player` events follow the same shape through [PlayerMock.getSignal] -- mock-only, with
	the name validated against the engine's reflected `Player` events so a typo errors instead of
	returning a signal that can never fire -- and [PlayerMock.fireSignal] as the test-side trigger:

	```lua
	local chatted = if PlayerMock.isMock(player) then PlayerMock.getSignal(player, "Chatted") else player.Chatted
	maid:GiveTask(chatted:Connect(onChatted))

	PlayerMock.fireSignal(player, "Chatted", "hello") -- test-side
	```

	Results of ID-keyed engine calls (group rank, gamepass/asset ownership, ...) that production
	code fetches from a Roblox web API by (player, id) follow the same shape through
	[PlayerMock.writeLookup] / [PlayerMock.readLookup], with the domain named after the canonical
	`Service.Method` being intercepted. The injected result lives on the mock -- one attribute per
	(domain, key) -- so it is centralized per player: every consumer whose answer derives from the
	same engine call resolves the same value, instead of each call site stubbing its own copy that
	can drift.

	```lua
	PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
		IsMember = true,
		Roles = { { Name = "Admin", Rank = 230 } },
	})
	-- GroupUtils.promiseRankInGroup(player, 372) now resolves 230 everywhere it is asked,
	-- and promiseRoleInGroup(player, 372) resolves the matching "Admin". Values are the raw
	-- engine result shape (see GroupTestUtils.assignGroupInfo for a friendlier writer).
	```

	@class PlayerMock
]=]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReflectionService = game:GetService("ReflectionService")
local Workspace = game:GetService("Workspace")

local PlayerMock = {}

-- CollectionService tag stamped on every mock: the single marker answering both "is this value
-- a mock?" ([PlayerMock.isMock]) and the reverse question "which mocks exist?" -- needed by
-- enumerating consumers like [PlayerMock.getMockByUserId] and [PlayerMockService.GetPlayerMocks].
-- Real Players never carry it, so the recognition can never false-positive on a real join.
-- `GetTagged` only resolves instances in the DataModel, which matches the engine calls being
-- mirrored (`Players:GetPlayerByUserId`, `Players:GetPlayers`): they only resolve players that
-- are in the game.
local MOCK_TAG = "PlayerMock"

--[=[
	The CollectionService tag every mock carries from construction: the place-wide discovery channel
	[PlayerMockService] and [PlayerMockServiceClient] observe. Replication is the default -- a real
	`Player` exists for every peer, so a mock is discoverable from any ServiceBag in either realm the
	moment it is parented into the DataModel (tag resolution is DataModel-scoped), and a destroyed
	(or kicked) mock drops out automatically.

	@prop TAG string
	@readonly
	@within PlayerMock
]=]
PlayerMock.TAG = MOCK_TAG

-- CollectionService tag marking the mock a test designated as the local player for the client realm
-- (via PlayerMockServiceClient). Carrying the designation on the mock itself -- rather than in Lua module
-- state -- keeps it inspectable and self-cleaning (a destroyed mock takes the designation with it), while
-- still letting DI-less code like dummy-mode Remoting resolve it.
local LOCAL_PLAYER_TAG = "PlayerMockLocalPlayer"

-- Shared with PlayerMockUtils (same package) so [PlayerMockUtils.observeMockedLocalPlayer] can watch
-- the designation change via the tag signals. Not public API -- consumers observe the designation
-- through that observable rather than the raw tag.
PlayerMock._LOCAL_PLAYER_TAG = LOCAL_PLAYER_TAG

type PropertySpec = {
	default: any,
	-- Instance-valued member: backed by a prefixed ObjectValue child instead of an attribute
	-- (attributes cannot hold Instances). Observed through [PlayerMock.getPropertyChangedSignal].
	instanceValued: boolean?,
	-- Bridges a value shape that a Roblox attribute cannot hold (e.g. an EnumItem) to/from a storable one.
	encode: ((any) -> any)?,
	decode: ((any) -> any)?,
}

-- Native `Player` properties a mock stands in for, each backed by a same-named attribute (so a test can
-- seed/mock the value and observe changes). Values are pre-authored with the real member's type/shape --
-- a `Player` cannot be `Instance.new`'d, so the defaults cannot be reflected off a live instance.
-- EnumItem-typed members (which attributes cannot store) round-trip through their `.Name`;
-- Instance-typed members (which attributes cannot store at all) are backed by an ObjectValue child.
local PLAYER_PROPERTIES: { [string]: PropertySpec } = {
	UserId = { default = 0 },
	DisplayName = { default = "" },
	MembershipType = {
		default = Enum.MembershipType.None,
		encode = function(value: any): string
			return (value :: EnumItem).Name
		end,
		decode = function(value: any): EnumItem
			return (Enum.MembershipType :: any)[value]
		end,
	},
	AccountAge = { default = 0 },
	HasVerifiedBadge = { default = false },
	FollowUserId = { default = 0 },
	Character = { instanceValued = true }, -- default nil, like a real Player before spawn
	ReplicationFocus = { instanceValued = true }, -- default nil; streaming focus stand-in
	RespawnLocation = { instanceValued = true }, -- default nil; checkpoint spawn stand-in
}

-- Prefix for the ObjectValue children backing Instance-valued stand-in properties. Like the
-- attribute backings, the value lives on the mock itself: inspectable and self-cleaning.
local PROPERTY_OBJECT_NAME_PREFIX = "PlayerMockProperty_"

local function findPropertyObjectValue(player: Player, propertyName: string): ObjectValue?
	return (player :: Instance):FindFirstChild(PROPERTY_OBJECT_NAME_PREFIX .. propertyName) :: ObjectValue?
end

local function getOrCreatePropertyObjectValue(player: Player, propertyName: string): ObjectValue
	local existing = findPropertyObjectValue(player, propertyName)
	if existing ~= nil then
		return existing
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = PROPERTY_OBJECT_NAME_PREFIX .. propertyName
	objectValue.Parent = player :: Instance
	return objectValue
end

--[=[
	Constructs a mock player. The returned value is typed as `Player` for drop-in use, but is really
	a marked `Folder`; it is unparented -- the caller parents and/or `maid:Add`s it as needed. Once
	parented into the DataModel it is replicated: discoverable place-wide through [PlayerMockService] /
	[PlayerMockServiceClient] in any ServiceBag, either realm (see [PlayerMock.TAG]).

	Every stand-in property (see [PlayerMock.read]) is seeded as an attribute from `overrides` (keyed by
	native property name, e.g. `UserId`), or the pre-authored default, so reads resolve without a real
	Player.

	@param overrides { [string]: any }? -- Per-property seed values, keyed by native property name.
	@return Player
]=]
function PlayerMock.new(overrides: { [string]: any }?): Player
	assert(overrides == nil or type(overrides) == "table", "Bad overrides")

	local userId = if overrides then overrides.UserId else nil
	assert(userId == nil or type(userId) == "number", "Bad UserId override")

	local player = Instance.new("Folder")
	player.Name = if userId ~= nil then string.format("PlayerMock_%d", userId) else "PlayerMock"
	CollectionService:AddTag(player, MOCK_TAG)

	local castPlayer = (player :: any) :: Player

	-- Seed each stand-in property as an attribute (mockable + observable via GetAttributeChangedSignal).
	for propertyName, spec in PLAYER_PROPERTIES do
		local value: any
		if overrides and overrides[propertyName] ~= nil then
			value = overrides[propertyName]
		elseif propertyName == "DisplayName" then
			value = player.Name
		else
			value = spec.default
		end

		if value ~= nil then
			PlayerMock.write(castPlayer, propertyName, value)
		end
	end

	-- The engine inserts a player's PlayerGui at join; mirror that with a stand-in. PlayerGui is
	-- not Instance.new-able (unlike Backpack), so like the mock itself this is a Folder cast to
	-- the native type, resolved through the explicit isMock branch (see PlayerMock.getPlayerGui).
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player

	-- The engine likewise inserts a player's PlayerScripts at join; mirror that with a stand-in.
	-- PlayerScripts is not Instance.new-able either, so this too is a Folder resolved through the
	-- explicit isMock branch (see PlayerMock.getPlayerScripts).
	local playerScripts = Instance.new("Folder")
	playerScripts.Name = "PlayerScripts"
	playerScripts.Parent = player

	-- The engine removes a player's character when the player leaves or is kicked; mirror that so
	-- a destroyed mock cannot leak its character into the Workspace.
	player.Destroying:Connect(function()
		PlayerMock.removeCharacter(castPlayer)
	end)

	return castPlayer
end

--[=[
	Returns whether the given value is a [PlayerMock]. Intended for use alongside a real-Player check
	in a guard, e.g. `player:IsA("Player") or PlayerMock.isMock(player)`.

	@param value any
	@return boolean
]=]
function PlayerMock.isMock(value: any): boolean
	-- A mock's backing instance is always a Folder (see [PlayerMock.new]); requiring it rejects
	-- foreign instances that merely carry the tag.
	return typeof(value) == "Instance" and value:IsA("Folder") and CollectionService:HasTag(value, MOCK_TAG)
end

--[=[
	Returns the nearest ancestor of `instance` that is a [PlayerMock], or nil. The mock counterpart
	of `FindFirstAncestorWhichIsA("Player")` -- a mock's backing Folder is invisible to an `IsA`
	walk, so code resolving the owning player from a descendant adds the explicit OR clause:

	```lua
	local player = instance:FindFirstAncestorWhichIsA("Player") or PlayerMock.findFirstAncestorMock(instance)
	```

	Like the engine call, the walk starts at the parent -- `instance` itself is never returned.

	@param instance Instance
	@return Player?
]=]
function PlayerMock.findFirstAncestorMock(instance: Instance): Player?
	assert(typeof(instance) == "Instance", "Bad instance")

	local ancestor = instance.Parent
	while ancestor ~= nil do
		if PlayerMock.isMock(ancestor) then
			return (ancestor :: any) :: Player
		end
		ancestor = ancestor.Parent
	end

	return nil
end

--[=[
	Returns the mock currently in the DataModel whose `UserId` stand-in matches, or nil. The mock
	counterpart of `Players:GetPlayerByUserId` -- the resolver for code paths keyed by userId alone
	(e.g. [MarketplaceUtils.promiseUserOwnsGamePass]), where no player value is in hand to
	`isMock`-branch on:

	```lua
	local mockPlayer = PlayerMock.getMockByUserId(userId)
	if mockPlayer ~= nil then
		result = PlayerMock.readLookup(mockPlayer, "MarketplaceService.UserOwnsGamePassAsync", gamePassId)
	else
		result = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end
	```

	Like the engine call, only mocks in the game resolve -- discovery runs over [PlayerMock.TAG],
	and tag resolution is DataModel-scoped, so an unparented (or destroyed) mock reads back as nil.
	Real UserIds are unique; seed mocks the same way, since the first match wins.

	@param userId number
	@return Player?
]=]
function PlayerMock.getMockByUserId(userId: number): Player?
	assert(type(userId) == "number", "Bad userId")

	for _, tagged in CollectionService:GetTagged(MOCK_TAG) do
		if PlayerMock.isMock(tagged) and PlayerMock.read((tagged :: any) :: Player, "UserId") == userId then
			return (tagged :: any) :: Player
		end
	end

	return nil
end

--[=[
	Returns the mock currently in the DataModel whose username stand-in matches, or nil. The mock
	counterpart of `Players:GetUserIdFromNameAsync` -- the resolver for code paths keyed by username
	alone (e.g. [PlayersServicePromises.promiseUserIdFromName]). A mock's username is its
	"UserService.GetUserInfosByUserIdsAsync" lookup's `Username`, which defaults to the mock's
	`Name` -- the same member that holds a real Player's username.

	Like [PlayerMock.getMockByUserId], only mocks in the game resolve, and the first match wins.

	@param username string
	@return Player?
]=]
function PlayerMock.getMockByUsername(username: string): Player?
	assert(type(username) == "string", "Bad username")

	for _, tagged in CollectionService:GetTagged(MOCK_TAG) do
		if PlayerMock.isMock(tagged) then
			local mock = (tagged :: any) :: Player
			local userInfo = PlayerMock.readLookup(mock, "UserService.GetUserInfosByUserIdsAsync", 0)
			if userInfo.Username == username then
				return mock
			end
		end
	end

	return nil
end

--[=[
	Returns the mock currently in the DataModel whose `Character` stand-in is the given model, or
	nil. The mock counterpart of `Players:GetPlayerFromCharacter` -- the resolver for code paths
	that start from a character (or a part of one) with no player value in hand to `isMock`-branch
	on (e.g. [CharacterUtils.getPlayerFromCharacter]):

	```lua
	local player = Players:GetPlayerFromCharacter(model) or PlayerMock.getMockFromCharacter(model)
	```

	Like the engine call, only the exact character model matches -- a descendant part resolves nil,
	so callers walking up from a descendant keep their own ancestor walk -- and only mocks in the
	game resolve (discovery runs over [PlayerMock.TAG], and tag resolution is DataModel-scoped).

	@param character Instance
	@return Player?
]=]
function PlayerMock.getMockFromCharacter(character: Instance): Player?
	assert(typeof(character) == "Instance", "Bad character")

	for _, tagged in CollectionService:GetTagged(MOCK_TAG) do
		if PlayerMock.isMock(tagged) and PlayerMock.read((tagged :: any) :: Player, "Character") == character then
			return (tagged :: any) :: Player
		end
	end

	return nil
end

--[=[
	Reads a stand-in native `Player` property off a mock: the seeded backing attribute, or the
	pre-authored typed default when unset. Errors on anything that is not a [PlayerMock] -- including a
	real `Player` -- so call sites must branch explicitly:

	```lua
	local userId = if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
	```

	Keeping the real-Player read as plain member access preserves luau-lsp's native property typing on
	the hot path instead of funneling every read through this `any`-returning helper.

	@param player Player -- must be a PlayerMock
	@param propertyName string
	@return any
]=]
function PlayerMock.read(player: Player, propertyName: string): any
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(propertyName) == "string", "Bad propertyName")

	local spec = PLAYER_PROPERTIES[propertyName]
	if spec and spec.instanceValued then
		local backing = findPropertyObjectValue(player, propertyName)
		return if backing ~= nil then backing.Value else spec.default
	end

	local raw = (player :: Instance):GetAttribute(propertyName)
	if raw == nil then
		return if spec then spec.default else nil
	end
	if spec and spec.decode then
		return spec.decode(raw)
	end
	return raw
end

--[=[
	Mocks a native `Player` property on a mock by writing its backing attribute, which also fires the
	instance's `GetAttributeChangedSignal(propertyName)` so observers see the change.

	Writing `Character = nil` carries the engine's despawn semantics (the model is destroyed) --
	see [PlayerMock.removeCharacter].

	@param player Player -- must be a PlayerMock
	@param propertyName string
	@param value any
]=]
function PlayerMock.write(player: Player, propertyName: string, value: any)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(propertyName) == "string", "Bad propertyName")

	local spec = PLAYER_PROPERTIES[propertyName]
	if spec and spec.instanceValued then
		assert(
			value == nil or typeof(value) == "Instance",
			string.format("Bad value for Instance-valued %s", propertyName)
		)

		local objectValue = getOrCreatePropertyObjectValue(player, propertyName)
		local oldValue = objectValue.Value

		-- The engine's Character setter despawns on nil: CharacterRemoving fires, the property
		-- nils (so observers tear down while the model is still alive), then the model is
		-- destroyed. Assigning a *different model* does not remove the old one -- the classic
		-- morph pattern destroys it manually.
		if propertyName == "Character" and value == nil and oldValue ~= nil then
			PlayerMock.fireSignal(player, "CharacterRemoving", oldValue)
			objectValue.Value = nil
			oldValue:Destroy()
			return
		end

		objectValue.Value = value
		return
	end

	local encoded = if spec and spec.encode then spec.encode(value) else value

	local instance = player :: Instance
	instance:SetAttribute(propertyName, encoded)
end

--[=[
	Returns the signal that fires when the given stand-in property changes on a mock: the backing
	attribute's changed signal, or the backing ObjectValue's Value-changed signal for Instance-valued
	members like `Character`. Mock-only, like [PlayerMock.read] -- the real-Player path stays
	`player:GetPropertyChangedSignal(propertyName)`.

	@param player Player -- must be a PlayerMock
	@param propertyName string
	@return RBXScriptSignal
]=]
function PlayerMock.getPropertyChangedSignal(player: Player, propertyName: string): RBXScriptSignal
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(propertyName) == "string", "Bad propertyName")

	local spec = PLAYER_PROPERTIES[propertyName]
	if spec and spec.instanceValued then
		return getOrCreatePropertyObjectValue(player, propertyName):GetPropertyChangedSignal("Value")
	end

	return (player :: Instance):GetAttributeChangedSignal(propertyName)
end

-- Prefix for the attributes backing ID-keyed service lookups on a mock (see [PlayerMock.readLookup]).
-- Like the property attributes, the backing lives on the mock itself: inspectable, self-cleaning,
-- and observable via `GetAttributeChangedSignal`.
local LOOKUP_ATTRIBUTE_PREFIX = "PlayerMockLookup_"

type LookupSpec = {
	default: any,
	-- Computes the default from the mock itself instead of `default`, for domains whose truthful
	-- unset answer is the mock's own identity (e.g. user info) rather than a constant.
	getDefault: ((player: Player) -> any)?,
	-- typeof() an injected value must satisfy, so a bad writeLookup fails at the write instead of as
	-- a confusing consumer failure at read time.
	valueType: string,
	-- What the domain is keyed by: an integer ID (the default), an EnumItem (e.g. CoreGuiType),
	-- or a string (e.g. a subscriptionId).
	keyKind: ("EnumItem" | "string")?,
	-- Deeper shape check for table-valued domains, run at write time.
	validate: ((any) -> ())?,
	-- Bridges a value shape a Roblox attribute cannot hold (e.g. a table) to/from a storable one.
	encode: ((any) -> any)?,
	decode: ((any) -> any)?,
}

-- ID-keyed engine calls a mock can stand in for, keyed by the canonical `Service.Method` the
-- production code path bottoms out in -- the interception point is the engine API, not the Nevermore
-- util wrapping it. That keeps the domain greppable against Roblox docs, and it centralizes the
-- injected result per (player, id): every consumer that derives an answer from the same engine call
-- -- a permission provider, an ownership tracker, a direct util call, rank AND role from the same
-- group query -- resolves from the same injected value, so answers can never tear. Defaults are the
-- truthful answer for a fake UserId: not in the group, owns nothing.
local LOOKUPS: { [string]: LookupSpec } = {
	-- GroupService:GetRolesInGroupAsync(userId, groupId) -> { IsMember, Roles = { { Name, Rank } } },
	-- stored as the raw engine result so consumers (GroupUtils.promiseRankInGroup /
	-- promiseRoleInGroup) run their real parsing over it. One entry backs both rank and role so an
	-- injected pair can never disagree.
	["GroupService.GetRolesInGroupAsync"] = {
		default = { IsMember = false, Roles = {} } :: any, -- Roblox's non-member answer
		valueType = "table",
		validate = function(value: any)
			assert(type(value.IsMember) == "boolean", "Bad value.IsMember")
			assert(type(value.Roles) == "table", "Bad value.Roles")
			for _, roleTable in value.Roles do
				assert(type(roleTable.Name) == "string", "Bad role.Name")
				assert(type(roleTable.Rank) == "number", "Bad role.Rank")
			end
		end,
		encode = function(value: any): string
			return HttpService:JSONEncode(value)
		end,
		decode = function(value: any): any
			return HttpService:JSONDecode(value)
		end,
	},
	-- GroupService:GetGroupsAsync(userId) -> { { Id, Rank, Role, ... } }. The engine call is keyed
	-- by userId alone and the injected result already lives on the mock, so the lookup key is
	-- fixed at 0.
	["GroupService.GetGroupsAsync"] = {
		default = {} :: any, -- a fake UserId is in no groups
		valueType = "table",
		validate = function(value: any)
			for _, groupInfo in value do
				assert(type(groupInfo.Id) == "number", "Bad group.Id")
				assert(type(groupInfo.Rank) == "number", "Bad group.Rank")
				assert(type(groupInfo.Role) == "string", "Bad group.Role")
			end
		end,
		encode = function(value: any): string
			return HttpService:JSONEncode(value)
		end,
		decode = function(value: any): any
			return HttpService:JSONDecode(value)
		end,
	},
	-- MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) -> owned
	["MarketplaceService.UserOwnsGamePassAsync"] = { default = false, valueType = "boolean" },
	-- MarketplaceService:PlayerOwnsAsset(player, assetId) -> owned (inventory items: hats, gear, ...)
	["MarketplaceService.PlayerOwnsAsset"] = { default = false, valueType = "boolean" },
	-- MarketplaceService:PlayerOwnsAssetAsync(player, assetId) -> owned (paid access to a game)
	["MarketplaceService.PlayerOwnsAssetAsync"] = { default = false, valueType = "boolean" },
	-- MarketplaceService:PlayerOwnsBundle(player, bundleId) -> owned
	["MarketplaceService.PlayerOwnsBundle"] = { default = false, valueType = "boolean" },
	-- MarketplaceService:PromptGamePassPurchase(player, gamePassId) -> whether the mock "user" accepts
	-- the prompt. The engine cannot prompt a mock, so consumers answer with this decision as if the
	-- engine had fired PromptGamePassPurchaseFinished; a fake user buys nothing by default.
	["MarketplaceService.PromptGamePassPurchase"] = { default = false, valueType = "boolean" },
	-- StarterGui:SetCoreGuiEnabled(coreGuiType, enabled) -- a client-only engine effect. Unlike the
	-- injected web-API lookups above, this domain is written by PRODUCTION code (CoreGuiEnabler
	-- performs the set on the mock local player, there being no CoreGui to affect) and read by tests
	-- to assert the effect. Default true: CoreGui starts enabled on a real client.
	["StarterGui.SetCoreGuiEnabled"] = { default = true, valueType = "boolean", keyKind = "EnumItem" },
	-- Players:GetFriendsAsync(userId) -> FriendPages, stored as the flat FriendData array the pages
	-- iterate ({ Id, Username, DisplayName, IsOnline }). The engine call is keyed by userId alone
	-- and the injected result already lives on the mock, so the lookup key is fixed at 0. Consumers
	-- (FriendUtils.promiseFriendPages) wrap the array back into a pages shape via PagesProxy so
	-- their real page iteration runs unchanged.
	["Players.GetFriendsAsync"] = {
		default = {} :: any, -- a fake UserId has no friends
		valueType = "table",
		validate = function(value: any)
			for _, friendData in value do
				assert(type(friendData.Id) == "number", "Bad friendData.Id")
				assert(type(friendData.Username) == "string", "Bad friendData.Username")
				assert(type(friendData.DisplayName) == "string", "Bad friendData.DisplayName")
				assert(type(friendData.IsOnline) == "boolean", "Bad friendData.IsOnline")
			end
		end,
		encode = function(value: any): string
			return HttpService:JSONEncode(value)
		end,
		decode = function(value: any): any
			return HttpService:JSONDecode(value)
		end,
	},
	-- Player:IsFriendsWithAsync(userId) -> isFriends, keyed by the other player's UserId. The
	-- backing attribute's changed signal (see [PlayerMock.getLookupChangedSignal]) doubles as the
	-- friendship-changed event for observers like RxFriendUtils, so a writeLookup mid-test stands
	-- in for the CoreGui friended/unfriended events.
	["Player.IsFriendsWithAsync"] = { default = false, valueType = "boolean" },
	-- UserService:GetUserInfosByUserIdsAsync({ userId })[1] -> { Id, Username, DisplayName,
	-- HasVerifiedBadge }. Keyed by userId alone like GetGroupsAsync, so the key is fixed at 0. The
	-- default derives from the mock's own identity (`Name` standing in for the username, like a real
	-- Player's) so identity consumers agree with the mock's properties without an injection; the one
	-- entry backs both username and display-name consumers (UserServiceUtils, Players.GetNameFromUserIdAsync
	-- wrappers like PlayerThumbnailUtils.promiseUserName) so an injected pair can never disagree.
	["UserService.GetUserInfosByUserIdsAsync"] = {
		getDefault = function(player: Player)
			return {
				Id = PlayerMock.read(player, "UserId"),
				Username = player.Name,
				DisplayName = PlayerMock.read(player, "DisplayName"),
				HasVerifiedBadge = PlayerMock.read(player, "HasVerifiedBadge"),
			}
		end,
		valueType = "table",
		validate = function(value: any)
			assert(type(value.Id) == "number", "Bad value.Id")
			assert(type(value.Username) == "string", "Bad value.Username")
			assert(type(value.DisplayName) == "string", "Bad value.DisplayName")
			assert(type(value.HasVerifiedBadge) == "boolean", "Bad value.HasVerifiedBadge")
		end,
		encode = function(value: any): string
			return HttpService:JSONEncode(value)
		end,
		decode = function(value: any): any
			return HttpService:JSONDecode(value)
		end,
	},
	-- MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId) -> { IsSubscribed, IsRenewing },
	-- keyed by the subscriptionId string (e.g. "EXP-...").
	["MarketplaceService.GetUserSubscriptionStatusAsync"] = {
		default = { IsSubscribed = false, IsRenewing = false } :: any, -- a fake user subscribes to nothing
		valueType = "table",
		keyKind = "string",
		validate = function(value: any)
			assert(type(value.IsSubscribed) == "boolean", "Bad value.IsSubscribed")
			assert(type(value.IsRenewing) == "boolean", "Bad value.IsRenewing")
		end,
		encode = function(value: any): string
			return HttpService:JSONEncode(value)
		end,
		decode = function(value: any): any
			return HttpService:JSONDecode(value)
		end,
	},
}

local function assertLookupKey(domain: string, spec: LookupSpec, key: any)
	if spec.keyKind == "EnumItem" then
		assert(typeof(key) == "EnumItem", string.format("Bad key for %s lookup (expected EnumItem)", domain))
	elseif spec.keyKind == "string" then
		assert(type(key) == "string" and key ~= "", string.format("Bad key for %s lookup (expected string)", domain))
	else
		assert(type(key) == "number" and key % 1 == 0, "Bad key")
	end
end

local function getLookupAttributeName(domain: string, key: number | EnumItem | string): string
	-- Attribute names cannot contain "." (or any non-word character, e.g. the "-" in a
	-- subscriptionId), so the canonical Service.Method and the key both flatten to word characters.
	local keyName = if typeof(key) == "EnumItem" then (key :: EnumItem).Name else tostring(key)
	keyName = string.gsub(keyName, "[^%w_]", "_")
	return string.format("%s%s_%s", LOOKUP_ATTRIBUTE_PREFIX, (string.gsub(domain, "%.", "_")), keyName)
end

--[=[
	Reads the injected result for an ID-keyed engine call off a mock: the value a test injected
	through [PlayerMock.writeLookup], or the domain's pre-authored default when unset. The domain is
	the canonical `Service.Method` the production code path bottoms out in, validated against the
	pre-authored set so a typo errors instead of silently reading a default.

	Like [PlayerMock.read], this is mock-only and errors on anything else (including a real
	`Player`), so consumers branch explicitly and the real-Player path keeps calling the real
	service:

	```lua
	if PlayerMock.isMock(player) then
		-- same raw result shape the engine call returns, so parsing below runs unchanged
		return PlayerMock.readLookup(player, "GroupService.GetRolesInGroupAsync", groupId)
	end
	return GroupService:GetRolesInGroupAsync(player.UserId, groupId)
	```

	Effect-recording domains (e.g. `StarterGui.SetCoreGuiEnabled`) run the same machinery in the
	other direction: production wrote the value through [PlayerMock.writeLookup], and the test reads
	it here to assert the engine effect.

	@param player Player -- must be a PlayerMock
	@param domain string -- a known lookup domain, e.g. "GroupService.GetRolesInGroupAsync"
	@param key number | EnumItem | string -- what the call is keyed by (groupId, gamePassId, CoreGuiType, subscriptionId, ...)
	@return any
]=]
function PlayerMock.readLookup(player: Player, domain: string, key: number | EnumItem | string): any
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	local spec = LOOKUPS[domain]
	assert(spec ~= nil, string.format("%q is not a known lookup domain", tostring(domain)))
	assertLookupKey(domain, spec, key)

	local raw = (player :: Instance):GetAttribute(getLookupAttributeName(domain, key))
	if raw == nil then
		if spec.getDefault then
			return spec.getDefault(player)
		end
		return spec.default
	end
	if spec.decode then
		return spec.decode(raw)
	end
	return raw
end

--[=[
	Injects the result a mock answers for an ID-keyed engine call, or clears it back to the
	domain default with nil. Because the value is stored on the mock -- one attribute per
	(domain, key) -- every consumer whose answer derives from the same engine call resolves the
	same value, and the write fires the backing attribute's `GetAttributeChangedSignal` so
	observers see the change.

	```lua
	PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", 372, {
		IsMember = true,
		Roles = { { Name = "Admin", Rank = 230 } },
	})
	PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", 12345, true)
	```

	For effect-recording domains (e.g. `StarterGui.SetCoreGuiEnabled`) the writer is production
	code instead: it performs the engine effect on the mock, and the test observes it through
	[PlayerMock.readLookup] or the backing attribute's changed signal.

	@param player Player -- must be a PlayerMock
	@param domain string -- a known lookup domain, e.g. "MarketplaceService.UserOwnsGamePassAsync"
	@param key number | EnumItem | string -- what the call is keyed by (groupId, gamePassId, CoreGuiType, subscriptionId, ...)
	@param value any -- must match the domain's value shape; nil clears back to the default
]=]
function PlayerMock.writeLookup(player: Player, domain: string, key: number | EnumItem | string, value: any)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	local spec = LOOKUPS[domain]
	assert(spec ~= nil, string.format("%q is not a known lookup domain", tostring(domain)))
	assertLookupKey(domain, spec, key)
	assert(
		value == nil or typeof(value) == spec.valueType,
		string.format("Bad value for %s lookup (expected %s)", domain, spec.valueType)
	)
	if value ~= nil and spec.validate then
		spec.validate(value)
	end

	local encoded = if value ~= nil and spec.encode then spec.encode(value) else value

	local instance = player :: Instance
	instance:SetAttribute(getLookupAttributeName(domain, key), encoded)
end

--[=[
	Returns the signal that fires when the injected result for an ID-keyed engine call changes on a
	mock: the backing attribute's changed signal. This lets a production observer treat a mid-test
	[PlayerMock.writeLookup] as the engine's own change event -- e.g. [RxFriendUtils] re-reading
	friendship when the "Player.IsFriendsWithAsync" domain changes, standing in for the CoreGui
	friended/unfriended events a mock can never receive. Mock-only, like [PlayerMock.readLookup].

	@param player Player -- must be a PlayerMock
	@param domain string -- a known lookup domain, e.g. "Player.IsFriendsWithAsync"
	@param key number | EnumItem | string -- what the call is keyed by
	@return RBXScriptSignal
]=]
function PlayerMock.getLookupChangedSignal(
	player: Player,
	domain: string,
	key: number | EnumItem | string
): RBXScriptSignal
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	local spec = LOOKUPS[domain]
	assert(spec ~= nil, string.format("%q is not a known lookup domain", tostring(domain)))
	assertLookupKey(domain, spec, key)

	return (player :: Instance):GetAttributeChangedSignal(getLookupAttributeName(domain, key))
end

--[=[
	Emulates `Player:LoadCharacterAsync()` on a mock. The caller supplies the character model -- e.g.
	`Players:CreateHumanoidModelFromUserId`/`FromDescription` (both work in cloud test runs) or a
	hand-built rig -- or omits it to get a default R15 built from an empty `HumanoidDescription`
	(may yield while the engine builds it).

	The observable sequence encodes the engine's avatar loading event ordering
	(https://devforum.roblox.com/t/avatar-loading-event-ordering-improvements/269607), and
	PlayerMock.spec asserts each step -- correct both together if that understanding is ever
	corrected:

	1. `CharacterRemoving(old)` fires while `Character` still points at the old model and it is
	   still parented -- the event's "just before removal" contract (not part of the announcement)
	2. `Character` nils and the old character is destroyed (see [RxCharacterUtils.observeLastCharacterBrio]'s
	   assumption); nil-before-destroy lets observers tear down while the instance is still alive
	3. the new rig is fully built before any signal fires -- the announcement's "appearance
	   initialized / rig built and scaled" steps; the caller's rig (or the built default) stands in
	4. `Character` is set to the new model (the property `Changed` fires)
	5. the new character is parented to the Workspace
	6. `CharacterAdded(new)` fires -- after both the assignment and the Workspace parenting, per
	   the announcement above (the pre-2019 "not in Workspace yet" gotcha is gone)
	7. `CharacterAppearanceLoaded(new)` fires -- after `CharacterAdded`, with the rig finalized
	8. only then does the call return, mirroring "LoadCharacter returns" ending the announced order

	Per the same announcement, `CharacterAdded` fires only during avatar loading -- which is why a
	plain `PlayerMock.write(player, "Character", model)` deliberately does not fire it.

	Each call also replaces the mock's `Backpack` stand-in with a fresh empty one before any spawn
	signal fires, like the engine does on respawn (minus the StarterPack copy) -- see
	[PlayerMock.getBackpack]. The first call additionally inserts the `StarterGear` stand-in,
	which later spawns keep -- see [PlayerMock.getStarterGear].

	@param player Player -- must be a PlayerMock
	@param character Model? -- the new character; nil builds a default R15 rig
	@return Model
]=]
function PlayerMock.loadCharacterAsync(player: Player, character: Model?): Model
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(character == nil or (typeof(character) == "Instance" and character:IsA("Model")), "Bad character")

	local newCharacter: Model = character
		or Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	newCharacter.Name = player.Name

	-- The Character-nil setter carries the removal semantics: CharacterRemoving -> nil -> destroy
	if PlayerMock.read(player, "Character") ~= nil then
		PlayerMock.write(player, "Character", nil)
	end

	-- Each spawn gets a fresh empty Backpack, like the engine replacing player.Backpack on
	-- respawn (minus the StarterPack copy). Replaced before any spawn signal fires so
	-- CharacterAdded handlers can already reach the new backpack.
	local oldBackpack = PlayerMock.getBackpack(player)
	if oldBackpack ~= nil then
		oldBackpack:Destroy()
	end

	local backpack = Instance.new("Backpack")
	backpack.Parent = player :: Instance

	-- The StarterGear appears alongside the first spawn and then persists -- the engine never
	-- replaces it on respawn (unlike the Backpack), so granted gear survives here too.
	if PlayerMock.getStarterGear(player) == nil then
		local starterGear = Instance.new("StarterGear")
		starterGear.Parent = player :: Instance
	end

	PlayerMock.write(player, "Character", newCharacter)
	newCharacter.Parent = Workspace
	PlayerMock.fireSignal(player, "CharacterAdded", newCharacter)
	PlayerMock.fireSignal(player, "CharacterAppearanceLoaded", newCharacter)

	return newCharacter
end

--[=[
	[PlayerMock.loadCharacterAsync] with a minimal hand-built rig -- an anchored `HumanoidRootPart`
	(the `PrimaryPart`) and a `Humanoid` -- instead of a full R15 built from a `HumanoidDescription`.
	That is the smallest shape character-driven code paths (equip flows, humanoid observers) accept,
	and building it never yields, so specs that only need *a* character spawn instantly:

	```lua
	local character = PlayerMock.loadMinimalCharacterAsync(playerMock)
	```

	@param player Player -- must be a PlayerMock
	@return Model
]=]
function PlayerMock.loadMinimalCharacterAsync(player: Player): Model
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	local character = Instance.new("Model")

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character
	character.PrimaryPart = rootPart

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character

	return PlayerMock.loadCharacterAsync(player, character)
end

--[=[
	Emulates the character being removed with no replacement, i.e. `player.Character = nil`:
	`CharacterRemoving` fires while `Character` still points at the model, `Character` is set to
	nil, and the model is destroyed. No-op when no character is loaded.

	Runs automatically when the mock itself is destroyed, mirroring the engine cleaning up the
	character when its player leaves or is kicked.

	@param player Player -- must be a PlayerMock
]=]
function PlayerMock.removeCharacter(player: Player)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	if PlayerMock.read(player, "Character") ~= nil then
		PlayerMock.write(player, "Character", nil)
	end
end

--[=[
	Returns the mock's current `Backpack` stand-in, or nil before the first spawn -- the engine only
	inserts a player's Backpack when their character spawns. The stand-in is a genuine `Backpack`
	instance parented to the mock (so it is the child named "Backpack", like a real Player's), which
	means production code that observes the backpack's children -- e.g.
	`RxInstanceUtils.observeLastNamedChildBrio(player, "Backpack", "Backpack")` -- works unchanged.

	[PlayerMock.loadCharacterAsync] replaces it with a fresh empty one on every spawn, like the
	engine does on respawn; the test parents `Tool`s into it directly:

	```lua
	local character = PlayerMock.loadCharacterAsync(player, rig)
	local backpack = assert(PlayerMock.getBackpack(player))
	tool.Parent = backpack
	```

	@param player Player -- must be a PlayerMock
	@return Backpack?
]=]
function PlayerMock.getBackpack(player: Player): Backpack?
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	return (player :: Instance):FindFirstChildOfClass("Backpack")
end

--[=[
	Returns the mock's current `StarterGear` stand-in, or nil before the first spawn -- the engine
	only inserts a player's StarterGear alongside their first character spawn. Like the Backpack
	stand-in it is a genuine `StarterGear` instance parented to the mock, so class-based lookups
	(`player:FindFirstChildOfClass("StarterGear")`) work unchanged; unlike the Backpack,
	[PlayerMock.loadCharacterAsync] never replaces it -- the engine keeps a player's StarterGear
	across respawns. Consumers that dot-index `player.StarterGear` resolve it through the usual
	explicit branch:

	```lua
	local starterGear = if PlayerMock.isMock(player)
		then PlayerMock.getStarterGear(player)
		else player.StarterGear
	```

	@param player Player -- must be a PlayerMock
	@return StarterGear?
]=]
function PlayerMock.getStarterGear(player: Player): StarterGear?
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	return (player :: Instance):FindFirstChildOfClass("StarterGear")
end

--[=[
	Returns the mock's `PlayerGui` stand-in, parented at construction -- mirroring the engine
	inserting a player's PlayerGui at join (unlike the Backpack, which only appears at first
	spawn). `PlayerGui` cannot be `Instance.new`'d, so like the mock itself the stand-in is really
	a `Folder` (named "PlayerGui") typed as the native class; consumers resolve it through the
	usual explicit branch instead of `FindFirstChildOfClass`:

	```lua
	local playerGui = if PlayerMock.isMock(player)
		then PlayerMock.getPlayerGui(player)
		else player:FindFirstChildOfClass("PlayerGui")
	```

	[PlayerGuiUtils] branches this way internally, so consumers of it work against a mock without
	changes. Tests parent ScreenGui/Frame surfaces into the stand-in directly.

	@param player Player -- must be a PlayerMock
	@return PlayerGui
]=]
function PlayerMock.getPlayerGui(player: Player): PlayerGui
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	local playerGui: any = assert((player :: Instance):FindFirstChild("PlayerGui"), "No PlayerGui")
	return playerGui :: PlayerGui
end

--[=[
	Returns the mock's `PlayerScripts` stand-in, parented at construction -- mirroring the engine
	inserting a player's PlayerScripts at join, like the PlayerGui stand-in. `PlayerScripts` cannot
	be `Instance.new`'d, so the stand-in is really a `Folder` (named "PlayerScripts") typed as the
	native class. A Folder can never satisfy an `IsA("PlayerScripts")` class filter, so consumers
	observing the child by class resolve it through the usual explicit branch:

	```lua
	local playerScriptsClassName = if PlayerMock.isMock(localPlayer) then "Folder" else "PlayerScripts"
	RxInstanceUtils.observeLastNamedChildBrio(localPlayer, playerScriptsClassName, "PlayerScripts")
	```

	Tests parent script stand-ins (e.g. an `RbxCharacterSounds` `LocalScript`) into it directly.

	@param player Player -- must be a PlayerMock
	@return PlayerScripts
]=]
function PlayerMock.getPlayerScripts(player: Player): PlayerScripts
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	local playerScripts: any = assert((player :: Instance):FindFirstChild("PlayerScripts"), "No PlayerScripts")
	return playerScripts :: PlayerScripts
end

-- Attribute recording the message a mock was kicked with (see [PlayerMock.kick]). Stored on the
-- mock so the record survives the destroy that ends the kick -- a held reference can still read it.
local KICK_MESSAGE_ATTRIBUTE = "PlayerMockKickMessage"

--[=[
	Emulates `Player:Kick(message)` on a mock. Kick is the special case among the stand-ins: a
	*method* whose observable effect is the engine removing the player from the game, not a property
	or event a test seeds -- so the mock really performs the removal sequence instead of merely
	recording the call:

	1. the kick message is recorded (see [PlayerMock.getKickMessage] -- no client exists to show it to)
	2. the character is removed (`CharacterRemoving` fires while `Character` still points at it,
	   `Character` nils, the model is destroyed), mirroring the engine cleaning up a kicked player's
	   character
	3. the mock leaves the DataModel (`Parent = nil`, not a destroy -- a held reference stays
	   readable), so the native `AncestryChanged` signal genuinely fires -- the same way a kicked
	   player's instance leaves `Players`

	`Players.PlayerRemoving` is a `Players`-service event only the engine fires, so consumers of that
	event cannot observe a mock kick; observe `AncestryChanged` instead.

	Production code branches explicitly, like every other mock seam:

	```lua
	if PlayerMock.isMock(player) then
		PlayerMock.kick(player, reason)
	else
		player:Kick(reason)
	end
	```

	@param player Player -- must be a PlayerMock
	@param message string? -- recorded for [PlayerMock.getKickMessage]; nil records ""
]=]
function PlayerMock.kick(player: Player, message: string?)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(message == nil or type(message) == "string", "Bad message")

	local instance = player :: Instance
	instance:SetAttribute(KICK_MESSAGE_ATTRIBUTE, message or "")

	-- Explicitly, rather than via the Destroying hook, so CharacterRemoving observers still see a
	-- live (parented) mock -- the engine removes the character before the player instance goes away.
	PlayerMock.removeCharacter(player)
	instance.Parent = nil
end

--[=[
	Returns the message a mock was kicked with (via [PlayerMock.kick]), or nil when it was never
	kicked. A kick with no message reads back as `""`. Stays readable after the kick destroys the
	mock, as long as the caller holds a reference.

	@param player Player -- must be a PlayerMock
	@return string?
]=]
function PlayerMock.getKickMessage(player: Player): string?
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	local message = (player :: Instance):GetAttribute(KICK_MESSAGE_ATTRIBUTE)
	return if type(message) == "string" then message else nil
end

-- Prefix for the BindableEvent children backing `Player`-class events on a mock (see
-- [PlayerMock.getSignal]). Stored on the mock itself so the backing stays inspectable and
-- self-cleaning, like the attribute-backed properties.
local SIGNAL_NAME_PREFIX = "PlayerMockSignal_"

-- Lazily-built set of the events reflection reports on `Player`, own and inherited alike. Used
-- purely as typo protection; which of the two backings serves a name is decided by
-- findNativeSignal below.
local playerEventNames: { [string]: boolean }? = nil

local function getPlayerEventNames(): { [string]: boolean }
	local names = playerEventNames
	if names ~= nil then
		return names
	end

	local built: { [string]: boolean } = {}
	for _, reflectedEvent in ReflectionService:GetEventsOfClass("Player") :: { any } do
		built[reflectedEvent.Name] = true
	end
	playerEventNames = built
	return built
end

local function isPlayerEvent(eventName: string): boolean
	return getPlayerEventNames()[eventName] == true
end

-- Events the mock's backing Folder inherits from Instance (`AncestryChanged`, `Destroying`, ...)
-- exist natively and genuinely fire; only the rest need a BindableEvent stand-in.
local function findNativeSignal(player: Player, eventName: string): RBXScriptSignal?
	local ok, member = pcall(function()
		return (player :: any)[eventName]
	end)
	if ok and typeof(member) == "RBXScriptSignal" then
		return member
	end

	return nil
end

local function getOrCreateSignalBindable(player: Player, eventName: string): BindableEvent
	local instance = player :: Instance
	local name = SIGNAL_NAME_PREFIX .. eventName

	local existing = instance:FindFirstChild(name)
	if existing ~= nil then
		return existing :: BindableEvent
	end

	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = name
	bindableEvent.Parent = instance
	return bindableEvent
end

--[=[
	Reads a stand-in native `Player` event off a mock: the genuine native signal when the backing
	Folder inherits it from `Instance` (`AncestryChanged`, `Destroying`, ...), otherwise a
	`BindableEvent`-backed signal a test fires through [PlayerMock.fireSignal]. The name is
	validated against the engine's reflected `Player` events, so a typo errors instead of
	returning a signal that can never fire.

	Like [PlayerMock.read], this is mock-only and errors on anything else (including a real
	`Player`), so call sites branch explicitly and the real-Player path stays plain member access:

	```lua
	local chatted = if PlayerMock.isMock(player) then PlayerMock.getSignal(player, "Chatted") else player.Chatted
	```

	@param player Player -- must be a PlayerMock
	@param eventName string
	@return RBXScriptSignal
]=]
function PlayerMock.getSignal(player: Player, eventName: string): RBXScriptSignal
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(eventName) == "string", "Bad eventName")

	-- Events the backing Folder inherits from Instance are genuine -- surface those, not a stand-in.
	local nativeSignal = findNativeSignal(player, eventName)
	if nativeSignal ~= nil then
		return nativeSignal
	end

	assert(isPlayerEvent(eventName), string.format("%q is not an event of Player", eventName))

	return getOrCreateSignalBindable(player, eventName).Event
end

--[=[
	Fires the backing signal for a `Player`-class event on a mock, so code connected through
	[PlayerMock.getSignal] observes the event as if the engine had fired it.

	Only `Player`-class events can be fired; events the backing Folder inherits from `Instance`
	resolve to genuine native signals, which only the engine fires.

	@param player Player -- must be a PlayerMock
	@param eventName string
	@param ... any -- Event arguments delivered to connected handlers.
]=]
function PlayerMock.fireSignal(player: Player, eventName: string, ...: any)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(eventName) == "string", "Bad eventName")
	assert(isPlayerEvent(eventName), string.format("%q is not an event of Player", eventName))
	assert(
		findNativeSignal(player, eventName) == nil,
		string.format("%q is a native signal only the engine fires", eventName)
	)

	-- No backing means no listeners ever connected -- firing would be unobservable. Not creating
	-- one here also keeps this safe while the mock is being destroyed (see removeCharacter), when
	-- parenting a new child would fail.
	local existing = (player :: Instance):FindFirstChild(SIGNAL_NAME_PREFIX .. eventName)
	if existing ~= nil then
		(existing :: BindableEvent):Fire(...)
	end
end

-- Prefix for the BindableFunction children backing ContextActionService action binds on a mock
-- (see [PlayerMock.bindInput]). The bound callback lives on the mock as the backing's OnInvoke
-- handler, so like the other backings it is inspectable and self-cleaning.
local ACTION_NAME_PREFIX = "PlayerMockAction_"

-- The raw Lua callback for each bind, keyed by its marker BindableFunction so [PlayerMock.fireInput]
-- can invoke it *directly*. Firing through the BindableFunction itself (as this once did) crosses the
-- bindable boundary, which strips a stand-in InputObject's methods/signals -- and real handlers read
-- `inputObject:GetPropertyChangedSignal(...)` (e.g. KeymapControls tracking the input's end). Weak keys
-- so an entry drops with its child; also cleared explicitly on unbind/rebind.
local boundActionCallbacks: { [BindableFunction]: (...any) -> ...any } = setmetatable({}, { __mode = "k" }) :: any

local function findActionBindable(player: Player, actionName: string): BindableFunction?
	return (player :: Instance):FindFirstChild(ACTION_NAME_PREFIX .. actionName) :: BindableFunction?
end

local function bindActionCallback(player: Player, actionName: string, functionToBind: any)
	assert(type(functionToBind) == "function", "Bad functionToBind")

	local bindableFunction = findActionBindable(player, actionName)
	if bindableFunction == nil then
		local created = Instance.new("BindableFunction")
		created.Name = ACTION_NAME_PREFIX .. actionName
		created.Parent = player :: Instance
		bindableFunction = created
	end

	boundActionCallbacks[bindableFunction :: BindableFunction] = functionToBind
end

-- Context-restricted input-binding engine calls a mock stands in for, keyed by the canonical
-- `Service.Method` like the LOOKUPS domains. The args after (player, domain, actionName) mirror
-- the engine call's own remaining args, so a production mock branch is the identical call aimed
-- at the mock; each handler validates the args the emulation depends on and discards the rest
-- (touch buttons, priority routing, and input-type routing are not modeled). All bind domains
-- share one action registry per mock -- like the engine's -- so rebinding a name replaces the
-- callback and "ContextActionService.UnbindAction" tears down either bind variant.
local INPUT_DOMAINS: { [string]: (player: Player, actionName: string, ...any) -> () } = {
	-- ContextActionService:BindAction(actionName, functionToBind, createTouchButton, ...inputTypes)
	["ContextActionService.BindAction"] = function(player, actionName, functionToBind)
		bindActionCallback(player, actionName, functionToBind)
	end,
	-- ContextActionService:BindActionAtPriority(actionName, functionToBind, createTouchButton,
	-- priorityLevel, ...inputTypes) -- the priority is required for signature parity, though
	-- with no engine bind stack there is nothing to prioritize against.
	["ContextActionService.BindActionAtPriority"] = function(
		player,
		actionName,
		functionToBind,
		_createTouchButton,
		priorityLevel
	)
		assert(type(priorityLevel) == "number", "Bad priorityLevel")
		bindActionCallback(player, actionName, functionToBind)
	end,
	-- ContextActionService:UnbindAction(actionName) -- like the engine call, unbinding an action
	-- that is not bound is a no-op.
	["ContextActionService.UnbindAction"] = function(player, actionName)
		local bindableFunction = findActionBindable(player, actionName)
		if bindableFunction ~= nil then
			boundActionCallbacks[bindableFunction] = nil
			bindableFunction:Destroy()
		end
	end,
}

--[=[
	Emulates a context-restricted `ContextActionService` call on a mock. The domain is the canonical
	`Service.Method` -- validated against the pre-authored set so a typo errors, like
	[PlayerMock.readLookup] -- and the args after it mirror the engine call's own args, so a
	production mock branch is the identical call aimed at the mock local player (there is no input
	to receive):

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

	A test dispatches a bound action through [PlayerMock.fireInput] as if the engine had routed
	input to it. What the emulation deliberately does not model: touch buttons, priority routing,
	input-type routing, and the engine's bind stack -- all bind domains share one action registry
	per mock (like the engine's), and rebinding a name simply replaces the callback.

	@param player Player -- must be a PlayerMock
	@param domain string -- a known input domain, e.g. "ContextActionService.BindAction"
	@param actionName string
	@param ... any -- the engine call's remaining args, e.g. `functionToBind, createTouchButton, ...inputTypes`
]=]
function PlayerMock.bindInput(player: Player, domain: string, actionName: string, ...: any)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	local handler = INPUT_DOMAINS[domain]
	assert(handler ~= nil, string.format("%q is not a known input domain", tostring(domain)))
	assert(type(actionName) == "string", "Bad actionName")

	handler(player, actionName, ...)
end

--[=[
	Returns whether the given action is currently bound on a mock (via [PlayerMock.bindInput]).
	Keyed by the action name alone -- both bind domains share one action registry, like the engine.

	@param player Player -- must be a PlayerMock
	@param actionName string
	@return boolean
]=]
function PlayerMock.isInputBound(player: Player, actionName: string): boolean
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")

	return findActionBindable(player, actionName) ~= nil
end

--[=[
	Dispatches a bound action on a mock, invoking the bound callback with
	`(actionName, userInputState, inputObject)` -- the argument order the engine uses -- and
	returning its result. Test-side counterpart of [PlayerMock.bindInput], like
	[PlayerMock.fireSignal] is for [PlayerMock.getSignal].

	Errors when the action is not bound: with no engine sink logic modeled, firing an unbound
	action can only be a test mistake (typo'd name, or firing after the production unbind).

	The bound callback is invoked directly (not through the marker BindableFunction), so `inputObject`
	is passed by reference: hand it a real `InputObject`, a plain table of the fields the callback reads
	(`UserInputType`, `Position`, `Delta`, ...), or a [PlayerMock.makeInputObject] stand-in when the
	callback also needs `:GetPropertyChangedSignal(...)` (e.g. a KeymapControls handler).

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
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(actionName) == "string", "Bad actionName")
	assert(
		typeof(userInputState) == "EnumItem" and userInputState.EnumType == Enum.UserInputState,
		"Bad userInputState"
	)

	local bindableFunction =
		assert(findActionBindable(player, actionName), string.format("%q is not a bound action", actionName))

	local callback = boundActionCallbacks[bindableFunction]
	if callback == nil then
		-- Bound before this mock carried a raw callback (or by foreign code): fall back to the bindable.
		return bindableFunction:Invoke(actionName, userInputState, inputObject)
	end

	return callback(actionName, userInputState, inputObject)
end

--[=[
	Builds a stand-in `InputObject` for [PlayerMock.fireInput] to hand a bound action -- for handlers
	that read more than the raw fields, in particular `:GetPropertyChangedSignal("UserInputState")`
	(KeymapControls connects it to learn when the press ends). A real `InputObject` cannot be
	`Instance.new`'d, so this is a plain table exposing the fields and that one method; drive the press
	lifecycle with `:SetUserInputState(...)`, which updates the field and fires the signal.

	```lua
	local input = PlayerMock.makeInputObject({ UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonA })
	PlayerMock.fireInput(mock, actionName, Enum.UserInputState.Begin, input)
	input:SetUserInputState(Enum.UserInputState.End) -- releases the press
	```

	@param props { UserInputType: Enum.UserInputType?, KeyCode: Enum.KeyCode?, UserInputState: Enum.UserInputState?, Position: Vector3?, Delta: Vector3? }?
	@return table -- an InputObject stand-in
]=]
function PlayerMock.makeInputObject(props: {
	UserInputType: Enum.UserInputType?,
	KeyCode: Enum.KeyCode?,
	UserInputState: Enum.UserInputState?,
	Position: Vector3?,
	Delta: Vector3?,
}?): any
	local resolved = props or {}
	assert(
		resolved.UserInputType == nil
			or (typeof(resolved.UserInputType) == "EnumItem" and resolved.UserInputType.EnumType == Enum.UserInputType),
		"Bad UserInputType"
	)

	-- One lightweight signal per observed property (only UserInputState is driven today). A local
	-- implementation keeps player-mock free of a Signal dependency; it exposes the Connect/Disconnect
	-- shape a Maid accepts.
	local signals: { [string]: any } = {}
	local function signalFor(propertyName: string)
		local signal = signals[propertyName]
		if signal then
			return signal
		end

		local connections: { [(...any) -> ()]: boolean } = {}
		signal = {
			Connect = function(_self, callback)
				connections[callback] = true
				return {
					Connected = true,
					Disconnect = function(self)
						self.Connected = false
						connections[callback] = nil
					end,
				}
			end,
			Fire = function(_self, ...)
				for callback in connections do
					callback(...)
				end
			end,
		}
		signals[propertyName] = signal
		return signal
	end

	local inputObject: any = {
		UserInputType = resolved.UserInputType or Enum.UserInputType.Keyboard,
		KeyCode = resolved.KeyCode or Enum.KeyCode.None,
		UserInputState = resolved.UserInputState or Enum.UserInputState.Begin,
		Position = resolved.Position or Vector3.zero,
		Delta = resolved.Delta or Vector3.zero,
	}

	function inputObject.GetPropertyChangedSignal(_self, propertyName: string)
		assert(type(propertyName) == "string", "Bad propertyName")
		return signalFor(propertyName)
	end

	function inputObject.SetUserInputState(self, userInputState: Enum.UserInputState)
		assert(
			typeof(userInputState) == "EnumItem" and userInputState.EnumType == Enum.UserInputState,
			"Bad userInputState"
		)
		self.UserInputState = userInputState
		signalFor("UserInputState"):Fire()
	end

	return inputObject
end

-- ObjectValue child standing in for the client-global `GuiService.SelectedObject` (gamepad/keyboard
-- focus). A headless server has no PlayerGui, so the engine refuses `GuiService.SelectedObject = obj`
-- ("not a descendant of a PlayerGui"); selection code branches to store/read it on the mock local
-- player instead, which is inspectable and self-cleaning like the other backings. Global focus maps to
-- the single mocked local player.
local SELECTED_GUI_OBJECT_NAME = "PlayerMockSelectedGuiObject"

local function getOrCreateSelectedGuiObjectValue(player: Player): ObjectValue
	local existing = (player :: Instance):FindFirstChild(SELECTED_GUI_OBJECT_NAME)
	if existing ~= nil then
		return existing :: ObjectValue
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = SELECTED_GUI_OBJECT_NAME
	objectValue.Parent = player :: Instance
	return objectValue
end

--[=[
	Sets the mock's stand-in for `GuiService.SelectedObject` (or clears it with nil). Selection code
	branches to this when the local player is a mock, since the engine's `GuiService.SelectedObject`
	rejects any object not under a real PlayerGui (which a headless run has none of):

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer ~= nil and PlayerMock.isMock(localPlayer) then
		PlayerMock.setSelectedGuiObject(localPlayer, button)
	else
		GuiService.SelectedObject = button
	end
	```

	@param player Player -- must be a PlayerMock
	@param guiObject GuiObject? -- the focused object, or nil to clear
]=]
function PlayerMock.setSelectedGuiObject(player: Player, guiObject: GuiObject?)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(guiObject == nil or (typeof(guiObject) == "Instance" and guiObject:IsA("GuiObject")), "Bad guiObject")

	getOrCreateSelectedGuiObjectValue(player).Value = guiObject
end

--[=[
	Reads the mock's stand-in for `GuiService.SelectedObject`, or nil when nothing is selected. The
	read side of the same branch as [PlayerMock.setSelectedGuiObject].

	@param player Player -- must be a PlayerMock
	@return GuiObject?
]=]
function PlayerMock.getSelectedGuiObject(player: Player): GuiObject?
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	local objectValue = (player :: Instance):FindFirstChild(SELECTED_GUI_OBJECT_NAME)
	return if objectValue ~= nil then (objectValue :: ObjectValue).Value :: GuiObject? else nil
end

--[=[
	Returns the signal that fires when the mock's stand-in for `GuiService.SelectedObject` changes --
	the backing ObjectValue's Value-changed signal. Lets a test (or a production observer that mirrors
	`GuiService:GetPropertyChangedSignal("SelectedObject")`) react to selection moving.

	@param player Player -- must be a PlayerMock
	@return RBXScriptSignal
]=]
function PlayerMock.getSelectedGuiObjectChangedSignal(player: Player): RBXScriptSignal
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	return getOrCreateSelectedGuiObjectValue(player):GetPropertyChangedSignal("Value")
end

--[=[
	Designates a mock as the local player for the client realm (or clears it with nil). Read through
	[PlayerMock.getMockedLocalPlayer] by client code falling back from `Players.LocalPlayer`.

	Call this directly *before* booting bags to pre-designate -- matching production, where
	`Players.LocalPlayer` exists before any service runs -- and a booting [PlayerMockServiceClient]
	adopts the designation as its local player and owns its cleanup. After boot, designate through
	[PlayerMockServiceClient.SetLocalPlayer] instead, which records the designation per simulated
	client.

	The mock must be parented into the DataModel first: the designation is carried as a
	CollectionService tag, and `GetTagged` only resolves parented instances -- an unparented
	designation would silently read back as nil.

	@param player Player? -- must be a PlayerMock in the DataModel, or nil to clear
]=]
function PlayerMock.setMockedLocalPlayer(player: Player?)
	assert(player == nil or PlayerMock.isMock(player), "Not a PlayerMock")
	assert(
		player == nil or (player :: Instance):IsDescendantOf(game),
		"PlayerMock must be parented into the DataModel to be designated the local player"
	)

	-- Only one mock can be the local player at a time.
	for _, tagged in CollectionService:GetTagged(LOCAL_PLAYER_TAG) do
		CollectionService:RemoveTag(tagged, LOCAL_PLAYER_TAG)
	end

	if player ~= nil then
		CollectionService:AddTag(player :: Instance, LOCAL_PLAYER_TAG)
	end
end

--[=[
	Returns the mock designated as the local player (via [PlayerMockServiceClient]), or nil. This is
	only ever the mock -- there is deliberately no helper that resolves the real `Players.LocalPlayer`,
	so call sites fall back explicitly and the real read stays visible to luau-lsp:

	```lua
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	```

	@return Player?
]=]
function PlayerMock.getMockedLocalPlayer(): Player?
	local tagged = CollectionService:GetTagged(LOCAL_PLAYER_TAG)[1]
	if tagged ~= nil and PlayerMock.isMock(tagged) then
		return (tagged :: any) :: Player
	end

	return nil
end

return PlayerMock
