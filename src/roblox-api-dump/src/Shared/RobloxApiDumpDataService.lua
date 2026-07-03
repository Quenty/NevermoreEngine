--!strict
--[=[
    @class RobloxApiDumpDataService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")
local RobloxApiDataTypes = require("RobloxApiDataTypes")
local RobloxApiDump = require("RobloxApiDump")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local RobloxApiDumpDataService = {}
RobloxApiDumpDataService.ServiceName = "RobloxApiDumpDataService"

export type RobloxApiDumpDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_promiseApiDumpCallbackValue: ValueObject.ValueObject<RobloxApiDump.PromiseDumpCallback?>,
		_robloxApiDump: RobloxApiDump.RobloxApiDump?,
	},
	{} :: typeof({ __index = RobloxApiDumpDataService })
))

function RobloxApiDumpDataService.Init(self: RobloxApiDumpDataService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._promiseApiDumpCallbackValue = self._maid:Add(ValueObject.new(nil))
end

--[=[
	Returns the Roblox API dump, which is cached for the lifetime of this service. This will error if no promiseApiDumpCallback
	has been set.

	@return RobloxApiDump
]=]
function RobloxApiDumpDataService.GetRobloxApiDump(self: RobloxApiDumpDataService): RobloxApiDump.RobloxApiDump
	if self._robloxApiDump then
		return self._robloxApiDump
	end

	self._robloxApiDump = self._maid:Add(RobloxApiDump.new(function()
		local callback = self._promiseApiDumpCallbackValue.Value
		if callback then
			return callback()
		else
			error("No promiseApiDumpCallback set on RobloxApiDumpDataService")
		end
	end))
	assert(self._robloxApiDump, "Typechecking assertion")

	return self._robloxApiDump
end

function RobloxApiDumpDataService.PromiseRawApiDump(
	self: RobloxApiDumpDataService
): Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>
	return self:GetRobloxApiDump():PromiseRawDump()
end

--[=[
	Sets the promise dump callback which will be used to retrieve the Roblox API dump. This should only be set once, and will be cached for the lifetime of this service.

	@param promiseApiDump RobloxApiDump.PromiseDumpCallback
	@return () -> () -- Function to clear the callback
]=]
function RobloxApiDumpDataService.SetPromiseApiDump(
	self: RobloxApiDumpDataService,
	promiseApiDump: RobloxApiDump.PromiseDumpCallback
): () -> ()
	return self._promiseApiDumpCallbackValue:SetValue(promiseApiDump)
end

function RobloxApiDumpDataService.Destroy(self: RobloxApiDumpDataService)
	self._maid:DoCleaning()
end

return RobloxApiDumpDataService
