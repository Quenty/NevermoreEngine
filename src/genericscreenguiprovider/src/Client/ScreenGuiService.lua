--!strict
--[=[
	Centralized provider so Hoarcekat stories can bootstrap in a fake PlayerGui

	@client
	@class ScreenGuiService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerGuiUtils = require("PlayerGuiUtils")
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
	Gets the current player gui to use

	return ScreenGui?
]=]
function ScreenGuiService.GetGuiParent(self: ScreenGuiService): Instance?
	self:_ensureInit()

	return self._guiParent.Value
end

--[=[
	Sets the current playerGui to use

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
	Observes the player gui to parent stuff into

	return Observable<ScreenGui?>
]=]
function ScreenGuiService.ObservePlayerGui(self: ScreenGuiService): Observable.Observable<ScreenGui?>
	self:_ensureInit()

	return (self._guiParent :: any):Observe()
end

function ScreenGuiService._ensureInit(self: ScreenGuiService): ()
	assert(self :: any ~= ScreenGuiService, "Cannot call directly, use serviceBag")

	if not self._maid then
		local maid = Maid.new()
		self._maid = maid
		self._guiParent = maid:Add(ValueObject.new(PlayerGuiUtils.findPlayerGui() :: Instance?))

		-- TODO: Don't do this? But what's the alternative..
		if not RunService:IsRunning() then
			if ScreenGuiService._hackPlayerGui then
				self._guiParent:Mount(ScreenGuiService._hackPlayerGui:Observe())
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
	self._maid:DoCleaning()
end

return ScreenGuiService
