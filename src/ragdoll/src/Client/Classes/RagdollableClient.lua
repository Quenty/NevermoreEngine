--!strict
--[=[
	Initialize via [RagdollServiceClient].

	@client
	@class RagdollableClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Observable = require("Observable")
local RagdollClient = require("RagdollClient")
local RagdollableBase = require("RagdollableBase")
local RagdollableInterface = require("RagdollableInterface")
local Rx = require("Rx")
local RxRagdollUtils = require("RxRagdollUtils")
local ServiceBag = require("ServiceBag")

local RagdollableClient = setmetatable({}, RagdollableBase)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

export type RagdollableClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: Binder.Binder<RagdollClient.RagdollClient>,
		},
		{} :: typeof({ __index = RagdollableClient })
	))
	& RagdollableBase.RagdollableBase

--[=[
	Constructs a new RagdollableClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollableClient
]=]
function RagdollableClient.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RagdollableClient
	local self: RagdollableClient = setmetatable(RagdollableBase.new(humanoid) :: any, RagdollableClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	self._maid:GiveTask(self._ragdollBinder:Observe(self._obj :: Instance):Subscribe(function(ragdoll)
		self:_onRagdollChanged(ragdoll)
	end))

	self._maid:GiveTask((RagdollableInterface :: any).Client:Implement(self._obj :: Instance, self))

	return self
end

function RagdollableClient.ObserveIsRagdolled(self: RagdollableClient): Observable.Observable<boolean>
	return (self._ragdollBinder:Observe(self._obj :: Instance) :: any):Pipe({
		Rx.map(function(value): any
			return value and true or false
		end),
	})
end

function RagdollableClient._onRagdollChanged(self: RagdollableClient, ragdoll: any): ()
	if ragdoll then
		self._maid._ragdoll = RxRagdollUtils.runLocal(self._obj :: Humanoid)
	else
		self._maid._ragdoll = nil
	end
end

return Binder.new("Ragdollable", RagdollableClient :: any) :: Binder.Binder<RagdollableClient>
