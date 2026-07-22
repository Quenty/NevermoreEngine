--!strict
--[=[
	Shared behavior for [PlayerMockService] (server realm) and [PlayerMockServiceClient] (client
	realm): the place-wide discovery surface, and mock consumption -- the leak detection between
	sequential tests in the shared place.

	Every mock a service observes -- alive at [PlayerMockServiceBase.Init], or parented later -- is
	marked as consumed in the service's realm, and the mark carries the consuming service's identity.
	Observing a mock whose consumer has since been destroyed is an error: the mock outlived the
	service that consumed it, which means it leaked from an earlier test. Because consumption replaces
	asserting an empty place at Init, mocks may be created (and the local player designated) *before*
	bags boot -- matching production, where `Players.LocalPlayer` exists before any service runs.

	Only one server-realm service may be alive at a time, while multiple client-realm services
	(simulated clients) may coexist -- so the client service tolerates marks from live concurrent
	consumers and the server service treats them as an error. A mock never observed by any mock
	service carries no mark and is not protected; the batch runner's between-package sweep is the
	backstop there.

	@class PlayerMockServiceBase
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local CONSUMER_TOKEN_TAG = "PlayerMockConsumerToken"

local PlayerMockServiceBase = {}

--[=[
	Initializes the service and begins consuming every mock in the place. Deriving services must
	define `ServiceName`, `_consumedAttributeName`, and `_allowConcurrentConsumers` as static fields.

	@param serviceBag ServiceBag
]=]
function PlayerMockServiceBase:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self:_startConsumingMocks()
end

function PlayerMockServiceBase:Start() end

--[=[
	Returns the mocks currently in the place. Mirrors `Players:GetPlayers()` -- the same answer from
	any ServiceBag in either realm -- so infrastructure that sweeps existing players (e.g. a binder
	unbinding on disable) can sweep the mocks the same way.

	@return { Player }
]=]
function PlayerMockServiceBase:GetPlayerMocks(): { Player }
	local players = {}
	for _, tagged in CollectionService:GetTagged(PlayerMock.TAG) do
		if PlayerMock.isMock(tagged) then
			table.insert(players, (tagged :: any) :: Player)
		end
	end
	return players
end

--[=[
	Observes every mock in the place -- those already alive and those parented later, from any bag in
	either realm -- emitting each mock once. Mirrors how `Players.PlayerAdded` +
	`Players:GetPlayers()` are consumed, so a PlayerBinder can treat mocks like real joins.

	@return Observable<Player>
]=]
function PlayerMockServiceBase:ObservePlayerMocks(): Observable.Observable<Player>
	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(CollectionService:GetInstanceAddedSignal(PlayerMock.TAG):Connect(function(instance)
			if PlayerMock.isMock(instance) then
				if sub:IsPending() then
					sub:Fire((instance :: any) :: Player)
				end
			end
		end))

		for _, tagged in CollectionService:GetTagged(PlayerMock.TAG) do
			if PlayerMock.isMock(tagged) then
				task.spawn(function()
					sub:Fire((tagged :: any) :: Player)
				end)
			end
		end

		return maid
	end) :: any
end

function PlayerMockServiceBase:_startConsumingMocks()
	self._consumerId = HttpService:GenerateGUID(false)

	-- A leak detected in this sweep throws out of Init; unwind any tokens already parented into
	-- earlier mocks so nothing is left behind for the next test.
	local ok, err = pcall(function()
		for _, tagged in CollectionService:GetTagged(PlayerMock.TAG) do
			if PlayerMock.isMock(tagged) then
				self:_consumeMock(tagged)
			end
		end
	end)
	if not ok then
		self._maid:DoCleaning()
		error(err, 0)
	end

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(PlayerMock.TAG):Connect(function(instance)
		if PlayerMock.isMock(instance) then
			self:_consumeMock(instance)
		end
	end))
end

function PlayerMockServiceBase:_consumeMock(mock: Instance)
	local existing = mock:GetAttribute(self._consumedAttributeName)
	if existing == nil then
		mock:SetAttribute(self._consumedAttributeName, self._consumerId)

		-- The liveness token outlives module copies (batch places load PlayerMock more than once per
		-- realm), so consumer identity rides the DataModel with the mock it consumed. It dies with
		-- the service (maid) or with the mock (parent), whichever goes first.
		local token = Instance.new("Configuration")
		token.Name = "PlayerMockConsumer"
		token:SetAttribute("ConsumerId", self._consumerId)
		CollectionService:AddTag(token, CONSUMER_TOKEN_TAG)
		token.Parent = mock
		self._maid:GiveTask(token)
		return
	end

	if existing == self._consumerId then
		return
	end

	if PlayerMockServiceBase._isConsumerAlive(existing :: string) then
		if self._allowConcurrentConsumers then
			return
		end

		error(
			string.format(
				"[%s] - Two %ss are alive at once (mock %s is already consumed); only one may exist at a time",
				self.ServiceName,
				self.ServiceName,
				mock:GetFullName()
			)
		)
	end

	error(
		string.format(
			"[%s] - PlayerMock %s leaked from a previous test (it outlived the %s that consumed it) -- destroy every mock a test creates",
			self.ServiceName,
			mock:GetFullName(),
			self.ServiceName
		)
	)
end

function PlayerMockServiceBase._isConsumerAlive(consumerId: string): boolean
	for _, token in CollectionService:GetTagged(CONSUMER_TOKEN_TAG) do
		if token:GetAttribute("ConsumerId") == consumerId then
			return true
		end
	end

	return false
end

function PlayerMockServiceBase:Destroy()
	self._maid:DoCleaning()
end

return PlayerMockServiceBase
