--!strict
--[=[
	Centralized provider for the parent that ScreenGuis mount into. Defaults to the local player's
	PlayerGui -- including a [PlayerMock] designated as the local player, even when the designation
	happens after this service initializes -- so tests "just work". Hoarcekat stories and tests can
	still override the parent explicitly with [ScreenGuiService.SetGuiParent].

	@client
	@class ScreenGuiService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerGuiUtils = require("PlayerGuiUtils")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local ScreenGuiService = {}
ScreenGuiService.ServiceName = "ScreenGuiService"
ScreenGuiService._hackPlayerGui = nil :: any?

export type ScreenGuiService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_guiParent: ValueObject.ValueObject<Instance?>,
	},
	{} :: typeof({ __index = ScreenGuiService })
))

--[=[
	Initializes the ScreenGuiService

	@param serviceBag ServiceBag
]=]
function ScreenGuiService.Init(self: ScreenGuiService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

--[=[
	Gets the current gui parent to use. When no explicit parent is set (see
	[ScreenGuiService.SetGuiParent]), falls back to the local player's PlayerGui -- resolved at call
	time, so a [PlayerMock] designated after this service initialized is still honored.

	return Instance?
]=]
function ScreenGuiService.GetGuiParent(self: ScreenGuiService): Instance?
	self:_ensureInit()

	return self._guiParent.Value or PlayerGuiUtils.findPlayerGui()
end

--[=[
	Sets the current playerGui to use, overriding the PlayerGui default. The returned task clears
	the override (restoring the default) if it is still ours.

	@param playerGui PlayerGui | Instance
	return MaidTask
]=]
function ScreenGuiService.SetGuiParent(self: ScreenGuiService, playerGui: Instance?): () -> ()
	self:_ensureInit()

	self._guiParent.Value = playerGui

	return function()
		if self._guiParent.Value == playerGui then
			self._guiParent.Value = nil
		end
	end
end

--[=[
	Observes the gui parent to parent stuff into. Emits the explicitly set parent when there is one
	(see [ScreenGuiService.SetGuiParent]), otherwise follows the local player's PlayerGui --
	including a [PlayerMock] designated as the local player after subscription.

	return Observable<Instance?>
]=]
function ScreenGuiService.ObservePlayerGui(self: ScreenGuiService): Observable.Observable<ScreenGui?>
	self:_ensureInit()

	return (self._guiParent :: any):Observe():Pipe({
		Rx.switchMap(function(guiParent: Instance?)
			if guiParent ~= nil then
				return Rx.of(guiParent) :: any
			end

			return PlayerGuiUtils.observePlayerGui()
		end) :: any,
	}) :: any
end

function ScreenGuiService._ensureInit(self: ScreenGuiService): ()
	assert(self :: any ~= ScreenGuiService, "Cannot call directly, use serviceBag")

	if not self._maid then
		local maid = Maid.new()
		self._maid = maid
		-- Holds only the explicit override; the PlayerGui default is resolved lazily in
		-- GetGuiParent/ObservePlayerGui so a PlayerMock designated after init is picked up.
		self._guiParent = maid:Add(ValueObject.new(nil :: Instance?))

		-- TODO: Don't do this? But what's the alternative..
		if not RunService:IsRunning() then
			-- The shared value object outlives any one service bag; a destroyed one (its bag tore
			-- down) has lost its methods, so adopt ours as the new shared parent instead.
			local hackPlayerGui = ScreenGuiService._hackPlayerGui
			if hackPlayerGui and type((hackPlayerGui :: any).Observe) == "function" then
				self._guiParent:Mount(hackPlayerGui:Observe())
			else
				ScreenGuiService._hackPlayerGui = self._guiParent
			end
		end
	end
end

--[=[
	Cleans up the ScreenGuiService
]=]
function ScreenGuiService.Destroy(self: ScreenGuiService): ()
	if ScreenGuiService._hackPlayerGui == self._guiParent then
		ScreenGuiService._hackPlayerGui = nil
	end

	self._maid:DoCleaning()
end

return ScreenGuiService
