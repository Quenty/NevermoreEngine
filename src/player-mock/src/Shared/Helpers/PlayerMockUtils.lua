--!strict
--[=[
	Mock identity: recognizing one, and finding the ones in the DataModel. Tag resolution is
	DataModel-scoped, so a mock is discoverable the moment it is parented in.

	Every other helper guards its arguments with [PlayerMockUtils.isMock], so this module stays a leaf
	-- discovery keyed by a value only another helper can read lives with that helper instead (see
	[PlayerMockPlayerServiceUtils.getPlayerByUserId] and
	[PlayerMockCharacterUtils.getMockFromCharacter]).

	@class PlayerMockUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMockConstants = require("PlayerMockConstants")

-- Never torn down: they mirror the place-wide tag channel, not any one subscription.
local mockAddedBindable: BindableEvent? = nil
local mockRemovingBindable: BindableEvent? = nil

local PlayerMockUtils = {}

--[=[
	Requiring the backing Folder rejects a foreign instance merely carrying the tag.

	Use [PlayerMock.isMock].

	@param value any
	@return boolean
]=]
function PlayerMockUtils.isMock(value: any): boolean
	return typeof(value) == "Instance"
		and value:IsA("Folder")
		and CollectionService:HasTag(value, PlayerMockConstants.MOCK_TAG)
end

--[=[
	Like the engine call it walks from the parent, so `instance` itself is never returned.

	Use [PlayerMock.findFirstAncestorMock].

	@param instance Instance
	@return Player?
]=]
function PlayerMockUtils.findFirstAncestorMock(instance: Instance): Player?
	assert(typeof(instance) == "Instance", "Bad instance")

	local ancestor = instance.Parent
	while ancestor ~= nil do
		if PlayerMockUtils.isMock(ancestor) then
			return (ancestor :: any) :: Player
		end
		ancestor = ancestor.Parent
	end

	return nil
end

--[=[
	Returns the mocks currently in the DataModel.

	Use [PlayerMock.getMocks].

	@return { Player }
]=]
function PlayerMockUtils.getMocks(): { Player }
	local mocks: { Player } = {}
	for _, tagged in CollectionService:GetTagged(PlayerMockConstants.MOCK_TAG) do
		if PlayerMockUtils.isMock(tagged) then
			table.insert(mocks, (tagged :: any) :: Player)
		end
	end

	return mocks
end

--[=[
	The [PlayerMockUtils.isMock] guard is applied before the signal fires, so it only ever hands back
	a genuine mock.

	Use [PlayerMock.getMockAddedSignal].

	@return RBXScriptSignal
]=]
function PlayerMockUtils.getMockAddedSignal(): RBXScriptSignal
	local bindable = mockAddedBindable
	if bindable == nil then
		bindable = Instance.new("BindableEvent")
		mockAddedBindable = bindable

		CollectionService:GetInstanceAddedSignal(PlayerMockConstants.MOCK_TAG):Connect(function(instance)
			if PlayerMockUtils.isMock(instance) then
				(bindable :: BindableEvent):Fire((instance :: any) :: Player)
			end
		end)
	end

	return (bindable :: BindableEvent).Event
end

--[=[
	Fires whether the mock was destroyed or merely unparented.

	Use [PlayerMock.getMockRemovingSignal].

	@return RBXScriptSignal
]=]
function PlayerMockUtils.getMockRemovingSignal(): RBXScriptSignal
	local bindable = mockRemovingBindable
	if bindable == nil then
		bindable = Instance.new("BindableEvent")
		mockRemovingBindable = bindable

		CollectionService:GetInstanceRemovedSignal(PlayerMockConstants.MOCK_TAG):Connect(function(instance)
			if PlayerMockUtils.isMock(instance) then
				(bindable :: BindableEvent):Fire((instance :: any) :: Player)
			end
		end)
	end

	return (bindable :: BindableEvent).Event
end

--[=[
	Returns the mock designated as the local player, or nil.

	Use [PlayerMock.getMockedLocalPlayer].

	@return Player?
]=]
function PlayerMockUtils.getMockedLocalPlayer(): Player?
	local tagged = CollectionService:GetTagged(PlayerMockConstants.LOCAL_PLAYER_TAG)[1]
	if tagged ~= nil and PlayerMockUtils.isMock(tagged) then
		return (tagged :: any) :: Player
	end

	return nil
end

--[=[
	Observes the mock designated as the local player (see [PlayerMock.setMockedLocalPlayer]), emitting
	the current designation on subscribe and again whenever it changes. This replaces one-shot reading
	[PlayerMock.getMockedLocalPlayer], which goes stale when a test designates after the consumer
	initializes (designation is only required before bags Start, not before Init). Like the getter,
	this only ever emits the mock -- the real `Players.LocalPlayer` fallback stays an explicit read at
	the call site.

	Re-designating from one mock to another emits nil in between: the designation is carried as a
	CollectionService tag on the mock, and the switch removes the old tag before adding the new one.

	@return Observable<Player?>
]=]
function PlayerMockUtils.observeMockedLocalPlayer(): Observable.Observable<Player?>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function update()
			sub:Fire(PlayerMockUtils.getMockedLocalPlayer())
		end

		maid:GiveTask(CollectionService:GetInstanceAddedSignal(PlayerMockConstants.LOCAL_PLAYER_TAG):Connect(update))
		maid:GiveTask(CollectionService:GetInstanceRemovedSignal(PlayerMockConstants.LOCAL_PLAYER_TAG):Connect(update))
		update()

		return maid
	end) :: any
end

return PlayerMockUtils
